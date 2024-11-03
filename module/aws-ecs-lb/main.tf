data "aws_region" "current" {}

data "aws_availability_zones" "available" {
  state = "available"
}

# This resource is to block all access to the deployed services except from 
# the deployer's own ip address
data "http" "my_public_ip" {
  url = "https://api.ipify.org"
}

