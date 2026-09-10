variable "services" {
  type        = list(string)
  description = "List of service names, one ECR repo created per entry"
}

variable "image_tag_mutability" {
  type    = string
  default = "MUTABLE"
}
