variable "start_local" {
  type        = bool
  description = "Set to true if you wish to start the healthcheck demo locally"
}

variable "start_remote" {
  type        = bool
  description = "Set to true if you with to start healthcheck demo on AWS"
}

variable "owner" {
  type        = string
  description = "Owner of the project"
}

variable "repo" {
  type        = string
  description = "Repository where source code is found. Update default if forked."
  default     = "https://github.com/baalimago/healthy-health-checks"
}
