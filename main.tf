module "docker" {
  source = "./module/docker-image/"
}

module "local" {
  count         = var.start_local ? 1 : 0
  source        = "./module/local/"
  docker-images = module.docker.image-names
}

module "remote" {
  count         = var.start_remote ? 1 : 0
  source        = "./module/aws-ecs-lb/"
  docker-images = module.docker.image-names
}
