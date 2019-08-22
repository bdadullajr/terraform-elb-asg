variable "region" {
  description = "AWS region for hosting our your network"
  type        = "string"
  default     = "eu-west-1"
}

variable "ami" {
  description = "Base AMI to launch the instances"
  type        = "string"
  default     = "ami-0bbc25e23a7640b9b"
}

variable "instance_type" {
  description = "Type of EC2 instances to be provision"
  type        = "string"
  default     = "t2.micro"
}
