resource "docker_image" "munchausen_without-healthcheck" {
  name = "munchausen_no-healthcheck"
  build {
    context    = "."
    dockerfile = "${path.root}/Dockerfile_no-healthcheck"
    tag        = ["munchausen:without-healthcheck"]
    label = {
      author : "Lorentz Kinde",
      blogpost : "Healthy healthchecks, lorentz.app"
    }
  }
  triggers = {
    dir_sha1        = filesha1("${path.root}/main.go")
    dockerfile_sha1 = filesha1("${path.root}/Dockerfile_no-healthcheck")
  }
}

resource "docker_image" "munchausen_with-healthcheck" {
  name = "munchausen_with-healthcheck"
  build {
    context    = "."
    dockerfile = "${path.root}/Dockerfile_with-healthcheck"
    tag        = ["munchausen:with-healthcheck"]
    label = {
      author : "Lorentz Kinde",
      blogpost : "Healthy healthchecks, lorentz.app"
    }
  }
  triggers = {
    dir_sha1        = filesha1("${path.root}/main.go")
    dockerfile_sha1 = filesha1("${path.root}/Dockerfile_with-healthcheck")
  }
}
