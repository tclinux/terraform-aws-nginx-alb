# ALB: 入口
# ALBというリソースを作る宣言
resource "aws_lb" "alb" {
  # 名前（AWS上の識別用）
  name               = "terraform-alb"
  # インターネット公開(false) or 非公開(true)
  internal           = false
  # ALBの種類: application: HTTP/HTTPS, network: TCP高速, gateway: 特殊
  load_balancer_type = "application"
  # 配置場所: 複数AZに配置 → 高可用性
  subnets            = var.subnets
  # ALBに適用するSG
  security_groups    = [var.alb_sg_id]
}

# ターゲットグループ: 転送先（EC2）
resource "aws_lb_target_group" "tg" {
  # 名前
  name     = "terraform-tg"
  # EC2への通信
  port     = 80
  protocol = "HTTP"
  # 所属VPC
  vpc_id   = var.vpc_id

  # ヘルスチェック: / にアクセスして正常ならOK
  health_check {
    path = "/"
  }
}

# HTTP(80) → HTTPS(443) リダイレクト
# ポート80の入口
resource "aws_lb_listener" "http" {
  # このALBに紐付け
  load_balancer_arn = aws_lb.alb.arn
  # HTTP通信
  port              = 80
  protocol          = "HTTP"

  # 転送ではなくリダイレクト
  default_action {
    type = "redirect"

    # http → https に強制変換
    redirect {
      port        = "443"
      protocol    = "HTTPS"
      status_code = "HTTP_301"
    }
  }
}

# HTTPSリスナー: 443 → EC2へ転送
# 443の入口
resource "aws_lb_listener" "https" {
  load_balancer_arn = aws_lb.alb.arn
  port              = 443
  protocol          = "HTTPS"
  # TLS設定
  ssl_policy        = "ELBSecurityPolicy-2016-08"
  # ACMの証明書
  certificate_arn   = var.certificate_arn

  # EC2へ送る
  default_action {
    type             = "forward"
    # 流れ: HTTPS → ALB → EC2
    target_group_arn = aws_lb_target_group.tg.arn
  }
}
