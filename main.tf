provider "aws" {
  region = "ap-northeast-1"
}

data "aws_ami" "amazon_linux" {
  most_recent = true
  owners      = ["amazon"]

  filter {
    name   = "name"
    values = ["amzn2-ami-hvm-*-x86_64-gp2"]
  }
}
############################################
# IAM
############################################

module "iam" {
  source = "./modules/iam"
}

############################################
# VPC
############################################
module "vpc" {
  source = "./modules/vpc"
}

############################################
# セキュリティグループ
############################################
module "sg" {
  source = "./modules/sg"

  vpc_id = module.vpc.vpc_id
}

############################################
# EC2（nginx）
############################################
module "ec2" {
  source = "./modules/ec2"

  ami              = data.aws_ami.amazon_linux.id
  web_sg_id        = module.sg.web_sg_id
  subnets          = module.vpc.public_subnets
  target_group_arn = module.alb.target_group_arn
  key_name = "test-instance-key-pair"
  subnet_ids = module.vpc.public_subnets
  instance_profile_name = module.iam.instance_profile_name
}

############################################
# ALB（HTTPS）
############################################
module "alb" {
  source = "./modules/alb"

  vpc_id             = module.vpc.vpc_id
  subnets            = module.vpc.public_subnets
  alb_sg_id          = module.sg.alb_sg_id

  certificate_arn = "arn:aws:acm:ap-northeast-1:881424867137:certificate/c34a1690-a90d-4f45-8b6c-96825937c55a"
}
############################################
# Route53（ドメイン → ALB）
############################################

# ホストゾーン取得
data "aws_route53_zone" "main" {
  name = "net-4.net"
}

# Aレコード（ALBへ紐付け）
resource "aws_route53_record" "alb_record" {
  zone_id = data.aws_route53_zone.main.zone_id
  name    = "net-4.net"
  type    = "A"

  alias {
    name                   = module.alb.alb_dns
    zone_id                = module.alb.alb_zone_id
    evaluate_target_health = true
  }
}
