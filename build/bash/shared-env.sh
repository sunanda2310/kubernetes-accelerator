#!/bin/bash

# -e     When this option is on, if a simple command fails for any of the reasons listed in Consequences of
#        Shell  Errors or returns an exit status value >0, and is not part of the compound list following a
#        while, until, or if keyword, and is not a part of an AND  or  OR  list,  and  is  not  a  pipeline
#        preceded by the ! reserved word, then the shell shall immediately exit.
set -e

# -u     The shell shall write a message to standard error when it tries to expand a variable that  is  not
#        set and immediately exit. An interactive shell shall not exit.
set -u

get_last_feature_image_tag() {
  echo $(aws ecr list-images --repository-name $ECR_REPOSITORY_NAME \
    | jq -r --arg NAMESPACE "$1" '[.imageIds[] | select(.imageTag != null) | .imageTag | select(startswith($NAMESPACE))] | max_by(. | split("-")[-1] | tonumber)')
}

BPWD=$(pwd)

readonly PROJECT_NAME=$(echo $CODEBUILD_BUILD_ID | sed 's/:/ /g' | awk '{print $1'})
readonly BUILD_ID=$(echo $CODEBUILD_BUILD_ID | sed 's/:/ /g' | awk '{print $2'})

echo "Project Name: $PROJECT_NAME"
echo "CodeBuild ID: $BUILD_ID"
echo "Source commit ID: $CODEBUILD_SOURCE_VERSION"
git name-rev $CODEBUILD_SOURCE_VERSION 
export BRANCH_NAME=$(git name-rev $CODEBUILD_SOURCE_VERSION | awk '{print $2; exit}') 
echo "Branch Name: $BRANCH_NAME"
export BRANCH_TYPE=$(echo $BRANCH_NAME | cut -d '/' -f1)
echo "Branch Type: $BRANCH_TYPE"
export APP_CHANGED="$(git whatchanged -n 1 | { grep -c 'app/' || true; })"
export APP_NAME=$(cat app.yml | yq -r '.application.name' | awk '{print tolower($0)}')

echo "Application Name: $APP_NAME"
echo "Application Changes?: $APP_CHANGED"

IMAGE_TAG=""
if [[ "$BRANCH_NAME" == *"master"* ]] || [[ "$BRANCH_NAME" == *"main"* ]]; then
  export APP_NAMESPACE=$APP_NAME
  export IMAGE_TAG="latest"
  export SHOULD_BUILD_IMAGE=$(test $APP_CHANGED -eq 1 && echo "true" || echo "false")
elif [[ "$BRANCH_NAME" == *"feature"* ]]; then
  export APP_NAMESPACE=$(echo $BRANCH_NAME | cut -d '/' -f2 | cut -c1-15 | awk '{print tolower($0)}')-$APP_NAME
  readonly IMAGE_TAG_COUNT=$(aws ecr list-images --repository-name $ECR_REPOSITORY_NAME \
      | jq --arg NAMESPACE "${APP_NAMESPACE}" '[.imageIds[] | select(.imageTag != null) | .imageTag | select(startswith($NAMESPACE))] | length + 1')
  if [ $APP_CHANGED -eq 1 ]; then
    export IMAGE_TAG=$APP_NAMESPACE-$IMAGE_TAG_COUNT
    export SHOULD_BUILD_IMAGE="true"
  elif [ $IMAGE_TAG_COUNT -eq 1 ]; then
    # if this is going to be the first application image build regardless
    export IMAGE_TAG=$APP_NAMESPACE-$IMAGE_TAG_COUNT
    export SHOULD_BUILD_IMAGE="true"
  else
    export IMAGE_TAG=$(get_last_feature_image_tag $APP_NAMESPACE)
    export SHOULD_BUILD_IMAGE="false"
  fi
else
  echo "\n>>>>>>>>>> UNSUPPORTED BRANCH TYPE: '${BRANCH_TYPE}' <<<<<<<<<<\n"
  exit 1
fi

if [ -n "${IMAGE_TAG}" ]; then
  echo "APPLICATION NAMESPACE: $APP_NAMESPACE"
  echo "IMAGE TAG: $IMAGE_TAG"
  echo "BUILD IMAGE?: $SHOULD_BUILD_IMAGE"
else
  echo "\n******* The container image tag was not set. Aborting build. *******\n"
  exit 1
fi
