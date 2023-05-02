# Ensure Workload Identity is enabled on the cluster by executing the following command:
# az feature list -o table --query "[?contains(name, 'Microsoft.ContainerService/EnableWorkloadIdentityPreview')].{Name:name,State:properties.state}"
# if the state is not registered, register it with the following command:
# az feature register --namespace "Microsoft.ContainerService" --name "EnableWorkloadIdentityPreview"
# and once registered
# az provider register --namespace Microsoft.ContainerService

cd aks/terraform
# Get current user
CURRENT_USER_OID=$(az ad signed-in-user show --query id -o tsv)
CURRENT_USER_SPN=$(az ad signed-in-user show --query userPrincipalName -o tsv)
cat <<EOF > terraform.tfvars
admin_ids = ["$CURRENT_USER_OID"]
mysql_aad_admin = "$CURRENT_USER_SPN"
EOF
terraform fmt
terraform init
terraform apply -auto-approve

ACR_NAME=$(terraform output -raw acr_name)
RESOURCE_GROUP=$(terraform output -raw resource_group)
DATABASE_ADDRESS=$(terraform output -raw database_url)
DATABASE_URL="jdbc:mysql://${DATABASE_ADDRESS}?useSSL=true"
SERVER_FQDN=$(terraform output -raw database_server_fqdn)
SERVER_NAME=$(terraform output -raw database_server_name)
DATABASE_NAME=$(terraform output -raw database_name)
CLUSTER_NAME=$(terraform output -raw cluster_name)
REGISTRY_URL=${ACR_NAME}.azurecr.io
cd ../..
pwd
cd ..
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

cd demo-identity-service
mvn package -PbuildAcr -DskipTests -DRESOURCE_GROUP=${RESOURCE_GROUP} -DACR_NAME=${ACR_NAME}
cd ..

cd iac
cd apps/terraform
cat << EOF > terraform.tfvars
database_url = "${DATABASE_URL}"
cluster_name = "${CLUSTER_NAME}"
resource_group = "${RESOURCE_GROUP}"
registry_url = "${REGISTRY_URL}"
database_name = "${DATABASE_NAME}"
database_server_fqdn = "${SERVER_FQDN}"
database_server_name = "${SERVER_NAME}"
EOF
terraform fmt
terraform init
terraform apply -auto-approve