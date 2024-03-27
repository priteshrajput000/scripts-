variable "AWS_ACCESS_KEY" {
    type = string
    default = "AKI1111111111111111"
}
variable "AWS_SECRET_KEY" {
    type = string
    default = "0pXhWsAUeYXR547OY+111111111111111111"
}
variable "AWS_REGION" {
    default = "us-11111-2"
}
variable "VPC_ID" {
  default = "vpc-1111111111111"
}
variable "SUBNETS" {
  default = ["subnet-11111111","subnet-1111111111111"]
}
variable "PUBLIC_KEY" {
    default = "autoscale"
}
variable "instance_id" {
    default = "i-1111111111111"
}

variable "AWS_AMI" {
  description = "AMI of existing EC2 machine"
  default = "ami-11111111111111"
}

variable "SECURITY_GROUP" {
  description = "List of security groups"
  default = [ "sg-11111111111111","sg-111111111111111111" ]
}

variable "AVAILABILITY_ZONE" {
  description = "List of availability zones"
  default = [ "us-1111-2a","us-1111-2b" ]
}

