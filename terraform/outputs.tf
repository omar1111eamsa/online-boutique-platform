output "vpc_id" {
  value = aws_vpc.main.id
}
output "private_subnet_ids" {
  value = aws_subnet.private[*].id
}
output "public_subnet_ids" {
  value = aws_subnet.public[*].id
}
output "ecr_repo_urls" {
  value = { for k, v in aws_ecr_repository.repos : k => v.repository_url }
}