resource "aws_lb" "app" {
  for_each                   = { for d in var.deployments : d.name => d }
  name                       = replace(each.value.name, "_", "-")
  internal                   = false
  load_balancer_type         = "application"
  security_groups            = [aws_security_group.alb.id]
  subnets                    = aws_subnet.public[*].id
  drop_invalid_header_fields = true
}

resource "aws_lb_target_group" "app" {
  for_each    = { for d in var.deployments : d.name => d }
  name        = replace(each.value.name, "_", "-")
  port        = 80
  protocol    = "HTTP"
  vpc_id      = aws_vpc.main.id
  target_type = "ip"

  dynamic "health_check" {
    for_each = each.value.with-lb-healthcheck ? [1] : []

    content {
      path                = "/health" # Set your desired health check path
      healthy_threshold   = each.value.lb-healthcheck.healthy_threshold
      unhealthy_threshold = each.value.lb-healthcheck.unhealthy_threshold
      timeout             = each.value.lb-healthcheck.timeout
      interval            = each.value.lb-healthcheck.interval
      matcher             = "200" # Expected HTTP response code
    }
  }
}

resource "aws_lb_listener" "app" {
  for_each          = { for d in var.deployments : d.name => d }
  load_balancer_arn = aws_lb.app[each.key].arn
  port              = 80
  protocol          = "HTTP"

  default_action {
    type             = "forward"
    target_group_arn = aws_lb_target_group.app[each.key].arn
  }
}

resource "aws_security_group" "alb" {
  name        = "alb-sg"
  description = "Security group for ALB"
  vpc_id      = aws_vpc.main.id

  ingress {
    description = "Allows access on port 80 to the deployers public IP"
    protocol    = "tcp"
    from_port   = 80
    to_port     = 80
    cidr_blocks = concat(["${data.http.my_public_ip.response_body}/32"], aws_subnet.public[*].cidr_block)
  }

  egress {
    description = "Allows egress access anywhere"
    protocol    = "-1"
    from_port   = 0
    to_port     = 0
    cidr_blocks = ["0.0.0.0/0"]
  }
}
