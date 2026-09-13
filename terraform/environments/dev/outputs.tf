output "vpc_id" {
  value = module.vpc.vpc_id
}

output "private_subnet_ids" {
  value = module.vpc.private_subnet_ids
}

output "public_subnet_ids" {
  value = module.vpc.public_subnet_ids
}

output "cluster_name" {
  value = module.eks.cluster_name
}

output "cluster_endpoint" {
  value = module.eks.cluster_endpoint
}

output "oidc_provider_arn" {
  value = module.eks.oidc_provider_arn
}

output "ecr_repo_urls" {
  value = module.ecr.repository_urls
}

output "route53_nameservers" {
  value       = data.aws_route53_zone.myser.name_servers
  description = "Add these as NS records for 'myser' at your DNS provider"
}

output "wildcard_certificate_arn" {
  value       = aws_acm_certificate.wildcard.arn
  description = "ACM cert ARN for *.myser.serghini.me (grafana/argocd ingresses)"
}