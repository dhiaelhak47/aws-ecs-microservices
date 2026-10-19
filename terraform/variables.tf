variable "aws_region" {
  description = "AWS region to deploy into"
  type        = string
  default     = "us-east-1"
}

variable "environment" {
  description = "Deployment environment (dev, staging, prod)"
  type        = string
  default     = "dev"

  validation {
    condition     = contains(["dev", "staging", "prod"], var.environment)
    error_message = "environment must be one of: dev, staging, prod"
  }
}

variable "project_name" {
  description = "Project name used as a prefix for all resource names"
  type        = string
  default     = "ecs-ms"
}

variable "vpc_cidr" {
  description = "CIDR block for the VPC"
  type        = string
  default     = "10.0.0.0/16"
}

variable "availability_zones" {
  description = "List of availability zones to use"
  type        = list(string)
  default     = ["us-east-1a", "us-east-1b"]
}

variable "public_subnet_cidrs" {
  description = "CIDR blocks for public subnets (one per AZ)"
  type        = list(string)
  default     = ["10.0.0.0/24", "10.0.2.0/24"]
}

variable "private_subnet_cidrs" {
  description = "CIDR blocks for private subnets (one per AZ)"
  type        = list(string)
  default     = ["10.0.1.0/24", "10.0.3.0/24"]
}

variable "container_image_tag" {
  description = "Docker image tag to deploy"
  type        = string
  default     = "latest"
}

variable "auth_service_cpu" {
  description = "CPU units for the auth service task (1 vCPU = 1024)"
  type        = number
  default     = 256
}

variable "auth_service_memory" {
  description = "Memory (MiB) for the auth service task"
  type        = number
  default     = 512
}

variable "orders_service_cpu" {
  description = "CPU units for the orders service task"
  type        = number
  default     = 256
}

variable "orders_service_memory" {
  description = "Memory (MiB) for the orders service task"
  type        = number
  default     = 512
}

variable "notifications_service_cpu" {
  description = "CPU units for the notifications service task"
  type        = number
  default     = 256
}

variable "notifications_service_memory" {
  description = "Memory (MiB) for the notifications service task"
  type        = number
  default     = 512
}

variable "elasticache_node_type" {
  description = "ElastiCache node type"
  type        = string
  default     = "cache.t3.micro"
}

variable "desired_count" {
  description = "Desired number of ECS tasks per service"
  type        = number
  default     = 2
}
