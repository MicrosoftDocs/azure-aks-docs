---
title: "Deploy Quarkus on Azure Kubernetes Service"
description: Shows how to quickly stand up Quarkus on Azure Kubernetes Service.
author: KarlErickson
ms.author: edburns
ms.service: azure-kubernetes-service
ms.topic: how-to
ms.date: 12/16/2024
ms.subservice: aks-developer
ms.custom: devx-track-java, devx-track-javaee, devx-track-javaee-quarkus, devx-track-javaee-quarkus-aks, devx-track-extended-java, devx-track-azurecli
# external contributor: danieloh30
---

# Deploy a Java application with Quarkus on an Azure Kubernetes Service cluster

This article shows you how to quickly deploy Red Hat Quarkus on Azure Kubernetes Service (AKS) with a simple CRUD application. The application is a "to do list" with a JavaScript front end and a REST endpoint. Azure Database for PostgreSQL Flexible Server provides the persistence layer for the app. The article shows you how to test your app locally and deploy it to AKS.

## Prerequisites

- [!INCLUDE [quickstarts-free-trial-note](~/reusable-content/ce-skilling/azure/includes/quickstarts-free-trial-note.md)]
- Prepare a local machine with Unix-like operating system installed - for example, Ubuntu, macOS, or Windows Subsystem for Linux.
- Install a Java SE implementation version 17 or later - for example, [Microsoft build of OpenJDK](/java/openjdk).
- Install [Maven](https://maven.apache.org/download.cgi), version 3.9.8 or higher.
- Install [Docker](https://docs.docker.com/get-docker/) for your OS.
- Install [jq](https://jqlang.github.io/jq/download/).
- Install [cURL](https://curl.se/download.html).
- Install the [Quarkus CLI](https://quarkus.io/guides/cli-tooling), version 3.12.1 or higher.
- Azure CLI for Unix-like environments. This article requires only the Bash variant of Azure CLI.
  - [!INCLUDE [azure-cli-login](~/reusable-content/ce-skilling/azure/includes/azure-cli-login.md)]
  - This article requires at least version 2.61.0 of Azure CLI.

## Create the app project

Use the following command to clone the sample Java project for this article. The sample is on [GitHub](https://github.com/Azure-Samples/quarkus-azure).

```bash
git clone https://github.com/Azure-Samples/quarkus-azure
cd quarkus-azure
git checkout 2024-12-16
cd aks-quarkus
```

If you see a message about being in *detached HEAD* state, this message is safe to ignore. Because this article doesn't require any commits, detached HEAD state is appropriate.

## Test your Quarkus app locally

The steps in this section show you how to run the app locally.

Quarkus supports the automatic provisioning of unconfigured services in development and test mode. Quarkus refers to this capability as dev services. Let's say you include a Quarkus feature, such as connecting to a database service. You want to test the app, but haven't yet fully configured the connection to a real database. Quarkus automatically starts a stub version of the relevant service and connects your application to it. For more information, see [Dev Services Overview](https://quarkus.io/guides/dev-services#databases) in the Quarkus documentation.

Make sure your container environment is running and use the following command to enter Quarkus dev mode:

```bash
quarkus dev
```

Instead of `quarkus dev`, you can accomplish the same thing with Maven by using `mvn quarkus:dev`.

You may be asked if you want to send telemetry of your usage of Quarkus dev mode. If so, answer as you like.

Quarkus dev mode enables live reload with background compilation. If you modify any aspect of your app source code and refresh your browser, you can see the changes. If there are any issues with compilation or deployment, an error page lets you know. Quarkus dev mode listens for a debugger on port 5005. If you want to wait for the debugger to attach before running, pass `-Dsuspend` on the command line. If you don't want the debugger at all, you can use `-Ddebug=false`.

The output should look like the following example:

```output
__  ____  __  _____   ___  __ ____  ______
 --/ __ \/ / / / _ | / _ \/ //_/ / / / __/
 -/ /_/ / /_/ / __ |/ , _/ ,< / /_/ /\ \
--\___\_\____/_/ |_/_/|_/_/|_|\____/___/
INFO  [io.quarkus] (Quarkus Main Thread) quarkus-todo-demo-app-aks 1.0.0-SNAPSHOT on JVM (powered by Quarkus 3.2.0.Final) started in 3.377s. Listening on: http://localhost:8080

INFO  [io.quarkus] (Quarkus Main Thread) Profile dev activated. Live Coding activated.
INFO  [io.quarkus] (Quarkus Main Thread) Installed features: [agroal, cdi, hibernate-orm, hibernate-orm-panache, hibernate-validator, jdbc-postgresql, narayana-jta, resteasy-reactive, resteasy-reactive-jackson, smallrye-context-propagation, vertx]

--
Tests paused
Press [e] to edit command line args (currently ''), [r] to resume testing, [o] Toggle test output, [:] for the terminal, [h] for more options>
```

Press <kbd>w</kbd> on the terminal where Quarkus dev mode is running. The <kbd>w</kbd> key opens your default web browser to show the `Todo` application. You can also access the application GUI at `http://localhost:8080` directly.

:::image type="content" source="media/howto-deploy-java-quarkus-app/demo.png" alt-text="Screenshot of the Todo sample app." lightbox="media/howto-deploy-java-quarkus-app/demo.png":::

Try selecting a few todo items in the todo list. The UI indicates selection with a strikethrough text style. You can also add a new todo item to the todo list by typing *Verify Todo apps* and pressing <kbd>ENTER</kbd>, as shown in the following screenshot:

:::image type="content" source="media/howto-deploy-java-quarkus-app/demo-local.png" alt-text="Screenshot of the Todo sample app with new items added." lightbox="media/howto-deploy-java-quarkus-app/demo-local.png":::

Access the RESTful API (`/api`) to get all todo items that store in the local PostgreSQL database:

```bash
curl --verbose http://localhost:8080/api | jq .
```

The output should look like the following example:

```output
* Connected to localhost (127.0.0.1) port 8080 (#0)
> GET /api HTTP/1.1
> Host: localhost:8080
> User-Agent: curl/7.88.1
> Accept: */*
>
< HTTP/1.1 200 OK
< content-length: 664
< Content-Type: application/json;charset=UTF-8
<
{ [664 bytes data]
100   664  100   664    0     0  13278      0 --:--:-- --:--:-- --:--:-- 15441
* Connection #0 to host localhost left intact
[
  {
    "id": 1,
    "title": "Introduction to Quarkus Todo App",
    "completed": false,
    "order": 0,
    "url": null
  },
  {
    "id": 2,
    "title": "Quarkus on Azure App Service",
    "completed": false,
    "order": 1,
    "url": "https://learn.microsoft.com/en-us/azure/developer/java/eclipse-microprofile/deploy-microprofile-quarkus-java-app-with-maven-plugin"
  },
  {
    "id": 3,
    "title": "Quarkus on Azure Container Apps",
    "completed": false,
    "order": 2,
    "url": "https://learn.microsoft.com/en-us/training/modules/deploy-java-quarkus-azure-container-app-postgres/"
  },
  {
    "id": 4,
    "title": "Quarkus on Azure Functions",
    "completed": false,
    "order": 3,
    "url": "https://learn.microsoft.com/en-us/azure/azure-functions/functions-create-first-quarkus"
  },
  {
    "id": 5,
    "title": "Verify Todo apps",
    "completed": false,
    "order": 5,
    "url": null
  }
]
```

Press <kbd>q</kbd> to exit Quarkus dev mode.

## Create the Azure resources to run the Quarkus app

The steps in this section show you how to create the following Azure resources to run the Quarkus sample app:

- Azure Database for PostgreSQL Flexible Server
- Azure Container Registry
- Azure Kubernetes Service (AKS)

> [!NOTE]
> This article disables PostgreSQL authentication to illustrate security best practices. Microsoft Entra ID is used to authenticate the connection to the server. If you need to enable PostgreSQL authentication, see [Quickstart: Use Java and JDBC with Azure Database for PostgreSQL - Flexible Server](/azure/postgresql/flexible-server/connect-java) and select the **Password** tab.

Some of these resources must have unique names within the scope of the Azure subscription. To ensure this uniqueness, you can use the *initials, sequence, date, suffix* pattern. To apply this pattern, name your resources by listing your initials, some sequence number, today's date, and some kind of resource specific suffix - for example, `rg` for "resource group". The following environment variables use this pattern. Replace the placeholder values `UNIQUE_VALUE` and `LOCATION` with your own values and then run the following commands in your terminal:

```bash
export UNIQUE_VALUE=<your unique value, such as ejb010717>
export RESOURCE_GROUP_NAME=${UNIQUE_VALUE}rg
export LOCATION=<your desired Azure region for deploying your resources - for example, northeurope>
export REGISTRY_NAME=${UNIQUE_VALUE}reg
export DB_SERVER_NAME=${UNIQUE_VALUE}db
export DB_NAME=demodb
export CLUSTER_NAME=${UNIQUE_VALUE}aks
export AKS_NS=${UNIQUE_VALUE}ns
```

### Create an Azure Database for PostgreSQL Flexible Server

Azure Database for PostgreSQL Flexible Server is a fully managed database service designed to provide more granular control and flexibility over database management functions and configuration settings. This section shows you how to create an Azure Database for PostgreSQL Flexible Server instance using the Azure CLI.

First, create a resource group to contain the database server and other resources by using the following command:

```azurecli
az group create \
    --name $RESOURCE_GROUP_NAME \
    --location $LOCATION
```

Next, create an Azure Database for PostgreSQL flexible server instance by using the following command:

```azurecli
az postgres flexible-server create \
    --name $DB_SERVER_NAME \
    --database-name $DB_NAME \
    --resource-group $RESOURCE_GROUP_NAME \
    --location $LOCATION \
    --public-access 0.0.0.0 \
    --sku-name Standard_B1ms \
    --tier Burstable \
    --active-directory-auth Enabled \
    --yes
```

It takes a few minutes to create the server, database, admin user, and firewall rules. If the command is successful, the output looks similar to the following example:

```output
{
  "connectionString": "postgresql://REDACTED@ejb011212qdb.postgres.database.azure.com/demodb?sslmode=require",
  "databaseName": "demodb",
  "firewallName": "AllowAllAzureServicesAndResourcesWithinAzureIps_2024-12-12_14-30-22",
  "host": "ejb011212qdb.postgres.database.azure.com",
  "id": "/subscriptions/c7844e91-b11d-4a7f-ac6f-996308fbcdb9/resourceGroups/ejb011211sfi/providers/Microsoft.DBforPostgreSQL/flexibleServers/ejb011212qdb",
  "location": "East US 2",
  "password": "REDACTED",
  "resourceGroup": "ejb011211sfi",
  "skuname": "Standard_B1ms",
  "username": "sorrycamel2",
  "version": "16"
}
```

#### Test app locally with Azure Database for PostgreSQL Flexible Server

In the previous section, you tested the Quarkus app locally in development mode with a PostgreSQL database provisioned as a Docker container. Now, test the connection to the Azure Database for PostgreSQL Flexible Server instance locally.

First, add the current signed-in user as Microsoft Entra Admin to the Azure Database for PostgreSQL Flexible Server instance by using the following commands:

```azurecli
ENTRA_ADMIN_NAME=$(az account show --query user.name --output tsv)
az postgres flexible-server ad-admin create \
    --resource-group $RESOURCE_GROUP_NAME \
    --server-name $DB_SERVER_NAME \
    --display-name $ENTRA_ADMIN_NAME \
    --object-id $(az ad signed-in-user show --query id -o tsv)
```

Successful output is a JSON object including the property `"type": "Microsoft.DBforPostgreSQL/flexibleServers/administrators"`.

Next, add the local IP address to the Azure Database for PostgreSQL Flexible Server instance firewall rules by following these steps:

1. Get the local IP address of your machine where you run the Quarkus app locally. For example, visit https://whatismyipaddress.com to get your public IP v4 address.
1. Define an environment variable with the local IP address you got in the previous step.

   ```bash
   AZ_LOCAL_IP_ADDRESS=<your local IP address>
   ```

1. Run the following command to add the local IP address to the Azure Database for PostgreSQL Flexible Server instance firewall rules:

   ```azurecli
   az postgres flexible-server firewall-rule create \
       --resource-group $RESOURCE_GROUP_NAME \
       --name $DB_SERVER_NAME \
       --rule-name $DB_SERVER_NAME-database-allow-local-ip \
       --start-ip-address $AZ_LOCAL_IP_ADDRESS \
       --end-ip-address $AZ_LOCAL_IP_ADDRESS
   ```

Then, set the following environment variables in your previous terminal. These environment variables are used to connect to the Azure Database for PostgreSQL Flexible Server instance from the Quarkus app running locally:

```bash
export AZURE_POSTGRESQL_HOST=${DB_SERVER_NAME}.postgres.database.azure.com
export AZURE_POSTGRESQL_PORT=5432
export AZURE_POSTGRESQL_DATABASE=${DB_NAME}
export AZURE_POSTGRESQL_USERNAME=${ENTRA_ADMIN_NAME}
```

> [!NOTE]
> The vules of environment variables `AZURE_POSTGRESQL_HOST`, `AZURE_POSTGRESQL_PORT`, `AZURE_POSTGRESQL_DATABASE`, and `AZURE_POSTGRESQL_USERNAME` are read by Database configuration properties defined in the *src/main/resources/application.properties* file introduced in the previous section. These values are automatically injected into the app at runtime using the Service Connector passwordless extension when you deploy the Quarkus app to the AKS cluster later in this article.

Now, run the Quarkus app locally to test the connection to the Azure Database for PostgreSQL Flexible Server instance. Use the following command to start the app in production mode:

```bash
quarkus build
java -jar target/quarkus-app/quarkus-run.jar
```

> [!NOTE]
> If the app fails to start with the similar error message `ERROR [org.hib.eng.jdb.spi.SqlExceptionHelper] (JPA Startup Thread) Acquisition timeout while waiting for new connection`, it's most likely because of the network setting of your local machine. Try to **Add current client IP address** from the Azure portal again by following section [Create a firewall rule after server is created](/azure/postgresql/flexible-server/how-to-manage-firewall-portal#create-a-firewall-rule-after-server-is-created) from the documentation [Create and manage firewall rules for Azure Database for PostgreSQL - Flexible Server using the Azure portal](/azure/postgresql/flexible-server/how-to-manage-firewall-portal), and then run the app again.

Open a new web browser to `http://localhost:8080` to access the Todo application. You should see the similar Todo app as you saw when you ran the app locally in development mode.

### Create an Azure Container Registry instance

Because Quarkus is a cloud native technology, it has built-in support for creating containers that run in Kubernetes. Kubernetes is entirely dependent on having a container registry from which it finds the container images to run. AKS has built-in support for Azure Container Registry.

Use the [az acr create](/cli/azure/acr#az-acr-create) command to create the container registry instance. The following example creates a container registry instance named with the value of your environment variable `${REGISTRY_NAME}`:

```azurecli
az acr create \
    --resource-group $RESOURCE_GROUP_NAME \
    --location ${LOCATION} \
    --name $REGISTRY_NAME \
    --sku Basic
```

After a short time, you should see JSON output that contains the following lines:

```output
  "provisioningState": "Succeeded",
  "publicNetworkAccess": "Enabled",
  "resourceGroup": "<YOUR_RESOURCE_GROUP>",
```

Get the login server for the Container Registry instance by using the following command:

```azurecli
export LOGIN_SERVER=$(az acr show \
    --name $REGISTRY_NAME \
    --query 'loginServer' \
    --output tsv)
echo $LOGIN_SERVER
```

### Connect your docker to the container registry instance

Sign in to the container registry instance. Signing in lets you push an image. Use the following command to sign in to the registry:

```azurecli
az acr login --name $REGISTRY_NAME
```

If you've signed into the container registry instance successfully, you should see `Login Succeeded` at the end of command output.

### Create an AKS cluster

Use the [az aks create](/cli/azure/aks#az-aks-create) command to create an AKS cluster. The following example creates a cluster named with the value of your environment variable `${CLUSTER_NAME}` with one node. The cluster is connected to the container registry instance you created in a preceding step. This command takes several minutes to complete.

```azurecli
az aks create \
    --resource-group $RESOURCE_GROUP_NAME \
    --name $CLUSTER_NAME \
    --attach-acr $REGISTRY_NAME \
    --node-count 1 \
    --generate-ssh-keys \
    --enable-managed-identity
```

After a few minutes, the command completes and returns JSON-formatted information about the cluster, including the following output:

```output
  "nodeResourceGroup": "MC_<your resource_group_name>_<your cluster name>_<your region>",
  "privateFqdn": null,
  "provisioningState": "Succeeded",
  "resourceGroup": "<your resource group name>",
```

### Connect to the AKS cluster

To manage a Kubernetes cluster, you use `kubectl`, the Kubernetes command-line client. To install `kubectl` locally, use the [az aks install-cli](/cli/azure/aks#az-aks-install-cli) command, as shown in the following example:

```azurecli
az aks install-cli
```

For more information about `kubectl`, see [Command line tool (kubectl)](https://kubernetes.io/docs/reference/kubectl/overview/) in the Kubernetes documentation.

To configure `kubectl` to connect to your Kubernetes cluster, use the [az aks get-credentials](/cli/azure/aks#az-aks-get-credentials) command, as shown in the following example. This command downloads credentials and configures the Kubernetes CLI to use them.

```azurecli
az aks get-credentials \
    --resource-group $RESOURCE_GROUP_NAME \
    --name $CLUSTER_NAME \
    --overwrite-existing \
    --admin
```

Successful output includes text similar to the following example:

```output
Merged "ejb010718aks-admin" as current context in /Users/edburns/.kube/config
```

You might find it useful to alias `k` to `kubectl`. If so, use the following command:

```bash
alias k=kubectl
```

To verify the connection to your cluster, use the `kubectl get` command to return a list of the cluster nodes, as shown in the following example:

```bash
k get nodes
```

The following example output shows the single node created in the previous steps. Make sure that the status of the node is **Ready**:

```output
NAME                                STATUS   ROLES   AGE     VERSION
aks-nodepool1-xxxxxxxx-yyyyyyyyyy   Ready    agent   76s     v1.28.9
```

### Create a new namespace in AKS

Use the following command to create a new namespace in your Kubernetes service for your Quarkus app:

```bash
kubectl create namespace ${AKS_NS}
```

The output should look like the following example:

```output
namespace/<your namespace> created
```

### Create a service connection in AKS with Service Connector

In this section, you create a service connection between the AKS cluster and the Azure Database for PostgreSQL Flexible Server using Microsoft Entra Workload ID with Service Connector. This connection allows the AKS cluster to access the Azure Database for PostgreSQL Flexible Server without using SQL authentication.

Run the following commands to create a connection between the AKS cluster and the PostgreSQL database using Microsoft Entra Workload ID with Service Connector.

```azurecli
# Register the Service Connector and Kubernetes Configuration resource providers
az provider register --namespace Microsoft.ServiceLinker --wait
az provider register --namespace Microsoft.KubernetesConfiguration --wait

# Install the Service Connector passwordless extension
az extension add --name serviceconnector-passwordless --upgrade --allow-preview true

# Retrieve the AKS cluster and Azure SQL Server resource IDs
export AKS_CLUSTER_RESOURCE_ID=$(az aks show \
    --resource-group $RESOURCE_GROUP_NAME \
    --name $CLUSTER_NAME \
    --query id \
    --output tsv)
export AZURE_POSTGRESQL_RESOURCE_ID=$(az postgres flexible-server show \
    --resource-group $RESOURCE_GROUP_NAME \
    --name $DB_SERVER_NAME \
    --query id \
    --output tsv)

# Create a user-assigned managed identity used for workload identity
export USER_ASSIGNED_IDENTITY_NAME=workload-identity-uami
az identity create \
    --resource-group ${RESOURCE_GROUP_NAME} \
    --name ${USER_ASSIGNED_IDENTITY_NAME}

# Retrieve the user-assigned managed identity resource ID
export UAMI_RESOURCE_ID=$(az identity show \
    --resource-group ${RESOURCE_GROUP_NAME} \
    --name ${USER_ASSIGNED_IDENTITY_NAME} \
    --query id \
    --output tsv)

# Create a service connection between your AKS cluster and your PostgreSQL database using Microsoft Entra Workload ID
az aks connection create postgres-flexible \
    --connection akspostgresconn \
    --kube-namespace $AKS_NS \
    --source-id $AKS_CLUSTER_RESOURCE_ID \
    --target-id $AZURE_POSTGRESQL_RESOURCE_ID/databases/$DB_NAME \
    --workload-identity $UAMI_RESOURCE_ID
```

> [!NOTE]
> We recommend using Microsoft Entra Workload ID for secure access to your Azure Database for PostgreSQL Flexible Server without using username/password authentication. If you need to use username/password authentication, ignore the previous steps in this section and use the username and password to connect to the database.

### Get service account and secret created by Service Connector

To authenticate to the Azure Database for PostgreSQL Flexible Server, you need to get the service account and secret created by Service Connector. Follow the instructions in the [Update your container](/azure/service-connector/tutorial-python-aks-sql-database-connection-string?pivots=workload-id&tabs=azure-cli#update-your-container) section of [Tutorial: Connect an AKS app to Azure SQL Database](/azure/service-connector/tutorial-python-aks-sql-database-connection-string?pivots=workload-id&tabs=azure-cli). Take the option **Directly create a deployment using the YAML sample code snippet provided** and use the following steps:

1. From the highlighted sections in the sample Kubernetes deployment YAML, copy the values of `serviceAccountName` and `secretRef.name`, represented as `<service-account-name>` and `<secret-name>` in the following example:

   ```yaml
   serviceAccountName: <service-account-name>
   containers:
   - name: raw-linux
      envFrom:
         - secretRef:
            name: <secret-name>
   ```
   
   These values are used in the next section to deploy the Quarkus application to the AKS cluster.

### Customize the cloud native configuration

As a cloud native technology, Quarkus offers the ability to automatically configure resources for standard Kubernetes, Red Hat OpenShift, and Knative. For more information, see the [Quarkus Kubernetes guide](https://quarkus.io/guides/deploying-to-kubernetes#kubernetes), [Quarkus OpenShift guide](https://quarkus.io/guides/deploying-to-kubernetes#openshift) and [Quarkus Knative guide](https://quarkus.io/guides/deploying-to-kubernetes#knative). Developers can deploy the application to a target Kubernetes cluster by applying the generated manifests.

To generate the appropriate Kubernetes resources, use the following command to add the `quarkus-kubernetes` and `container-image-jib` extensions in your local terminal:

```bash
quarkus ext add kubernetes container-image-jib
```

Quarkus modifies the POM to ensure these extensions are listed as `<dependencies>`. If asked to install something called `JBang`, answer *yes* and allow it to be installed.

The output should look like the following example:

```output
[SUCCESS] ✅  Extension io.quarkus:quarkus-kubernetes has been installed
[SUCCESS] ✅  Extension io.quarkus:quarkus-container-image-jib has been installed
```

To verify the extensions are added, you can run `git diff` and examine the output.

As a cloud native technology, Quarkus supports the notion of configuration profiles. Quarkus has the following three built-in profiles:

- `dev` - Activated when in development mode
- `test` - Activated when running tests
- `prod` - The default profile when not running in development or test mode

Quarkus supports any number of named profiles, as needed.

The remaining steps in this section direct you to customize values in the *src/main/resources/application.properties* file.

The `prod.` prefix indicates that these properties are active when running in the `prod` profile. For more information on configuration profiles, see the [Quarkus documentation](https://access.redhat.com/search/?q=Quarkus+Using+configuration+profiles).

#### Database configuration

Examine the following database configuration variables. The database connection related properties `%prod.quarkus.datasource.jdbc.url` and `%prod.quarkus.datasource.username` read values from the environment variables `AZURE_POSTGRESQL_HOST`, `AZURE_POSTGRESQL_PORT`, `AZURE_POSTGRESQL_DATABASE`, and `AZURE_POSTGRESQL_USERNAME`, respectively. These environment variables map to secret values that store the database connection information for security reasons, they are auto-generated using the Service Connector passwordless extension later in this article.

```yaml
# Database configurations
%prod.quarkus.datasource.jdbc.url=jdbc:postgresql://${AZURE_POSTGRESQL_HOST}:${AZURE_POSTGRESQL_PORT}/${AZURE_POSTGRESQL_DATABASE}?\
authenticationPluginClassName=com.azure.identity.extensions.jdbc.postgresql.AzurePostgresqlAuthenticationPlugin\
&sslmode=require
%prod.quarkus.datasource.username=${AZURE_POSTGRESQL_USERNAME}
%prod.quarkus.datasource.jdbc.acquisition-timeout=10
%prod.quarkus.hibernate-orm.database.generation=drop-and-create
%prod.quarkus.hibernate-orm.sql-load-script=import.sql
```

#### Kubernetes configuration

Examine the following Kubernetes configuration variables. `service-type` is set to `load-balancer` to access the app externally. Replace the values of `<service-account-name>` and `<secret-name>` with the values of the actual values you copied in the previous section.

```yaml
# Kubernetes configurations
%prod.quarkus.kubernetes.deployment-target=kubernetes
%prod.quarkus.kubernetes.service-type=load-balancer
%prod.quarkus.kubernetes.labels."azure.workload.identity/use"=true
%prod.quarkus.kubernetes.service-account=<service-account-name>
%prod.quarkus.kubernetes.env.mapping.AZURE_CLIENT_ID.from-secret=<secret-name>
%prod.quarkus.kubernetes.env.mapping.AZURE_CLIENT_ID.with-key=AZURE_POSTGRESQL_CLIENTID
%prod.quarkus.kubernetes.env.mapping.AZURE_POSTGRESQL_HOST.from-secret=<secret-name>
%prod.quarkus.kubernetes.env.mapping.AZURE_POSTGRESQL_HOST.with-key=AZURE_POSTGRESQL_HOST
%prod.quarkus.kubernetes.env.mapping.AZURE_POSTGRESQL_PORT.from-secret=<secret-name>
%prod.quarkus.kubernetes.env.mapping.AZURE_POSTGRESQL_PORT.with-key=AZURE_POSTGRESQL_PORT
%prod.quarkus.kubernetes.env.mapping.AZURE_POSTGRESQL_DATABASE.from-secret=<secret-name>
%prod.quarkus.kubernetes.env.mapping.AZURE_POSTGRESQL_DATABASE.with-key=AZURE_POSTGRESQL_DATABASE
%prod.quarkus.kubernetes.env.mapping.AZURE_POSTGRESQL_USERNAME.from-secret=<secret-name>
%prod.quarkus.kubernetes.env.mapping.AZURE_POSTGRESQL_USERNAME.with-key=AZURE_POSTGRESQL_USERNAME
```

The other Kubernetes configurations specify the mapping of the secret values to the environment variables in the Quarkus application. The `<secret-name>` secret contains the database connection information. The `AZURE_POSTGRESQL_CLIENTID`, `AZURE_POSTGRESQL_HOST`, `AZURE_POSTGRESQL_PORT`, `AZURE_POSTGRESQL_DATABASE`, and `AZURE_POSTGRESQL_USERNAME` keys in the secret map to the `AZURE_CLIENT_ID`, `AZURE_POSTGRESQL_HOST`, `AZURE_POSTGRESQL_PORT`, `AZURE_POSTGRESQL_DATABASE`, and `AZURE_POSTGRESQL_USERNAME` environment variables, respectively.

#### Container image configuration

As a cloud native technology, Quarkus supports generating OCI container images compatible with Docker. Replace the value of `<LOGIN_SERVER_VALUE>` with the value of the actual value of the `${LOGIN_SERVER}` environment variable.

```yaml
# Container Image Build
%prod.quarkus.container-image.build=true
%prod.quarkus.container-image.image=<LOGIN_SERVER_VALUE>/todo-quarkus-aks:1.0
```

### Build the container image and push it to container registry

Now, use the following command to build the application itself. This command uses the Kubernetes and Jib extensions to build the container image.

```bash
quarkus build --no-tests
```

The output should end with `BUILD SUCCESS`. The Kubernetes manifest files are generated in *target/kubernetes*, as shown in the following example:

```output
tree target/kubernetes
target/kubernetes
├── kubernetes.json
└── kubernetes.yml

0 directories, 2 files
```

You can verify whether the container image is generated as well using `docker` command line (CLI). Output looks similar to the following example:

```output
docker images | grep todo-quarkus-aks
<LOGIN_SERVER_VALUE>/todo-quarkus-aks   1.0       b13c389896b7   18 minutes ago   422MB
```

Push the container images to container registry by using the following command:

```bash
export TODO_QUARKUS_TAG=$(docker images | grep todo-quarkus-aks | head -n1 | cut -d " " -f1)
echo ${TODO_QUARKUS_TAG}
docker push ${TODO_QUARKUS_TAG}:1.0
```

The output should look similar to the following example:

```output
The push refers to repository [<LOGIN_SERVER_VALUE>/todo-quarkus-aks]
dfd615499b3a: Pushed
56f5cf1aa271: Pushed
4218d39b228e: Pushed
b0538737ed64: Pushed
d13845d85ee5: Pushed
60609ec85f86: Pushed
1.0: digest: sha256:0ffd70d6d5bb3a4621c030df0d22cf1aa13990ca1880664d08967bd5bab1f2b6 size: 1995
```

Now that you've pushed the app to container registry, you can tell AKS to run the app.

## Deploy the Quarkus app to AKS

The steps in this section show you how to run the Quarkus sample app on the Azure resources you've created.

### Use kubectl apply to deploy the Quarkus app to AKS

Deploy the Kubernetes resources using `kubectl` on the command line, as shown in the following example:

```bash
kubectl apply -f target/kubernetes/kubernetes.yml -n ${AKS_NS}
```

The output should look like the following example:

```output
service/quarkus-todo-demo-app-aks created
deployment.apps/quarkus-todo-demo-app-aks created
```

Verify the app is running by using the following command:

```bash
kubectl -n $AKS_NS get pods
```

If the value of the `STATUS` field shows anything other than `Running`, troubleshoot and resolve the problem before continuing. It may help to examine the pod logs by using the following command:

```bash
kubectl -n $AKS_NS logs $(kubectl -n $AKS_NS get pods | grep quarkus-todo-demo-app-aks | cut -d " " -f1)
```

Get the `EXTERNAL-IP` to access the Todo application by using the following command:

```bash
kubectl get svc -n ${AKS_NS}
```

The output should look like the following example:

```output
NAME                        TYPE           CLUSTER-IP     EXTERNAL-IP     PORT(S)        AGE
quarkus-todo-demo-app-aks   LoadBalancer   10.0.236.101   20.12.126.200   80:30963/TCP   37s
```

You can use the following command to save the value of `EXTERNAL-IP` to an environment variable as a fully qualified URL:

```bash
export QUARKUS_URL=http://$(kubectl get svc -n ${AKS_NS} | grep quarkus-todo-demo-app-aks | cut -d " " -f10)
echo $QUARKUS_URL
```

Open a new web browser to the value of `${QUARKUS_URL}`. Then, add a new todo item with the text `Deployed the Todo app to AKS`. Also, select the `Introduction to Quarkus Todo App` item as complete.

:::image type="content" source="media/howto-deploy-java-quarkus-app/demo-updated.png" alt-text="Screenshot of the Todo sample app running in AKS." lightbox="media/howto-deploy-java-quarkus-app/demo-updated.png":::

Access the RESTful API (`/api`) to get all todo items stored in the Azure PostgreSQL database, as shown in the following example:

```bash
curl --verbose ${QUARKUS_URL}/api | jq .
```

The output should look like the following example:

```output
* Connected to 20.237.68.225 (20.237.68.225) port 80 (#0)
> GET /api HTTP/1.1
> Host: 20.237.68.225
> User-Agent: curl/7.88.1
> Accept: */*
>
< HTTP/1.1 200 OK
< content-length: 828
< Content-Type: application/json;charset=UTF-8
<
[
  {
    "id": 2,
    "title": "Quarkus on Azure App Service",
    "completed": false,
    "order": 1,
    "url": "https://learn.microsoft.com/en-us/azure/developer/java/eclipse-microprofile/deploy-microprofile-quarkus-java-app-with-maven-plugin"
  },
  {
    "id": 3,
    "title": "Quarkus on Azure Container Apps",
    "completed": false,
    "order": 2,
    "url": "https://learn.microsoft.com/en-us/training/modules/deploy-java-quarkus-azure-container-app-postgres/"
  },
  {
    "id": 4,
    "title": "Quarkus on Azure Functions",
    "completed": false,
    "order": 3,
    "url": "https://learn.microsoft.com/en-us/azure/azure-functions/functions-create-first-quarkus"
  },
  {
    "id": 5,
    "title": "Deployed the Todo app to AKS",
    "completed": false,
    "order": 5,
    "url": null
  },
  {
    "id": 1,
    "title": "Introduction to Quarkus Todo App",
    "completed": true,
    "order": 0,
    "url": null
  }
]
```

### Verify the database has been updated

Run the following command to verify that the database has been updated correctly:

```azurecli
ACCESS_TOKEN=$(az account get-access-token --resource-type oss-rdbms --output tsv --query accessToken)
az postgres flexible-server execute \
    --admin-user $ENTRA_ADMIN_NAME \
    --admin-password $ACCESS_TOKEN \
    --name $DB_SERVER_NAME \
    --database-name $DB_NAME \
    --querytext "select * from todo;"
```

If you're asked to install an extension, answer <kbd>Y</kbd>.

The output should look similar to the following example, and should include same items in the Todo app GUI and output of `curl` command earlier:

```output
Successfully connected to <DB_SERVER_NAME>.
Ran Database Query: 'select * from todo;'
Retrieving first 30 rows of query output, if applicable.
Closed the connection to <DB_SERVER_NAME>
[
  {
    "completed": false,
    "id": 2,
    "ordering": 1,
    "title": "Quarkus on Azure App Service",
    "url": "https://learn.microsoft.com/en-us/azure/developer/java/eclipse-microprofile/deploy-microprofile-quarkus-java-app-with-maven-plugin"
  },
  {
    "completed": false,
    "id": 3,
    "ordering": 2,
    "title": "Quarkus on Azure Container Apps",
    "url": "https://learn.microsoft.com/en-us/training/modules/deploy-java-quarkus-azure-container-app-postgres/"
  },
  {
    "completed": false,
    "id": 4,
    "ordering": 3,
    "title": "Quarkus on Azure Functions",
    "url": "https://learn.microsoft.com/en-us/azure/azure-functions/functions-create-first-quarkus"
  },
  {
    "completed": false,
    "id": 5,
    "ordering": 5,
    "title": "Deployed the Todo app to AKS",
    "url": null
  },
  {
    "completed": true,
    "id": 1,
    "ordering": 0,
    "title": "Introduction to Quarkus Todo App",
    "url": null
  }
]
```

When you're finished, delete the firewall rule that allows your local IP address to access the Azure Database for PostgreSQL Flexible Server instance by using the following command:

```azurecli
az postgres flexible-server firewall-rule delete \
    --resource-group $RESOURCE_GROUP_NAME \
    --name $DB_SERVER_NAME \
    --rule-name $DB_SERVER_NAME-database-allow-local-ip \
    --yes
```

## Clean up resources

To avoid Azure charges, you should clean up unneeded resources. When the cluster is no longer needed, use the [az group delete](/cli/azure/group#az-group-delete) command to remove the resource group, container service, container registry, and all related resources.

```azurecli
git reset --hard
docker rmi ${TODO_QUARKUS_TAG}:1.0
docker rmi postgres
az group delete --name $RESOURCE_GROUP_NAME --yes --no-wait
```

You may also want to use `docker rmi` to delete the container images `postgres` and `testcontainers` generated by Quarkus dev mode.

## Next steps

- [Azure Kubernetes Service](https://azure.microsoft.com/free/services/kubernetes-service/)
- [Deploy serverless Java apps with Quarkus on Azure Functions](/azure/azure-functions/functions-create-first-quarkus)
- [Quarkus](https://quarkus.io/)
- [Kubernetes Extension](https://quarkus.io/guides/deploying-to-kubernetes)
- [Jib Options](https://quarkus.io/guides/container-image#jib-options)
- [Jakarta EE on Azure](/azure/developer/java/ee)
