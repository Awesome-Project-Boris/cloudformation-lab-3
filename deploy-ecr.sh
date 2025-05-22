#!/usr/bin/env bash
set -e

PREFIX=$1
REPO="${PREFIX}-processor-repo"
ACCOUNT=$(aws sts get-caller-identity --query Account --output text)
REGION=$(aws configure get region)
TAG="latest"

# בניית Docker
docker build -t ${REPO}:${TAG} .

# יצירת ECR אם לא קיים
if ! aws ecr describe-repositories --repository-names ${REPO} >/dev/null 2>&1; then
  aws ecr create-repository --repository-name ${REPO}
fi

# התחברות ל-ECR ו‐push
aws ecr get-login-password --region ${REGION} \
  | docker login --username AWS --password-stdin ${ACCOUNT}.dkr.ecr.${REGION}.amazonaws.com
docker tag ${REPO}:${TAG} ${ACCOUNT}.dkr.ecr.${REGION}.amazonaws.com/${REPO}:${TAG}
docker push ${ACCOUNT}.dkr.ecr.${REGION}.amazonaws.com/${REPO}:${TAG}

echo "✅ pushed image to ECR: ${ACCOUNT}.dkr.ecr.${REGION}.amazonaws.com/${REPO}:${TAG}"
