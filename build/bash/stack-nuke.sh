#!/bin/bash

export AWS_PAGER=""
unset AWS_ACCESS_KEY_ID AWS_SECRET_ACCESS_KEY AWS_SESSION_TOKEN

cloud-nuke aws --exclude-resource-type iam --region us-east-1

aws cloudformation delete-stack --stack-name create-cluster-codebuild-eks
aws cloudformation delete-stack --stack-name create-app-install-and-configure-codebuild-eks
aws cloudformation delete-stack --stack-name eksctl-ed-k8s-addon-iamserviceaccount-default-aws-admin
aws cloudformation delete-stack --stack-name eks-cluster-job
aws cloudformation delete-stack --stack-name eksctl-ed-k8s-cluster
eksctl delete cluster --region=us-east-1 --name=ed-k8s

POLICY_ARN=$(aws iam list-policies | jq -rc ".Policies[] | select( .PolicyName == \"ed-k8s-us-east-1-external-dns\") | .Arn")
aws iam delete-policy --policy-arn "$POLICY_ARN"
POLICY_ARN=$(aws iam list-policies | jq -rc ".Policies[] | select( .PolicyName == \"ed-k8s-us-east-1-admin-policy\") | .Arn")
aws iam delete-policy --policy-arn "$POLICY_ARN"

aws iam delete-role-policy #... figure this out next time
aws iam delete-role --role-name ed-k8s-us-east-1-Administrators
