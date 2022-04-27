terraform {
  required_providers {
    azurerm = {
      source  = "hashicorp/azurerm"
      version = "~> 3.0.2"
    }
    kubernetes = {
      source  = "hashicorp/kubernetes"
      version = "~> 2.9.0"
    }
    helm = {
      source  = "hashicorp/helm"
      version = "~> 2.5.1"
    }
  }
  required_version = ">= 1.1.0"
}

provider "azurerm" {
  features {
    resource_group {
      prevent_deletion_if_contains_resources = false
    }
  }
}

provider "kubernetes" {
  host                   = azurerm_kubernetes_cluster.cluster1.kube_config.0.host
  client_key             = base64decode(azurerm_kubernetes_cluster.cluster1.kube_config.0.client_key)
  client_certificate     = base64decode(azurerm_kubernetes_cluster.cluster1.kube_config.0.client_certificate)
  cluster_ca_certificate = base64decode(azurerm_kubernetes_cluster.cluster1.kube_config.0.cluster_ca_certificate)
}

provider "helm" {
  kubernetes {
    host                   = azurerm_kubernetes_cluster.cluster1.kube_config.0.host
    client_key             = base64decode(azurerm_kubernetes_cluster.cluster1.kube_config.0.client_key)
    client_certificate     = base64decode(azurerm_kubernetes_cluster.cluster1.kube_config.0.client_certificate)
    cluster_ca_certificate = base64decode(azurerm_kubernetes_cluster.cluster1.kube_config.0.cluster_ca_certificate)
  }
}

resource "azurerm_resource_group" "rg" {
  name     = "tstahl-k8s-resources"
  location = "eastus"

  tags = {
    Environment = "Tim Stahl - K8s Testing"
    Team        = "Sales"
  }
}

# Service Principal for the K8s cluster.
resource "azurerm_user_assigned_identity" "aksmi" {
  resource_group_name = azurerm_resource_group.rg.name
  location            = azurerm_resource_group.rg.location
  name                = "tstahlaksmi"
  depends_on          = [azurerm_resource_group.rg]
}

resource "azurerm_virtual_network" "k8s-vnet" {
  name                = "tstahl-network"
  location            = azurerm_resource_group.rg.location
  resource_group_name = azurerm_resource_group.rg.name
  address_space       = ["10.1.0.0/16"]

  tags = {
    Environment = "Tim Stahl - K8s Testing"
    Team        = "Sales"
  }
}

resource "azurerm_subnet" "internal" {
  name                 = "internal"
  virtual_network_name = azurerm_virtual_network.k8s-vnet.name
  resource_group_name  = azurerm_resource_group.rg.name
  address_prefixes     = ["10.1.0.0/24"]

}

resource "azurerm_container_registry" "acr" {
  name                = "tstahlacr1"
  resource_group_name = azurerm_resource_group.rg.name
  location            = azurerm_resource_group.rg.location
  sku                 = "Basic"
}

resource "azurerm_kubernetes_cluster" "cluster1" {
  name                = "tstahl-k8s-cluster1"
  location            = azurerm_resource_group.rg.location
  resource_group_name = azurerm_resource_group.rg.name
  dns_prefix          = "tstahl-k8s-cluster1"

  default_node_pool {
    name           = "tstahlnode"
    node_count     = 3
    vm_size        = "Standard_B2s"
    vnet_subnet_id = azurerm_subnet.internal.id
  }

  identity {
    type         = "UserAssigned"
    identity_ids = [azurerm_user_assigned_identity.aksmi.id]
  }
}

# Give the Service Principal access to the ACR.
resource "azurerm_role_assignment" "ra" {
  principal_id                     = azurerm_kubernetes_cluster.cluster1.kubelet_identity[0].object_id
  role_definition_name             = "AcrPull"
  scope                            = azurerm_container_registry.acr.id
  skip_service_principal_aad_check = true

  depends_on = [azurerm_kubernetes_cluster.cluster1]
}

# Give the Service Principal Network Contributor access to the resource group -- for dynamic setting of IP on nginx-ingress-controller.
resource "azurerm_role_assignment" "ranet" {
  principal_id                     = azurerm_user_assigned_identity.aksmi.principal_id
  role_definition_name             = "Network Contributor"
  scope                            = azurerm_resource_group.rg.id
  skip_service_principal_aad_check = true

  depends_on = [azurerm_kubernetes_cluster.cluster1]
}

