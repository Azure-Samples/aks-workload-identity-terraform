terraform {
  required_providers {
    azurecaf = {
      source  = "aztfmod/azurecaf"
      version = "1.2.16"
    }
    azapi = {
      source = "azure/azapi"
    }
  }
}


locals {
  database_username          = "aad-${random_string.username.result}"
  database_url_with_username = "${var.database_url}&useSSL=true&requireSSL=true&user=${local.database_username}&authenticationPlugins=com.azure.identity.providers.mysql.AzureIdentityMysqlAuthenticationPlugin"
}

resource "random_string" "username" {
  length  = 20
  special = false
  upper   = false
}

resource "azurecaf_name" "app_umi" {
  name          = var.appname
  resource_type = "azurerm_user_assigned_identity"
  suffixes      = [var.environment, "micro"]
}

resource "azurerm_user_assigned_identity" "app_umi" {
  name                = azurecaf_name.app_umi.result
  resource_group_name = var.resource_group
  location            = var.location

  provisioner "local-exec" {
    command     = "./scripts/create-db-user.sh ${var.database_server_fqdn} ${local.database_username} ${azurerm_user_assigned_identity.app_umi.principal_id} ${var.database_name}"
    working_dir = path.module
    when        = create
  }

  # provisioner "local-exec" {
  #   command = "./scripts/delete-db-user.sh ${var.server_fqdn} ${local.database_username} ${var.database_name}"
  #   when = destroy
  # }
}

# resource "azapi_resource" "federated_credential" {
#   type      = "Microsoft.ManagedIdentity/userAssignedIdentities/federatedIdentityCredentials@2022-01-31-preview"
#   name      = "fc-${var.appname}"
#   parent_id = azurerm_user_assigned_identity.app_umi.id
#   body = jsonencode({
#     properties = {
#       audiences = ["api://AzureADTokenExchange"]
#       issuer    = var.aks_oidc_issuer_url
#       subject   = "system:serviceaccount:${var.namespace}:${var.appname}"
#     }
#   })
# }

resource "azurerm_federated_identity_credential" "federated_credential" {
  name                = "fc-${var.appname}"
  resource_group_name = var.resource_group
  audience            = ["api://AzureADTokenExchange"]
  issuer              = var.aks_oidc_issuer_url
  parent_id           = azurerm_user_assigned_identity.app_umi.id
  subject             = "system:serviceaccount:${var.namespace}:${var.appname}"
}


resource "kubernetes_service_account_v1" "service_account" {
  metadata {
    name      = var.appname
    namespace = var.namespace
    annotations = {
      "azure.workload.identity/client-id" = azurerm_user_assigned_identity.app_umi.client_id
    }
    labels = {
      "azure.workload.identity/use" = "true"
    }
  }
}



# resource "azuread_application_federated_identity_credential" "federated_credential" {
#   application_object_id = azurerm_user_assigned_identity.app_umi.id
#   display_name          = var.appname
#   audiences             = ["api://AzureADTokenExchange"]
#   issuer                = var.aks_oidc_issuer_url
#   subject               = "system:serviceaccount:${var.namespace}:${var.appname}"
# }


resource "kubernetes_service_v1" "app_service" {
  metadata {
    name      = var.appname
    namespace = var.namespace
    labels = {
      app = var.appname
    }
  }
  spec {
    selector = {
      app = var.appname
    }
    port {
      port        = var.container_port
      target_port = var.container_port
      protocol    = "TCP"
      name        = "endpoint"
    }

    # Debug port
    port {
      port        = 5005
      target_port = 5005
      protocol    = "TCP"
      name        = "debug"
    }
    type = "LoadBalancer"

  }
}


resource "kubernetes_deployment_v1" "app_deployment" {
  metadata {
    name      = var.appname
    namespace = var.namespace
  }

  spec {
    selector {
      match_labels = {
        app = var.appname
      }
    }
    template {
      metadata {
        labels = {
          app = var.appname
        }
        namespace = var.namespace
      }
      spec {
        service_account_name = kubernetes_service_account_v1.service_account.metadata[0].name
        container {
          name              = var.appname
          image             = var.image
          image_pull_policy = "Always"

          port {
            name           = "endpoint"
            container_port = var.container_port
          }

          port {
            name           = "debug"
            container_port = 8000
          }

          security_context {
            privileged = false
          }

          env {
            name  = "SPRING_PROFILES_ACTIVE"
            value = var.profile
          }

          # env {
          #   name  = "SPRING_DATASOURCE_AZURE_PASSWORDLESSENABLED"
          #   value = "true"
          # }
          env {
            name  = "SPRING_DATASOURCE_URL"
            value = local.database_url_with_username
          }
          env {
            name  = "AZURE_MSSQL_CONNECTIONSTRING"
            value = "Server=tcp:mssql-passwordless.database.windows.net;Database=checklist;Authentication=Active Directory Default;TrustServerCertificate=True;Min Pool Size=20"
          }
          # dynamic "env" {
          #   for_each = var.env_vars
          #   content {
          #     name  = var.env_vars[env.key].name
          #     value = var.env_vars[env.key].value
          #   }
          # }

          # for_each = var.env_vars
          # env {
          #   name  = each.key
          #   value = each.value
          # }

          liveness_probe {
            http_get {
              path = var.health_check_path
              port = var.container_port
            }
            initial_delay_seconds = 30
            period_seconds        = 30
          }
        }
      }

    }
  }

}
