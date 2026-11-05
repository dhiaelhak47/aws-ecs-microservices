resource "aws_ecs_cluster" "main" {
  name = "${local.name_prefix}-cluster"

  setting {
    name  = "containerInsights"
    value = "enabled"
  }

  tags = {
    Name = "${local.name_prefix}-cluster"
  }
}

resource "aws_security_group" "ecs_tasks" {
  name        = "${local.name_prefix}-ecs-tasks-sg"
  description = "Security group for ECS Fargate tasks"
  vpc_id      = aws_vpc.main.id

  ingress {
    description     = "HTTP from ALB"
    from_port       = 3001
    to_port         = 3003
    protocol        = "tcp"
    security_groups = [aws_security_group.alb.id]
  }

  ingress {
    description = "Inter-service communication"
    from_port   = 3001
    to_port     = 3003
    protocol    = "tcp"
    self        = true
  }

  egress {
    from_port   = 0
    to_port     = 0
    protocol    = "-1"
    cidr_blocks = ["0.0.0.0/0"]
  }

  tags = {
    Name = "${local.name_prefix}-ecs-tasks-sg"
  }
}

resource "aws_cloudwatch_log_group" "auth_service" {
  name              = "/ecs/${local.name_prefix}/auth-service"
  retention_in_days = 14
}

resource "aws_cloudwatch_log_group" "orders_service" {
  name              = "/ecs/${local.name_prefix}/orders-service"
  retention_in_days = 14
}

resource "aws_cloudwatch_log_group" "notifications_service" {
  name              = "/ecs/${local.name_prefix}/notifications-service"
  retention_in_days = 14
}

resource "aws_ecs_task_definition" "auth_service" {
  family                   = "${local.name_prefix}-auth-service"
  network_mode             = "awsvpc"
  requires_compatibilities = ["FARGATE"]
  cpu                      = var.auth_service_cpu
  memory                   = var.auth_service_memory
  execution_role_arn       = aws_iam_role.ecs_task_execution.arn
  task_role_arn            = aws_iam_role.ecs_task.arn

  container_definitions = jsonencode([
    {
      name      = "auth-service"
      image     = "${aws_ecr_repository.auth_service.repository_url}:${var.container_image_tag}"
      essential = true
      portMappings = [
        {
          containerPort = 3001
          protocol      = "tcp"
        }
      ]
      environment = [
        { name = "NODE_ENV", value = "production" },
        { name = "AUTH_SERVICE_PORT", value = "3001" },
        { name = "REDIS_HOST", value = aws_elasticache_cluster.redis.cache_nodes[0].address },
        { name = "REDIS_PORT", value = "6379" }
      ]
      secrets = [
        {
          name      = "JWT_SECRET"
          valueFrom = aws_secretsmanager_secret.jwt_secret.arn
        }
      ]
      logConfiguration = {
        logDriver = "awslogs"
        options = {
          awslogs-group         = aws_cloudwatch_log_group.auth_service.name
          awslogs-region        = var.aws_region
          awslogs-stream-prefix = "ecs"
        }
      }
      healthCheck = {
        command     = ["CMD-SHELL", "node -e \"require('http').get('http://localhost:3001/health', r => r.statusCode === 200 ? process.exit(0) : process.exit(1))\""]
        interval    = 30
        timeout     = 10
        retries     = 3
        startPeriod = 10
      }
    },
    {
      name      = "xray-daemon"
      image     = "amazon/aws-xray-daemon"
      essential = false
      portMappings = [
        {
          containerPort = 2000
          protocol      = "udp"
        }
      ]
      logConfiguration = {
        logDriver = "awslogs"
        options = {
          awslogs-group         = aws_cloudwatch_log_group.auth_service.name
          awslogs-region        = var.aws_region
          awslogs-stream-prefix = "xray"
        }
      }
    }
  ])

  tags = {
    Name = "${local.name_prefix}-auth-service-td"
  }
}

resource "aws_ecs_task_definition" "orders_service" {
  family                   = "${local.name_prefix}-orders-service"
  network_mode             = "awsvpc"
  requires_compatibilities = ["FARGATE"]
  cpu                      = var.orders_service_cpu
  memory                   = var.orders_service_memory
  execution_role_arn       = aws_iam_role.ecs_task_execution.arn
  task_role_arn            = aws_iam_role.ecs_task.arn

  container_definitions = jsonencode([
    {
      name      = "orders-service"
      image     = "${aws_ecr_repository.orders_service.repository_url}:${var.container_image_tag}"
      essential = true
      portMappings = [
        {
          containerPort = 3002
          protocol      = "tcp"
        }
      ]
      environment = [
        { name = "NODE_ENV", value = "production" },
        { name = "ORDERS_SERVICE_PORT", value = "3002" },
        { name = "AUTH_SERVICE_URL", value = "http://auth-service.microservices.local:3001" },
        { name = "NOTIFICATIONS_SERVICE_URL", value = "http://notifications-service.microservices.local:3003" },
        { name = "REDIS_HOST", value = aws_elasticache_cluster.redis.cache_nodes[0].address },
        { name = "REDIS_PORT", value = "6379" }
      ]
      secrets = [
        {
          name      = "JWT_SECRET"
          valueFrom = aws_secretsmanager_secret.jwt_secret.arn
        }
      ]
      logConfiguration = {
        logDriver = "awslogs"
        options = {
          awslogs-group         = aws_cloudwatch_log_group.orders_service.name
          awslogs-region        = var.aws_region
          awslogs-stream-prefix = "ecs"
        }
      }
      healthCheck = {
        command     = ["CMD-SHELL", "node -e \"require('http').get('http://localhost:3002/health', r => r.statusCode === 200 ? process.exit(0) : process.exit(1))\""]
        interval    = 30
        timeout     = 10
        retries     = 3
        startPeriod = 10
      }
    },
    {
      name      = "xray-daemon"
      image     = "amazon/aws-xray-daemon"
      essential = false
      portMappings = [
        {
          containerPort = 2000
          protocol      = "udp"
        }
      ]
      logConfiguration = {
        logDriver = "awslogs"
        options = {
          awslogs-group         = aws_cloudwatch_log_group.orders_service.name
          awslogs-region        = var.aws_region
          awslogs-stream-prefix = "xray"
        }
      }
    }
  ])

  tags = {
    Name = "${local.name_prefix}-orders-service-td"
  }
}

