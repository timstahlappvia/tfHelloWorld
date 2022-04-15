#!/bin/zsh
# Script written to set up the entire k8s project.
terraform apply
echo Setting up Azure Container Registry ...
source ./helm/setupACR.sh
echo Setting up nginx-ingress
source ./helm/setupIngress.sh
export EXTERNAL_IP=$(kubectl --namespace ingress-basic get services nginx-ingress-ingress-nginx-controller -o jsonpath='{.status.loadBalancer.ingress[0].ip}')
echo nginx-Ingress Public IP is : $EXTERNAL_IP
source ./helm/setupDNS.sh
echo Setting up Certificate Manager ...
source ./helm/setupCertManager.sh
echo Deploy the Kubernetes application, cluster issuer, and ingress ...
kubectl apply -f ./k8s/deployment.yaml
kubectl apply -f ./k8s/cluster-issuer.yaml
kubectl apply -f ./k8s/ingress.yaml
echo Complete!