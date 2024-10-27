variable "docker-images" {
  description = "Image names to deploy"
  type = object({
    with-healthcheck : string
    without-healthcheck : string
  })
}
