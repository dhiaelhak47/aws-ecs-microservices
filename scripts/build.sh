#!/usr/bin/env bash
set -euo pipefail

# Build and tag Docker images for ECR push.
# This script does NOT push images. Run this after setting AWS_ACCOUNT_ID and AWS_REGION.

AWS_ACCOUNT_ID="${AWS_ACCOUNT_ID:?AWS_ACCOUNT_ID is required}"
AWS_REGION="${AWS_REGION:?AWS_REGION is required}"
IMAGE_TAG="${IMAGE_TAG:-latest}"
PROJECT="${PROJECT_NAME:-ecs-ms}"
ENVIRONMENT="${ENVIRONMENT:-dev}"

ECR_BASE="${AWS_ACCOUNT_ID}.dkr.ecr.${AWS_REGION}.amazonaws.com"
NAME_PREFIX="${PROJECT}-${ENVIRONMENT}"

SERVICES=("auth-service" "orders-service" "notifications-service")

echo "Building images for ${NAME_PREFIX} in ${AWS_REGION}"
echo "ECR base: ${ECR_BASE}"
echo "Tag: ${IMAGE_TAG}"
echo ""

for SERVICE in "${SERVICES[@]}"; do
  echo "Building ${SERVICE}..."
  docker build -t "${SERVICE}:${IMAGE_TAG}" "./app/${SERVICE}"
  docker tag "${SERVICE}:${IMAGE_TAG}" "${ECR_BASE}/${NAME_PREFIX}-${SERVICE}:${IMAGE_TAG}"
  echo "Tagged: ${ECR_BASE}/${NAME_PREFIX}-${SERVICE}:${IMAGE_TAG}"
  echo ""
done

echo "All images built and tagged."
echo ""
echo "To push to ECR:"
echo "  1. Authenticate: aws ecr get-login-password --region ${AWS_REGION} | docker login --username AWS --password-stdin ${ECR_BASE}"
for SERVICE in "${SERVICES[@]}"; do
  echo "  2. Push: docker push ${ECR_BASE}/${NAME_PREFIX}-${SERVICE}:${IMAGE_TAG}"
done
