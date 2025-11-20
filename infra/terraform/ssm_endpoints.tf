// SSM connectivity for private subnets without relying on NAT.
// Creates Interface VPC Endpoints for SSM, SSMMessages, and EC2Messages.
// Controlled by var.enable_ssm_endpoints (default: true).

variable "enable_ssm_endpoints" {
  description = "Create VPC Interface Endpoints for SSM services"
  type        = bool
  default     = true
}

locals {
  ssm_services = [
    "ssm",
    "ssmmessages",
    "ec2messages",
  ]
}

data "aws_vpc" "this" {
  id = module.vpc.vpc_id
}

resource "aws_security_group" "ssm_endpoints" {
  count       = var.enable_ssm_endpoints ? 1 : 0
  name        = "${var.project}-ssm-endpoints-sg"
  description = "Security group for SSM Interface Endpoints"
  vpc_id      = module.vpc.vpc_id

  ingress {
    description = "Allow HTTPS from VPC CIDR"
    from_port   = 443
    to_port     = 443
    protocol    = "tcp"
    cidr_blocks = [data.aws_vpc.this.cidr_block]
  }

  egress {
    from_port   = 0
    to_port     = 0
    protocol    = "-1"
    cidr_blocks = ["0.0.0.0/0"]
  }

  tags = {
    Name    = "${var.project}-ssm-endpoints-sg"
    Project = var.project
  }
}

resource "aws_vpc_endpoint" "ssm_if" {
  for_each            = var.enable_ssm_endpoints ? toset(local.ssm_services) : []
  vpc_id              = module.vpc.vpc_id
  service_name        = "com.amazonaws.${var.region}.${each.key}"
  vpc_endpoint_type   = "Interface"
  subnet_ids          = module.vpc.private_subnets
  security_group_ids  = [aws_security_group.ssm_endpoints[0].id]
  private_dns_enabled = true

  tags = {
    Name    = "${var.project}-${each.key}-endpoint"
    Project = var.project
  }
}

