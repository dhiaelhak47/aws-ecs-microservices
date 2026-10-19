#!/usr/bin/env bash
set -euo pipefail

echo "ECS Microservices — Cleanup"
echo "==========================="
echo ""

echo "Stopping services and removing volumes..."
docker compose down -v --remove-orphans

echo ""
echo "Removing built images..."
docker image rm auth-service:latest orders-service:latest notifications-service:latest 2>/dev/null || true

echo ""
echo "Local resources cleaned up."
echo ""
echo "NOTE: AWS resources (ECS, ECR, VPC, RDS, ElastiCache) are NOT affected."
echo "To destroy AWS resources: cd terraform && terraform destroy"
