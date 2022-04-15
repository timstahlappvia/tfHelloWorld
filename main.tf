terraform {
  required_providers {
    azurerm = {
      source  = "hashicorp/azurerm"
      version = "~> 3.0.2"
    }
  }
  required_version = ">= 1.1.0"
}

provider "azurerm" {
  features {}
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
  name                = "tstahlACR1"
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

data "azurerm_subscription" "sub" {

}

# Give the Service Principal access to the ACR.
resource "azurerm_role_assignment" "ra" {
  principal_id                     = azurerm_user_assigned_identity.aksmi.principal_id
  role_definition_name             = "AcrPull"
  scope                            = data.azurerm_subscription.sub.id
  skip_service_principal_aad_check = true

  depends_on = [azurerm_kubernetes_cluster.cluster1]
}