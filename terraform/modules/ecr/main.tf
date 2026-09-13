resource "aws_ecr_repository" "repos" {
  for_each             = toset(var.services)
  name                 = each.value
  image_tag_mutability = var.image_tag_mutability
  # Images get pushed by CI on every build; without this, `terraform destroy`
  # fails on any repo that still has images instead of destroying cleanly.
  force_delete = true

  image_scanning_configuration {
    scan_on_push = true
  }
}