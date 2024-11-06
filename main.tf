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
  deployments = [{
    name                   = "quickly-healthy"
    local-docker-image     = module.docker.image-names.with-healthcheck,
    healthy-after-duration = "5s"
    }, {
    name                   = "slowly-healthy"
    local-docker-image     = module.docker.image-names.with-healthcheck,
    healthy-after-duration = "180s"
    },
    {
      name                     = "quickly-unhealthy-no-ecs-hc"
      local-docker-image       = module.docker.image-names.with-healthcheck,
      healthy-after-duration   = "5s",
      unhealthy-after-duration = "30s",
      with-ecs-healthcheck     = false
      with-lb-healthcheck      = true
    },
    {
      name                     = "quickly-unhealthy-yes-ecs-hc"
      local-docker-image       = module.docker.image-names.with-healthcheck,
      healthy-after-duration   = "5s",
      unhealthy-after-duration = "30s",
      with-ecs-healthcheck     = true
      with-lb-healthcheck      = true
    }
  ]
}
