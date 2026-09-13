variable "region" {
  type    = string
  default = "eu-west-1"
}

variable "vpc_cidr" {
  type    = string
  default = "10.0.0.0/16"
}

variable "cluster_name" {
  type    = string
  default = "boutique-dev"
}

variable "public_subnet_cidrs" {
  type    = list(string)
  default = ["10.0.0.0/20", "10.0.16.0/20", "10.0.32.0/20"]
}

variable "private_subnet_cidrs" {
  type    = list(string)
  default = ["10.0.48.0/20", "10.0.64.0/20", "10.0.80.0/20"]
}

variable "cluster_version" {
  type    = string
  default = "1.33"
}

variable "node_instance_types" {
  type    = list(string)
  default = ["c7i-flex.large"]
}

variable "node_desired_size" {
  type    = number
  default = 2 # was 1 -- Karpenter's own controller can ONLY run on this node group
              # (by design, to avoid a chicken-and-egg problem with self-managed
              # nodes). With desired=1, that single node dying left Karpenter with
              # nowhere to reschedule, completely unable to fix anything -- including
              # itself. A second node means there's always a fallback.
}

variable "node_min_size" {
  type    = number
  default = 2
}

variable "node_max_size" {
  type    = number
  default = 3 # was 2 -- headroom above desired=2 for rolling node replacements
}

variable "services" {
  type = list(string)
  default = [
    "frontend", "cartservice", "productcatalogservice", "currencyservice",
    "paymentservice", "shippingservice", "emailservice", "checkoutservice",
    "recommendationservice", "adservice", "loadgenerator"
  ]
}

variable "domain_name" {
  type    = string
  default = "boutique.myser.serghini.me"
}

variable "github_token" {
  type      = string
  sensitive = true
}