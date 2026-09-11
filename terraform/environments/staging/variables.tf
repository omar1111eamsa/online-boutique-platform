variable "region" {
  type    = string
  default = "eu-west-1"
}

variable "cluster_name" {
  type    = string
  default = "boutique-staging"
}

variable "cluster_version" {
  type    = string
  default = "1.33"
}

variable "vpc_cidr" {
  type    = string
  default = "10.1.0.0/16"
}

variable "public_subnet_cidrs" {
  type    = list(string)
  default = ["10.1.0.0/20", "10.1.16.0/20", "10.1.32.0/20"]
}

variable "private_subnet_cidrs" {
  type    = list(string)
  default = ["10.1.48.0/20", "10.1.64.0/20", "10.1.80.0/20"]
}

variable "node_instance_types" {
  type    = list(string)
  default = ["c7i-flex.large"]
}

variable "node_desired_size" {
  type    = number
  default = 2
}

variable "node_min_size" {
  type    = number
  default = 2
}

variable "node_max_size" {
  type    = number
  default = 3
}

variable "admin_principal_arn" {
  type        = string
  description = "IAM user/role ARN granted EKS cluster-admin"
  default     = "arn:aws:iam::858093957996:user/terrafrom-aws"
}

variable "services" {
  type = list(string)
  default = [
    "frontend", "cartservice", "productcatalogservice", "currencyservice",
    "paymentservice", "shippingservice", "emailservice", "checkoutservice",
    "recommendationservice", "adservice", "loadgenerator"
  ]
}
