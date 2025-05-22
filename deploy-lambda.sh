#!/usr/bin/env bash
set -e

PREFIX=$1
STACK="${PREFIX}-chain-stack"

# פרסום התבנית (יצירת IAM, Cognito, S3, SNS, SQS, ECS, DynamoDB)
aws cloudformation deploy \
  --template-file template.yaml \
  --stack-name ${STACK} \
  --parameter-overrides EnvPrefix=${PREFIX} \
  --capabilities CAPABILITY_NAMED_IAM

# עדכון קוד פונקציות Lambda (מקמpressions המקומיות שלך)
aws lambda update-function-code \
  --function-name ${PREFIX}-generate-upload-url \
  --zip-file fileb://generate_upload_url.zip

aws lambda update-function-code \
  --function-name ${PREFIX}-process-image \
  --zip-file fileb://process_image.zip

echo "✅ Lambdas updated"
