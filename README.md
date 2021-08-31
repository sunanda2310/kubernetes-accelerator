# aws kubernetes accelerator
**PUT YOUR LAPTOP PASSWORD HERE**
Project is structured as follows:
:/
```shell
├── app          # Place your application source code here (e.g. microservice, etc)
├── app-settings # Helm chart definition, templates and values
├── app.yml      # Application configuration and Helm values.yaml overrides
├── build        # CI/CD pipeline scripts
├── cfn          # CloudFormation templates used to create CodeBuild jobs. You must update params.
├── cluster      # EKS cluster creation Cloudformation, scripts and k8s configurations
└── container    # Dockerfile definitions
```

## Setting up your workstation

The following is the tooling required to get a local work station to run and debug the various components of this k8s accelerator.

Because one can be running Windows or Mac, the instructions will be left at a general level.

* Download and Install
  * [Python 3.latest](https://www.python.org/downloads/)
  * [Helm](https://docs.brew.sh/Installation)
  * [Docker Desktop](https://www.docker.com/products/docker-desktop)
  * [kubectl](https://kubernetes.io/docs/tasks/tools/install-kubectl/)
  * [eksctl](https://eksctl.io/introduction/installation/)
  * [aws cli](https://docs.aws.amazon.com/cli/latest/userguide/install-cliv2.html)
  * [aws-iam-authenticator](https://docs.aws.amazon.com/eks/latest/userguide/install-aws-iam-authenticator.html)
  * [cfn-lint](https://github.com/aws-cloudformation/cfn-lint) (`pip install cfn-lint`)

## Setting up the Infrastructure (CI/CD CodeBuild Jobs)

NOTE: This assumes you have a clean AWS account where none of the included cfn templates have been run.

### Route 53 
The accelerator leverages a Route53 Domain. This must be setup and working (e.g. hosted zones and domain name servers must be set up and configured). This is a manual step and a pre-requisite.

### SSL Certificates
A wildcard certificate should be configured and available in AWS Certificate Manager. This is a manual step and a pre-requisite.

### ECR Repository
A valid ECR repository must be created in the same region as the EKS cluster.

Private repo. Repo must allow service principal to obtain image, create a permission statement. Otherwise kubelet will be unable to retrieve the image.

### GitHub Integration Must Be Set Manually in AWS CodeBuild
Before creating the CodeBuild jobs below, you must manually go to CodeBuild and authenticate to github (aka creating an 'Open ID Connect' aka OIDC).  

1. Create a new CodeBuild, 
2. Selecting github as source and 
3. Authenticate to github. 
4. You can **delete** the CodeBuild job after you authenticate. Don't have anything. 

This is a manual step and a pre-requisite.

This ends the one-time infrastructure configuration.
# --------------------------------------------------

### Creating the EKS Cluster

1. Run `/build/bash/deploy-create-cluster-codebuild.sh` to apply this template `cfn/create-cluster-codebuild.yml` or by importing into the AWS Cloudformation Console  

Push commit to github, trigger pipeline.

**NOTE:** Code must be pushed to main/master for the first time, in order to trigger the EKS creation

**NOTE:** It will take about 20 minutes to create the EKS. 

### Creating the sample application installation and configuration

2. Run `/build/bash/deploy-create-app-install-and-configure-codebuild.sh` to apply this template `cfn/create-app-install-and-configure-codebuild.yml` or by importing into the AWS Cloudformation Console  

### ECR Image Clean up Job
3. Run `/build/bash/deploy-install-feature-reaper.sh` to apply this template  `cfn/install-feature-reaper.yml` or by importing into the AWS Cloudformation Console
## Connecting to EKS Cluster 

This part is not needed as we made a script to this working "account-init.sh"

/* In order to use helm to manage charts or to interact with the EKS cluster to manage k8s workloads or troubleshoot, you'll need the following:

1. A working local AWS profile
   * This is done by running `aws configure` and setting up your AWS Secret and Access Keys
   * Once you configure your AWS profile, type `aws s3 ls` to see if you have acccess to aws.

2. To talk to the EKS Cluster, you need to assume the AWS EKS Cluster role.
    * The AWS EKS Cluster admin role will be given to you by the EKS Cluster administrator.
    * To assume the given EKS Cluster admin role, type:
   `aws sts assume-role --role-arn AWS_EKS_ROLE --role-session-name "EKS-role-for-me"`
    * You will see your Access and Secret keys on your terminal
    * export your keys as follows:

      MAC/LINUX:

      ```shell
      export AWS_ACCESS_KEY_ID="{enter your value here}"
      export AWS_SECRET_ACCESS_KEY="{enter your value here}"
      export AWS_DEFAULT_REGION="{your region}"
      ```

      WINDOWS:

      ```powershell
      setx AWS_ACCESS_KEY_ID {enter your value here}
      setx AWS_SECRET_ACCESS_KEY {enter your value here}
      setx AWS_DEFAULT_REGION {your region}
      ```
*/

Just run the account-init.sh script (" source .build/bash/account-init.sh " )      

3. Now that your AWS Session has been configured, you need to connect and download the EKS cluster configuration. Run:
    * `aws eks update-kubeconfig --name CLUSTER-NAME --role-arn arn:aws:iam::AWS_ACCOUNT:role/CLUSTER_AWS_IAM_ROLE --role-session-name=EKS-role-for-me`

4. Now that your local kubeconfig has been set up, check your connectivity
    * `kubectl get nodes`
        * this should return a list of nodes
    * `helm list`
        * this should return a list of helm charts (or an empty list if none have been published)

## `app.yml`: Configuring your application

Your accelerated application's configuration is defined in `app.yml`. The details of that file will be covered here.

The bare minimum configuration supported (required values):

```yaml
application:
  name: my
  domain: speedy.app
  image:
    name: 005331601127.dkr.ecr.us-west-2.amazonaws.com/apps/my
  tags:
    Name: Joe Developer
```

* `name` is often used as a default value for other values.
* `domain` a wildcard certificate should be created. The example above would have a certificate of `*.speedy.app`. The `master` deployment of this application will be accessible at `my.speedy.app`. If the accelerator is configured to use domain based routing feature branches will be accessible at `[BRANCH_NAME].speedy.app`.
  * `BRANCH_NAME` if greater than 15 characters is truncated to 15 characters.
* `image.name` is the image name of the application without the image tag. The image tag will be calculated. Currently `master` builds are tagged `latest`. Feature branch builds follow the format `[BRANCH_NAME]-[application.name]-[IMAGE_COUNT]`.
  * `BRANCH_NAME` if greater than 15 characters is truncated to 15 characters.
  * `IMAGE_COUNT` is 1 based and auto incremented.
* `tags` are _optional_ key/value pairs. These tags are currently not being leveraged at the resource level.

### Calculated values

#### `BRANCH_NAME`

The branch name is pulled from `git` directly. Supported branch names are `master` and other legal branch names that are prepended with `feature/`. Any other branch name scheme will result in a failed build.

#### `BRANCH_TYPE`

Assuming the supported branch name scheme is being followed the `master` branch has a type of `master` and `feature/*` branches will have a type of `feature`.

#### `APP_NAMESPACE`

For a `master` build the namespace is set to `application.name` (APP_NAME) from `app.yml`. For `feature` builds the namespace is formatted `[BRANCH_NAME]-[APP_NAME]`. If `BRANCH_NAME` is longer than 15 characters it's truncated. The value is normalized to lowercase.

#### `IMAGE_TAG`

For a `master` build the image tag is always `latest`. For `feature` builds the image tag is formatted `[APP_NAMESPACE]-[IMAGE_COUNT]`, where `IMAGE_COUNT` ia an autoincremented integer. The `IMAGE_TAG` depends on CodeBuild to guarantee jobs are executed sequentially in `git commit` order.

The bare minimum configuration will deploy your application but without more it won't be very useful.

### Deployment

```yaml
deployment:
  container:
    name: something-other-than-application-name
    replicaCount: 2
  ports:
    - port: 3000
      name: slippy-http
```

* `container.name` is _optional_ and defaults to `application.name`
* `container.replicaCount` is _optional_ and defaults to 1
* `ports` is an array of port numbers and port names. The port name is _optional_. The default is to deploy with no ports.

If your application needs additional containers deployed to support the application those can are to be defined in `supportContainers`. Each container defined in `supportContainers` must be a valid [Kubernetes Container definition](https://kubernetes.io/docs/reference/generated/kubernetes-api/v1.18/#container-v1-core). Each `supportContainers` entry is expanded directly without modification into the deployment.

### Ingress

```yaml
  ingress:
    routing: path
```

* `routing` is _optional_ and defaults to `path`. Refer to [Routing options](#routing-options) for more information.

### Service

```yaml
service:
  type: ClusterIP
  ports:
    - port: 80
      targetPort: 3000
      protocol: TCP
```

* `type` is _optional_ and defaults to `ClusterIP`. Valid values are defined by the [Kubernetes ServiceSpec type attribute](https://kubernetes.io/docs/reference/generated/kubernetes-api/v1.18/#servicespec-v1-core)
* `ports` are required and must contain `port` and `targetPort`. Optionally the port `protocol` can be specified. The default `protocol` is `TCP`.

## Routing options

There are two supported ways to provide access to `feature` builds. The routing option is configured by setting the optional `ingress.routing` property in app.yml to `path` or `domain`. The default routing method is `path`.

### Path-based

The benefit of path-based routing is the lack of DNS update which makes the feature build accessible, on average, substantially quicker.

Feature builds are accessible by navigating to `https://APP_NAME.APP_DOMAIN/BRANCH_NAME`.

* `APP_NAME` is equal to lowercased `application.name`
* `APP_DOMAIN` is equal to `application.domain`
* `BRANCH_NAME` is the lowercase normalized first 15 characters of the feature branch name

### Domain-based

If `ingress.routing` is set to `domain` a subdomain is created for each feature branch following the structure: `BRANCH_NAME`.`APP_DOMAIN`.

* `BRANCH_NAME` is the lowercase normalized first 15 characters of the feature branch name
* `APP_DOMAIN` is equal to `application.domain`

Once the subdomain is created and DNS is updated (which can take several minutes) the feature builds are accessible by navigating to `https://BRANCH_NAME.APP_DOMAIN`.

The accelerator is self-cleaning. Once a feature branch is deleted the subdomain, among other things, are removed.

### Tool configuration

#### `helmVersion`

```yaml
helmVersion: v3.1.2
```

The default [version of helm](https://github.com/helm/helm/releases) installed for use by the accelerator is `v3.1.2` but can be changed by providing `helmVersion`.
# kubernetes-accelerator
