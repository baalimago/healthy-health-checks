
##############################
# 1. Build docker images
##############################

resource "docker_image" "munchausen_no-health" {
  name = "munchausen_no-health"
  build {
    context    = "."
    dockerfile = "Dockerfile_no-healthcheck"
    tag        = ["munchausen:no-health"]
    label = {
      author : "Lorentz Kinde",
      blogpost : "Healthy healthchecks, lorentz.app"
    }
  }
  triggers = {
    dir_sha1        = sha1(join("", [for f in fileset(path.module, "src/*") : filesha1(f)]))
    dockerfile_sha1 = filesha1("${path.module}/Dockerfile_no-healthcheck")
  }
}

resource "docker_image" "munchausen_with-health" {
  name = "munchausen_with-health"
  build {
    context    = "."
    dockerfile = "Dockerfile_with-healthcheck"
    tag        = ["munchausen:with-health"]
    label = {
      author : "Lorentz Kinde",
      blogpost : "Healthy healthchecks, lorentz.app"
    }
  }
  triggers = {
    dir_sha1        = sha1(join("", [for f in fileset(path.module, "src/*") : filesha1(f)]))
    dockerfile_sha1 = filesha1("${path.module}/Dockerfile_with-healthcheck")
  }
}

##############################
# 2. Start docker containers locally
##############################

resource "docker_container" "without_health" {
  name = "munchausen_no-health"
  image = docker_image.munchausen_no-health.name
  ports {
    internal = 8080
    external = 8008
  }

  env = [
    "HEALTHY_AFTER_DURATION=5s"
  ]

  depends_on = [docker_image.munchausen_no-health]
}

resource "docker_container" "with_health" {
  name = "munchausen_with-health"
  image = docker_image.munchausen_with-health.name
  ports {
    internal = 8080
    external = 8007
  }
  env = [
    "HEALTHY_AFTER_DURATION=5s"
  ]

  depends_on = [docker_image.munchausen_with-health]
}
