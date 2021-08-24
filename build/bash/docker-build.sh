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

# Successfully exit if the application image doesn't need to be created
if [[ "$SHOULD_BUILD_IMAGE" == "false" ]]; then
  exit 0;
fi

BPWD=$(pwd)

$(aws ecr get-login --region $AWS_DEFAULT_REGION --no-include-email)

# Running docker lint
#docker run --rm -i hadolint/hadolint < container/Dockerfile

# build phase
cd app
docker build -t $ECR_REPOSITORY_URI:$IMAGE_TAG -f ../container/Dockerfile .
cd $BPWD

# post_build phase
docker push $ECR_REPOSITORY_URI:$IMAGE_TAG
echo "Pushed $ECR_REPOSITORY_URI:$IMAGE_TAG"
docker images
echo "Completed docker build and push"
