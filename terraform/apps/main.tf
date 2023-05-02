terraform {
  required_providers {
    azurerm = {
      source  = "hashicorp/azurerm"
      version = "3.11.0"
    }
    azurecaf = {
      source  = "aztfmod/azurecaf"
      version = "1.2.16"
    }
    azapi = {
      source = "azure/azapi"
    }
    azuread = {
      source = "hashicorp/azuread"
    }
    kubernetes = {
      source  = "hashicorp/kubernetes"
      version = "2.15.0"
    }
    helm = {
      source = "hashicorp/helm"
    }
  }
  backend "azurerm" {
    resource_group_name  = "rg-terraformstate"
    storage_account_name = "terraformstate26020"
    container_name       = "appstate"
    key                  = "terraform.tfstate"
  }
}

data "azurerm_client_config" "current" {

}

data "azurerm_kubernetes_cluster" "aks" {
  name                = var.cluster_name
  resource_group_name = var.resource_group
}

provider "kubernetes" {
  host                   = data.azurerm_kubernetes_cluster.aks.kube_config.0.host
  cluster_ca_certificate = base64decode(data.azurerm_kubernetes_cluster.aks.kube_config.0.cluster_ca_certificate)
  exec {
    api_version = "client.authentication.k8s.io/v1beta1"
    command     = "kubelogin"
    args = [
      "get-token",
      "--login",
      "azurecli", # spn if you want to use service principal, but requires use of env vars AAD_SERVICE_PRINCIPAL_CLIENT_ID and AAD_SERVICE_PRINCIPAL_CLIENT_SECRET
      "--environment",
      "AzurePublicCloud",
      "--tenant-id",
      data.azurerm_client_config.current.tenant_id,
      "--server-id",
      "6dae42f8-4368-4678-94ff-3960e28e3630",
      "|",
      "jq",
      ".status.token"
    ]
  }
}

provider "helm" {
  kubernetes {
    host                   = data.azurerm_kubernetes_cluster.aks.kube_config.0.host
    cluster_ca_certificate = base64decode(data.azurerm_kubernetes_cluster.aks.kube_config.0.cluster_ca_certificate)
    exec {
      api_version = "client.authentication.k8s.io/v1beta1"
      command     = "kubelogin"
      args = [
        "get-token",
        "--login",
        "azurecli", # spn if you want to use service principal, but requires use of env vars AAD_SERVICE_PRINCIPAL_CLIENT_ID and AAD_SERVICE_PRINCIPAL_CLIENT_SECRET
        "--environment",
        "AzurePublicCloud",
        "--tenant-id",
        data.azurerm_client_config.current.tenant_id,
        "--server-id",
        "6dae42f8-4368-4678-94ff-3960e28e3630",
        "|",
        "jq",
        ".status.token"
      ]
    }

  }

}

provider "azapi" {
}

provider "azurerm" {
  features {}
}

provider "azuread" {
}

resource "kubernetes_namespace" "app_namespace" {
  metadata {
    name = var.apps_namespace
    labels = {
      "environment" = var.environment
      "app"         = var.application_name
    }
  }
}

locals {
  // If an environment is set up (dev, test, prod...), it is used in the application name
  environment         = var.environment == "" ? "dev" : var.environment
  api_gateway_service = "spring-petclinic-api-gateway"
  config_service      = "spring-petclinic-config-server"
  discovery_service   = "spring-petclinic-discovery-server"
  admin_service       = "spring-petclinic-admin-server"
  dotnet_service      = "sample-workload-identity"
  java_service        = "demo-identity-service"
  mssql_service       = "mssql-sample"
}

# first deploy config server
module "config_server" {
  source           = "./modules/k8s-svc"
  appname          = local.config_service
  namespace        = kubernetes_namespace.app_namespace.metadata[0].name
  image            = "${var.registry_url}/${local.config_service}:${var.apps_version}"
  resource_group   = var.resource_group
  application_name = var.application_name
  environment      = var.environment
  location         = var.location
  container_port   = var.container_port
}

# and discovery server
module "discovery_server" {
  source           = "./modules/k8s-svc"
  appname          = local.discovery_service
  namespace        = kubernetes_namespace.app_namespace.metadata[0].name
  image            = "${var.registry_url}/${local.config_service}:${var.apps_version}"
  resource_group   = var.resource_group
  application_name = var.application_name
  environment      = var.environment
  location         = var.location
  profile          = var.profile
  container_port   = var.container_port
  depends_on = [
    module.config_server
  ]
}

# and api-gateway server
module "api_gateway_server" {
  source           = "./modules/k8s-svc"
  appname          = local.api_gateway_service
  namespace        = kubernetes_namespace.app_namespace.metadata[0].name
  image            = "${var.registry_url}/${local.api_gateway_service}:${var.apps_version}"
  resource_group   = var.resource_group
  application_name = var.application_name
  environment      = var.environment
  location         = var.location
  profile          = var.profile
  container_port   = var.container_port
  depends_on = [
    module.config_server
  ]
}

