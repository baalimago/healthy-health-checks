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
  }

  required_version = "~> 1.9"
}