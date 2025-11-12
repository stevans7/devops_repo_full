
resource "aws_iam_role" "ec2_role" {
  name = "${var.project}-ec2-role"
  assume_role_policy = jsonencode({Version="2012-10-17",Statement=[{Effect="Allow",Principal={Service="ec2.amazonaws.com"},Action="sts:AssumeRole"}]})
}
resource "aws_iam_role_policy_attachment" "ec2_ssm" { role = aws_iam_role.ec2_role.name policy_arn = "arn:aws:iam::aws:policy/AmazonSSMManagedInstanceCore" }
resource "aws_iam_role_policy_attachment" "ec2_cw"  { role = aws_iam_role.ec2_role.name policy_arn = "arn:aws:iam::aws:policy/CloudWatchAgentServerPolicy" }
resource "aws_iam_role_policy_attachment" "ec2_s3"  { role = aws_iam_role.ec2_role.name policy_arn = "arn:aws:iam::aws:policy/AmazonS3ReadOnlyAccess" }
resource "aws_iam_role_policy_attachment" "ec2_ecr" { role = aws_iam_role.ec2_role.name policy_arn = "arn:aws:iam::aws:policy/AmazonEC2ContainerRegistryReadOnly" }
resource "aws_iam_instance_profile" "ec2_profile" { name = "${var.project}-ec2-profile" role = aws_iam_role.ec2_role.name }

########################
# Security Groups
########################
resource "aws_security_group" "alb" {
  name        = "${var.project}-alb-sg"
  description = "ALB security group"
  vpc_id      = module.vpc.vpc_id
  ingress { from_port=80  to_port=80  protocol="tcp" cidr_blocks=["0.0.0.0/0"] }
  ingress { from_port=443 to_port=443 protocol="tcp" cidr_blocks=["0.0.0.0/0"] }
  egress  { from_port=0   to_port=0   protocol="-1"  cidr_blocks=["0.0.0.0/0"] }
}

resource "aws_security_group" "front" {
  name        = "${var.project}-front-sg"
  description = "Front instances"
  vpc_id      = module.vpc.vpc_id
  ingress { from_port=80  to_port=80  protocol="tcp" security_groups=[aws_security_group.alb.id] }
  # Node exporter metrics from monitoring host
  ingress { from_port=9100 to_port=9100 protocol="tcp" security_groups=[aws_security_group.monitoring.id] }
  egress  { from_port=0   to_port=0   protocol="-1"  cidr_blocks=["0.0.0.0/0"] }
}

resource "aws_security_group" "back" {
  name        = "${var.project}-back-sg"
  description = "Back instances"
  vpc_id      = module.vpc.vpc_id
  ingress { from_port=3000 to_port=3000 protocol="tcp" security_groups=[aws_security_group.alb.id] }
  # Node exporter metrics from monitoring host
  ingress { from_port=9100 to_port=9100 protocol="tcp" security_groups=[aws_security_group.monitoring.id] }
  egress  { from_port=0   to_port=0   protocol="-1"  cidr_blocks=["0.0.0.0/0"] }
}

resource "aws_security_group" "db" {
  name        = "${var.project}-db-sg"
  description = "MongoDB instance"
  vpc_id      = module.vpc.vpc_id
  ingress { from_port=27017 to_port=27017 protocol="tcp" security_groups=[aws_security_group.back.id] }
   # Node exporter metrics from monitoring host
  ingress { from_port=9100 to_port=9100 protocol="tcp" security_groups=[aws_security_group.monitoring.id] }
  egress  { from_port=0   to_port=0   protocol="-1"  cidr_blocks=["0.0.0.0/0"] }
}

resource "aws_security_group" "monitoring" {
  name        = "${var.project}-mon-sg"
  description = "Monitoring"
  vpc_id      = module.vpc.vpc_id
  # Allow Prometheus UI (9090) and Grafana (3000) internally if needed
  ingress { from_port=9090 to_port=9090 protocol="tcp" cidr_blocks=[var.vpc_cidr] }
  ingress { from_port=3000 to_port=3000 protocol="tcp" security_groups=[aws_security_group.alb.id] }
  # Node exporter on self
  ingress { from_port=9100 to_port=9100 protocol="tcp" self = true }
  # Alertmanager UI/API
  ingress { from_port=9093 to_port=9093 protocol="tcp" cidr_blocks=[var.vpc_cidr] }
  egress  { from_port=0   to_port=0   protocol="-1"  cidr_blocks=["0.0.0.0/0"] }
}

