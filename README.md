# AWS ECS Fargate — Containerized Microservices

A production-grade microservices architecture deployed on **Amazon ECS Fargate** with Terraform-managed infrastructure, blue/green deployments, and distributed tracing via AWS X-Ray.

---

## Architecture

![Architecture Diagram](diagrams/architecture.drawio)

The system is composed of three independent microservices behind an **Application Load Balancer**, running on ECS Fargate in private subnets across two Availability Zones.

```
Internet → Route 53 → ALB (path-based routing)
              ├── /auth/*          → Auth Service        (ECS Fargate)
              ├── /api/orders/*    → Orders Service       (ECS Fargate)
              └── /notifications/* → Notifications Service (ECS Fargate)

All services → ElastiCache Redis  (session cache)
All services → AWS Cloud Map      (service discovery)
All services → Secrets Manager    (JWT secret, Redis URL)
All services → CloudWatch Logs + X-Ray (observability)
```

---

## AWS Services

| Layer | Service | Purpose |
|---|---|---|
| Compute | ECS Fargate | Serverless container runtime — no EC2 to manage |
| Networking | VPC, ALB, Security Groups | Isolated network with path-based routing |
| Registry | ECR | Private Docker image registry with vulnerability scanning |
| Discovery | AWS Cloud Map | DNS-based service-to-service discovery (`microservices.local`) |
| Cache | ElastiCache Redis | Shared session store across stateless container instances |
| Secrets | Secrets Manager | Encrypted credentials injected at container startup |
| Observability | CloudWatch Logs, X-Ray | Centralized logs and distributed tracing across all services |
| CI/CD | CodePipeline, CodeDeploy | Blue/green deployments with automatic rollback |
| DNS | Route 53 | Alias record pointing to ALB with health checks |

---

## Services

### Auth Service — `POST /auth/register` · `POST /auth/login` · `GET /auth/verify`

Handles user registration, password hashing (bcrypt), and JWT issuance. Other services validate tokens by calling `/auth/verify` internally via Cloud Map DNS resolution.

### Orders Service — `GET|POST /api/orders` · `GET|PUT|DELETE /api/orders/:id`

Full CRUD for orders. Enforces JWT authentication on every route, calculates order totals, and fires an event to the Notifications Service on each new order. Returns 403 for cross-user access attempts.

### Notifications Service — `POST /notifications` · `GET /notifications` · `GET /notifications/:id`

Receives order lifecycle events from the Orders Service and stores them for audit and delivery. Operates as an internal service — no direct public auth required.

---

## Infrastructure

All AWS resources are provisioned with **Terraform**.

```
terraform/
├── main.tf           # Provider and locals
├── vpc.tf            # VPC, public/private subnets, NAT Gateway (2 AZs)
├── ecr.tf            # ECR repositories + lifecycle policies
├── alb.tf            # ALB, target groups, path-based listener rules
├── ecs.tf            # ECS cluster, task definitions, Fargate services
├── cloudmap.tf       # Private DNS namespace + service registry
├── elasticache.tf    # Redis cluster in private subnets
├── secrets.tf        # Secrets Manager secrets
├── iam.tf            # Task execution role + per-service task roles
├── variables.tf      # All configurable inputs
└── outputs.tf        # ALB DNS, ECR URLs, cluster name
```

---

## Deploying to AWS

### Prerequisites

- AWS CLI configured (`aws configure`)
- Terraform ≥ 1.5
- Docker

### 1 — Build and push images to ECR

```bash
# Authenticate Docker with ECR
aws ecr get-login-password --region us-east-1 \
  | docker login --username AWS \
    --password-stdin <ACCOUNT_ID>.dkr.ecr.us-east-1.amazonaws.com

# Build and tag
docker build -t auth-service ./app/auth-service
docker tag auth-service:latest <ACCOUNT_ID>.dkr.ecr.us-east-1.amazonaws.com/ecs-microservices-prod-auth-service:latest

# Repeat for orders-service and notifications-service, then push all three
docker push <ACCOUNT_ID>.dkr.ecr.us-east-1.amazonaws.com/ecs-microservices-prod-auth-service:latest
```

Or use the helper script:

```bash
AWS_ACCOUNT_ID=<your-account-id> AWS_REGION=us-east-1 bash scripts/build.sh
```

### 2 — Provision infrastructure

```bash
cd terraform
terraform init
terraform plan -out=tfplan
terraform apply tfplan
```

Terraform outputs the ALB DNS name on completion.

### 3 — Set the JWT secret

The JWT secret is created by Terraform but its value must be set manually — never stored in code:

```bash
aws secretsmanager put-secret-value \
  --secret-id "ecs-microservices-prod/jwt-secret" \
  --secret-string "$(openssl rand -base64 48)"
```

### 4 — Verify deployment

```bash
ALB=$(terraform output -raw alb_dns_name)

curl -X POST http://$ALB/auth/register \
  -H "Content-Type: application/json" \
  -d '{"email":"test@example.com","password":"Test123!","name":"Test User"}'

TOKEN=$(curl -s -X POST http://$ALB/auth/login \
  -H "Content-Type: application/json" \
  -d '{"email":"test@example.com","password":"Test123!"}' | jq -r .token)

curl http://$ALB/api/orders -H "Authorization: Bearer $TOKEN"
```

### Teardown

```bash
terraform destroy
```

---

## CI/CD

GitHub Actions runs on every push:

- **CI pipeline** — installs dependencies, runs Jest tests for all three services, builds Docker images
- **Terraform validate** — checks formatting and validates HCL on every change to `terraform/`

Blue/green deployments to ECS are handled by **AWS CodeDeploy**, configured in `terraform/ecs.tf`. A failed health check triggers automatic rollback to the previous task definition.

---

## Local Development

```bash
cp .env.example .env
docker compose up -d
```

Services available at `http://localhost` via NGINX reverse proxy. The local stack mirrors the AWS architecture — NGINX replaces ALB, Docker networking replaces Cloud Map DNS.

---

## Security

- Containers run in **private subnets** — not directly reachable from the internet
- Each service has a dedicated **IAM task role** with least-privilege policies
- Credentials are injected from **Secrets Manager** at container startup — never in environment files or images
- ECR scans images for vulnerabilities on every push
- ALB security group allows only ports 80/443; ECS security group allows only traffic from ALB

---

## Estimated Cost (us-east-1)

| Resource | Monthly estimate |
|---|---|
| ECS Fargate (3 services × 0.25 vCPU / 512 MB) | ~$25 |
| ALB | ~$18 |
| ElastiCache Redis (cache.t3.micro) | ~$15 |
| NAT Gateway | ~$35 |
| ECR, CloudWatch, Secrets Manager | ~$5 |
| **Total** | **~$98 / month** |

Run `terraform destroy` when not in use to avoid charges.
