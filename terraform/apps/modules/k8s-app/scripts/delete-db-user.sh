DATABASE_FQDN=$1
APPLICATION_LOGIN_NAME=$2
DATABASE_NAME=$3

echo "Delting user ${APPLICATION_LOGIN_NAME} in database ${DATABASE_NAME} on ${DATABASE_FQDN}..."

CURRENT_USER=$(az ad signed-in-user show --query userPrincipalName -o tsv)
RDBMS_ACCESS_TOKEN=$(az account get-access-token --resource-type oss-rdbms --output tsv --query accessToken)
mysql -h "${DATABASE_FQDN}" --user "${CURRENT_USER}" --enable-cleartext-plugin --password="$RDBMS_ACCESS_TOKEN" <<EOF
SET aad_auth_validate_oids_in_tenant = OFF;

DROP USER IF EXISTS '${APPLICATION_LOGIN_NAME}'@'%';

FLUSH privileges;
EOF