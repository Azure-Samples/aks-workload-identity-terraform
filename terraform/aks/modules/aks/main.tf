terraform {
  required_providers {
    azurecaf = {
      source  = "aztfmod/azurecaf"
      version = "1.2.16"
    }
  }
}

resource "azurecaf_name" "aks_cluster" {
  name          = var.application_name
  resource_type = "azurerm_kubernetes_cluster"
  suffixes      = [var.environment]
}

resource "azurerm_kubernetes_cluster" "aks" {
  name                = azurecaf_name.aks_cluster.result
  resource_group_name = var.resource_group
  location            = var.location
  dns_prefix          = var.dns_prefix

  default_node_pool {
    name       = "defaultpool"
    node_count = 2
    vm_size    = "Standard_B2s"
  }

  local_account_disabled = true
  oidc_issuer_enabled = true
  workload_identity_enabled = true

  identity {
    type = "SystemAssigned"
  }

  
  azure_active_directory_role_based_access_control {
    managed = true
    admin_group_object_ids = [
      var.aks_rbac_admin_group_object_id,
    ]
    azure_rbac_enabled = false
  }  
}

# grant permission to aks to pull images from acr
resource "azurerm_role_assignment" "acrpull_role" {
  scope                = var.acr_id
  role_definition_name = "AcrPull"
  principal_id         = azurerm_kubernetes_cluster.aks.kubelet_identity.0.object_id  
}

# grant permission to admin group to manage aks
resource "azurerm_role_assignment" "aks_user_roles" {
  scope                = azurerm_kubernetes_cluster.aks.id
  role_definition_name = "Azure Kubernetes Service Cluster User Role"
  principal_id         = var.aks_rbac_admin_group_object_id
}
