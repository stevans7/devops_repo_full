module "vpc" { source = "./modules/vpc" project = var.project vpc_cidr = var.vpc_cidr }
module "alb" { source = "./modules/alb" project = var.project vpc_id = module.vpc.vpc_id public_subnets = module.vpc.public_subnets certificate_arn = var.certificate_arn security_groups = [ aws_security_group.alb.id ] }
module "eks" { source = "./modules/eks" project = var.project vpc_id = module.vpc.vpc_id private_subnets = module.vpc.private_subnets public_subnets = module.vpc.public_subnets }
module "ecr" { source = "./modules/ecr" project = var.project }
module "s3"  { source = "./modules/s3"  project = var.project }
module "waf" { source = "./modules/waf" project = var.project alb_arn = module.alb.alb_arn }

# IAM + ASGs + CodeDeploy are in codedeploy.tf and appended below
