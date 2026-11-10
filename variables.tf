variable "aws_region" {
  type        = string
  default     = "ap-south-1" # Mumbai region
  description = "AWS region for deployment"
}

variable "environment" {
  type        = string
  default     = "prod"
  description = "Environment name (dev/staging/prod)"
}

variable "vpc_cidr" {
  type        = string
  default     = "10.0.0.0/16"
  description = "Main VPC IP address block"
}

variable "public_subnet_cidrs" {
  type        = list(string)
  default     = ["10.0.1.0/24", "10.0.2.0/24"]
  description = "IP ranges for public subnets (Front-end / Load Balancers)"
}

variable "private_subnet_cidrs" {
  type        = list(string)
  default     = ["10.0.10.0/24", "10.0.20.0/24"]
  description = "IP ranges for private subnets (Application / Databases)"
}

variable "availability_zones" {
  type        = list(string)
  default     = ["ap-south-1a", "ap-south-1b"]
  description = "AWS Availability Zones for multi-AZ redundancy"
}