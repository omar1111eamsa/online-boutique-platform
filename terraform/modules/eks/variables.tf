variable "cluster_name" {
  type        = string
  description = "EKS cluster name"
}

variable "cluster_version" {
  type    = string
  default = "1.33"
}

variable "cluster_role_arn" {
  type        = string
  description = "IAM role ARN for the EKS control plane"
}

variable "node_role_arn" {
  type        = string
  description = "IAM role ARN for the managed node group"
}

variable "private_subnet_ids" {
  type        = list(string)
  description = "Private subnet IDs for the cluster and node group"
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
  default = 2
}

variable "admin_principal_arn" {
  type        = string
  description = "IAM principal ARN granted cluster-admin"
}

variable "karpenter_node_role_arn" {
  type        = string
  description = "ARN of Karpenter node IAM role, granted EKS access"
}