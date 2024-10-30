data "aws_region" "current" {}

# We'll deploy to the default VPC for simplicity's sake
data "aws_vpc" "default" {
  default = true
}

data "aws_subnets" "default" {
  filter {
    name   = "vpc-id"
    values = [data.aws_vpc.default.id]
  }
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
  family                   = "healthy-healthchecks"
  requires_compatibilities = ["FARGATE"]
  network_mode             = "awsvpc"
  cpu                      = 256
  memory                   = 512
  execution_role_arn       = aws_iam_role.ecs_execution_role.arn
  container_definitions = jsonencode([
    {
      name  = "my-app"
      image = "${aws_ecr_repository.healthy-healthchecks.repository_url}:latest"
      portMappings = [
        {
          containerPort = 80
          protocol      = "tcp"
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
  name            = "healthy-healthchecks"
  cluster         = aws_ecs_cluster.main.id
  task_definition = aws_ecs_task_definition.app.arn
  desired_count   = 1
  launch_type     = "FARGATE"
  network_configuration {
    subnets          = data.aws_subnets.default.ids
    assign_public_ip = true
    security_groups  = [aws_security_group.ecs_tasks.id]
  }
}


resource "aws_security_group" "ecs_tasks" {
  name        = "ecs-tasks-sg"
  description = "Security group for ECS tasks"
  vpc_id      = data.aws_vpc.default.id

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
