variable "deployments" {
  description = "Name of the ecs services to start in the cluster"
  type = list(object({
    name : string,
    local-docker-image : string
    healthy-after-duration : string,
    unhealthy-after-duration : optional(string)
    with-ecs-healthcheck : optional(bool, true),
    with-lb-healthcheck : optional(bool, true)
    lb-healthcheck : object({
      healthy_threshold : optional(number, 3),
      unhealthy_threshold : optional(number, 3),
      timeout : optional(number, 5),
      interval : optional(number, 10),
    })
  }))
}
