---
author: haiche
ms.service: azure-kubernetes-service
ms.topic: include
ms.date: 09/23/2024
ms.author: haiche
---

This section creates an Azure SQL Database using Microsoft Entra authentication, a database with managed identity connection enabled.

### Create a resource group

Create a resource group with [az group create](/cli/azure/group#az-group-create). Because resource groups must be unique within a subscription, pick a unique name. An easy way to have unique names is to use a combination of your initials, today's date, and some identifier. For example, *abc1228rg*. This example creates a resource group named `abc1228rg` in the `eastus` location:

```azurecli-interactive
export RESOURCE_GROUP_NAME="abc1228rg"
az group create \
    --name ${RESOURCE_GROUP_NAME} \
    --location eastus
```

### Create a database server and a database

Create a server with the [az sql server create](/cli/azure/sql/server#az-sql-server-create) command. This example creates a server named `myazuresql20130213` with admin user `azureuser` and admin password `Secret123456`. Replace the password with yours. For more information, see [Quickstart: Create a single database - Azure SQL Database](/azure/azure-sql/database/single-database-create-quickstart?tabs=azure-cli).

```azurecli-interactive
export AZURESQL_SERVER_NAME="myazuresql20130213"
export AZURESQL_ADMIN_USER="azureuser"
export AZURESQL_ADMIN_PASSWORD="Secret123456"

az sql server create \
    --resource-group $RESOURCE_GROUP_NAME \
    --name $AZURESQL_SERVER_NAME \
    --location westus \
    --admin-user $AZURESQL_ADMIN_USER \
    --admin-password $AZURESQL_ADMIN_PASSWORD
```

Create a database with the [az sql db create](/cli/azure/sql/db) command in the [serverless compute tier](/azure/azure-sql/database/serverless-tier-overview).

```azurecli-interactive
export DATABASE_NAME="mysingledatabase20230213"

az sql db create \
    --resource-group $RESOURCE_GROUP_NAME \
    --server $AZURESQL_SERVER_NAME \
    --name $DATABASE_NAME \
    --sample-name AdventureWorksLT \
    --edition GeneralPurpose \
    --compute-model Serverless \
    --family Gen5 \
    --capacity 2
```

### Configure a Microsoft Entra administrator

For information on how Azure SQL Server interacts with managed identities, see [Connect using Microsoft Entra authentication](/sql/connect/jdbc/connecting-using-azure-active-directory-authentication).

The following example configures a Microsoft Entra administrator account to Azure SQL server from the portal.

1. In the [Azure portal](https://portal.azure.com/), open the Azure SQL server instance `myazuresql20130213`.
1. Select **Settings**, then select **Microsoft Entra ID**. On the **Microsoft Entra ID** page, select **Set admin**.
1. On the **Add admin** page, search for a user, select the user or group to be an administrator, and then select **Select**.
1. At the top of the **Microsoft Entra ID** page, select **Save**. For Microsoft Entra users and groups, the Object ID is displayed next to the admin name.
1. The process of changing the administrator may take several minutes. Then, the new administrator appears in the **Microsoft Entra ID** box.

### Create a user-assigned managed identity

Next, in Azure CLI, create an identity in your subscription by using the [az identity create](/cli/azure/identity#az-identity-create) command. You use this managed identity to connect to your database.

```azurecli-interactive
az identity create \
    --resource-group ${RESOURCE_GROUP_NAME} \
    --name myManagedIdentity
```

To configure the identity in the following steps, use the [az identity show](/cli/azure/identity#az-identity-show) command to store the identity's client ID in a shell variable.

```azurecli-interactive
# Get client ID of the user-assigned identity
export CLIENT_ID=$(az identity show \
    --resource-group ${RESOURCE_GROUP_NAME} \
    --name myManagedIdentity \
    --query clientId \
    --output tsv)
```

### Create a database user for your managed identity

Now, connect as the Microsoft Entra administrator user to your Azure SQL database from the Azure portal, and create a user for your managed identity.

First, create a firewall rule to access the Azure SQL server from portal, as shown in the following steps.

1. In the [Azure portal](https://portal.azure.com/), open the Azure SQL server instance `myazuresql20130213`.
1. Select **Security**, then select **Networking**.
1. Under **Firewall rules**, select **Add your client IPV4 IP address**.
1. Under  **Exceptions**, select **Allow Azure services and resources to access this server**.
1. Select **Save**.

After the firewall rule is created, you can access the Azure SQL server from portal. Use the following steps to create a database user.

1. Select **Settings**, then select **SQL databases**. Select `mysingledatabase20230213`.
1. Select **Query editor**. On the **Welcome to SQL Database Query Editor** page, under **Active Directory authentication**, find a message like "Logged in as user@contoso.com".
1. Select **Continue as user@contoso.com**, where `user` is your AD admin account name.
1. After signing in, in the **Query 1** editor, run the following commands to create a database user for managed identity `myManagedIdentity`.

   ```sql
   CREATE USER "myManagedIdentity" FROM EXTERNAL PROVIDER
   ALTER ROLE db_datareader ADD MEMBER "myManagedIdentity";
   ALTER ROLE db_datawriter ADD MEMBER "myManagedIdentity";
   ALTER ROLE db_ddladmin ADD MEMBER "myManagedIdentity";
   GO
   ```

1. In the **Query 1** editor, select **Run** to run the SQL commands.
1. If the commands complete successfully, you can find a message saying "Query succeeded: Affected rows: 0".