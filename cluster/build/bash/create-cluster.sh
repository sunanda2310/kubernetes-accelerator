#!/bin/bash

# -e     When this option is on, if a simple command fails for any of the reasons listed in Consequences of
#        Shell  Errors or returns an exit status value >0, and is not part of the compound list following a
#        while, until, or if keyword, and is not a part of an AND  or  OR  list,  and  is  not  a  pipeline
#        preceded by the ! reserved word, then the shell shall immediately exit.
set -e

# -u     The shell shall write a message to standard error when it tries to expand a variable that  is  not
#        set and immediately exit. An interactive shell shall not exit.
set -u

# -o pipefail Sets the exit code of a pipeline to that of the rightmost command to exit with a non-zero
#   status, or to zero if all commands of the pipeline exit successfully.
set -o pipefail

# set current working directory
BPWD=$(pwd)

# This scripts expects the CLUSTER_NAME variable which must be set in the CodeBuild environment properties

# Install Phase
echo "Install Phase"
uname -s
apt-get update

# install & configure kubectl
#Deprecated Version: curl -o kubectl https://amazon-eks.s3.us-west-2.amazonaws.com/1.15.10/2020-02-22/bin/linux/amd64/kubectl
curl -o kubectl https://amazon-eks.s3.us-west-2.amazonaws.com/1.16.15/2020-11-02/bin/linux/amd64/kubectl
chmod +x ./kubectl
mv ./kubectl /usr/local/bin/kubectl
kubectl version --short --client

# install eksctl
curl --silent --location "https://github.com/weaveworks/eksctl/releases/download/latest_release/eksctl_$(uname -s)_amd64.tar.gz" | tar xz -C /tmp
mv /tmp/eksctl /usr/local/bin
eksctl version

# install cloud-formation linting tool
pip3 install cfn-lint --quiet

# Check cluster template lint

