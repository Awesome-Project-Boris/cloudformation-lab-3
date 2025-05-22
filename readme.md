# Chain Demo AWS Infrastructure

This project demonstrates a sample AWS infrastructure with a chain of operations connecting multiple AWS services, including Cognito, API Gateway, Lambda, S3, Rekognition, SNS, SQS, ECR, ECS, and DynamoDB.

## Table of Contents

* [Prerequisites](#prerequisites)
* [Architecture Overview](#architecture-overview)
* [Deployment Steps](#deployment-steps)

  * [1. Deploy CloudFormation Stack](#1-deploy-cloudformation-stack)
  * [2. Build and Push Docker Image to ECR](#2-build-and-push-docker-image-to-ecr)
  * [3. Package and Deploy Lambda Functions](#3-package-and-deploy-lambda-functions)
* [Using the Application](#using-the-application)
* [Cleanup](#cleanup)
* [Parameters and Outputs](#parameters-and-outputs)
* [License](#license)

## Prerequisites

* AWS CLI configured with appropriate credentials and region.
* Docker installed (for building the image).
* Node.js (for packaging Lambda functions).
* IAM permissions to create CloudFormation stacks and AWS resources.

## Architecture Overview

The infrastructure comprises the following workflow:

1. **Cognito** for user authentication.
2. **API Gateway** secured with Cognito to invoke **Lambda (GenerateUploadUrl)**.
3. **GenerateUploadUrl Lambda** returns a pre-signed S3 URL.
4. **S3** bucket stores uploaded images and triggers **ProcessImage Lambda** on object creation.
5. **ProcessImage Lambda** calls **Rekognition** to detect labels in the image.
6. Detected labels are published to an **SNS** topic.
7. **SNS** pushes messages to an **SQS** queue.
8. **ECS Fargate** service (image from **ECR**) polls **SQS**, processes messages, and writes results to **DynamoDB**.
9. **API Gateway** (with Cognito) invokes **Lambda** to retrieve results from **DynamoDB** for the user.

## Deployment Steps

### 1. Deploy CloudFormation Stack

```bash
aws cloudformation deploy \
  --template-file template.yaml \
  --stack-name <EnvPrefix>-chain-stack \
  --parameter-overrides EnvPrefix=<EnvPrefix> \
  --capabilities CAPABILITY_NAMED_IAM
```

This creates:

* Cognito User Pool & Client
* API Gateway with authorizer
* S3 bucket
* Two Lambda functions (GenerateUploadUrl & ProcessImage)
* SNS topic & SQS queue subscription
* ECR repository
* ECS cluster, task definition & service
* DynamoDB table

### 2. Build and Push Docker Image to ECR

```bash
./deploy-ecr.sh <EnvPrefix>
```

This script:

1. Builds the Docker image for the image processor.
2. Creates the ECR repository if missing.
3. Tags & pushes the image to ECR.

### 3. Package and Deploy Lambda Functions

1. Zip each Lambda function folder:

   ```bash
   zip generate_upload_url.zip index.js
   zip process_image.zip index.js
   ```
2. Run the deploy script:

   ```bash
   ./deploy-lambda.sh <EnvPrefix>
   ```

This updates Lambda code for both functions.

## Using the Application

1. **User Authentication**: Sign in via Cognito Hosted UI or AWS SDK to obtain an `ID_TOKEN`.
2. **Get Upload URL**:

   ```bash
   curl -H "Authorization: Bearer $ID_TOKEN" \
     https://<ApiId>.execute-api.<region>.amazonaws.com/prod/upload-url
   ```
3. **Upload Image**: PUT the image to the returned URL.
4. **Processing**: The image is processed end-to-end (Lambda → Rekognition → SNS → SQS → ECS → DynamoDB).
5. **Fetch Results**: Implement or extend a GET endpoint in API Gateway + Lambda to query DynamoDB for processed results.

## Cleanup

To delete all resources:

```bash
aws cloudformation delete-stack --stack-name <EnvPrefix>-chain-stack
```

This removes all provisioned resources automatically.

## Parameters and Outputs

* **Parameter**: `EnvPrefix` (String) — prefix for naming resources.

* **Outputs**:

  * `ApiUrl` — Base URL of the API Gateway endpoint for upload-url.

## License

This sample project is provided under the MIT License.
