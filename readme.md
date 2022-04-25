# Kubernetes Project
This project was developed to learn k8s in Azure using Terraform/Helm and end up with a fully working k8s application using TLS behind an nginx-ingress service.

## Installation

Terraform init / terraform apply the main.tf file.
kubectl apply -f ./k8s/cluster-issuer.yaml to create the issuer.
Had to make that part separate due to constraints with the kubernetes_manifest resource in Terraform. The cluster must be created before planning can commence due to the requirement of TF to use the API.

## Usage

When complete, an application will be available at https://tstahltest.eastus.cloudapp.azure.com