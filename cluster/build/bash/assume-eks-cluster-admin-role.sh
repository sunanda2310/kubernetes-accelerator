#!/bin/bash
echo "Assuming role and getting the session"

aws sts assume-role --role-arn arn:aws:iam::005331601127:role/ed-k8s-v7-ca-central-1-Administrators \
--role-session-name "eks-your-cluster-super-admin" > assume-role-output.json 

export AWS_ACCESS_KEY_ID=$(jq -r '.Credentials.AccessKeyId' assume-role-output.json)
export AWS_SECRET_ACCESS_KEY=$(jq -r '.Credentials.SecretAccessKey' assume-role-output.json)
export AWS_SESSION_TOKEN=$(jq -r '.Credentials.SessionToken' assume-role-output.json)
rm assume-role-output.json
aws sts get-caller-identity

eksctl utils write-kubeconfig --cluster=ed-k8s-v7 --set-kubeconfig-context=true --region ca-central-1
