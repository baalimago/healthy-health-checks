variable "docker-images" {
  description = "Name of the docker image to start in the ecs cluster. Will be uploaded to ECR."
  type = object({
    with-healthcheck : string
    without-healthcheck : string
  })
}
