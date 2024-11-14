module "docker" {
  source = "./module/docker-image/"
}

module "local" {
  count         = var.start_local ? 1 : 0
  source        = "./module/local/"
  docker-images = module.docker.image-names
}

module "remote" {
  count  = var.start_remote ? 1 : 0
  source = "./module/aws-ecs-lb/"
  deployments = [
    {
      name                     = "long-boottime-yes-all-hc"
      local-docker-image       = module.docker.image-names.with-healthcheck,
      healthy-after-duration   = "5s",
      unhealthy-after-duration = "180s",
      with-ecs-healthcheck     = true
      with-lb-healthcheck      = true
      lb-healthcheck = {
        healthy_threshhold    = 1
        unhealthy_threashhold = 50
        interval              = 5
        timeout               = 3
      }
    }
  ]
}
