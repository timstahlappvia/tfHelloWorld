export ACR_URL=tstahlacr1.azurecr.io
export SOURCE_REGISTRY=k8s.gcr.io
export CONTROLLER_IMAGE=ingress-nginx/controller
export CONTROLLER_TAG=v1.0.4
export PATCH_IMAGE=ingress-nginx/kube-webhook-certgen
export PATCH_TAG=v1.1.1
export DEFAULTBACKEND_IMAGE=defaultbackend-amd64
export DEFAULTBACKEND_TAG=1.5
export CERT_MANAGER_REGISTRY=quay.io
export CERT_MANAGER_TAG=v1.5.4
export CERT_MANAGER_IMAGE_CONTROLLER=jetstack/cert-manager-controller
export CERT_MANAGER_IMAGE_WEBHOOK=jetstack/cert-manager-webhook
export CERT_MANAGER_IMAGE_CAINJECTOR=jetstack/cert-manager-cainjector

# Label the ingress-basic namespace to disable resource validation
kubectl label namespace ingress-basic cert-manager.io/disable-validation=true

# Add the Jetstack Helm repository
helm repo add jetstack https://charts.jetstack.io

# Update your local Helm chart repository cache
helm repo update

# Install the cert-manager Helm chart
helm install cert-manager jetstack/cert-manager \
  --namespace ingress-basic \
  --version $CERT_MANAGER_TAG \
  --set installCRDs=true \
  --set nodeSelector."kubernetes\.io/os"=linux \
  --set image.repository=$ACR_URL/$CERT_MANAGER_IMAGE_CONTROLLER \
  --set image.tag=$CERT_MANAGER_TAG \
  --set webhook.image.repository=$ACR_URL/$CERT_MANAGER_IMAGE_WEBHOOK \
  --set webhook.image.tag=$CERT_MANAGER_TAG \
  --set cainjector.image.repository=$ACR_URL/$CERT_MANAGER_IMAGE_CAINJECTOR \
  --set cainjector.image.tag=$CERT_MANAGER_TAG