### Setting up ExternalDNS for Services

ExternalDNS synchronizes exposed Kubernetes Services and Ingresses with DNS providers like AWS Route53.

### Pre-Requisites
- Cluster is set up with OIDC ID provider in AWS and is equiped to useIAM Roles for Service Accounts (IRSA). Example: If using eksctl for provisioning cluster, we can setup the OIDC ID provider by:

  eksctl utils associate-iam-oidc-provider --name **cluster-name** --approve


- Public Hosted Zone is setup in Route 53. Make a note of the Hosted Zone Id - Example: Z37IPDMLONOWWC


### Steps
- Create an IAM policy to allow ExternalDNS to update Route53 resource recordsets in the hosted zone. Update the Hosted Zone Id in the policy and save it as policy.json.

````json
{
    "Version": "2012-10-17",
    "Statement": [
        {
            "Effect": "Allow",
            "Action": [
                "route53:ChangeResourceRecordSets"
            ],
            "Resource": [
                "arn:aws:route53:::hostedzone/Z37IPDMLONOWWC"
            ]
        },
        {
            "Effect": "Allow",
            "Action": [
                "route53:ListHostedZones",
                "route53:ListResourceRecordSets"
            ],
            "Resource": [
                "*"
            ]
        }
    ]
}
````


We can use the aws cli to create the policy as below:

aws iam create-policy --policy-name my-policy --policy-document file://policy.json

Note the Policy ARN

- Create an IAM Role that can be assumed by ExternalDNS pods, Attach the Role to the above IAM Policy and create a Kubernetes Service Account with the role annotation. We can use the eksctl utility to do all 3 as part of 1 step. Update the below command with the IAM Policy ARN from above and other cluster specific details.

  eksctl create iamserviceaccount \
    --region **region** \
    --name external-dns \
    --namespace kube-system \
    --cluster **cluster-name** \
    --attach-policy-arn **iam-policy-arn** \
    --override-existing-serviceaccounts \
    --approve
 
- Save the below external dns installation manifest file as external-dns.yaml. Update the domain name as necessary


```yaml
apiVersion: rbac.authorization.k8s.io/v1beta1
kind: ClusterRole
metadata:
  name: external-dns
rules:
- apiGroups: [""]
  resources: ["services","endpoints","pods"]
  verbs: ["get","watch","list"]
- apiGroups: ["extensions"]
  resources: ["ingresses"]
  verbs: ["get","watch","list"]
- apiGroups: [""]
  resources: ["nodes"]
  verbs: ["list","watch"]
---
apiVersion: rbac.authorization.k8s.io/v1beta1
kind: ClusterRoleBinding
metadata:
  name: external-dns-viewer
roleRef:
  apiGroup: rbac.authorization.k8s.io
  kind: ClusterRole
  name: external-dns
subjects:
- kind: ServiceAccount
  name: external-dns
  namespace: kube-system
---
apiVersion: apps/v1
kind: Deployment
metadata:
  name: external-dns
  namespace: kube-system
spec:
  strategy:
    type: Recreate
  selector:
    matchLabels:
      app: external-dns
  template:
    metadata:
      labels:
        app: external-dns
    spec:
      serviceAccountName: external-dns
      containers:
      - name: external-dns
        image: registry.opensource.zalan.do/teapot/external-dns:latest
        args:
        - --source=service
        - --source=ingress
        - --domain-filter=sunandak8labtest.com # will make ExternalDNS see only the hosted zones matching provided domain, omit to process all available hosted zones
        - --provider=aws
        - --aws-zone-type=public # only look at public hosted zones (valid values are public, private or no value for both)
        - --registry=txt
        - --txt-owner-id=my-identifier
      securityContext:
        fsGroup: 65534 # For ExternalDNS to be able to read Kubernetes and AWS token files
```

- Apply the manifest to the cluster to deploy external dns

 kubectl apply -f external-dns.yaml

- Verify it deployed successfully

 kubectl logs -f $(kubectl get po | egrep -o 'external-dns[A-Za-z0-9-]+')

### Usage
- To create a record set in the Hosted zone, from an ingress object add an annotation and apply the manifest (this is assuming the ingress controller is already deployed). Example:


```yaml
annotations:
  kubernetes.io/ingress.class: alb
  alb.ingress.kubernetes.io/scheme: internet-facing

  # for creating record-set
  external-dns.alpha.kubernetes.io/hostname: nginx.sunandak8labtest.com # set domain name here
```

- Any LoadBalancer type Service with the same annotation will also yield the same results.

```yaml
apiVersion: v1
kind: Service
metadata:
  name: nginx
  annotations:
    external-dns.alpha.kubernetes.io/hostname: nginx.sunandak8labtest.com # set domain name here
```
