### Deny all traffic from other namespaces

We can configure a NetworkPolicy to deny all the traffic from other namespaces while allowing all the traffic coming from the same namespace the pods get deployed to.

### Use Cases

We do not want deployments in another namespace to accidentally send traffic to other services or databases in the current namespace.
We host different versions of the applications in separate Kubernetes namespaces and we would like to block traffic coming from outside a namespace.
### Steps

- Install the Calico Network Policy engine on the Amazon EKS cluster

 kubectl apply -f https://raw.githubusercontent.com/aws/amazon-vpc-cni-k8s/release-1.5/config/v1.5/calico.yaml


- Save the following manifest to deny-other-ns.yaml. Update the namespace name in the manifest. You can also apply it part of your deployment package using Helm charts (recommended)
```yaml
kind: NetworkPolicy
apiVersion: networking.k8s.io/v1
metadata:
  namespace: <current-namespace-name>
  name: deny-other-ns
spec:
  podSelector:
    matchLabels:
  ingress:
  - from:
    - podSelector: {}
```

- Apply the manifest to the cluster

 kubectl apply -f deny-other-ns.yaml