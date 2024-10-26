terraform {
  required_providers {
    aws = {
      version = "~> 5.52.0"
    }
    null = {
      source  = "hashicorp/null"
      version = "~> 3.0"
    }
    docker = {
      source  = "kreuzwerker/docker"
      version = "3.0.2"
    }
  }

  required_version = "~> 1.9"
}
