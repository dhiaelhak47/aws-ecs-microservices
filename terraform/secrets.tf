resource "aws_secretsmanager_secret" "jwt_secret" {
  name                    = "${local.name_prefix}/jwt-secret"
  description             = "JWT signing secret for auth service"
  recovery_window_in_days = 7

  tags = {
    Name = "${local.name_prefix}-jwt-secret"
  }
}

resource "aws_secretsmanager_secret_version" "jwt_secret" {
  secret_id     = aws_secretsmanager_secret.jwt_secret.id
  secret_string = "REPLACE_WITH_A_STRONG_RANDOM_SECRET_BEFORE_APPLYING"

  lifecycle {
    ignore_changes = [secret_string]
  }
}

resource "aws_secretsmanager_secret" "redis_connection" {
  name                    = "${local.name_prefix}/redis-connection"
  description             = "Redis connection string for session caching"
  recovery_window_in_days = 7

  tags = {
    Name = "${local.name_prefix}-redis-connection"
  }
}

resource "aws_secretsmanager_secret_version" "redis_connection" {
  secret_id     = aws_secretsmanager_secret.redis_connection.id
  secret_string = "redis://${aws_elasticache_cluster.redis.cache_nodes[0].address}:6379"

  lifecycle {
    ignore_changes = [secret_string]
  }
}