cfn-lint --template cfn/*.yml --region $AWS_DEFAULT_REGION --ignore-checks W

# Determine branch name and type
BRANCH_NAME=$(git branch --contains $CODEBUILD_SOURCE_VERSION --sort=-committerdate | awk '{print $1; exit}')
BRANCH_TYPE=$(echo $BRANCH_NAME | cut -d '/' -f1) # Only needed if checking that the branch is a feature, PR, etc.
PROJECT_NAME=$(echo $CODEBUILD_BUILD_ID | sed 's/:/ /g' | awk '{print $1'})
BUILD_ID=$(echo $CODEBUILD_BUILD_ID | sed 's/:/ /g' | awk '{print $2'})
AWS_ACCOUNT_ID=$(aws sts get-caller-identity | jq .Account --raw-output)

echo "Branch Name: $BRANCH_NAME"
echo "Branch Type: $BRANCH_TYPE"
echo "Projecte Name: $PROJECT_NAME"
echo "CodeBuild ID $BUILD_ID"

# Current path of working directory
echo $BPWD
# Commenting out the SSH KEY as this might not be required
#   echo $EKS_NODE_SSH_KEY_LOCATION
#   SSH_KEY=$(aws ssm get-parameter --name "$EKS_NODE_SSH_KEY_LOCATION" --with-decryption --output text --query Parameter.Value)
#   echo $SSH_KEY > ~/.ssh/eks_worker_nodes_pub.pem
#    ls -la ~/.ssh

cd $BPWD
ls -la

# Update cluster name from Environment Variable EKS_CLUSTER_NAME and Region to target files 
echo "Updating customer's cluster name to $EKS_CLUSTER_NAME"
sed -i "s/CUSTOMER_DESIRED_CLUSTER_NAME/${EKS_CLUSTER_NAME}/g" cluster/cluster.yml
sed -i "s/CUSTOMER_CURRENT_JOB_AWS_REGION/${AWS_DEFAULT_REGION}/g" cluster/cluster.yml
sed -i "s/CUSTOMER_DESIRED_COMPUTE_INSTANCE_TYPE/${EKS_COMPUTE_INSTANCE_TYPE}/g" cluster/cluster.yml
sed -i "s/CUSTOMER_DESIRED_NODEGROUP_CAPACITY/${EKS_NODE_GROUP_CAPACITY}/g" cluster/cluster.yml
sed -i "s/CUSTOMER_DESIRED_CLUSTER_NAME/${EKS_CLUSTER_NAME}/g" cluster/ingress/alb-ingress-controller.yaml
# End update to cluster name, instance type and worker node capacity
echo "starting post cluster name"

if expr "$BRANCH_NAME" : "master" > /dev/null; then
    eksctl create cluster --config-file=cluster/cluster.yml;
    echo "entered if loop"
    # Install Calico Network Policy Engine
    kubectl apply -f $BPWD/cluster/calico/calico-v1.5.yml
    echo "finished calico"
    # Create IAM policy for external DNS
    kubectl apply -f cluster/external-dns/external-dns.yml

    POLICY_ARN=$(aws iam create-policy --policy-name $EKS_CLUSTER_NAME-$AWS_DEFAULT_REGION-external-dns --policy-document file://cluster/external-dns/policy.json --output text --query Policy.Arn)
    
    eksctl create iamserviceaccount \
    --region $AWS_DEFAULT_REGION \
    --name external-dns \
    --namespace kube-system \
    --cluster $EKS_CLUSTER_NAME \
    --attach-policy-arn $POLICY_ARN \
    --override-existing-serviceaccounts \
    --approve
    # End Create IAM policy for external DNS
    echo "Created IAM policy for external DNS"

    # Create IAM ROLE that EKS admin team can use
    echo "Creating EKS IAM role for admin team"
    TRUST="{ \"Version\": \"2012-10-17\", \"Statement\": [ { \"Effect\": \"Allow\", \"Principal\": { \"AWS\": \"arn:aws:iam::${AWS_ACCOUNT_ID}:root\" }, \"Action\": \"sts:AssumeRole\" } ] }"
    echo '{ "Version": "2012-10-17", "Statement": [ { "Effect": "Allow", "Action": "eks:*", "Resource": "*" } ] }' > /tmp/iam-role-policy
    
    EKS_AWS_ADMIN_ROLE=$(aws iam create-role --role-name $EKS_CLUSTER_NAME-$AWS_DEFAULT_REGION-Administrators --assume-role-policy-document "$TRUST" --output text --query 'Role.Arn')
    EKS_AWS_ADMIN_ROLE_NAME=$(echo $EKS_AWS_ADMIN_ROLE | cut -d'/' -f2)
    aws iam put-role-policy --role-name $EKS_AWS_ADMIN_ROLE_NAME --policy-name $EKS_CLUSTER_NAME-$AWS_DEFAULT_REGION-admin-policy --policy-document file:///tmp/iam-role-policy

    eksctl create iamidentitymapping --cluster $EKS_CLUSTER_NAME  --arn $EKS_AWS_ADMIN_ROLE --group system:masters --username $EKS_CLUSTER_NAME-admin-team
    # uncomment for debug and see aws-auth config map
    # eksctl get iamidentitymapping --cluster $EKS_CLUSTER_NAME --arn $EKS_AWS_ADMIN_ROLE
    # End IAM ROLE for EKS admin team

    # Configure NGINX NLB Ingress
    echo "Creating NGINX NLB Ingress configuration"
    kubectl apply -f $BPWD/cluster/nlb-ingress/nlb-ingress-controller.yml
    kubectl apply -f $BPWD/cluster/nlb-ingress/nlb-service.yml
    echo "Created NGINX NLB Ingress configuration successfully"
    # End Configure NGINX ALB Ingress

    # Configure CloudWatch Container Insights
    cat cluster/cloudwatch-insights/cwagent-fluentd-quickstart.yaml \
    | sed "s/{{cluster_name}}/${EKS_CLUSTER_NAME}/;s/{{region_name}}/${AWS_DEFAULT_REGION}/" \
    | kubectl apply -f - 
    echo "Configured CloudWatch Container Insights successfully."
    # End Configure CloudWatch Container Insights

    # Configure Cluster Autoscaler
    cat cluster/cluster-autoscaler/cluster-autoscaler-autodiscover.yaml \
    | sed "s/{{cluster_name}}/${EKS_CLUSTER_NAME}/" \
    | kubectl apply -f - 
    echo "Configured Cluster Autoscaler successfully."
    # End Configure Cluster Autoscaler

    # Configure the metrics server for Horizontal Pod Autoscaler
    kubectl apply -f https://github.com/kubernetes-sigs/metrics-server/releases/download/v0.3.6/components.yaml
    echo "Configured metrics server for HPA successfully."
    # End Configure metrics server for Horizontal Pod Autoscaler

    echo "EKS_AWS_ADMIN_ROLE: $EKS_AWS_ADMIN_ROLE"

elif expr "$BRANCH_TYPE" : "feature" > /dev/null; then
    # TAG for non-prod docker image tagging
    echo "No EKS Cluster Action was taken because this was run against a FEATURE branch"
fi
echo "Created $EKS_CLUSTER_NAME"
echo "create-cluster bash script completed."