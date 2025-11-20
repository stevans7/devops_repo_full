variable "project" {
  type = string
}

variable "region" {
  type    = string
  default = "eu-central-1"
}

variable "tf_state_bucket" {
  type = string
}

variable "tf_lock_table" {
  type = string
}

variable "vpc_cidr" {
  type    = string
  default = "10.0.0.0/16"
}

variable "certificate_arn" {
  type    = string
  default = ""
}

variable "ssh_key_name" {
  type    = string
  default = "soutenace"
}

variable "enable_compute" {
  description = "Whether to create compute resources (ASGs, EC2 instances, CodeDeploy DG). Set false to modify VPC without dependency issues."
  type        = bool
  default     = true
}

variable "route53_zone_name" {
  description = "Public Route53 zone name (e.g., example.com.)"
  type        = string
  default     = ""
}

variable "route53_record_name" {
  description = "Record name to point at the ALB (e.g., app.example.com)"
  type        = string
  default     = ""
}
