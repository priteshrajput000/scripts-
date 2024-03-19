provider "aws" {
  region = var.AWS_REGION
}

# Ensure that the key pair exists
resource "aws_key_pair" "asg_key" {
  key_name   = var.PUBLIC_KEY
  public_key = file("${path.module}/${var.PUBLIC_KEY}")
}

# Launch configuration for Auto Scaling Group
resource "aws_launch_configuration" "autoscaling_lc" {
  name_prefix                   = "autoscaling_lc"
  image_id                      = var.AWS_AMI
  instance_type                 = "t2.micro"
  security_groups               = var.SECURITY_GROUP
  key_name                      = aws_key_pair.asg_key.key_name
  associate_public_ip_address   = true

  lifecycle {
    create_before_destroy = true
  }
}

# Define autoscaling group
resource "aws_autoscaling_group" "autoscaling_group" {
  name                      = "autoscaling_group"
  vpc_zone_identifier       = var.SUBNETS
  launch_configuration      = aws_launch_configuration.autoscaling_lc.name
  min_size                  = 1
  max_size                  = 3
  health_check_grace_period = 60
  health_check_type         = "EC2"
  force_delete              = true

  tag {
    key                 = "name"
    value               = "asg_ec2_instance"
    propagate_at_launch = true
  }
}

# Define autoscaling configuration policy
resource "aws_autoscaling_policy" "scaleout_scaling" {
  name                   = "scaleout_scaling"
  autoscaling_group_name = aws_autoscaling_group.autoscaling_group.name
  adjustment_type        = "ChangeInCapacity"
  scaling_adjustment     = 1
  cooldown               = 60
  policy_type            = "SimpleScaling"
}

# Define Cloudwatch monitoring
resource "aws_cloudwatch_metric_alarm" "scaleout_alarm" {
  alarm_name          = "scaleout_alarm"
  alarm_description   = "alarm once cpu > 60%"
  comparison_operator = "GreaterThanOrEqualToThreshold"
  evaluation_periods  = 2
  metric_name         = "CPUUtilization"
  namespace           = "AWS/EC2"
  period              = 120
  statistic           = "Average"
  threshold           = 60

  dimensions = {
    AutoscalingGroupName = aws_autoscaling_group.autoscaling_group.name
  }
  actions_enabled = true
  alarm_actions   = [aws_autoscaling_policy.scaleout_scaling.arn]
}

# Define descaling policy
resource "aws_autoscaling_policy" "scalein_scaling" {
  name                   = "scaleIn_scaling"
  autoscaling_group_name = aws_autoscaling_group.autoscaling_group.name
  adjustment_type        = "ChangeInCapacity"
  scaling_adjustment     = -1
  cooldown               = 60
  policy_type            = "SimpleScaling"
}

# Define Cloudwatch monitoring
resource "aws_cloudwatch_metric_alarm" "scaleIn_alarm" {
  alarm_name          = "scaleIn_alarm"
  alarm_description   = "alarm once cpu < 60%"
  comparison_operator = "LessThanOrEqualToThreshold"
  evaluation_periods  = 2
  metric_name         = "CPUUtilization"
  namespace           = "AWS/EC2"
  period              = 120
  statistic           = "Average"
  threshold           = 40

  dimensions = {
    AutoscalingGroupName = aws_autoscaling_group.autoscaling_group.name
  }
  actions_enabled = true
  alarm_actions   = [aws_autoscaling_policy.scalein_scaling.arn]
}

# Define target group
resource "aws_lb_target_group" "alb" {
  name        = "alb"
  port        = 80
  protocol    = "TCP"
  vpc_id      = var.VPC_ID
  target_type = "instance"

  health_check {
    path                = "/"
    interval            = 30
    timeout             = 5
    healthy_threshold   = 2
    unhealthy_threshold = 2
  }

  deregistration_delay = 30

  stickiness {
    type            = "lb_cookie"
    cookie_duration = 86400
  }
}


# # Attach Elastic IP to EC2 instance
# resource "aws_eip_association" "eip_attach" {
#   allocation_id = var.EIP_ALLOT.id
#   instance_id  = aws_autoscaling_group.autoscaling_group.id
# }

# Define load balancer
resource "aws_lb" "balancer" {
  name               = "balancer"
  load_balancer_type = "application"
  security_groups    = var.SECURITY_GROUP
  internal           = false

  subnet_mapping {
    subnet_id     = element(var.SUBNETS, 0)
  }

  subnet_mapping {
    subnet_id     = element(var.SUBNETS, 1)
  }
}

# Define listener
resource "aws_lb_listener" "listener-alb" {
  load_balancer_arn = aws_lb.balancer.arn
  port              = "80"
  protocol          = "TCP"

  default_action {
    type             = "forward"
    target_group_arn = aws_lb_target_group.alb.arn
  }
}

# Attach the autoscaling group to the target group
resource "aws_autoscaling_attachment" "alb_attach" {
  autoscaling_group_name = aws_autoscaling_group.autoscaling_group.name
  lb_target_group_arn   = aws_lb_target_group.alb.arn
}

data "aws_instance" "EC2" {
  instance_id = "i-0fca52b7661035ced"
}

# Attach the instance to the target group
resource "aws_lb_target_group_attachment" "alb_attach_b" {
  target_group_arn = aws_lb_target_group.alb.arn
  target_id        = data.aws_instance.EC2.id
}
