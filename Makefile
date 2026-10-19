.PHONY: help build up down logs test test-auth test-orders test-notifications lint \
        terraform-init terraform-validate terraform-plan clean

# Default target
help:
	@echo "ECS Microservices - Available Commands"
	@echo "======================================"
	@echo ""
	@echo "Local Development:"
	@echo "  make build              Build all Docker images"
	@echo "  make up                 Start all services"
	@echo "  make down               Stop all services"
	@echo "  make logs               Tail logs from all services"
	@echo "  make clean              Stop services and remove volumes"
	@echo ""
	@echo "Testing:"
	@echo "  make test               Run all tests"
	@echo "  make test-auth          Run auth-service tests only"
	@echo "  make test-orders        Run orders-service tests only"
	@echo "  make test-notifications Run notifications-service tests only"
	@echo ""
	@echo "Code Quality:"
	@echo "  make lint               Run ESLint on all services"
	@echo ""
	@echo "Terraform:"
	@echo "  make terraform-init     Initialize Terraform"
	@echo "  make terraform-validate Validate Terraform configuration"
	@echo "  make terraform-plan     Show Terraform plan (dry-run)"
	@echo ""
	@echo "Setup:"
	@echo "  make setup              First-time setup (copy .env, build)"

setup:
	@if [ ! -f .env ]; then cp .env.example .env && echo "Created .env from .env.example"; fi
	@$(MAKE) build
	@echo ""
	@echo "Setup complete. Run 'make up' to start all services."

build:
	docker compose build

up:
	docker compose up -d
	@echo ""
	@echo "Services started. Available at:"
	@echo "  Auth Service:          http://localhost:3001"
	@echo "  Orders Service:        http://localhost:3002"
	@echo "  Notifications Service: http://localhost:3003"
	@echo "  NGINX (all services):  http://localhost:80"

down:
	docker compose down

logs:
	docker compose logs -f

test: test-auth test-orders test-notifications

test-auth:
	@echo "Running auth-service tests..."
	cd app/auth-service && npm ci --silent && NODE_ENV=test JWT_SECRET=test-secret npm test

test-orders:
	@echo "Running orders-service tests..."
	cd app/orders-service && npm ci --silent && NODE_ENV=test JWT_SECRET=test-secret npm test

test-notifications:
	@echo "Running notifications-service tests..."
	cd app/notifications-service && npm ci --silent && NODE_ENV=test npm test

lint:
	@echo "Linting auth-service..."
	cd app/auth-service && npm ci --silent && npm run lint || true
	@echo "Linting orders-service..."
	cd app/orders-service && npm ci --silent && npm run lint || true
	@echo "Linting notifications-service..."
	cd app/notifications-service && npm ci --silent && npm run lint || true

terraform-init:
	cd terraform && terraform init

terraform-validate:
	cd terraform && terraform fmt -check -recursive && terraform validate

terraform-plan:
	cd terraform && terraform plan -out=tfplan

clean:
	docker compose down -v --remove-orphans
	@echo "Stopped services and removed volumes."
