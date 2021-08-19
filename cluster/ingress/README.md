# Setting up the AWS ALB Ingress Controller

1. Run `kubectl apply -f rbac-role.yaml`
2. aws iam create-policy \
    --policy-name ALBIngressControllerIAMPolicy \
    --policy-document https://raw.githubusercontent.com/kubernetes-sigs/aws-alb-ingress-controller/v1.1.4/docs/examples/iam-policy.json

    The policy document is also found in this directory `ALBIngressControllerIAMPolicy.json`
3. You now need to create a k8s service account to proxy the permissions between EKS and AWS IAM.  
   Run the following:

```
eksctl create iamserviceaccount \
       --cluster=$EKS_CLUSTERNAME \
       --namespace=kube-system \
       --name=alb-ingress-controller \
       --attach-policy-arn=$ALBIngressControllerIAMPolicyArn \
       --override-existing-serviceaccounts \
       --approve
```
*Example*
```
eksctl create iamserviceaccount \
       --cluster=ed-k8s \
       --namespace=kube-system \
       --name=alb-ingress-controller \
       --attach-policy-arn=arn:aws:iam::005331601127:policy/ALBIngressControllerIAMPolicy \
       --override-existing-serviceaccounts \
       --approve \
       --region=ca-central-1
```

4. You now need to run the `alb-ingress-controller.yaml` which creates the kubernetes controller that will proxy the credentials.  
   * *REMEMBER*: to update your cluster name.

   * `kubectl apply -f alb-ingress-controller.yaml`

   * You can check if the controller pod got created by running: `kubectl get po -n kube-system` and check the alb-ingress-controller pod exists and is running.

5. At this point, you should be able to deploy your application specific ingress and code. See echo-sample-app.

6. arn:aws:iam::005331601127:role/eksctl-ed-k8s-nodegroup-ng-1-NodeInstanceRole-1937MUXSV84NH 
youyr EKS worker group role has to have R53 permissions
This role  AmazonRoute53AutoNamingFullAccess didn't have enough permissions as it was missing `route53:ListHostedZone` so went with full access managed policy `AmazonRoute53FullAccess`

## Troubleshooting
* Run the following to get the status of the external DNS configuration
`kubectl logs -f $(kubectl get po | egrep -o 'external-dns[A-Za-z0-9-]+'`