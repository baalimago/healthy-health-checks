output "image-names" {
  description = "Name of the built docker image"
  value = {
    with-healthcheck    = docker_image.munchausen_with-healthcheck.name
    without-healthcheck = docker_image.munchausen_without-healthcheck.name
  }
}
