# CloudFormation (cfn): Configuring the Templates

There are three `cfn template` files. Each `cfn template` creates a CodeBuild job. Each CodeBuild is configured with a GitHub webhook that triggers the CodeBuild (except for the feature-reaper one).

```shell
├─ create-app-install-and-configure-codebuild.yml # Builds your app's docker container and EKS resources
├─ create-cluster-codebuild.yml                   # Creates an EKS cluster with ELB/NGINX and CloudWatch Insights.
└─ install-feature-reaper.yml                     # Creates a CloudWatch event that triggers a CodeBuild job.
```

## You MUST update your PARAMETER default values

Each `cfn template` has a set of parameters whose values must be provided either **at run time** or by **setting default values**. The default values have `test-values` and you must update them for your use.

The parameters have **descriptions** that tell you what you need to provide.

## You MUST update your TAG values

When you run a `cfn template`, it will tag the AWS resources it creates. The tag `values` must be updated to match your company's standards.  

If you remove or rename a `tag name`, you **MUST** update all the places in the `cfn template` file where the tag was used.  

## Installing (e.g. applying) the templates

You can use the AWS Console to import and apply your `cfn template` or use the AWS CLI, etc. to apply the template for you. If you use a `cli`, know that you will need to provide the parameter values overwrites via the command line (e.g. `--parameter-overrides <value> [<value>...]]`)