variable "project" {
  type = string
}

variable "name" {
  type = string
}

variable "vpc_id" {
  type = string
}

variable "subnets" {
  type = list(string)
}

variable "user_data" {
  type = string
}

variable "target_group_arns" {
  type    = list(string)
  default = []
}

variable "iam_instance_profile" {
  type    = string
  default = null
}

variable "key_name" {
  type    = string
  default = null
}

variable "security_group_ids" {
  type    = list(string)
  default = []
}

variable "root_volume_size" {
  type    = number
  default = 20
}

data "aws_ami" "al2023" {
  most_recent = true
  owners      = ["137112412989"]

  filter {
    name   = "name"
    values = ["al2023-ami-*-x86_64"]
  }
}

resource "aws_launch_template" "this" {
  name_prefix            = "${var.project}-${var.name}-lt"
  image_id               = data.aws_ami.al2023.id
  instance_type          = "t3.micro"
  user_data              = base64encode(var.user_data)
  key_name               = var.key_name
  vpc_security_group_ids = var.security_group_ids

  iam_instance_profile {
    name = var.iam_instance_profile
  }

  block_device_mappings {
    device_name = "/dev/xvda"
    ebs {
      volume_size           = var.root_volume_size
      volume_type           = "gp3"
      delete_on_termination = true
    }
  }
}

resource "aws_autoscaling_group" "this" {
  name                = "${var.project}-${var.name}-asg"
  desired_capacity    = 2
  min_size            = 2
  max_size            = 6
  vpc_zone_identifier = var.subnets

  launch_template {
    id      = aws_launch_template.this.id
    version = "$Latest"
  }

  target_group_arns = var.target_group_arns

  tag {
    key                 = "Name"
    value               = "${var.project}-${var.name}"
    propagate_at_launch = true
  }

  tag {
    key                 = "Project"
    value               = var.project
    propagate_at_launch = true
  }

  tag {
    key                 = "Tier"
    value               = var.name
    propagate_at_launch = true
  }
}
