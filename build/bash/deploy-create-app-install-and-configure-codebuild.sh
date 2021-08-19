#!/bin/sh
# This script deploys a CloudFormation stack.

# Ensures script execution halts on first error
set -exo pipefail

stackName="create-app-install-and-configure-codebuild-eks"

# Deploy the stack
aws cloudformation deploy \
  --template-file ./cfn/create-app-install-and-configure-codebuild.yml \
  --stack-name "${stackName}" \
  --no-fail-on-empty-changeset \
  --capabilities CAPABILITY_NAMED_IAM \
  --profile #[eks admin profile]
 
# ensure that termination protection enabled
# aws cloudformation update-termination-protection \
#   --enable-termination-protection \
#   --stack-name "$stackName" \
#   --profile #[eks admin profile]

# bash ./build/bash/deploy-create-app-install-and-configure-codebuild.sh