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
