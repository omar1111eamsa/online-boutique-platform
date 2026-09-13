resource "random_password" "redis_cart" {
  length  = 32
  special = false   # alphanumeric only — avoids shell/env escaping issues in redis --requirepass
}

resource "aws_secretsmanager_secret" "redis_cart_auth" {
  name = "${var.cluster_name}-redis-cart-auth"
  # Default recovery window (30 days) blocks recreating a secret with the
  # same name after `terraform destroy` -- every subsequent `apply` fails
  # with "already scheduled for deletion" until someone manually restores
  # or force-deletes it. Purge immediately instead.
  recovery_window_in_days = 0
}

resource "aws_secretsmanager_secret_version" "redis_cart_auth" {
  secret_id     = aws_secretsmanager_secret.redis_cart_auth.id
  secret_string = jsonencode({ password = random_password.redis_cart.result })
}