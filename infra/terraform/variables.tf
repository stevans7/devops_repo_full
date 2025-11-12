variable "project" { type = string }
variable "region"  { type = string  default = "eu-central-1" }
variable "tf_state_bucket" { type = string }
variable "tf_lock_table" { type = string }
variable "vpc_cidr" { type = string default = "10.0.0.0/16" }
variable "certificate_arn" { type = string default = "" }
variable "ssh_key_name" { type = string default = "soutenace" }
