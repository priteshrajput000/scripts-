provider "aws" {
  region = var.AWS_REGION
}

# Ensure that the key pair exists
resource "aws_key_pair" "asg_key" {
  key_name   = var.PUBLIC_KEY
  public_key = file("${path.module}/asg.pub")
}

# Launch configuration for Auto Scaling Group
resource "aws_launch_configuration" "autoscaling_lc" {
  name_prefix          = "autoscaling_lc"
  image_id             = var.AWS_AMI
  instance_type        = "t2.micro"
  security_groups      = var.SECURITY_GROUP
  key_name             = aws_key_pair.asg_key.key_name
  associate_public_ip_address = true

  lifecycle {
    create_before_destroy = true
    }
}

# Define autoscaling group
resource "aws_autoscaling_group" "autoscaling_group" {
  name = "autoscaling_group"
  vpc_zone_identifier = var.SUBNETS
  launch_configuration = aws_launch_configuration.autoscaling_lc.name
  min_size = 1
  max_size = 3
  health_check_grace_period = 60
  health_check_type = "EC2"
  force_delete = true
  tag {
    key = "name"
    value = "asg_ec2_instance"
    propagate_at_launch = true
  }
}

# Define autoscaling configuration policy
resource "aws_autoscaling_policy" "scaleout_scaling" {
  name = "scaleout_scaling"
  autoscaling_group_name = aws_autoscaling_group.autoscaling_group.name
  adjustment_type = "ChangeInCapacity"
  scaling_adjustment = 1
  cooldown = 60
  policy_type = "SimpleScaling"
}

# Define Cloudwatch monitoring
resource "aws_cloudwatch_metric_alarm" "scaleout_alarm" {
  alarm_name = "scaleout_alarm"
  alarm_description = "alarm once cpu > 60%"
  comparison_operator = "GreaterThanOrEqualToThreshold"
  evaluation_periods = 2
  metric_name = "CPU_Utilization"
  namespace = "AWS/EC2"
  period = 120
  statistic = "Average"
  threshold = 60

dimensions = {
    "AutoscalingGroupName": aws_autoscaling_group.autoscaling_group.name
}
actions_enabled = true
alarm_actions = [aws_autoscaling_policy.scaleout_scaling.arn]
}

# Define descaling policy
resource "aws_autoscaling_policy" "scalein_scaling" {
 name = "scaleIn_scaling" 
 autoscaling_group_name = aws_autoscaling_group.autoscaling_group.name
 adjustment_type = "ChangeInCapacity"
 scaling_adjustment = -1
 cooldown = 60
 policy_type = "SimpleScaling"
}

# Define Cloudwatch monitoring
resource "aws_cloudwatch_metric_alarm" "scaleIn_alarm" {
  alarm_name = "scaleout_alarm"
  alarm_description = "alarm once cpu < 60%"
  comparison_operator = "LessThanOrEqualToThreshold"
  evaluation_periods = 2
  metric_name = "CPU_Utilization"
  namespace = "AWS/EC2"
  period = 120
  statistic = "Average"
  threshold = 40

dimensions = {
    "AutoscalingGroupName": aws_autoscaling_group.autoscaling_group.name
}
actions_enabled = true
alarm_actions = [aws_autoscaling_policy.scalein_scaling.arn]
}

# Define target group
resource "aws_alb_target_group" "alb" {
  name     = "alb"
  port     = 80
  protocol = "HTTP"
  vpc_id   = var.VPC_ID
  target_type = "alb"
  

  health_check {
    path                = "/"
    interval            = 30
    timeout             = 5
    healthy_threshold   = 2
    unhealthy_threshold = 2
    # matcher             = "200-299"
  }

  deregistration_delay = 30
  stickiness {
    type            = "lb_cookie"
    cookie_duration = 86400
  }
}

resource "aws_eip" "set_eip" {
  count = length(var.EIP_ALLOT)
}

# Define load balancer
resource "aws_alb" "balancer" {
  name            = "balancer"
  load_balancer_type = "application"
  subnets         = var.SUBNETS
  security_groups = var.SECURITY_GROUP
  internal           = false  

   subnet_mapping {
    subnet_id     = element(var.SUBNETS, 0) // Choose the appropriate subnet ID from the list
    allocation_id = aws_eip.set_eip[count.index].id

  }

  subnet_mapping {
    subnet_id     = element(var.SUBNETS, 1) // Choose the appropriate subnet ID from the list
    allocation_id = aws_eip.set_eip[length(var.EIP_ALLOT)].id
  }
}

# Define listener
resource "aws_alb_listener" "listener-alb" {
  load_balancer_arn = aws_alb.balancer.arn
  port              = "80"
  protocol          = "HTTP"

  default_action {
    target_group_arn = aws_alb_target_group.alb.arn
    type             = "forward"
  }
}

# Attach the autoscaling group to the target group
resource "aws_autoscaling_attachment" "alb_attach_a" {
  autoscaling_group_name = aws_autoscaling_group.autoscaling_group.name
  lb_target_group_arn   = aws_alb_target_group.alb.arn
}
# Attach the autoscaling group to the target group
resource "aws_lb_target_group_attachment" "alb_attach_b" {
  target_group_arn = aws_alb_target_group.alb.arn
  target_id = "*****************"
}
