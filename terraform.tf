provider "aws" {
  region = var.AWS_REGION
}
data "aws_instance" "existing_instance" {
  instance_id = "***************"
}

# Launch configuration for Auto Scaling Group
resource "aws_launch_configuration" "autoscaling_lc" {
  name_prefix          = "autoscaling_lc"
  image_id             = var.AWS_AMI
  instance_type        = "t2.micro"
  security_groups      = var.SECURITY_GROUP
  
  # Update key_name to reference the correct key pair
  key_name             = aws_key_pair.asg_key.key_name

  lifecycle {
    create_before_destroy = true
    }
    associate_public_ip_address = true
}

resource "aws_eip" "EIPS" {
  count = length(var.EIP_ALLOT)
}

resource "aws_eip_association" "EIP" {
  count       = 2
  instance_id = aws_autoscaling_group.autoscaling_group.name
  allocation_id = aws_eip.EIPS[count.index % length(var.EIP_ALLOT)].id 
  }

# Ensure that the key pair exists
resource "aws_key_pair" "asg_key" {
  key_name   = var.PUBLIC_KEY
  public_key = file("${path.module}/**.pub")
}

#Define autoscaling group
resource "aws_autoscaling_group" "autoscaling_group" {
  name = "autoscaling_group"
  vpc_zone_identifier = ["subnet-***"]
  launch_configuration = aws_launch_configuration.autoscaling_lc.name
  min_size = 0
  max_size = 2
  health_check_grace_period = 90
  health_check_type = "EC2"
  force_delete = true
  tag {
    key = "name"
    value = "asg_ec2_instance"
    propagate_at_launch = true
  }
}

#Define autoscaling configuration policy
resource "aws_autoscaling_policy" "scaleout_scaling" {
  name = "scaleout_scaling"
  autoscaling_group_name = aws_autoscaling_group.autoscaling_group.name
  adjustment_type = "ChangeInCapacity"
  scaling_adjustment = 1
  cooldown = 60
  policy_type = "SimpleScaling"
}

#Define Cloudwatch monitoring
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

#Define descaling policy
resource "aws_autoscaling_policy" "scalein_scaling" {
 name = "scaleIn_scaling" 
 autoscaling_group_name = aws_autoscaling_group.autoscaling_group.name
 adjustment_type = "ChangeInCapacity"
 scaling_adjustment = -1
 cooldown = 60
 policy_type = "SimpleScaling"
}


# # Get the instance IDs from the Auto Scaling Group
# data "aws_autoscaling_group" "instance" {
#   name = aws_autoscaling_group.autoscaling_group.name
# }


# # Get the newest launched instance
# data "aws_instance" "newest_instance" {
#   for_each = {
#     for idx, instance in data.aws_autoscaling_group.instance : idx => instance
#   }

#   instance_id = each.value.instance_id
# }


# Get the Auto Scaling Group details
data "aws_autoscaling_group" "autoscaling_group" {
  name = aws_autoscaling_group.autoscaling_group.name # Replace with your Auto Scaling Group name
}

# Get the instance IDs from the Auto Scaling Group
data "aws_autoscaling_group" "instances" {
  name = data.aws_autoscaling_group.autoscaling_group.name
}

# Get the newest launched instance
data "aws_instance" "newest_instance" {
  for_each = toset(data.aws_autoscaling_group.instances.id)

  instance_id = each.key
}

# Retrieve the instance details of the newest launched instance
output "newest_instance_id" {
  value = values(data.aws_instance.newest_instance)[0].id
}


#Define descaling cloudwatch monitoring
resource "aws_cloudwatch_metric_alarm" "scaledown_alarm" {
  alarm_name = "scaledown_alarm"
  alarm_description = "alarm once cpu < 50%"
  comparison_operator = "LessThanOrEqualToThreshold"
  evaluation_periods = 2
  metric_name = "CPU_Utilization"
  namespace = "AWS/EC2"
  period = 120
  statistic = "Average"
  threshold = 50
dimensions = {
    "AutoScalingGroupName": aws_autoscaling_group.autoscaling_group.name
}
actions_enabled = true
alarm_actions = [aws_autoscaling_policy.scalein_scaling.arn]
}








