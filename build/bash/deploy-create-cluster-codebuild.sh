#!/bin/sh
# This script deploys a CloudFormation stack.

# Ensures script execution halts on first error
set -exo pipefail

stackName="create-cluster-codebuild-eks"

# Deploy the stack
aws cloudformation deploy \
  --template-file ./cfn/create-cluster-codebuild.yml \
  --stack-name "${stackName}" \
  --no-fail-on-empty-changeset \
  --capabilities CAPABILITY_NAMED_IAM \
  #--profile #[eks admin profile]
 
# ensure that termination protection enabled
# aws cloudformation update-termination-protection \
#   --enable-termination-protection \
#   --stack-name "$stackName" \
#   --profile #[eks admin profile]

# bash ./build/bash/deploy-create-cluster-codebuild.sh
