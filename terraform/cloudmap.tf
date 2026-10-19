resource "aws_service_discovery_private_dns_namespace" "main" {
  name        = "microservices.local"
  description = "Private DNS namespace for ECS service discovery"
  vpc         = aws_vpc.main.id

  tags = {
    Name = "${local.name_prefix}-namespace"
  }
}

resource "aws_service_discovery_service" "auth_service" {
  name = "auth-service"

  dns_config {
    namespace_id = aws_service_discovery_private_dns_namespace.main.id

    dns_records {
      ttl  = 10
      type = "A"
    }

    routing_policy = "MULTIVALUE"
  }

  health_check_custom_config {
    failure_threshold = 1
  }

  tags = {
    Name = "${local.name_prefix}-auth-sd"
  }
}

resource "aws_service_discovery_service" "orders_service" {
  name = "orders-service"

  dns_config {
    namespace_id = aws_service_discovery_private_dns_namespace.main.id

    dns_records {
      ttl  = 10
      type = "A"
    }

    routing_policy = "MULTIVALUE"
  }

  health_check_custom_config {
    failure_threshold = 1
  }

  tags = {
    Name = "${local.name_prefix}-orders-sd"
  }
}

resource "aws_service_discovery_service" "notifications_service" {
  name = "notifications-service"

  dns_config {
    namespace_id = aws_service_discovery_private_dns_namespace.main.id

    dns_records {
      ttl  = 10
      type = "A"
    }

    routing_policy = "MULTIVALUE"
  }

  health_check_custom_config {
    failure_threshold = 1
  }

  tags = {
    Name = "${local.name_prefix}-notifications-sd"
  }
}
