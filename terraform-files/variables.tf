variable "aws_region" {
  description = "AWS region to deploy resources"
  type        = string
  default     = "us-east-1"
}

variable "vpc_cidr" {
  description = "CIDR block for the VPC"
  type        = string
  default     = "10.0.0.0/16"
}

variable "public_subnet_cidr" {
  description = "CIDR block for the public subnet"
  type        = string
  default     = "10.0.1.0/24"
}

variable "ami_id" {
  description = "AMI ID for EC2 instances (Ubuntu 20.04 LTS)"
  type        = string
  default     = "ami-0261755bbcb8c4a84" # Ubuntu 20.04 LTS in us-east-1
}

variable "master_instance_type" {
  description = "Instance type for Kubernetes master node"
  type        = string
  default     = "t3.medium" # At least 2 vCPUs and 4GB RAM recommended
}

variable "worker_instance_type" {
  description = "Instance type for Kubernetes worker node"
  type        = string
  default     = "t3.medium"
}

variable "key_name" {
  description = "Name of the AWS key pair to use for SSH access"
  type        = string
  default     = "carvilla-key" # Make sure this key pair exists in your AWS account
}
