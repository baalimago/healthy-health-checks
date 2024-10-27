module "docker" {
  source = "./module/docker-image/"
}

module "local" {
  count         = var.start-local ? 1 : 0
  source        = "./module/local/"
  docker-images = module.docker.image-names
}
