provider "aws" {
  region = "ap-northeast-1"
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

  ami           = "ami-0c3fd0f5d33134a76"
  instance_type = "t3.micro"

  subnet_id = module.vpc.public_subnets[0]
  sg_ids    = [module.sg.web_sg_id]
}

############################################
# ALB（HTTPS）
############################################
module "alb" {
  source = "./modules/alb"

  vpc_id             = module.vpc.vpc_id
  subnets            = module.vpc.public_subnets
  alb_sg_id          = module.sg.alb_sg_id
  target_instance_id = module.ec2.instance_id

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
