##############################
# 1. Build docker images
##############################



##############################
# 2. Start docker containers locally
##############################

resource "docker_container" "no-healthcheck" {
  name  = "munchausen_no-healthcheck"
  image = var.docker-images.without-healthcheck
  ports {
    internal = 8080
    external = 8008
  }

  env = [
    "HEALTHY_AFTER_DURATION=5s"
  ]
}

resource "docker_container" "with_healthcheck" {
  name  = "munchausen_with-healthcheck_healthy-after-5s"
  image = var.docker-images.with-healthcheck
  ports {
    internal = 8080
    external = 8007
  }
  env = [
    "HEALTHY_AFTER_DURATION=5s"
  ]
}

resource "docker_container" "with_healthcheck_eventually-unhealthy" {
  name  = "munchausen_with-healthcheck_healthy-after-5s_unhealthy-after-30s"
  image = var.docker-images.with-healthcheck
  ports {
    internal = 8080
    external = 8000
  }
  env = [
    "HEALTHY_AFTER_DURATION=5s",
    "UNHEALTHY_AFTER_DURATION=10s"
  ]
}
