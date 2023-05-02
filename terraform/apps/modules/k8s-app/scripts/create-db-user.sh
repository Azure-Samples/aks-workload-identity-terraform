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