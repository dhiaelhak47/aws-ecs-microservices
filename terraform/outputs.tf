output "alb_dns_name" {
  description = "DNS name of the Application Load Balancer"
  value       = aws_lb.main.dns_name
}

output "ecr_auth_repository_url" {
  description = "ECR repository URL for the auth service"
  value       = aws_ecr_repository.auth_service.repository_url
}

output "ecr_orders_repository_url" {
  description = "ECR repository URL for the orders service"
  value       = aws_ecr_repository.orders_service.repository_url
}

output "ecr_notifications_repository_url" {
  description = "ECR repository URL for the notifications service"
  value       = aws_ecr_repository.notifications_service.repository_url
}

output "ecs_cluster_name" {
  description = "Name of the ECS cluster"
  value       = aws_ecs_cluster.main.name
}

output "vpc_id" {
  description = "ID of the VPC"
  value       = aws_vpc.main.id
}

output "redis_endpoint" {
  description = "ElastiCache Redis endpoint"
  value       = aws_elasticache_cluster.redis.cache_nodes[0].address
}

output "private_subnet_ids" {
  description = "IDs of the private subnets"
  value       = aws_subnet.private[*].id
}

output "public_subnet_ids" {
  description = "IDs of the public subnets"
  value       = aws_subnet.public[*].id
}
