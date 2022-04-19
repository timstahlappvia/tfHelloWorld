#!/bin/zsh
# Script written to set up the entire k8s project.

# Apply the main infrastructure in Azure.
terraform apply -auto-approve

# Give Azure time to finalize all resource generation -- then push images to ACR.
sleep 30
echo Setting up Azure Container Registry ...
./helm/setupACR.sh

# Setup the Ingress Controller
sleep 15
echo Setting up nginx-ingress
source ./helm/setupIngress.sh

# Setup the DNS A Zone
sleep 60
export EXTERNAL_IP=$(kubectl --namespace ingress-basic get services nginx-ingress-ingress-nginx-controller -o jsonpath='{.status.loadBalancer.ingress[0].ip}')
echo nginx-Ingress Public IP is : $EXTERNAL_IP
sleep 5
source ./helm/setupDNS.sh

read -s -k "?DNS Complete -- Press any key to continue."
# Setup the Cert Manager
sleep 10
echo Setting up Certificate Manager ...
source ./helm/setupCertManager.sh

# Deploy the k8s env, cluster cert issuer, and ingress.
sleep 60
echo Deploy the Kubernetes application, cluster issuer, and ingress ...
kubectl apply -f ./k8s/cluster-issuer.yaml
kubectl apply -f ./k8s/deployment.yaml
kubectl apply -f ./k8s/ingress.yaml
echo Complete!