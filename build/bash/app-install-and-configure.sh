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
#             status, or to zero if all commands of the pipeline exit successfully.
set -o pipefail

# grab current working directory
BPWD=$(pwd)

readonly HELM_VERSION=$(cat app.yml | yq -r '.helmVersion | if . == null or . == "" then "v3.1.2" else . end')
# install helm
curl -fsSL -o get_helm.sh https://raw.githubusercontent.com/helm/helm/master/scripts/get-helm-3
chmod 700 get_helm.sh
./get_helm.sh --version $HELM_VERSION --no-sudo
which helm
helm version

# install & configure kubectl
curl -o kubectl https://amazon-eks.s3-us-west-2.amazonaws.com/1.14.6/2019-08-22/bin/linux/amd64/kubectl
chmod +x ./kubectl
mv ./kubectl /usr/local/bin/kubectl
kubectl version --short --client

# install eksctl
curl --silent --location "https://github.com/weaveworks/eksctl/releases/download/latest_release/eksctl_$(uname -s)_amd64.tar.gz" | tar xz -C /tmp
mv /tmp/eksctl /usr/local/bin
eksctl version

readonly APP_DOMAIN=$(cat app.yml | yq -r '.application.domain')
readonly APP_IMAGE_NAME=$(cat app.yml | yq -r '.application.image.name')
readonly APP_TAGS="$(cat app.yml | yq -r '.application.tags | to_entries | map(.key + "=" + .value) | join("\\,")')"

if [ "$BRANCH_NAME"=="master" ] || [ "$BRANCH_NAME"=="main" ]; then
  APP_ROUTING="domain"
  FEATURE_DOMAIN=${APP_NAME}.${APP_DOMAIN}
  INGRESS_PATH="/"
elif expr "$BRANCH_TYPE" : "feature" > /dev/null; then
  APP_ROUTING=$(cat app.yml | yq -r '.ingress.routing | if . == "path" or . == "domain" then . else "path" end')

  readonly HELM_BRANCH_NAME=${APP_NAMESPACE%-${APP_NAME}}
  if [[ "$APP_ROUTING" == "domain" ]]; then
    FEATURE_DOMAIN=$HELM_BRANCH_NAME.$APP_DOMAIN
    INGRESS_PATH="/"
  else
    FEATURE_DOMAIN=${APP_NAME}.${APP_DOMAIN}
    INGRESS_PATH="/${HELM_BRANCH_NAME}"
  fi
fi

# Set container name to use
readonly IMAGE_NAME=${APP_IMAGE_NAME}:${IMAGE_TAG}

# Assume EKS ROLE
aws sts assume-role --role-arn $EKS_ADMIN_ROLE --role-session-name "EKS-CodeBuild-admin-session" > assume-role-output.json
export AWS_ACCESS_KEY_ID=$(jq -r '.Credentials.AccessKeyId' assume-role-output.json)
export AWS_SECRET_ACCESS_KEY=$(jq -r '.Credentials.SecretAccessKey' assume-role-output.json)
export AWS_SESSION_TOKEN=$(jq -r '.Credentials.SessionToken' assume-role-output.json)
rm assume-role-output.json
# END Assume EKS ROLE

eksctl utils write-kubeconfig --cluster=$EKS_CLUSTER_NAME --set-kubeconfig-context=true
kubectl get nodes

# install & configure app helm chart
echo "HELM_RELEASE_NAME: $APP_NAMESPACE"
echo "FEATURE_DOMAIN: $FEATURE_DOMAIN"
echo "IMAGE_NAME: $IMAGE_NAME"

# dry-run to validate the upgrade
helm upgrade $APP_NAMESPACE ./app-settings --values app.yml --install --dry-run \
  --set application.domain=$FEATURE_DOMAIN \
  --set deployment.namespace=$APP_NAMESPACE \
  --set image.name=$IMAGE_NAME \
  --set ingress.routing=$APP_ROUTING \
  --set ingress.path=$INGRESS_PATH

# dry-run was successful perform upgrade/install
helm upgrade $APP_NAMESPACE ./app-settings --values app.yml --install \
  --set application.domain=$FEATURE_DOMAIN \
  --set deployment.namespace=$APP_NAMESPACE \
  --set image.name=$IMAGE_NAME \
  --set ingress.routing=$APP_ROUTING \
  --set ingress.path=$INGRESS_PATH

echo "Completed pushing helm chart successfully to $APP_NAMESPACE namespace."
echo -e "\n####################################################################\n"
echo "Access at: https://$FEATURE_DOMAIN$INGRESS_PATH"
echo -e "\n####################################################################"