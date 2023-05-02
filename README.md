# AKS Workload Identity Terraform sample

This sample demonstrates how to deploy using Terraform an application that uses Workload Federated identity to access Azure resources.

For this demo, it will be used the well-known Java example [Spring PetClinic](https://github.com/azure-samples/spring-petclinic-microservices). As the Azure version already implements passwordless it won't be necessary to change the code, hence we will use the original repo.

## Features

This sample has two parts:

* Infrastructure deployment. There is a Terraform configuration to create an AKS cluster, a Container Registry and a MySQL Flexible server. It will do all configuration required to allow the cluster to use Workload Federated Identity.
* Application deployment. There is another Terraform configuration that will create a Kubernetes Service for each microservice of the PetClinic application, will create an User-Assigned Managed Identity,will bind a service account to the identity and will configure the identity to access the MySQL server.

## Preparation

Create a Terraform state storage account and a container to store the state file. You can use the following commands:

```bash
rgName=rg-terraformstate
random=$RANDOM 
saName=terraformstate${random}
containerName=springstate

# Create Azure Resource Group
az group create \
    --name $rgName \
    --location eastus
# Create Storage Account with public access disabled
az storage account create \
    --resource-group $rgName \
    --name $saName \
    --sku Standard_LRS \
    --allow-blob-public-access $false
# Create container to store configuration state file
az storage container create \
    --name $containerName \
    --account-name $saName
```

Set this configuration in backend configuration in infrastructure [main.tf](./terraform/infra/main.tf) and apps [main.tf](./terraform/apps/main.tf), like this:

**Infrastructure**

```terraform
terraform {
  required_providers {
    azurerm = {
      source  = "hashicorp/azurerm"
      version = "3.30.0"
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
  }
  backend "azurerm" {
    resource_group_name  = "rg-terraformstate"
    storage_account_name = "terraformstate26020"
    container_name       = "springstate"
    key                  = "terraform.tfstate"
  }
}
```

**Apps**

```terraform
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
```

Please note that the only difference is the `container_name` attribute.

## Infrastructure deployment

The infrastructure deployment consists of:

* A group of administrators.
* A Container Registry to store the PetClinic images.
* An AKS cluster with Workload Federated Identity enabled.
  * It is attached to the Container Registry.
  * The administrators group is configured as AKS AD Admins.
* A MySQL Flexible server.
  * There is a managed identity associated to the server. This is necessary to allow AAD authentication.
  * A user is assigned as an AAD admin.

All configuration is under `aks` folder. To deploy it run the following commands:

```bash
cd aks
terraform init
terraform apply
```

The following sub-sections explain the detail of each component.

### Administrators group

It is defined in [admins](./terraform/infra/modules/admins/) module. It creates a group and adds the users defined in `admin_ids` variable.

### Container Registry

It is defined in [acr](./terraform/infra/modules/acr/) module. It creates a Container Registry.

### AKS Cluster

It is defined in [aks](./terraform/infra/modules/aks/) module. It creates an AKS cluster with the following configuration:

#### Enable workload identity

```terraform
resource "azurerm_kubernetes_cluster" "aks" {
  name                = azurecaf_name.aks_cluster.result
  resource_group_name = var.resource_group
  # ...

  workload_identity_enabled = true

  # ...
}
```

#### Enable OIDC issuer

```terraform
resource "azurerm_kubernetes_cluster" "aks" {
  name                = azurecaf_name.aks_cluster.result
  resource_group_name = var.resource_group
  # ...

  oidc_issuer_enabled       = true

  # ...
}
```

#### Assign Azure AD admins

```terraform
resource "azurerm_kubernetes_cluster" "aks" {
  name                = azurecaf_name.aks_cluster.result
  resource_group_name = var.resource_group
  # ...

  azure_active_directory_role_based_access_control {
    managed = true
    admin_group_object_ids = [
      var.aks_rbac_admin_group_object_id,
    ]
    azure_rbac_enabled = false
  }

  # ...
}

# grant permission to admin group to manage aks
resource "azurerm_role_assignment" "aks_user_roles" {
  scope                = azurerm_kubernetes_cluster.aks.id
  role_definition_name = "Azure Kubernetes Service Cluster User Role"
  principal_id         = var.aks_rbac_admin_group_object_id
}
```

#### Attach AKS to ACR

```terraform
resource "azurerm_kubernetes_cluster" "aks" {
  name                = azurecaf_name.aks_cluster.result
  resource_group_name = var.resource_group
  # ...

  identity {
    type = "SystemAssigned"
  }

  # ...
}

# grant permission to aks to pull images from acr
resource "azurerm_role_assignment" "acrpull_role" {
  scope                = var.acr_id
  role_definition_name = "AcrPull"
  principal_id         = azurerm_kubernetes_cluster.aks.kubelet_identity.0.object_id
}
```

### MySQL Flexible server

It is defined in [mysql](./terraform/infra/modules/mysql/) module. It creates:

* A User-Assigned Managed Identity. This will be the identity associated to MySQL server. Among other features not related to this scenario, it is used to retrieve information from Azure AD about the users connecting to the server. If you plan to use RBAC features, such as granting permissions to groups, you will need to assign elevated permissions to this identity. See this [article](https://learn.microsoft.com/azure/mysql/flexible-server/concepts-azure-ad-authentication#permissions) for more details.
* A MySQL Flexible server. It is configured to use Azure AD authentication. The identity created in the previous step is associated to the server.
* A MySQL AAD admin.
* A firewall rule to allow current machine to connect to the server.
* Create a database.

Here the configuration of the unusual parts:

#### Create a Managed Identity and assign to MySQL

This is an operation not yet supported in the Terraform provider. It is done using the [azapi](https://registry.terraform.io/providers/azure/azapi/latest/docs) provider.

```terraform
resource "azurerm_user_assigned_identity" "mysql_umi" {
  name                = azurecaf_name.mysql_umi.result
  resource_group_name = var.resource_group
  location            = var.location
}

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
```

#### Assign a user as Azure AD admin

This operation is not yet support by the Terraform provider, so it is done using the [azapi](https://registry.terraform.io/providers/azure/azapi/latest/docs) provider.

```terraform
# MySQL AAD Admin
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
```

#### A firewall rule to allow current machine to connect to the server

Current machine IP is retrieved using an HTTP request to a public service.

```terraform
data "http" "myip" {
  url = "http://whatismyip.akamai.com"
}

locals {
  myip = chomp(data.http.myip.response_body)
}

# This rule is to enable current machine
resource "azurerm_mysql_flexible_server_firewall_rule" "rule_allow_iac_machine" {
  name                = azurecaf_name.mysql_firewall_rule_allow_iac_machine.result
  resource_group_name = var.resource_group
  server_name         = azurerm_mysql_flexible_server.database.name
  start_ip_address    = local.myip
  end_ip_address      = local.myip
}
```

## Application deployment

Application can be deployed independently from the infrastructure. For demo purposes, this sample uses the well-known application [Spring PetClinic](https://github.com/azure-samples/spring-petclinic-microservices), using the Azure version that already uses passwordless connections. This repo supports two types of deployments:

* Services: Microservices that are part of the [Spring Cloud](https://spring.io/cloud) architecture:
  * Config Server.
  * Service Registry.
  * API Gateway.
* Applications: Business microservices that implements the application logic.
  * Customers.
  * Visits.
  * Vets.

Applications require to connect to MySQL, for that reason it will be configured to use Azure AD authentication thru Workload Identities. Each application requires:

* User-Assigned Managed Identity.
* An AKS service account linked to the User-Assigned Managed Identity.
* A MySQL user linked to the User-Assigned Managed Identity.

As the AKS components depends on the Azure Managed Identity it is considered easier to link and maintain everything with Terraform configuration.

> [!IMPORTANT] The application Managed Identities are different to the Managed Identity used to configure MySQL. Potentially the identity associated with MySQL may have elevated permissions on Azure AD that are not required by the application.

The logic to create the application is defined in [k8s-app](./terraform/apps/modules/k8s-app/main.tf). It creates:

**User-Assigned Managed Identity creation and Database user assignment**

```terraform
resource "azurerm_user_assigned_identity" "app_umi" {
  name                = azurecaf_name.app_umi.result
  resource_group_name = var.resource_group
  location            = var.location

  provisioner "local-exec" {
    command     = "./scripts/create-db-user.sh ${var.database_server_fqdn} ${local.database_username} ${azurerm_user_assigned_identity.app_umi.principal_id} ${var.database_name}"
    working_dir = path.module
    when        = create
  }
}

resource "azurerm_federated_identity_credential" "federated_credential" {
  name                = "fc-${var.appname}"
  resource_group_name = var.resource_group
  audience            = ["api://AzureADTokenExchange"]
  issuer              = var.aks_oidc_issuer_url
  parent_id           = azurerm_user_assigned_identity.app_umi.id
  subject             = "system:serviceaccount:${var.namespace}:${var.appname}"
}
```

Note that it is executed a provisioner during creation of the managed identity. There is a script that creates the MySQL user and grants the required permissions. The script is defined in [create-db-user.sh](./terraform/apps/modules/k8s-app/scripts/create-db-user.sh).

```SQL
DATABASE_FQDN=$1
APPLICATION_LOGIN_NAME=$2
APPLICATION_IDENTITY_APPID=$3
DATABASE_NAME=$4

echo "Creating user ${APPLICATION_LOGIN_NAME} in database ${DATABASE_NAME} on ${DATABASE_FQDN}..."

CURRENT_USER=$(az ad signed-in-user show --query userPrincipalName -o tsv)
RDBMS_ACCESS_TOKEN=$(az account get-access-token --resource-type oss-rdbms --output tsv --query accessToken)
mysql -h "${DATABASE_FQDN}" --user "${CURRENT_USER}" --enable-cleartext-plugin --password="$RDBMS_ACCESS_TOKEN" <<EOF
SET aad_auth_validate_oids_in_tenant = OFF;

DROP USER IF EXISTS '${APPLICATION_LOGIN_NAME}'@'%';

CREATE AADUSER '${APPLICATION_LOGIN_NAME}' IDENTIFIED BY '${APPLICATION_IDENTITY_APPID}';

GRANT ALL PRIVILEGES ON ${DATABASE_NAME}.* TO '${APPLICATION_LOGIN_NAME}'@'%';

FLUSH privileges;
EOF
```

Then the managed identity should be linked to the AKS service account.

```terraform
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
```

And the service account is used by the service:

```terraform
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
          
          env {
            name  = "SPRING_DATASOURCE_URL"
            value = local.database_url_with_username
          }
          
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
```

See `service_account_name` attribute, where the service account is linked to the deployment.

### Build application images

The first step is to get the code. For that execute the following commands:

```bash
git clone https://github.com/Azure-Samples/spring-petclinic-microservices.git
cd spring-petclinic-microservices
```

This sample requires to create the images and store it in the Azure Container Registry that will be used by AKS. It is possible to use Azure Container Registry to build and store the images, no need for Docker installed in the developer machine. See this article for details: [Using Azure Container Registry to build Docker images for Java projects](https://techcommunity.microsoft.com/t5/fasttrack-for-azure/using-azure-container-registry-to-build-docker-images-for-java/ba-p/3563875)

Steps to build the images:
* Create a new profile in pom.xml

```xml
<profile>
    <id>buildAcr</id>
    <build>
        <plugins>
            <plugin>
                <groupId>org.codehaus.mojo</groupId>
                <artifactId>exec-maven-plugin</artifactId>
                <version>3.0.0</version>
                <executions>
                    <execution>
                        <id>acr-package</id>
                        <phase>package</phase>
                        <goals>
                            <goal>exec</goal>
                        </goals>
                        <configuration>
                            <executable>az</executable>
                            <workingDirectory>${project.basedir}</workingDirectory>
                            <arguments>
                                <argument>acr</argument>
                                <argument>build</argument>
                                <argument>--resource-group</argument>
                                <argument>${RESOURCE_GROUP}</argument>
                                <argument>--registry</argument>
                                <argument>${ACR_NAME}</argument>
                                <argument>--image</argument>
                                <argument>${project.artifactId}:${project.version}</argument>
                                <argument>--build-arg</argument>
                                <argument>ARTIFACT_NAME=target/${project.build.finalName}.jar</argument>
                                <argument>-f</argument>
                                <argument>Dockerfile</argument>
                                <argument>.</argument>
                            </arguments>
                        </configuration>
                    </execution>
                </executions>
            </plugin>
        </plugins>
    </build>
</profile>
```

Build the images:

```bash
cd spring-petclinic-admin-server
mvn package -PbuildAcr -DskipTests -DRESOURCE_GROUP=${RESOURCE_GROUP} -DACR_NAME=${ACR_NAME}
cd ..
cd spring-petclinic-api-gateway
mvn package -PbuildAcr -DskipTests -DRESOURCE_GROUP=${RESOURCE_GROUP} -DACR_NAME=${ACR_NAME}
cd ..
cd spring-petclinic-config-server
mvn package -PbuildAcr -DskipTests -DRESOURCE_GROUP=${RESOURCE_GROUP} -DACR_NAME=${ACR_NAME}
cd ..
cd spring-petclinic-discovery-server
mvn package -PbuildAcr -DskipTests -DRESOURCE_GROUP=${RESOURCE_GROUP} -DACR_NAME=${ACR_NAME}
cd ..
cd spring-petclinic-customers-service
mvn package -PbuildAcr -DskipTests -DRESOURCE_GROUP=${RESOURCE_GROUP} -DACR_NAME=${ACR_NAME}
cd ..
cd spring-petclinic-vets-service
mvn package -PbuildAcr -DskipTests -DRESOURCE_GROUP=${RESOURCE_GROUP} -DACR_NAME=${ACR_NAME}
cd ..
cd spring-petclinic-visits-service
mvn package -PbuildAcr -DskipTests -DRESOURCE_GROUP=${RESOURCE_GROUP} -DACR_NAME=${ACR_NAME}
cd ..
```

Now it is possible to execute the Terraform script to deploy the application in AKS. AKS and SQL parameters can be extracted from Infrastructure terraform deployment.

```bash
cd terraform/infra
ACR_NAME=$(terraform output -raw acr_name)
RESOURCE_GROUP=$(terraform output -raw resource_group)
DATABASE_ADDRESS=$(terraform output -raw database_url)
DATABASE_URL="jdbc:mysql://${DATABASE_ADDRESS}?useSSL=true"
SERVER_FQDN=$(terraform output -raw database_server_fqdn)
SERVER_NAME=$(terraform output -raw database_server_name)
DATABASE_NAME=$(terraform output -raw database_name)
CLUSTER_NAME=$(terraform output -raw cluster_name)
REGISTRY_URL=${ACR_NAME}.azurecr.io
```

Then create a tfvars file with the following content:

```bash
cd terraform/apps
cat << EOF > terraform.tfvars
database_url = "${DATABASE_URL}"
cluster_name = "${CLUSTER_NAME}"
resource_group = "${RESOURCE_GROUP}"
registry_url = "${REGISTRY_URL}"
database_name = "${DATABASE_NAME}"
database_server_fqdn = "${SERVER_FQDN}"
database_server_name = "${SERVER_NAME}"
EOF
```

Then finally execute the Terraform script:

```bash
terraform fmt
terraform init
terraform apply
```

Once cloned the code and created the profile in the pom.xml file, it is possible to use [deploy.sh](deploy.sh) script to deploy both infrastructure and apps.

