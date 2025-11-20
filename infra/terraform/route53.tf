// Optional Route53 alias to the ALB
// Set both variables to enable:
//  - var.route53_zone_name (e.g., "example.com.")
//  - var.route53_record_name (e.g., "app.example.com")

locals {
  create_dns = length(var.route53_zone_name) > 0 && length(var.route53_record_name) > 0
}

data "aws_route53_zone" "selected" {
  count = local.create_dns ? 1 : 0
  name  = var.route53_zone_name
}

data "aws_lb" "this" {
  arn = module.alb.alb_arn
}

resource "aws_route53_record" "alb_a" {
  count   = local.create_dns ? 1 : 0
  zone_id = data.aws_route53_zone.selected[0].zone_id
  name    = var.route53_record_name
  type    = "A"
  alias {
    name                   = data.aws_lb.this.dns_name
    zone_id                = data.aws_lb.this.zone_id
    evaluate_target_health = false
  }
}

resource "aws_route53_record" "alb_aaaa" {
  count   = local.create_dns ? 1 : 0
  zone_id = data.aws_route53_zone.selected[0].zone_id
  name    = var.route53_record_name
  type    = "AAAA"
  alias {
    name                   = data.aws_lb.this.dns_name
    zone_id                = data.aws_lb.this.zone_id
    evaluate_target_health = false
  }
}

