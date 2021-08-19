# This script has been deprecated.
# You can resurrect it as needeed and might need to update the path to files based on
# what location the script is running from. 

# Configure AWS ALB Ingress
echo "Creating AWS ALB Ingress configuration"
kubectl apply -f $BPWD/cluster/ingress/rbac-role.yaml
INGRESS_POLICY_ARN=$(aws iam create-policy \
--policy-name $EKS_CLUSTER_NAME-$AWS_DEFAULT_REGION-ALBIngressControllerIAMPolicy \
--policy-document file://$BPWD/cluster/ingress/ALBIngressControllerIAMPolicy.json --output text --query Policy.Arn)

eksctl create iamserviceaccount \
--cluster=$EKS_CLUSTER_NAME \
--namespace=kube-system \
--name=alb-ingress-controller \
--attach-policy-arn=$INGRESS_POLICY_ARN \
--override-existing-serviceaccounts \
--approve

kubectl apply -f $BPWD/cluster/ingress/alb-ingress-controller.yaml
# End Configure AWS ALB Ingress