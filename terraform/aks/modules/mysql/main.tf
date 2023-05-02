terraform {
  required_providers {
    azurecaf = {
      source  = "aztfmod/azurecaf"
      version = "1.2.16"
    }
    azapi = {
      source  = "azure/azapi"
    }
    azuread = {
      source  = "hashicorp/azuread"
    }
  }
}

resource "azurecaf_name" "mysql_server" {
  name          = var.application_name
  resource_type = "azurerm_mysql_server"
  suffixes      = [var.environment]
}

resource "random_password" "password" {
  length           = 32
  special          = true
  override_special = "_%@"
}

resource "azurerm_mysql_flexible_server" "database" {
  name                = azurecaf_name.mysql_server.result
  resource_group_name = var.resource_group
  location            = var.location

  administrator_login    = var.administrator_login
  administrator_password = random_password.password.result

  sku_name                     = "B_Standard_B1ms"
  backup_retention_days        = 7
  geo_redundant_backup_enabled = false
  zone                         = "1"


  tags = {
    "environment"      = var.environment
    "application-name" = var.application_name
  }
}

resource "azurerm_mysql_flexible_database" "database" {
  name                = var.database_name
  resource_group_name = var.resource_group
  server_name         = azurerm_mysql_flexible_server.database.name
  charset             = "utf8"
  collation           = "utf8_unicode_ci"
}

resource "azurecaf_name" "mysql_firewall_rule" {
  name          = var.application_name
  resource_type = "azurerm_mysql_firewall_rule"
  suffixes      = [var.environment]
}

# This rule is to enable the 'Allow access to Azure services' checkbox
resource "azurerm_mysql_flexible_server_firewall_rule" "database" {
  name                = azurecaf_name.mysql_firewall_rule.result
  resource_group_name = var.resource_group
  server_name         = azurerm_mysql_flexible_server.database.name
  start_ip_address    = "0.0.0.0"
  end_ip_address      = "0.0.0.0"
}

resource "azurecaf_name" "mysql_firewall_rule_allow_iac_machine" {
  name          = var.application_name
  resource_type = "azurerm_mysql_firewall_rule"
  suffixes      = [var.environment, "iac"]
}

data "http" "myip" {
  url = "http://whatismyip.akamai.com"
}

locals {
  myip = chomp(data.http.myip.response_body)
}

# This rule is to enable current user
resource "azurerm_mysql_flexible_server_firewall_rule" "rule_allow_iac_machine" {
  name                = azurecaf_name.mysql_firewall_rule_allow_iac_machine.result
  resource_group_name = var.resource_group
  server_name         = azurerm_mysql_flexible_server.database.name
  start_ip_address    = local.myip
  end_ip_address      = local.myip
}

resource "azurecaf_name" "mysql_aadmin" {
  name          = var.application_name
  resource_type = "azurerm_user_assigned_identity"
  suffixes      = [var.environment, "mysql"]
}

resource "azurerm_user_assigned_identity" "mysql_umi" {
  name                = azurecaf_name.mysql_aadmin.result
  resource_group_name = var.resource_group
  location            = var.location
}

# MySQL AAD Admin

data "azurerm_resource_group" "parent_rg" {
  name = var.resource_group
}

resource "azapi_update_resource" "mysql_tf_identity" {
  type      = "Microsoft.DBForMySql/flexibleServers@2021-12-01-preview"
  name      = azurerm_mysql_flexible_server.database.name
  parent_id = data.azurerm_resource_group.parent_rg.id

  body = jsonencode({
    identity : {
      userAssignedIdentities : {
        "${azurerm_user_assigned_identity.mysql_umi.id}" : {}
      },
      type : "UserAssigned"
    },
  })
  
  timeouts {
    create = "5m"
    update = "5m"
    delete = "5m"
    read   = "3m"
  }
}

data "azuread_user" "aad_admin" {
  user_principal_name = var.mysql_aad_admin
}

data "azurerm_client_config" "current_client" {
}

resource "azapi_resource" "mysql_aad_admin" {
  type = "Microsoft.DBforMySQL/flexibleServers/administrators@2021-12-01-preview"
  name = "ActiveDirectory"
  depends_on = [
    azapi_update_resource.mysql_tf_identity,
    azurerm_mysql_flexible_server.database
  ]
  parent_id = azurerm_mysql_flexible_server.database.id
  body = jsonencode({
    properties = {
      administratorType  = "ActiveDirectory"
      identityResourceId = azurerm_user_assigned_identity.mysql_umi.id
      login              = data.azuread_user.aad_admin.user_principal_name
      sid                = data.azuread_user.aad_admin.object_id
      tenantId           = data.azurerm_client_config.current_client.tenant_id
    }
  })
  timeouts {
    create = "10m"
    update = "5m"
    delete = "10m"
    read   = "3m"
  }
}
