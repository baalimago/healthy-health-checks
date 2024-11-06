output "lb-endpoints" {
  value = { for k, v in aws_lb.app : k => v.dns_name }
}

