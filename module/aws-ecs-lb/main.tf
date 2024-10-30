data "aws_region" "current" {}

data "aws_availability_zones" "available" {
  state = "available"
}

# Add these blocks
resource "aws_vpc" "main" {
  cidr_block           = "10.0.0.0/16"
  enable_dns_hostnames = true
  enable_dns_support   = true

  tags = {
    Name = "healthy-healthchecks-vpc"
  }
}

resource "aws_subnet" "public" {
  count             = 2
  vpc_id            = aws_vpc.main.id
  cidr_block        = "10.0.${count.index + 1}.0/24"
  availability_zone = data.aws_availability_zones.available.names[count.index]

  map_public_ip_on_launch = true

  tags = {
    Name = "healthy-healthchecks-public-${count.index + 1}"
  }
}

resource "aws_internet_gateway" "main" {
  vpc_id = aws_vpc.main.id
}

resource "aws_route_table" "public" {
  vpc_id = aws_vpc.main.id

  route {
    cidr_block = "0.0.0.0/0"
    gateway_id = aws_internet_gateway.main.id
  }
}

resource "aws_route_table_association" "public" {
  count          = 2
  subnet_id      = aws_subnet.public[count.index].id
  route_table_id = aws_route_table.public.id
}


# This resource is to block all access to the deployed services except from 
# the deployer's own ip address
data "http" "my_public_ip" {
  url = "https://api.ipify.org"
}

resource "aws_kms_key" "ecr_key" {
  description             = "KMS key for ECR repository encryption"
  deletion_window_in_days = 7
  enable_key_rotation     = true
}

resource "aws_ecr_repository" "healthy-healthchecks" {
  name = "healthy-healthchecks"

  encryption_configuration {
    encryption_type = "KMS"
    kms_key         = aws_kms_key.ecr_key.arn
  }
  image_tag_mutability = "IMMUTABLE"
  image_scanning_configuration {
    scan_on_push = true
  }

  provisioner "local-exec" {
    when    = destroy
    command = "aws ecr batch-delete-image --repository-name healthy-healthchecks --image-ids \"$(aws ecr list-images --repository-name healthy-healthchecks --query 'imageIds[*]' --output json)\""
  }
}


resource "null_resource" "docker_build" {
  for_each = var.docker-images

  triggers = {
    ecr_repository_url = aws_ecr_repository.healthy-healthchecks.repository_url
  }

  provisioner "local-exec" {
    command = <<EOF
      aws ecr get-login-password --region ${data.aws_region.current.name} | docker login --username AWS --password-stdin ${aws_ecr_repository.healthy-healthchecks.repository_url}
      docker tag ${each.value} ${aws_ecr_repository.healthy-healthchecks.repository_url}:${each.key}
      docker push ${aws_ecr_repository.healthy-healthchecks.repository_url}:${each.key}
    EOF
  }
}


resource "aws_ecs_task_definition" "app" {
  for_each                 = var.docker-images
  family                   = "healthy-healthchecks"
  requires_compatibilities = ["FARGATE"]
  network_mode             = "awsvpc"
  cpu                      = 256
  memory                   = 512
  execution_role_arn       = aws_iam_role.ecs_execution_role.arn
  container_definitions = jsonencode([
    {
      name  = each.value
      image = "${aws_ecr_repository.healthy-healthchecks.repository_url}:${each.value}"
      portMappings = [
        {
          containerPort = 80
          protocol      = "tcp"
        }
      ]

      environment = [
        {
          "name" : "HEALTHY_AFTER_DURATION",
          "value" : "5s"
        }
      ]

    }
  ])

  depends_on = [null_resource.docker_build]
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

resource "aws_ecs_service" "app" {
  for_each        = var.docker-images
  name            = "healthy-healthchecks"
  cluster         = aws_ecs_cluster.main.id
  task_definition = aws_ecs_task_definition.app[each.key].arn
  desired_count   = 1
  launch_type     = "FARGATE"
  network_configuration {
    subnets          = [aws_subnet.public[0].cidr_block, aws_subnet.public[1].cidr_block]
    assign_public_ip = true
    security_groups  = [aws_security_group.ecs_tasks.id]
  }

  load_balancer {
    target_group_arn = aws_lb_target_group.app.arn
    container_name   = "my-app"
    container_port   = 80
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

  egress {
    description = "Allow any port on the deloyers current IP address"
    protocol    = "-1"
    from_port   = 0
    to_port     = 0
    cidr_blocks = ["${data.http.my_public_ip.response_body}/32"]
  }
}

resource "aws_ecs_cluster" "main" {
  name = "healthy-healthchecks"

  setting {
    name  = "containerInsights"
    value = "enabled"
  }
}

resource "aws_lb" "app" {
  name                       = "healthy-healthchecks"
  internal                   = false
  load_balancer_type         = "application"
  security_groups            = [aws_security_group.alb.id]
  subnets                    = [aws_subnet.public[0].id, aws_subnet.public[1].id]
  drop_invalid_header_fields = true
}

resource "aws_lb_target_group" "app" {
  name        = "healthy-healthchecks"
  port        = 80
  protocol    = "HTTP"
  vpc_id      = aws_vpc.main.id
  target_type = "ip"
}

resource "aws_lb_listener" "app" {
  load_balancer_arn = aws_lb.app.arn
  port              = 80
  protocol          = "HTTP"

  default_action {
    type             = "forward"
    target_group_arn = aws_lb_target_group.app.arn
  }
}

# Add ALB security group
resource "aws_security_group" "alb" {
  name        = "alb-sg"
  description = "Security group for ALB"
  vpc_id      = aws_vpc.main.id

  ingress {
    description = "Allows access on port 80 to the deployers public IP"
    protocol    = "tcp"
    from_port   = 80
    to_port     = 80
    cidr_blocks = ["${data.http.my_public_ip.response_body}/32"]
  }

  egress {
    description = "Allows access on port 80 to the deployers public IP"
    protocol    = "-1"
    from_port   = 0
    to_port     = 0
    cidr_blocks = ["${data.http.my_public_ip.response_body}/32"]
  }
}
