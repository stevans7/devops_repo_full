<<<<<<< HEAD
resource "aws_wafv2_web_acl" "this" {
  name  = "${var.project}-waf"
  scope = "REGIONAL"

  default_action {
    allow {}
  }

  visibility_config {
    cloudwatch_metrics_enabled = true
    metric_name                = "${var.project}-waf"
    sampled_requests_enabled   = true
  }

  rule {
    name     = "AWSManagedRulesCommonRuleSet"
    priority = 1

    override_action {
      none {}
    }

    statement {
      managed_rule_group_statement {
        name        = "AWSManagedRulesCommonRuleSet"
        vendor_name = "AWS"
      }
    }

    visibility_config {
      cloudwatch_metrics_enabled = true
      metric_name                = "common"
      sampled_requests_enabled   = true
    }
  }
}

=======

resource "aws_wafv2_web_acl" "this" {
  name="${var.project}-waf" scope="REGIONAL"
  default_action { allow {} }
  visibility_config { cloudwatch_metrics_enabled=true metric_name="${var.project}-waf" sampled_requests_enabled=true }
  rule {
    name="AWSManagedRulesCommonRuleSet" priority=1
    override_action { none {} }
    statement { managed_rule_group_statement { name="AWSManagedRulesCommonRuleSet" vendor_name="AWS" } }
    visibility_config { cloudwatch_metrics_enabled=true metric_name="common" sampled_requests_enabled=true }
  }
}
>>>>>>> eca1baaa5cdec3a3cd1a54758194940fdd81d46d
resource "aws_wafv2_web_acl_association" "assoc" {
  resource_arn = var.alb_arn
  web_acl_arn  = aws_wafv2_web_acl.this.arn
}
