variable "AWS_ACCESS_KEY" {
    type = string
    default = "******************"
}
variable "AWS_SECRET_KEY" {
    type = string
    default = "*************+*************"
}
variable "AWS_REGION" {
    default = "us-**-2"
}
# variable "PATH_TO_PRIVATE_KEY" {
#     default = "mykey"
# }
variable "PUBLIC_KEY" {
    default = "**.pub"
}
variable "INSTANCE_USERNAME" {
    default = "ubuntu"
}

variable "VPC_ID" {
  default = "vpc-***"
}
variable "SUBNETS" {
    default = ["subnet-aaa","subnet-bb"]

variable "AWS_AMI" {
  description = "AMI of existing EC2 machine"
  default = "ami-*****"
}

variable "EIPS" {
  description = "List of elastic IP addresses"
  default = [ "1111", "2222" ]
}

variable "EIP_ALLOT" {
  description = "List of Elastic IP allocation IDs"
  type        = list(string)
  default     = ["eipalloc-1111111", "eipalloc-222222222"]
}

variable "SECURITY_GROUP" {
  description = "List of security groups"
  default = [ "sg-*******" ]
}

variable "AVAILABILITY_ZONE" {
  description = "List of availability zones"
  default = [ "us-**-2a", "us-***-2b" ]
}

