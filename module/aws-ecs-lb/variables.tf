variable "deployments" {
  description = "Name of the ecs services to start in the cluster"
  type = list(object({
    name : string,
    local-docker-image : string
    healthy-after-duration : string,
    unhealthy-after-duration : optional(string)
  }))
}