resource "aws_ecs_task_definition" "notifications_service" {
  family                   = "${local.name_prefix}-notifications-service"
  network_mode             = "awsvpc"
  requires_compatibilities = ["FARGATE"]
  cpu                      = var.notifications_service_cpu
  memory                   = var.notifications_service_memory
  execution_role_arn       = aws_iam_role.ecs_task_execution.arn
  task_role_arn            = aws_iam_role.ecs_task.arn

  container_definitions = jsonencode([
    {
      name      = "notifications-service"
      image     = "${aws_ecr_repository.notifications_service.repository_url}:${var.container_image_tag}"
      essential = true
      portMappings = [
        {
          containerPort = 3003
          protocol      = "tcp"
        }
      ]
      environment = [
        { name = "NODE_ENV", value = "production" },
        { name = "NOTIFICATIONS_SERVICE_PORT", value = "3003" }
      ]
      logConfiguration = {
        logDriver = "awslogs"
        options = {
          awslogs-group         = aws_cloudwatch_log_group.notifications_service.name
          awslogs-region        = var.aws_region
          awslogs-stream-prefix = "ecs"
        }
      }
      healthCheck = {
        command     = ["CMD-SHELL", "node -e \"require('http').get('http://localhost:3003/health', r => r.statusCode === 200 ? process.exit(0) : process.exit(1))\""]
        interval    = 30
        timeout     = 10
        retries     = 3
        startPeriod = 10
      }
    },
    {
      name      = "xray-daemon"
      image     = "amazon/aws-xray-daemon"
      essential = false
      portMappings = [
        {
          containerPort = 2000
          protocol      = "udp"
        }
      ]
      logConfiguration = {
        logDriver = "awslogs"
        options = {
          awslogs-group         = aws_cloudwatch_log_group.notifications_service.name
          awslogs-region        = var.aws_region
          awslogs-stream-prefix = "xray"
        }
      }
    }
  ])

  tags = {
    Name = "${local.name_prefix}-notifications-service-td"
  }
}

resource "aws_ecs_service" "auth_service" {
  name            = "${local.name_prefix}-auth-service"
  cluster         = aws_ecs_cluster.main.id
  task_definition = aws_ecs_task_definition.auth_service.arn
  desired_count   = var.desired_count
  launch_type     = "FARGATE"

  network_configuration {
    subnets          = aws_subnet.private[*].id
    security_groups  = [aws_security_group.ecs_tasks.id]
    assign_public_ip = false
  }

  load_balancer {
    target_group_arn = aws_lb_target_group.auth_service.arn
    container_name   = "auth-service"
    container_port   = 3001
  }

  service_registries {
    registry_arn = aws_service_discovery_service.auth_service.arn
  }

  depends_on = [aws_lb_listener_rule.auth_service]

  tags = {
    Name = "${local.name_prefix}-auth-service"
  }
}

resource "aws_ecs_service" "orders_service" {
  name            = "${local.name_prefix}-orders-service"
  cluster         = aws_ecs_cluster.main.id
  task_definition = aws_ecs_task_definition.orders_service.arn
  desired_count   = var.desired_count
  launch_type     = "FARGATE"

  network_configuration {
    subnets          = aws_subnet.private[*].id
    security_groups  = [aws_security_group.ecs_tasks.id]
    assign_public_ip = false
  }

  load_balancer {
    target_group_arn = aws_lb_target_group.orders_service.arn
    container_name   = "orders-service"
    container_port   = 3002
  }

  service_registries {
    registry_arn = aws_service_discovery_service.orders_service.arn
  }

  depends_on = [aws_lb_listener_rule.orders_service]

  tags = {
    Name = "${local.name_prefix}-orders-service"
  }
}

resource "aws_ecs_service" "notifications_service" {
  name            = "${local.name_prefix}-notifications-service"
  cluster         = aws_ecs_cluster.main.id
  task_definition = aws_ecs_task_definition.notifications_service.arn
  desired_count   = var.desired_count
  launch_type     = "FARGATE"

  network_configuration {
    subnets          = aws_subnet.private[*].id
    security_groups  = [aws_security_group.ecs_tasks.id]
    assign_public_ip = false
  }

  load_balancer {
    target_group_arn = aws_lb_target_group.notifications_service.arn
    container_name   = "notifications-service"
    container_port   = 3003
  }

  service_registries {
    registry_arn = aws_service_discovery_service.notifications_service.arn
  }

  depends_on = [aws_lb_listener_rule.notifications_service]

  tags = {
    Name = "${local.name_prefix}-notifications-service"
  }
}
