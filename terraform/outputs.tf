output "vpc_id" {
  value = module.vpc.vpc_id
}

output "private_subnet_ids" {
  value = module.vpc.private_subnet_ids
}

output "public_subnet_ids" {
  value = module.vpc.public_subnet_ids
}

output "ecr_repo_urls" {
  value = { for k, v in aws_ecr_repository.repos : k => v.repository_url }
}
