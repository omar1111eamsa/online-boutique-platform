resource "random_password" "redis_cart" {
  length  = 32
  special = false   # alphanumeric only — avoids shell/env escaping issues in redis --requirepass
}

resource "aws_secretsmanager_secret" "redis_cart_auth" {
  name = "${var.cluster_name}-redis-cart-auth"
}

resource "aws_secretsmanager_secret_version" "redis_cart_auth" {
  secret_id     = aws_secretsmanager_secret.redis_cart_auth.id
  secret_string = jsonencode({ password = random_password.redis_cart.result })
}