module "k8s_apps" {
  count                = length(var.apps)
  source               = "./modules/k8s-app"
  resource_group       = var.resource_group
  application_name     = var.application_name
  environment          = local.environment
  location             = var.location
  appname              = var.apps[count.index]
  namespace            = kubernetes_namespace.app_namespace.metadata[0].name
  aks_oidc_issuer_url  = data.azurerm_kubernetes_cluster.aks.oidc_issuer_url
  database_url         = var.database_url
  image                = "${var.registry_url}/${var.apps[count.index]}:latest"
  profile              = var.profile
  container_port       = var.container_port
  database_name        = var.database_name
  database_server_fqdn = var.database_server_fqdn
  database_server_name = var.database_server_name
  depends_on = [
    module.config_server,
    module.discovery_server
  ]
}

module "identity_demo_app" {
  source               = "./modules/k8s-app"
  resource_group       = var.resource_group
  application_name     = var.application_name
  environment          = local.environment
  location             = var.location
  appname              = local.java_service
  namespace            = kubernetes_namespace.app_namespace.metadata[0].name
  aks_oidc_issuer_url  = data.azurerm_kubernetes_cluster.aks.oidc_issuer_url
  database_url         = var.database_url
  image                = "${var.registry_url}/${local.java_service}:latest"
  profile              = var.profile
  container_port       = var.container_port
  database_name        = var.database_name
  database_server_fqdn = var.database_server_fqdn
  database_server_name = var.database_server_name
  env_vars = {
    "SERVER_PORT" = var.container_port
  }
  depends_on = [
    module.config_server,
    module.discovery_server
  ]
}

# module "sample_workload_app" {
#   source               = "./modules/k8s-app"
#   resource_group       = var.resource_group
#   application_name     = var.application_name
#   environment          = local.environment
#   location             = var.location
#   appname              = local.dotnet_service
#   namespace            = kubernetes_namespace.app_namespace.metadata[0].name
#   aks_oidc_issuer_url  = data.azurerm_kubernetes_cluster.aks.oidc_issuer_url
#   database_url         = var.database_url
#   image                = "${var.registry_url}/${local.dotnet_service}:${var.apps_version}"
#   profile              = var.profile
#   container_port       = 80
#   database_name        = var.database_name
#   database_server_fqdn = var.database_server_fqdn
#   database_server_name = var.database_server_name
#   health_check_path    = "/healthz"
#   depends_on = [
#     module.config_server,
#     module.discovery_server
#   ]
# }


# module "mssql_workload_app" {
#   source               = "./modules/k8s-app"
#   resource_group       = var.resource_group
#   application_name     = var.application_name
#   environment          = local.environment
#   location             = var.location
#   appname              = local.mssql_service
#   namespace            = kubernetes_namespace.app_namespace.metadata[0].name
#   aks_oidc_issuer_url  = data.azurerm_kubernetes_cluster.aks.oidc_issuer_url
#   database_url         = var.database_url
#   image                = "${var.registry_url}/${local.mssql_service}:${var.apps_version}"
#   profile              = var.profile
#   container_port       = 80
#   database_name        = var.database_name
#   database_server_fqdn = var.database_server_fqdn
#   database_server_name = var.database_server_name
#   health_check_path    = "/healthz"
#   depends_on = [
#     module.config_server,
#     module.discovery_server
#   ]
# }

# module "k8s_svcs" {
#   count            = length(var.cloud_services)
#   source           = "./modules/k8s-svc"
#   resource_group   = var.resource_group
#   application_name = var.application_name
#   environment      = local.environment
#   location         = var.location
#   appname          = var.cloud_services[count.index]
#   namespace        = kubernetes_namespace.app_namespace.metadata[0].name
#   image            = "${var.registry_url}/${var.cloud_services[count.index]}:${var.apps_version}"
#   profile          = var.profile
#   container_port   = var.container_port
#   depends_on = [
#     module.config_server,
#     module.discovery_server
#   ]
# }

module "ingress" {
  source    = "./modules/ingress"
  namespace = kubernetes_namespace.app_namespace.metadata[0].name
  # ingress_routes = []
  ingress_routes = [{
    name    = local.api_gateway_service
    path    = "/clinic(/|$)(.*)"
    service = local.api_gateway_service
    port    = var.container_port
    }, {
    name    = local.admin_service
    path    = "/admin(/|$)(.*)"
    service = local.admin_service
    port    = var.container_port
    }, {
    name    = local.dotnet_service
    path    = "/dotnet(/|$)(.*)"
    service = local.dotnet_service
    port    = 80
    }, {
    name    = local.java_service
    path    = "/java(/|$)(.*)"
    service = local.java_service
    port    = var.container_port
    }, {
    name    = local.mssql_service
    path    = "/mssql(/|$)(.*)"
    service = local.mssql_service
    port    = 80
  }]
}

