<<<<<<< HEAD
variable "project" {
  type = string
}

variable "vpc_id" {
  type = string
}

variable "public_subnets" {
  type = list(string)
}

variable "certificate_arn" {
  type    = string
  default = ""
}

variable "security_groups" {
  type = list(string)
}

resource "aws_lb" "this" {
  name               = "${var.project}-alb"
  load_balancer_type = "application"
  subnets            = var.public_subnets
  security_groups    = var.security_groups
}

resource "aws_lb_target_group" "front" {
  name     = "${var.project}-tg-front"
  port     = 80
  protocol = "HTTP"
  vpc_id   = var.vpc_id
  health_check {
    path = "/"
  }
}

resource "aws_lb_target_group" "back" {
  name     = "${var.project}-tg-back"
  port     = 3000
  protocol = "HTTP"
  vpc_id   = var.vpc_id
  health_check {
    path = "/healthz"
  }
}

resource "aws_lb_target_group" "grafana" {
  name     = "${var.project}-tg-grafana"
  port     = 3000
  protocol = "HTTP"
  vpc_id   = var.vpc_id
  health_check {
    path = "/login"
  }
}

=======

variable "project" { type = string }
variable "vpc_id"  { type = string }
variable "public_subnets" { type = list(string) }
variable "certificate_arn" { type = string default = "" }
variable "security_groups" { type = list(string) }
resource "aws_lb" "this" { name="${var.project}-alb" load_balancer_type="application" subnets=var.public_subnets security_groups=var.security_groups }
resource "aws_lb_target_group" "front" { name="${var.project}-tg-front" port=80 protocol="HTTP" vpc_id=var.vpc_id health_check{path="/"} }
resource "aws_lb_target_group" "back"  { name="${var.project}-tg-back"  port=3000 protocol="HTTP" vpc_id=var.vpc_id health_check{path="/healthz"} }
resource "aws_lb_target_group" "grafana" { name="${var.project}-tg-grafana"  port=3000 protocol="HTTP" vpc_id=var.vpc_id health_check{path="/login"} }
>>>>>>> eca1baaa5cdec3a3cd1a54758194940fdd81d46d
resource "aws_lb_listener" "http" {
  load_balancer_arn = aws_lb.this.arn
  port              = 80
  protocol          = "HTTP"
  default_action {
    type = "redirect"
    redirect {
      port        = "443"
      protocol    = "HTTPS"
      status_code = "HTTP_301"
    }
  }
}

# Optional HTTPS listener when certificate_arn is provided
resource "aws_lb_listener" "https" {
<<<<<<< HEAD
  count             = var.certificate_arn == "" ? 0 : 1
  load_balancer_arn = aws_lb.this.arn
  port              = 443
  protocol          = "HTTPS"
  ssl_policy        = "ELBSecurityPolicy-2016-08"
  certificate_arn   = var.certificate_arn

  default_action {
    type             = "forward"
    target_group_arn = aws_lb_target_group.front.arn
  }
=======
  count               = var.certificate_arn == "" ? 0 : 1
  load_balancer_arn   = aws_lb.this.arn
  port                = 443
  protocol            = "HTTPS"
  ssl_policy          = "ELBSecurityPolicy-2016-08"
  certificate_arn     = var.certificate_arn
  default_action { type = "forward" target_group_arn = aws_lb_target_group.front.arn }
>>>>>>> eca1baaa5cdec3a3cd1a54758194940fdd81d46d
}

resource "aws_lb_listener_rule" "api_rule_https" {
  count        = length(aws_lb_listener.https)
  listener_arn = aws_lb_listener.https[0].arn
  priority     = 10
<<<<<<< HEAD

  action {
    type             = "forward"
    target_group_arn = aws_lb_target_group.back.arn
  }

  condition {
    path_pattern {
      values = ["/api/*"]
    }
  }
=======
  action { type = "forward" target_group_arn = aws_lb_target_group.back.arn }
  condition { path_pattern { values = ["/api/*"] } }
>>>>>>> eca1baaa5cdec3a3cd1a54758194940fdd81d46d
}

resource "aws_lb_listener_rule" "grafana_rule_https" {
  count        = length(aws_lb_listener.https)
  listener_arn = aws_lb_listener.https[0].arn
  priority     = 20
<<<<<<< HEAD

  action {
    type             = "forward"
    target_group_arn = aws_lb_target_group.grafana.arn
  }

  condition {
    path_pattern {
      values = ["/grafana/*"]
    }
  }
}

output "alb_arn" {
  value = aws_lb.this.arn
}

output "alb_dns_name" {
  value = aws_lb.this.dns_name
}

output "tg_front_arn" {
  value = aws_lb_target_group.front.arn
}

output "tg_back_arn" {
  value = aws_lb_target_group.back.arn
}

output "tg_grafana_arn" {
  value = aws_lb_target_group.grafana.arn
}
=======
  action { type = "forward" target_group_arn = aws_lb_target_group.grafana.arn }
  condition { path_pattern { values = ["/grafana/*"] } }
}
output "alb_arn" { value=aws_lb.this.arn } output "alb_dns_name" { value=aws_lb.this.dns_name } output "tg_front_arn" { value=aws_lb_target_group.front.arn } output "tg_back_arn" { value=aws_lb_target_group.back.arn } output "tg_grafana_arn" { value=aws_lb_target_group.grafana.arn }
>>>>>>> eca1baaa5cdec3a3cd1a54758194940fdd81d46d