########################
# Monitoring (Prometheus + Grafana)
########################
resource "aws_instance" "monitoring" {
  ami                         = data.aws_ami.al2023.id
  instance_type               = "t3.micro"
  subnet_id                   = module.vpc.private_subnets[0]
  vpc_security_group_ids      = [ aws_security_group.monitoring.id ]
  iam_instance_profile        = aws_iam_instance_profile.ec2_profile.name
  key_name                    = var.ssh_key_name
  associate_public_ip_address = false
  user_data                   = file("${path.module}/userdata/monitor.sh")
  tags = { Name = "${var.project}-monitoring", Project = var.project, Tier = "monitoring" }
  root_block_device { volume_size = 20 }
}

# Register monitoring instance to Grafana target group
resource "aws_lb_target_group_attachment" "grafana_target" {
  target_group_arn = module.alb.tg_grafana_arn
  target_id        = aws_instance.monitoring.id
  port             = 3000
}

########################
# IAM for Prometheus EC2 discovery
########################
resource "aws_iam_role_policy" "ec2_read" {
  name = "${var.project}-ec2-describe"
  role = aws_iam_role.ec2_role.id
  policy = jsonencode({
    Version = "2012-10-17",
    Statement = [
      { Effect = "Allow", Action = [
          "ec2:DescribeInstances", "ec2:DescribeTags", "ec2:DescribeInstanceStatus"
        ], Resource = "*" }
    ]
  })
}

########################
# Database (MongoDB)
########################
data "aws_ami" "al2023" { most_recent=true owners=["137112412989"] filter{ name="name" values=["al2023-ami-*-x86_64"] } }

resource "aws_instance" "db" {
  ami                         = data.aws_ami.al2023.id
  instance_type               = "t3.micro"
  subnet_id                   = module.vpc.private_subnets[0]
  vpc_security_group_ids      = [ aws_security_group.db.id ]
  iam_instance_profile        = aws_iam_instance_profile.ec2_profile.name
  key_name                    = var.ssh_key_name
  associate_public_ip_address = false
  user_data                   = file("${path.module}/userdata/mongo.sh")
  tags = { Name = "${var.project}-db", Project = var.project, Tier = "db" }
  root_block_device { volume_size = 20 }
}

module "asg_front" {
  source = "./modules/asg"
  project = var.project
  name    = "front"
  vpc_id  = module.vpc.vpc_id
  subnets = module.vpc.private_subnets
  user_data = templatefile("${path.module}/userdata/nginx.sh", { PROJECT = var.project })
  target_group_arns = [ module.alb.tg_front_arn ]
  iam_instance_profile = aws_iam_instance_profile.ec2_profile.name
  key_name = var.ssh_key_name
  security_group_ids = [ aws_security_group.front.id ]
}
module "asg_back" {
  source = "./modules/asg"
  project = var.project
  name    = "back"
  vpc_id  = module.vpc.vpc_id
  subnets = module.vpc.private_subnets
  user_data = templatefile("${path.module}/userdata/backend.sh", { MONGO_URI = "mongodb://${aws_instance.db.private_ip}:27017/rdv" })
  target_group_arns = [ module.alb.tg_back_arn ]
  iam_instance_profile = aws_iam_instance_profile.ec2_profile.name
  key_name = var.ssh_key_name
  security_group_ids = [ aws_security_group.back.id ]
}

resource "aws_iam_role" "codedeploy_role" {
  name = "${var.project}-codedeploy-role"
  assume_role_policy = jsonencode({Version="2012-10-17",Statement=[{Effect="Allow",Principal={Service="codedeploy.amazonaws.com"},Action="sts:AssumeRole"}]})
}
resource "aws_iam_role_policy_attachment" "codedeploy_managed" { role = aws_iam_role.codedeploy_role.name policy_arn = "arn:aws:iam::aws:policy/service-role/AWSCodeDeployRole" }

resource "aws_codedeploy_app" "backend" { name = "${var.project}-backend" compute_platform = "Server" }
resource "aws_codedeploy_deployment_group" "backend_dg" {
  app_name              = aws_codedeploy_app.backend.name
  deployment_group_name = "${var.project}-backend-dg"
  service_role_arn      = aws_iam_role.codedeploy_role.arn
  autoscaling_groups    = [ module.asg_back.this_asg_name ]
  deployment_style { deployment_option = "WITHOUT_TRAFFIC_CONTROL" deployment_type = "IN_PLACE" }
}
