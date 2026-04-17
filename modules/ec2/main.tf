resource "aws_launch_template" "web" {
  name_prefix   = "web-template"
  image_id      = "ami-0c3fd0f5d33134a76"
  instance_type = "t3.micro"
  vpc_security_group_ids = [var.web_sg_id]
  key_name = var.key_name

  user_data = base64encode(<<-EOF
    #!/bin/bash
    amazon-linux-extras install -y nginx1
    systemctl start nginx
  EOF
  )
}

resource "aws_autoscaling_group" "web" {
  # 通常台数（今は2台）
  desired_capacity = 2
  # 最大（3台まで増える）
  max_size         = 3
  # 最低（1台は必ず維持）
  min_size         = 1

  vpc_zone_identifier = var.subnet_ids

  launch_template {
    id      = aws_launch_template.web.id
    version = "$Latest"
  }

  target_group_arns = [var.target_group_arn]

  # ALBが死活監視する
  health_check_type         = "ELB"
  health_check_grace_period = 60

  tag {
    key                 = "Name"
    value               = "terraform-asg"
    propagate_at_launch = true
  }
}

# CPUでスケールアウト
resource "aws_autoscaling_policy" "scale_out" {
  name                   = "scale-out"
  scaling_adjustment     = 1
  adjustment_type        = "ChangeInCapacity"
  autoscaling_group_name = aws_autoscaling_group.web.name
}
# CPUでスケールイン
resource "aws_autoscaling_policy" "scale_in" {
  name                   = "scale-in"
  scaling_adjustment     = -1
  adjustment_type        = "ChangeInCapacity"
  autoscaling_group_name = aws_autoscaling_group.web.name
}

# CPU高い → 増やす
resource "aws_cloudwatch_metric_alarm" "cpu_high" {
  alarm_name          = "cpu-high"
  comparison_operator = "GreaterThanThreshold"
  evaluation_periods  = 2
  metric_name         = "CPUUtilization"
  namespace           = "AWS/EC2"
  period              = 60
  statistic           = "Average"
  threshold           = 60

  dimensions = {
    AutoScalingGroupName = aws_autoscaling_group.web.name
  }

  alarm_actions = [aws_autoscaling_policy.scale_out.arn]
}
# CPU低い → 減らす
resource "aws_cloudwatch_metric_alarm" "cpu_low" {
  alarm_name          = "cpu-low"
  comparison_operator = "LessThanThreshold"
  evaluation_periods  = 2
  metric_name         = "CPUUtilization"
  namespace           = "AWS/EC2"
  period              = 60
  statistic           = "Average"
  threshold           = 20

  dimensions = {
    AutoScalingGroupName = aws_autoscaling_group.web.name
  }

  alarm_actions = [aws_autoscaling_policy.scale_in.arn]
}

/* 自動で最適な台数に調整
resource "aws_autoscaling_policy" "cpu_target" {
  policy_type = "TargetTrackingScaling"

  target_tracking_configuration {
    predefined_metric_specification {
      predefined_metric_type = "ASGAverageCPUUtilization"
    }

    target_value = 50.0
  }

  autoscaling_group_name = aws_autoscaling_group.web.name
}
*/
