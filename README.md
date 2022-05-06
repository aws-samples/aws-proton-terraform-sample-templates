## AWS Proton Sample Terraform Templates

This repository is a curated list of sample templates to use within AWS Proton that are authored for integration with [Terraform](https://www.terraform.io/).

To use this repository, browse to the folder that corresponds to the template that you want to use. You will find there all the information you need to create environment and service templates and to deploy the corresponding environments and services. You will also find a link to a repository with basic code that runs on each one of them, in case you want to fork it to use it as the basis for your deployment.

### Registering Templates Using Template Sync
All of the Templates in this directory are set up to work with [AWS Proton Template Sync](https://docs.aws.amazon.com/proton/latest/adminguide/create-template-sync.html). This repository is also a Github Template Repository. So you can click "Use this template" on the home page of this repo and that will create an identical repo in your account, which you can then use with template sync.

### Running Terraform Using AWS Proton Self-managed Provisioning
If you need an example of how to run your Terraform code, head on over to [this repo](https://github.com/aws-samples/aws-proton-terraform-github-actions-sample) where we offer an example of running Terraform using GitHub Actions.

### Local Development

For local development, the `<template>/dev-resources/` directory contains variable definitions/values which are normally generated
by Proton at provision time:

- `proton.variables.tf`: variable type definitions
- `proton.auto.tfvars.json`: variable value assignments (contains provisioning inputs, environment outputs etc)

To test a template locally, you can create symbolic links to these files in the infrastructure directory. E.g.:

```
cd <template>/vx/<infrastructure>/
ln -s ../../dev-resources/proton.variables.tf dev.proton.auto.tfvars.json
ln -s ../../dev-resources/proton.auto.tfvars.json dev.proton.auto.tfvars.json
terraform init
terraform plan
```

Note that you will need to populate `proton.auto.tfvars.json` with the required values according to the template. For
environments, this will typically be the `environment.name` and `environment.inputs` fields, for example.

## Security

See [CONTRIBUTING](CONTRIBUTING.md#security-issue-notifications) for more information.

## License

This library is licensed under the MIT-0 License. See the LICENSE file.

