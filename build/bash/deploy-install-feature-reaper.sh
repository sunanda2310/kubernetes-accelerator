#!/bin/sh
# This script deploys a CloudFormation stack.

# Ensures script execution halts on first error
set -exo pipefail

stackName="install-feature-reaper-eks"

# Deploy the stack
aws cloudformation deploy \
  --template-file ./cfn/install-feature-reaper.yml \
  --stack-name "${stackName}" \
  --no-fail-on-empty-changeset \
  --capabilities CAPABILITY_NAMED_IAM \
  --profile #[eks admin profile]
 
# ensure that termination protection enabled
# aws cloudformation update-termination-protection \
#   --enable-termination-protection \
#   --stack-name "$stackName" \
#   --profile #[eks admin profile]

# bash ./build/bash/deploy-install-feature-reaper.sh