resource "kubernetes_namespace" "labelns" {
  metadata {
    annotations = {
      name = "ingress-basic"
    }
    labels = {
      "certmanager.io/disable-validation" = "true"
    }
    name = "ingress-basic"
  }
  depends_on = [azurerm_kubernetes_cluster.cluster1]
}

# Setup the Static IP for the ingress.
resource "azurerm_public_ip" "externalip" {
  name                = "nginxIngressExternalIP1"
  location            = azurerm_resource_group.rg.location
  resource_group_name = azurerm_resource_group.rg.name
  allocation_method   = "Static"
  domain_name_label   = "tstahltest"
  sku                 = "Standard"
  tags = {
    createdfor = "tstahl test env"
  }
}

# Deploy the nginx Ingress Helm Chart
resource "helm_release" "nginx_ingress" {
  name       = "nginx-ingress-controller"
  repository = "https://kubernetes.github.io/ingress-nginx"
  chart      = "ingress-nginx"
  namespace  = "ingress-basic"

  set {
    name  = "controller.replicaCount"
    value = "2"
  }

  set {
    name  = "controller.service.loadBalancerIP"
    value = azurerm_public_ip.externalip.ip_address
  }

  set {
    name  = "controller.service.annotations.service\\.beta\\.kubernetes\\.io/azure-load-balancer-resource-group"
    value = azurerm_resource_group.rg.name
  }

  set {
    name  = "controller.admissionWebhooks.patch.image.image"
    value = "ingress-nginx/kube-webhook-certgen"
  }

  depends_on = [kubernetes_namespace.labelns, azurerm_public_ip.externalip, azurerm_role_assignment.ranet]
}

# Deploy the Cert Manager
resource "helm_release" "cert_manager" {
  name       = "cert-manager"
  repository = "https://charts.jetstack.io"
  chart      = "cert-manager"

  set {
    name  = "installCRDs"
    value = "true"
  }

  depends_on = [helm_release.nginx_ingress]
}

data "kubernetes_service" "ingress-controller" {
  metadata {
    name      = "nginx-ingress-controller-ingress-nginx-controller"
    namespace = "ingress-basic"
  }
  depends_on = [helm_release.nginx_ingress]
}

resource "kubernetes_deployment" "deployment" {
  metadata {
    name = "hello-k8s"
    labels = {
      app = "helloworld"
    }
  }

  spec {
    replicas = 3
    selector {
      match_labels = {
        app = "helloworld"
      }
    }
    template {
      metadata {
        labels = {
          app = "helloworld"
        }
      }
      spec {
        container {
          image = "paulbouwer/hello-kubernetes:1.5"
          name  = "example"
          port {
            container_port = 8080
          }
        }
      }
    }
  }
}

resource "kubernetes_service" "helloworldsvc" {
  metadata {
    name = "helloworldsvc"
  }
  spec {
    selector = {
      app = "helloworld"
    }
    port {
      port        = 80
      target_port = 8080
    }
    type = "ClusterIP"
  }
}

resource "helm_release" "cert_issuer" {
  name       = "letsencrypt"
  repository = "./modules/cert-issuer"
  chart      = "cert-issuer"
  namespace  = "default"

  set {
    name  = "fullnameOverride"
    value = "Tim Stahl"
  }
  set {
    name  = "ingressClass"
    value = "nginx"
  }
  set {
    name  = "acmeEmail"
    value = "tim.stahl@appvia.io"
  }
  set {
    name  = "acmeServer"
    value = "https://acme-v02.api.letsencrypt.org/directory"
  }
  depends_on = [helm_release.cert_manager]
}

resource "kubernetes_ingress_v1" "hellowing" {
  metadata {
    name = "hellowing"
    annotations = {
      "nginx.ingress.kubernetes.io/rewrite-target" = "/$1"
      "cert-manager.io/cluster-issuer"             = "letsencrypt"
    }
  }
  spec {
    ingress_class_name = "nginx"
    tls {
      hosts       = ["tstahltest.eastus.cloudapp.azure.com"]
      secret_name = "tls-secret"
    }
    rule {
      host = "tstahltest.eastus.cloudapp.azure.com"
      http {
        path {
          path = "/*"
          backend {
            service {
              name = "helloworldsvc"
              port {
                number = 80
              }
            }
          }
        }
      }
    }
  }
  depends_on = [helm_release.cert_issuer]
}