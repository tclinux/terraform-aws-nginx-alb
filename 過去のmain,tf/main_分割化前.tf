############################################
# AWSプロバイダ
############################################
provider "aws" {
  region = "ap-northeast-1"
}

############################################
# VPC（ネットワーク）
############################################
resource "aws_vpc" "main" {
  cidr_block = "10.0.0.0/16"

  tags = {
    Name = "secure-vpc"
  }
}

############################################
# インターネットゲートウェイ
############################################
resource "aws_internet_gateway" "igw" {
  vpc_id = aws_vpc.main.id
}

############################################
# パブリックサブネット（2AZ）
############################################
resource "aws_subnet" "public1" {
  vpc_id                  = aws_vpc.main.id
  cidr_block              = "10.0.1.0/24"
  availability_zone       = "ap-northeast-1a"
  map_public_ip_on_launch = true
}

resource "aws_subnet" "public2" {
  vpc_id                  = aws_vpc.main.id
  cidr_block              = "10.0.2.0/24"
  availability_zone       = "ap-northeast-1c"
  map_public_ip_on_launch = true
}

############################################
# ルートテーブル（インターネット接続）
############################################
resource "aws_route_table" "public_rt" {
  vpc_id = aws_vpc.main.id

  route {
    cidr_block = "0.0.0.0/0"
    gateway_id = aws_internet_gateway.igw.id
  }
}

resource "aws_route_table_association" "assoc1" {
  subnet_id      = aws_subnet.public1.id
  route_table_id = aws_route_table.public_rt.id
}

resource "aws_route_table_association" "assoc2" {
  subnet_id      = aws_subnet.public2.id
  route_table_id = aws_route_table.public_rt.id
}

############################################
# ALB用セキュリティグループ
# → インターネットからのHTTPのみ許可
############################################
resource "aws_security_group" "alb_sg" {
  name   = "alb-sg"
  vpc_id = aws_vpc.main.id

  # インターネット → ALB
  ingress {
    from_port   = 80
    to_port     = 80
    protocol    = "tcp"
    cidr_blocks = ["0.0.0.0/0"]
  }

  # インターネット → ALB (https)
    ingress {
    from_port   = 443
    to_port     = 443
    protocol    = "tcp"
    cidr_blocks = ["0.0.0.0/0"]
  }

  # ALB → 外部（全許可）
  egress {
    from_port   = 0
    to_port     = 0
    protocol    = "-1"
    cidr_blocks = ["0.0.0.0/0"]
  }
}

############################################
# EC2用セキュリティグループ（重要）
# → ALBからの通信のみ許可
############################################
resource "aws_security_group" "web_sg" {
  name   = "web-sg"
  vpc_id = aws_vpc.main.id

  # ALB → EC2（HTTPのみ許可）
  ingress {
    from_port       = 80
    to_port         = 80
    protocol        = "tcp"
    security_groups = [aws_security_group.alb_sg.id]
  }

  # SSH（自分のIPだけ許可にする）
  ingress {
    from_port   = 22
    to_port     = 22
    protocol    = "tcp"
    cidr_blocks = ["175.41.114.206/32"] # ←必ず自分のIPに変更
  }

  # EC2 → 外部（全許可）
  egress {
    from_port   = 0
    to_port     = 0
    protocol    = "-1"
    cidr_blocks = ["0.0.0.0/0"]
  }
}

############################################
# EC2（nginx）
############################################
resource "aws_instance" "web" {
  ami           = "ami-0c3fd0f5d33134a76"
  instance_type = "t3.micro"

  subnet_id                   = aws_subnet.public1.id
  vpc_security_group_ids      = [aws_security_group.web_sg.id]
  associate_public_ip_address = true

  user_data = <<-EOF
#!/bin/bash
amazon-linux-extras install -y nginx1
systemctl start nginx
systemctl enable nginx
EOF

  tags = {
    Name = "secure-nginx"
  }
}

############################################
# ALB（ロードバランサー）
############################################
resource "aws_lb" "alb" {
  name               = "secure-alb"
  internal           = false
  load_balancer_type = "application"

  security_groups = [aws_security_group.alb_sg.id]

  # 2つのAZに配置（必須）
  subnets = [
    aws_subnet.public1.id,
    aws_subnet.public2.id
  ]
}

############################################
# ターゲットグループ（EC2に流す）
############################################
resource "aws_lb_target_group" "tg" {
  name     = "secure-tg"
  port     = 80
  protocol = "HTTP"
  vpc_id   = aws_vpc.main.id
}

############################################
# EC2をターゲットに登録
############################################
resource "aws_lb_target_group_attachment" "attach" {
  target_group_arn = aws_lb_target_group.tg.arn
  target_id        = aws_instance.web.id
  port             = 80
}


############################################
# 出力
############################################
output "alb_dns" {
  value = aws_lb.alb.dns_name
}

############################################
# ACM証明書
############################################

resource "aws_acm_certificate" "cert" {
  domain_name       = "net-4.net"
  validation_method = "DNS"

  lifecycle {
    create_before_destroy = true
  }
}


############################################
# DNS検証（Route53）
############################################

resource "aws_route53_record" "cert_validation" {
  for_each = {
    for dvo in aws_acm_certificate.cert.domain_validation_options :
    dvo.domain_name => dvo
  }

  zone_id = "Z01400701AB30HJNHDL0E"

  name    = each.value.resource_record_name
  type    = each.value.resource_record_type
  records = [each.value.resource_record_value]

  ttl = 60
}

############################################
# 証明書の検証完了
############################################

resource "aws_acm_certificate_validation" "cert_validation" {
  certificate_arn         = aws_acm_certificate.cert.arn
  validation_record_fqdns = [
    for record in aws_route53_record.cert_validation : record.fqdn
  ]
}

############################################
# HTTPSリスナー（443）
############################################

resource "aws_lb_listener" "https" {
  load_balancer_arn = aws_lb.alb.arn
  port              = 443
  protocol          = "HTTPS"

  ssl_policy        = "ELBSecurityPolicy-2016-08"
  certificate_arn   = aws_acm_certificate.cert.arn

  default_action {
    type             = "forward"
    target_group_arn = aws_lb_target_group.tg.arn
  }

  depends_on = [aws_acm_certificate_validation.cert_validation]
}

############################################
# HTTP → HTTPSリダイレクト
############################################

resource "aws_lb_listener" "http_redirect" {
  load_balancer_arn = aws_lb.alb.arn
  port              = 80
  protocol          = "HTTP"

  default_action {
    type = "redirect"

    redirect {
      port        = "443"
      protocol    = "HTTPS"
      status_code = "HTTP_301"
    }
  }
}

############################################
# Route53（ALBに向ける）
############################################

resource "aws_route53_record" "alb_record" {
  zone_id = "Z01400701AB30HJNHDL0E"
  name    = "net-4.net"
  type    = "A"

  alias {
    name                   = aws_lb.alb.dns_name
    zone_id                = aws_lb.alb.zone_id
    evaluate_target_health = true
  }
}
