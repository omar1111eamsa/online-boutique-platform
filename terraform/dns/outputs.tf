output "zone_id" {
  value = aws_route53_zone.myser.zone_id
}

output "zone_arn" {
  value = aws_route53_zone.myser.arn
}

output "name_servers" {
  value = aws_route53_zone.myser.name_servers
}
