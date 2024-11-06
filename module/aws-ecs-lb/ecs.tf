locals {
  healthchecks = { for d in var.deployments : d.name => {
    command = ["CMD-SHELL", <<-EOF
wget --no-verbose \
        --tries=1 \
        --spider \
        --server-response \
        http://localhost:8080/health 2>&1 | grep -q "HTTP/1.1 2" || exit 1
EOF
    ]
    interval    = 30
    timeout     = 5
    retries     = 3
    startPeriod = 10
  } }
}
resource "aws_ecs_task_definition" "app" {
  for_each                 = { for d in var.deployments : d.name => d }
  family                   = "healthy-healthchecks"
  requires_compatibilities = ["FARGATE"]
  network_mode             = "awsvpc"
  cpu                      = 256
  memory                   = 512
  execution_role_arn       = aws_iam_role.ecs_execution_role.arn
  container_definitions = jsonencode([
    {
      name  = each.value.name
      image = "${aws_ecr_repository.healthy-healthchecks.repository_url}:${each.value.local-docker-image}"
      portMappings = [
        {
          containerPort = 8080
          protocol      = "tcp"
        }
      ]

      environment = [
        {
          "name" : "HEALTHY_AFTER_DURATION",
          "value" : each.value.healthy-after-duration
        },
        {

          "name" : "UNHEALTHY_AFTER_DURATION",
          "value" : each.value.unhealthy-after-duration
        }
      ]
      logConfiguration = {
        logDriver = "awslogs"
        options = {
          "awslogs-group"         = "/ecs/healthy-healthchecks"
          "awslogs-region"        = data.aws_region.current.name
          "awslogs-stream-prefix" = each.value.name
        }
      }
      healthCheck = each.value.with-ecs-healthcheck ? local.healthchecks[each.value.name] : null
    }
  ])

  depends_on = [null_resource.docker_build]
}

resource "aws_cloudwatch_log_group" "ecs" {
  name              = "/ecs/healthy-healthchecks"
  retention_in_days = 30
}

resource "aws_iam_role" "ecs_execution_role" {
  name = "ecs_execution_role"
  assume_role_policy = jsonencode({
    Version = "2012-10-17"
    Statement = [
      {
        Action = "sts:AssumeRole"
        Effect = "Allow"
        Principal = {
          Service = "ecs-tasks.amazonaws.com"
        }
      }
    ]
  })
}

resource "aws_iam_role_policy" "kms_policy" {
  name = "kms_policy"
  role = aws_iam_role.ecs_execution_role.id

  policy = jsonencode({
    Version = "2012-10-17"
    Statement = [
      {
        Effect = "Allow"
        Action = [
          "kms:Decrypt",
          "kms:GenerateDataKey"
        ]
        Resource = aws_kms_key.ecr_key.arn
      }
    ]
  })
}

resource "aws_iam_role_policy_attachment" "ecs_execution_role_policy" {
  role       = aws_iam_role.ecs_execution_role.name
  policy_arn = "arn:aws:iam::aws:policy/service-role/AmazonECSTaskExecutionRolePolicy"
}

resource "aws_ecs_service" "app" {
  for_each        = { for d in var.deployments : d.name => d }
  name            = each.value.name
  cluster         = aws_ecs_cluster.main.id
  task_definition = aws_ecs_task_definition.app[each.key].arn
  desired_count   = 1
  launch_type     = "FARGATE"

  network_configuration {
    subnets          = aws_subnet.public[*].id
    assign_public_ip = true
    security_groups  = [aws_security_group.ecs_tasks.id]
  }

  load_balancer {
    target_group_arn = aws_lb_target_group.app[each.key].arn
    container_name   = each.value.name
    container_port   = 8080
  }
}


resource "aws_security_group" "ecs_tasks" {
  name        = "ecs-tasks-sg"
  description = "Security group for ECS tasks"
  vpc_id      = aws_vpc.main.id

  ingress {
    description = "Allow port 80 on the deloyers current IP address"
    protocol    = "tcp"
    from_port   = 80
    to_port     = 80
    cidr_blocks = ["${data.http.my_public_ip.response_body}/32"]
  }

  ingress {
    description     = "Allow ALB"
    protocol        = "tcp"
    from_port       = 8080
    to_port         = 8080
    security_groups = [aws_security_group.alb.id]
  }

  egress {
    description = "Allow any traffic egress"
    protocol    = "-1"
    from_port   = 0
    to_port     = 0
    cidr_blocks = ["0.0.0.0/0"]
  }
}

resource "aws_ecs_cluster" "main" {
  name = "healthy-healthchecks"

  setting {
    name  = "containerInsights"
    value = "enabled"
  }
}


