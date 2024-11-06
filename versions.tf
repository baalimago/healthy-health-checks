terraform {
  required_providers {
    aws = {
      source  = "hashicorp/aws"
      version = "~> 5.52.0"
    }

    null = {
      source  = "hashicorp/null"
      version = "~> 3.2"
    }

    http = {
      source  = "hashicorp/http"
      version = "~> 3.4.5"
    }
  }

  required_version = "~> 1.9"
}

provider "aws" {
  default_tags {
    tags = {
      Environment        = "blog-demo"
      Application        = "healthy-healthchecks"
      Terraform          = "true"
      OriginalRepository = var.repo
      Owner              = var.owner
    }
  }
}
