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
    name                    = "internal"
    virtual_network_name    = azurerm_virtual_network.k8s-vnet.name
    resource_group_name     = azurerm_resource_group.rg.name
    address_prefix          = ["10.1.0.0/24"]

    tags = {
        Environment = "Tim Stahl - K8s Testing"
        Team        = "Sales"
  }
}

resource "azure_kubernetes_cluster" "cluster1" {
    name                    = "tstahl-k8s-cluster1"
    location                = azurerm_resource_group.rg.location
    resource_group_name     = azurerm_resource_group.rg.name
    dns_prefix              = "tstahl-k8s-cluster1"

    tags = {
        Environment = "Tim Stahl - K8s Testing"
        Team        = "Sales"
  }
}