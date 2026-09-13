variable "vpc_cidr" {
  type        = string
  description = "CIDR block for the VPC"
}

variable "cluster_name" {
  type        = string
  description = "EKS cluster name, used for tagging"
}

variable "public_subnet_cidrs" {
  type        = list(string)
  description = "CIDR blocks for public subnets, one per AZ"
}

variable "private_subnet_cidrs" {
  type        = list(string)
  description = "CIDR blocks for private subnets, one per AZ"
}