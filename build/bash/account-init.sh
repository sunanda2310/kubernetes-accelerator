#!/bin/sh
# This script inits the shell for kubectl

# bash ./build/bash/account-init.sh

# export these vars to set your script
export EKS_AWS_ADMIN_ROLE="test"
export EKS_ADMIN_PROFILE=""
export EKS_CLUSTER_NAME="ed-k8s"
export EKS_REGION="us-east-1"

echo "get the role arn for $EKS_AWS_ADMIN_ROLE"
EKS_AWS_ADMIN_ROLE_ARN=$(aws iam get-role --role-name $EKS_AWS_ADMIN_ROLE --profile $EKS_ADMIN_PROFILE --output text --query 'Role.Arn')
echo
echo "Create assume role credentials file using: $EKS_AWS_ADMIN_ROLE arn"
 aws sts assume-role --role-arn $EKS_AWS_ADMIN_ROLE_ARN \
  --role-session-name "EKS-role-for-me" --profile $EKS_ADMIN_PROFILE > assume-role-output.json 
echo
echo "assign session credentials from file" 
export AWS_ACCESS_KEY_ID=$(jq -r '.Credentials.AccessKeyId' assume-role-output.json)
export AWS_SECRET_ACCESS_KEY=$(jq -r '.Credentials.SecretAccessKey' assume-role-output.json)
export AWS_SESSION_TOKEN=$(jq -r '.Credentials.SessionToken' assume-role-output.json)
rm assume-role-output.json
echo
echo "aws caller identity"
aws sts get-caller-identity

echo "eksctl write kubeconfig"
eksctl utils write-kubeconfig --cluster=$EKS_CLUSTER_NAME --set-kubeconfig-context=true --region $EKS_REGION

echo "kubectl get nodes"
kubectl get nodes

echo "helm list"
helm list

''' more general helpers

  kubectl get svc -n ingress-nginx
  kubectl describe service -n ingress-nginx ingress-nginx
  kubectl get namespaces
  kubectl get svc --all-namespaces
  kubectl describe nodes
  kubectl get pod -A -o wide

'''

''' tear down and recreate ingress controller

      ##delete the ingress service for a namespace
      kubectl delete svc ingress-nginx -n ingress-nginx
      ##create the nlb ingress service
      kubectl apply -f cluster/nlb-ingress/nlb-service.yml
'''

''' drain and delete nodegroup

      kubectl get nodes 
      kubectl cordon [nodegroup]
      kubectl drain [nodegroup] --ignore-daemonsets
      kubectl drain [nodegroup] --ignore-daemonsets
      kubectl delete --all pods --namespace=[namespace]

'''


echo "check subnets for our vpc"
aws ec2 describe-subnets --profile cd-dev \
--filters "Name=vpc-id,Values=vpc-[vpc id]" | grep 'MapPublicIpOnLaunch\|SubnetId\|VpcId\|State'

echo "bash into a container namespace"
kubectl exec -it --namespace=[namespace] [pod] -- /bin/bash