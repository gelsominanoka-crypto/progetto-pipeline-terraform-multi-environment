# AWS Region
variable "aws_region" {
  description = "AWS region for resources"
  type        = string
  default     = "us-east-1"
}

# Environment name
variable "environment" {
  description = "Environment name (Dev/Prod)"
  type        = string
  default     = "Dev"
}

# EC2 Instance Type
variable "instance_type" {
  description = "EC2 instance type"
  type        = string
  default     = "t2.micro"
}

# Key Pair Name
variable "key_pair_name" {
  description = "Name of the AWS Key Pair for EC2 access"
  type        = string
  default     = "chuave-per-pipeline" 
}

# Allowed CIDR for SSH access
variable "allowed_cidr" {
  description = "CIDR block allowed for SSH access"
  type        = string
  default     = "0.0.0.0/0"
}

