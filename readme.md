# Kubernetes Project
This project was developed to learn k8s in Azure using Terraform/Helm and end up with a fully working k8s application using TLS behind an nginx-ingress service.

## Installation

Setup your Azure environment in your shell:
```zsh
export ARM_CLIENT_ID="xxxx"
export ARM_CLIENT_SECRET="xxxx"
export ARM_SUBSCRIPTION_ID="xxxx"
export ARM_TENANT_ID="xxxx"

az login
```

## Usage

Run install.sh

When complete, an application will be available at tstahltest.eastus.cloudapp.azure.com