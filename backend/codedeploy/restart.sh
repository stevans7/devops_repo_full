#!/bin/bash
set -euo pipefail

IMG_FILE="/srv/backend/image.txt"
IMAGE="${IMAGE:-}"
if [ -z "${IMAGE}" ] && [ -f "$IMG_FILE" ]; then
  IMAGE=$(cat "$IMG_FILE" | tr -d '\n\r')
fi
if [ -z "${IMAGE}" ]; then
  echo "No image reference provided; falling back to 'backend:latest'"
  IMAGE="backend:latest"
fi

# Optional env file for secrets/config
ENV_FILE="/etc/backend.env"
[ -f "$ENV_FILE" ] && ENV_ARG=(--env-file "$ENV_FILE") || ENV_ARG=()

# Login to ECR if needed
REGISTRY="${IMAGE%%/*}"
if echo "$REGISTRY" | grep -q ".ecr."; then
  REGION_FROM_IMAGE=$(echo "$REGISTRY" | sed -n 's#.*\.ecr\.\([^\.]*\)\.amazonaws\.com#\1#p')
  aws ecr get-login-password --region "$REGION_FROM_IMAGE" | docker login --username AWS --password-stdin "$REGISTRY"
fi

echo "Deploying container $IMAGE"
docker rm -f backend || true
docker run -d --restart=always --name backend -p 3000:3000 "${ENV_ARG[@]}" "$IMAGE"
echo 'Deployed'
