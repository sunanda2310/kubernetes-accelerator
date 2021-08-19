# Creating an EKS Cluster
The following is the current structure of the cluster folder
  * **build**: This contains the required CodeBuild buildspec.yml and related create-cluster.sh file
  * **calico**: To provide kuberntes network policy based isolation across namespaces, Calico is being used as the CNI pluggin.
  * **cloudwatch-insights**: CloudWatch Logs Insights enables to interactively search and analyze your log EKS data in Amazon CloudWatch Logs. The required script is found here. Note that the file(s) found here are applied via the create-cluster.sh file.
  * **external-dns**: ExternalDNS makes Kubernetes resources discoverable via public DNS servers. It retrieves a list of resources (Services, Ingresses, etc.) from the Kubernetes API to determine a desired list of DNS records. It also manages the required Route53 Hosted Zone entries.
  * **ingress**: The files required to set up AWS ALB Ingress controller are found here. This feature is not installed by the create-cluster.sh and has been deprecated.
  * **nlb-ingress**: This is the official kubeaccelerator ingress controller. It uses NGINX and AWS NLB to provide ingress functionality. It gets applied via the create-cluster.sh script.  

# GitHub Integration Must Be Set Manually in AWS CodeBuild
Before creating the CodeBuild job or anything that integrates with github, you must manually go to CodeBuild and authenticate to github (aka creating an 'Open ID Connect' aka OIDC) by creating a new CodeBuild, selecting github as source and authenticating to github. You can **delete** the CodeBuild job you created manually. AWS will remember your OATH token for future interactions with GITHUB.

## EKSCTL tips and tricks
* To prevent storing cluster credentials locally, run:  
`eksctl create cluster --name=cluster-3 --nodes=4 --write-kubeconfig=false`

* To let eksctl manage cluster credentials under ~/.kube/eksctl/clusters directory, run:  
`eksctl create cluster --name=cluster-3 --nodes=4 --auto-kubeconfig`

* To obtain cluster credentials at any point in time, run:  
`eksctl utils write-kubeconfig --cluster=ed-k8s-v4 --set-kubeconfig-context=true  [--kubeconfig=<path>][--set-kubeconfig-context=<bool>]`

* You can also create a cluster passing all configuration information in a file using --config-file:  
`eksctl create cluster --config-file=cluster/cluster.yml`

## Assuming role:
```
echo "Assuming role and getting the session"
aws sts assume-role --role-arn arn:aws:iam::005331601127:role/your-cluster-name-k8s-accelerator-team --role-session-name "k8s-admins" > assume-role-output.json
export AWS_ACCESS_KEY_ID=$(jq -r '.Credentials.AccessKeyId' assume-role-output.json)
export AWS_SECRET_ACCESS_KEY=$(jq -r '.Credentials.SecretAccessKey' assume-role-output.json)
export AWS_SESSION_TOKEN=$(jq -r '.Credentials.SessionToken' assume-role-output.json)
rm assume-role-output.json
aws sts get-caller-identity
```

## Adding more IAM role access to EKS
* Once you create create your cluster, you must add permissions to other roles to acccess the EKS cluster. You can do this via eksctl

```
eksctl create iamidentitymapping --cluster ed-k8s \
--arn arn:aws:iam::005331601127:role/service-role/codebuild-your-project-slippy-app-service-role \
--group system:masters --username codebuild-job
```

* You can run the following to create a kubeconfig with a particular role:  
`aws eks update-kubeconfig --name ed-k8s-v4 --kubeconfig=/root/.kube/config --role-arn=arn:aws:iam::005331601127:role/service-role/codebuild-your-project-slippy-app-service-role`

## Utility & Troubleshooting Cheat Sheet

### EKS Cluster Access

If you run `helm list` or kubectl commands and receive:
  * `Access denied` or 
  * `No resources found` or 
  * `You need to login to the server`

These mean you do not have access to the EKS Cluster and you must assume an AWS Role to talk to the cluster. The role will be given to you by the person that created the EKS cluster.

### Download your EKS config
This step assumes you have been given acces to a EKS:* role and that you actually have access to EKS.  
By default, terraform creates a {cluster-name}-{aws-region}-cluster-root-masters role.  You should have acces to assume this role.

Your cluster creator admin will provide you this role arn.

Run
`aws sts assume-role --role-arn arn:aws:iam::005331601127:role/my-k8s-accelerator-team --role-session-name=my-session`
`aws eks update-kubeconfig --name $CLUSTER_NAME --role-arn arn:aws:iam::005331601127:role/my-k8s-accelerator-team --role-session-name=my-session`

### Get all namespaces
`kubectl get ns`

### DELETE ALL resources in a namespace
`kubectl -n slippy-charted delete deploy,ing,pod,svc --all`

### Access Denied when running kubectl or related CLI against EKS Cluster
This happens **because** only the person that created the EKS cluster has access to it.  
In this case, you must set a trust relationship and role policy.
```
An error occurred (AccessDenied) when calling the AssumeRole operation: 
User: arn:aws:sts::ACCOUNT_ID:assumed-role/codebuild-slippy-app-service-role/AWSCodeBuild-0a6acc04-0b5d-44a5-9882-ae31c7595408 is not authorized to perform: 
sts:AssumeRole on resource: 
arn:aws:iam::ACCOUNT_ID:role/service-role/codebuild-slippy-app-service-role
```

### GET and SEE all EKS Cluster access roles to see who's got access to EKS cluster
The following does a listing of the aws_auth configmap that EKS uses to grant access to the cluster. By default, only the person or role that created the cluster has access to it.

`eksctl get iamidentitymapping --cluster $EKS_CLUSTER_NAME`

### create a Trust relationship
```
{
  "Version": "2012-10-17",
  "Statement": [
    {
      "Effect": "Allow",
      "Principal": {
        "AWS": [
          "arn:aws:iam::005331601127:root"   -- THIS Makes it so that others (people or processes) can assume the erole
        ],
        "Service": [
          "eks.amazonaws.com",
          "ec2.amazonaws.com",
          "codebuild.amazonaws.com"
        ]
      },
      "Action": "sts:AssumeRole"
    }
  ]
}
```

### CODEBUILD job needs this policy

your-project-allow-codebuild-to-assume-eks-admin-role

```
{
    "Version": "2012-10-17",
    "Statement": {
        "Action": [
            "sts:AssumeRole"
        ],
        "Resource": [
            "arn:aws:iam::005331601127:role/your-cluster-name-k8s-accelerator-team"
        ],
        "Effect": "Allow"
    }
}
```

### Create a resource policy to attach to a role as a inline policy
```
{
    "Version": "2012-10-17",
    "Statement": [
        {
            "Action": [
                "sts:AssumeRole"
            ],
            "Resource": [
                "arn:aws:sts::005331601127:assumed-role/codebuild-your-project-slippy-app-service-role/*"
            ],
            "Effect": "Allow"
        }
    ]
}
```
