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
  name = "nginxIngressExternalIP1"
  location            = azurerm_resource_group.rg.location
  resource_group_name = azurerm_resource_group.rg.name
  allocation_method = "Static"
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
    name = "controller.service.externalIPs"
    value = "{${azurerm_public_ip.externalip.ip_address}}"
  }
  
  set {
    name  = "controller.admissionWebhooks.patch.image.image"
    value = "ingress-nginx/kube-webhook-certgen"
  }

  depends_on = [kubernetes_namespace.labelns, azurerm_public_ip.externalip]
}

# Deploy the Cert Manager
resource "helm_release" "cert_manager" {
  name       = "cert-manager"
  repository = "https://charts.jetstack.io"
  chart      = "cert-manager"
  namespace  = "ingress-basic"

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
      app = "HelloWorld"
    }
  }

  spec {
    replicas = 3
    selector {
      match_labels = {
        app = "HelloWorld"
      }
    }
    template {
      metadata {
        labels = {
          app = "HelloWorld"
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
