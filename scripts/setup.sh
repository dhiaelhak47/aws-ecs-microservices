#!/usr/bin/env bash
set -euo pipefail

echo "ECS Microservices — Setup"
echo "========================="

# Check Docker
if ! command -v docker &>/dev/null; then
  echo "ERROR: Docker is not installed. Install from https://docs.docker.com/get-docker/"
  exit 1
fi
echo "Docker: $(docker --version)"

# Check Docker Compose
if ! docker compose version &>/dev/null; then
  echo "ERROR: Docker Compose plugin not found. Update Docker Desktop or install the plugin."
  exit 1
fi
echo "Docker Compose: $(docker compose version)"

# Copy .env if it does not exist
if [ ! -f .env ]; then
  cp .env.example .env
  echo "Created .env from .env.example — review and update values before running in production"
else
  echo ".env already exists — skipping"
fi

# Build all images
echo ""
echo "Building Docker images..."
docker compose build

echo ""
echo "Setup complete!"
echo ""
echo "Next steps:"
echo "  make up          Start all services"
echo "  make logs        Tail service logs"
echo "  make test        Run all tests"
echo ""
echo "Service URLs (after 'make up'):"
echo "  NGINX gateway:         http://localhost:80"
echo "  Auth Service:          http://localhost:3001"
echo "  Orders Service:        http://localhost:3002"
echo "  Notifications Service: http://localhost:3003"
