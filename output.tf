output "lb-endpoints" {
  value = module.remote[*].lb-endpoints
}
