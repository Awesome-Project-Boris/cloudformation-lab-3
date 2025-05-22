# Chain Demo AWS Infrastructure

This repository implements a sample AWS-based “chain” of operations connecting 10+ AWS services:
Cognito, API Gateway, Lambda, S3, Rekognition, SNS, SQS, ECR, ECS (Fargate) and DynamoDB.

> **Note:** All resources are created via a single CloudFormation template (`template.yaml`),
> and application code is deployed using two helper scripts.

---

## Table of Contents

* [Features](#features)
* [Prerequisites](#prerequisites)
* [Repository Structure](#repository-structure)
* [Installation](#installation)

  * [1. Bootstrap AWS CLI & ECR](#1-bootstrap-aws-cli--ecr)
  * [2. Deploy CloudFormation Stack](#2-deploy-cloudformation-stack)
  * [3. Build & Push Processor Docker Image](#3-build--push-processor-docker-image)
  * [4. Package & Deploy Lambda Functions](#4-package--deploy-lambda-functions)
* [Usage](#usage)
* [Cleanup](#cleanup)
* [Troubleshooting](#troubleshooting)
* [License](#license)

---

## Features

1. **Cognito** User Pool for authentication
2. **API Gateway** secured by Cognito to expose endpoints
3. **Lambda** to generate pre-signed S3 upload URLs
4. **S3** bucket to store images & trigger processing
5. **Lambda** to call **Rekognition**, detect labels
6. **SNS** topic to publish Rekognition results
7. **SQS** queue subscribed to the SNS topic
8. **ECR** repository to store the Docker image
9. **ECS Fargate** service to poll SQS and write to DynamoDB
10. **DynamoDB** table to persist analysis results

---

## Prerequisites

* **AWS CLI** installed and configured (`aws configure`)
* **Docker** (for building ECS image)
* **Node.js** (for packaging simple Lambdas)
* IAM user/role with privileges for CloudFormation, IAM, Lambda, S3, SNS, SQS, ECR, ECS, DynamoDB

---

## Repository Structure

```
├── template.yaml           # CloudFormation template creating all AWS resources
├── deploy-ecr.sh           # Script: build & push Docker image to ECR
├── deploy-lambda.sh        # Script: deploy CF stack & update Lambda code
├── lambda/                 # Directory with Lambda source code
│   ├── generate/           # GenerateUploadUrl lambda
│   │   └── index.js
│   └── process/            # ProcessImage lambda
│       └── index.js
└── README.md               # Installation & usage instructions
```

---

## Installation

Replace `<ENV>` with your chosen environment prefix (e.g., `dev`, `test`, `prod`).

### 1. Bootstrap AWS CLI & ECR

Ensure you have logged in:

```bash
aws sts get-caller-identity
aws ecr get-login-password --region $(aws configure get region) \
  | docker login --username AWS --password-stdin $(aws sts get-caller-identity --query Account --output text).dkr.ecr.$(aws configure get region).amazonaws.com
```

This logs Docker into your ECR registry.

### 2. Deploy CloudFormation Stack

Run the CloudFormation deployment to create all networking and compute resources:

```bash
aws cloudformation deploy \
  --template-file template.yaml \
  --stack-name ${ENV}-chain-stack \
  --parameter-overrides EnvPrefix=${ENV} \
  --capabilities CAPABILITY_NAMED_IAM
```

*On success, you will see an output `ApiUrl`—the base URL for the upload endpoint.*

### 3. Build & Push Processor Docker Image

Build the Docker image for your ECS Fargate service and push to ECR:

```bash
chmod +x deploy-ecr.sh
./deploy-ecr.sh ${ENV}
```

This script will:

* Build `Dockerfile` in the root (or specify path)
* Create ECR repository `${ENV}-processor-repo` if missing
* Tag & push the `latest` image

### 4. Package & Deploy Lambda Functions

1. **Zip** each Lambda folder:

   ```bash
   cd lambda/generate
   zip ../../generate_upload_url.zip index.js
   cd ../process
   zip ../../process_image.zip index.js
   cd ../../
   ```
2. Make deployment script executable and run:

   ```bash
   chmod +x deploy-lambda.sh
   ./deploy-lambda.sh ${ENV}
   ```

This updates the two Lambda functions with your latest code.

---

## Usage

1. **Authenticate** via Cognito (AWS SDK or Hosted UI) to obtain an `ID_TOKEN`.
2. **Get Upload URL**:

   ```bash
   curl -H "Authorization: Bearer $ID_TOKEN" \
     $(aws cloudformation describe-stacks \
        --stack-name ${ENV}-chain-stack \
        --query "Stacks[0].Outputs[?OutputKey=='ApiUrl'].OutputValue" \
        --output text)
   ```
3. **Upload** an image to the returned URL:

   ```bash
   curl -X PUT --upload-file myphoto.jpg "<uploadUrl>"
   ```
4. **Process** runs automatically through the chain.
5. **Fetch Results**: Implement a GET Lambda endpoint (similar to upload-url) that queries the DynamoDB table by image key.

---

## Cleanup

Remove everything by deleting the CloudFormation stack:

```bash
aws cloudformation delete-stack --stack-name ${ENV}-chain-stack
```

All associated resources will be cleaned up automatically.

---

## Troubleshooting

* **Circular dependency error**: Ensure `template.yaml` uses block scalars for `Description` and separate `Lambda::Permission` for S3 triggers.
* **Permission denied** on S3 notifications: verify `ProcessImagePermission` exists and references correct ARNs.
* **Docker push failures**: check ECR login and repository name match `${ENV}-processor-repo`.

For additional debugging, examine the CloudFormation Events in the AWS Console.

---

## License

This sample code is licensed under the MIT License. Feel free to adapt and extend!
