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

# Assume EKS ROLE
aws sts assume-role --role-arn $EKS_ADMIN_ROLE --role-session-name "EKS-CodeBuild-admin-session" > assume-role-output.json
export AWS_ACCESS_KEY_ID=$(jq -r '.Credentials.AccessKeyId' assume-role-output.json)
export AWS_SECRET_ACCESS_KEY=$(jq -r '.Credentials.SecretAccessKey' assume-role-output.json)
export AWS_SESSION_TOKEN=$(jq -r '.Credentials.SessionToken' assume-role-output.json)
rm assume-role-output.json
# END Assume EKS ROLE

eksctl utils write-kubeconfig --cluster=$EKS_CLUSTER_NAME --set-kubeconfig-context=true
kubectl get nodes

readonly appName=$(cat app.yml | yq -r '.application.name' | awk '{print tolower($0)}')
readonly helmReleases=$(helm list -o json | jq -r '[.[] | .name] | join(" ")')
readonly gitBranchList=$(git branch -r)

# Loop through the open git branches and
# grab the names of the feature branches
# format to follow helm chart release naming
# COUPLED: Formatting is performed in shared-env.sh.
formattedGitBranches=""
while read -r line ; do
    branch=$(echo "$line" \
        | sed -e 's#origin/feature/##g' -e 't' -e 'd' \
        | cut -c1-15 \
        | tr '[:upper:]' '[:lower:]')
    formattedGitBranches+=" ${branch}"
done <<< "$gitBranchList"

echo "HELM FEATURE BRANCH NAMES: ${formattedGitBranches}"
echo "HELM RELEASE NAMES: ${helmReleases}"

for release in $helmReleases; do
  # COUPLED: Formatting is performed in shared-env.sh.
  formattedReleaseName=${release%-${appName}}

  # Ignore the master branch application release
  if [ "${formattedReleaseName}" == "${appName}" ]; then
    continue
  fi

  # Test whether the helm release still has a feature branch associated with it
  if [[ "$formattedGitBranches" = *"${formattedReleaseName}"* ]]; then
    echo -e "\n-----Release ${release} still has a feature branch association. The release will NOT be uninstalled."
  else
    echo -e "\n-----Release ${release} no longer has a feature branch association. Uninstalling release."
    helm uninstall $release

    # Optionally delete container images for the feature branch
    if [[ "$REAP_FEATURE_IMAGES" == "true" ]]; then
      echo -e "\n***** Release ${release} images will be deleted *****"

      # Login to ECR
      $(aws ecr get-login --region $AWS_DEFAULT_REGION --no-include-email)

      # List of images to delete in the format: imageTag=[TAG_NAME] (space delimited)
      readonly imageDeleteList=$(aws ecr list-images --repository-name $ECR_REPOSITORY_NAME \
        | jq -r --arg NAMESPACE "${release}" '[.imageIds[] | select(.imageTag != null) | .imageTag  | select(startswith($NAMESPACE))] | map("imageTag=" + .) | join(" ")')

      aws ecr batch-delete-image \
        --repository-name $ECR_REPOSITORY_NAME \
        --image-ids $imageDeleteList
    fi
  fi
done
