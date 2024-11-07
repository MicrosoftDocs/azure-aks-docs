---
title: Deploy a Java application with Open Liberty/WebSphere Liberty on an Azure Kubernetes Service (AKS) cluster
recommendations: false
description: Deploy a Java application with Open Liberty or WebSphere Liberty on an AKS cluster by using the Azure Marketplace offer, which automatically provisions resources.
author: KarlErickson
ms.author: edburns
ms.topic: how-to
ms.date: 11/14/2024
ms.subservice: aks-developer
keywords: java, jakartaee, javaee, microprofile, open-liberty, websphere-liberty, aks, kubernetes
ms.custom: devx-track-java, devx-track-javaee, devx-track-javaee-liberty, devx-track-javaee-liberty-aks, devx-track-javaee-websphere, build-2023, devx-track-extended-java
---

# Deploy a Java application with Open Liberty or WebSphere Liberty on an Azure Kubernetes Service (AKS) cluster

This article demonstrates how to:

* Run your Java, Java EE, Jakarta EE, or MicroProfile application on the [Open Liberty](https://openliberty.io/) or [IBM WebSphere Liberty](https://www.ibm.com/cloud/websphere-liberty) runtime.
* Build the application's Docker image with `az acr build` by using Open Liberty or WebSphere Liberty container images.
* Deploy the containerized application to an Azure Kubernetes Service (AKS) cluster by using the Open Liberty Operator or WebSphere Liberty Operator.

The Open Liberty Operator simplifies the deployment and management of applications running on Kubernetes clusters. With the Open Liberty Operator or WebSphere Liberty Operator, you can also perform more advanced operations, such as gathering traces and dumps.

This article uses the Azure Marketplace offer for Open Liberty or WebSphere Liberty to accelerate your journey to AKS. The offer automatically provisions some Azure resources, including:

* An Azure Container Registry instance.
* An AKS cluster.
* An Application Gateway Ingress Controller (AGIC) instance.
* The Open Liberty Operator and WebSphere Liberty Operator.
* Optionally, a container image that includes Liberty and your application.

If you prefer manual step-by-step guidance for running Liberty on AKS, see [Manually deploy a Java application with Open Liberty or WebSphere Liberty on an Azure Kubernetes Service (AKS) cluster](/azure/developer/java/ee/howto-deploy-java-liberty-app-manual).

This article is intended to help you quickly get to deployment. Before you go to production, you should explore the [IBM documentation about tuning Liberty](https://www.ibm.com/docs/was-liberty/base?topic=tuning-liberty).

If you're interested in providing feedback or working closely on your migration scenarios with the engineering team developing WebSphere on Azure solutions, fill out this short [survey on WebSphere migration](https://aka.ms/websphere-on-azure-survey) and include your contact information. The team of program managers, architects, and engineers will promptly get in touch with you to initiate close collaboration.

## Prerequisites

* An Azure subscription. [!INCLUDE [quickstarts-free-trial-note](~/reusable-content/ce-skilling/azure/includes/quickstarts-free-trial-note.md)]
* Prepare a local machine with Unix-like operating system installed - for example, Ubuntu, Azure Linux, macOS, or Windows Subsystem for Linux.
* Install the [Azure CLI](/cli/azure/install-azure-cli) to run Azure CLI commands.
  * Sign in to the Azure CLI by using the [az login](/cli/azure/reference-index#az-login) command. To finish the authentication process, follow the steps displayed in your terminal. For other sign-in options, see [Sign into Azure with Azure CLI](/cli/azure/authenticate-azure-cli#sign-into-azure-with-azure-cli).
  * When you're prompted, install the Azure CLI extension on first use. For more information about extensions, see [Use and manage extensions with the Azure CLI](/cli/azure/azure-cli-extensions-overview).
  * Run [az version](/cli/azure/reference-index?#az-version) to find the version and dependent libraries that are installed. To upgrade to the latest version, run [az upgrade](/cli/azure/reference-index?#az-upgrade). This article requires at least version 2.61.0 of Azure CLI.
* Install a Java Standard Edition (SE) implementation, version 17 (for example, [Eclipse Open J9](https://www.eclipse.org/openj9/)).
* Install [Maven](https://maven.apache.org/download.cgi) 3.9.8 or higher.
* Ensure [Git](https://git-scm.com) is installed.
* Make sure you're assigned either the `Owner` role or the `Contributor` and `User Access Administrator` roles in the subscription. You can verify it by following steps in [List role assignments for a user or group](/azure/role-based-access-control/role-assignments-list-portal#list-role-assignments-for-a-user-or-group).

## Create a Liberty on AKS deployment using the portal

The following steps guide you to create a Liberty runtime on AKS. After you complete these steps, you'll have a Container Registry instance and an AKS cluster for deploying your containerized application.

1. Go to the [Azure portal](https://portal.azure.com/). In the search box at the top of the page, enter **WebSphere Liberty/Open Liberty on Kubernetes**. When the suggestions appear, select the one and only match in the **Marketplace** section.

   If you prefer, you can [go directly to the offer](https://aka.ms/liberty-aks).

1. Select **Create**.

1. On the **Basics** pane:

   1. Create a new resource group. Because resource groups must be unique within a subscription, choose a unique name. An easy way to have unique names is to use a combination of your initials, today's date, and some identifier (for example, `ejb0913-java-liberty-project-rg`). Save aside the resource group name for later use in this article.
   1. For **Region**, select a region that's close to you. For example, select **East US 2**.

1. Select **Next**. On the **AKS** pane, you can optionally select an existing AKS cluster and Container Registry instance, instead of causing the deployment to create new ones. This choice enables you to use the sidecar pattern, as shown in the [Azure Architecture Center](/azure/architecture/patterns/sidecar). You can also adjust the settings for the size and number of the virtual machines in the AKS node pool.

   For the purposes of this article, just keep all the defaults on this pane.

1. Select **Next**. On the **Load Balancing** pane, next to **Connect to Azure Application Gateway?**, select **Yes**. In this section, you can customize the following deployment options:

   * For **Virtual network** and **Subnet**, you can optionally customize the virtual network and subnet into which the deployment places the resources. You don't need to change the remaining values from their defaults.
   * For **TLS/SSL certificate**, you can provide the TLS/SSL certificate from Azure Application Gateway. Leave the values at their defaults to cause the offer to generate a self-signed certificate.

     Don't go to production with a self-signed certificate. For more information about self-signed certificates, see [Create a self-signed public certificate to authenticate your application](/azure/active-directory/develop/howto-create-self-signed-certificate).
   * You can select **Enable cookie based affinity**, also known as sticky sessions. This article uses sticky sessions, so be sure to select this option.

1. Select **Next**. On the **Operator and application** pane, this article uses all the defaults. However, you can customize the following deployment options:

   * You can deploy WebSphere Liberty Operator by selecting **Yes** for the option **IBM supported?**. Leaving the default **No** deploys Open Liberty Operator.
   * You can deploy an application for your selected operator by selecting **Yes** for the option **Deploy an application?**. Leaving the default **No** doesn't deploy any application.

1. Select **Review + create** to validate your selected options. On the **Review + create** pane, when you see **Create** become available after validation passes, select it.

   The deployment can take up to 20 minutes. While you wait for the deployment to finish, you can follow the steps in the section [Create an Azure SQL Database instance](#create-an-azure-sql-database-instance). After you complete that section, come back here and continue.

## Capture selected information from the deployment

If you moved away from the **Deployment is in progress** pane, the following steps show you how to get back to that pane. If you're still on the pane that shows **Your deployment is complete**, go to the newly created resource group and skip to the third step.

1. In the corner of any portal page, select the menu button, and then select **Resource groups**.
1. In the box with the text **Filter for any field**, enter the first few characters of the resource group that you created previously. If you followed the recommended convention, enter your initials, and then select the appropriate resource group.
1. In the list of resources in the resource group, select the resource with the **Type** value of **Container registry**.
1. On the navigation pane, under **Settings**, select **Access keys**.
1. Save aside the values for **Registry name** and **Login server**. You can use the copy icon next to each field to copy the value to the system clipboard.

   > [!NOTE]
   > This article uses the [`az acr build`](/cli/azure/acr#az-acr-build) command to build  and push the Docker image to the Container Registry, without using `username` and `password` of the Container Registry. It's still possible to use username and password with `docker login` and `docker push`. Using username and password is less secure than passwordless authentication.

1. Go back to the resource group into which you deployed the resources.
1. In the **Settings** section, select **Deployments**.
1. Select the bottom-most deployment in the list. The **Deployment name** value matches the publisher ID of the offer. It contains the string `ibm`.
1. On the navigation pane, select **Outputs**.
1. By using the same copy technique as with the preceding values, save aside the values for the following outputs:

   * `cmdToConnectToCluster`
   * `appDeploymentTemplateYaml` if the deployment doesn't include an application. That is, you selected **No** for **Deploy an application?** when you deployed the Marketplace offer. This article selected **No**. However, if you selected **Yes**, save aside the value of `appDeploymentYaml`, which includes the application deployment.

      ### [Bash](#tab/in-bash)

      Paste the value of `appDeploymentTemplateYaml` or `appDeploymentYaml` into a Bash shell, and run the command.

      ### [PowerShell](#tab/in-powershell)

      Paste the value of `appDeploymentTemplateYaml` or `appDeploymentYaml` into PowerShell (excluding the `| base64` portion), append `| ForEach-Object { [System.Text.Encoding]::UTF8.GetString([System.Convert]::FromBase64String($_)) }`, and run the command.

       ---

      The output of this command is the application deployment YAML. Look for the ingress TLS secret with keyword `secretName`, such as `- secretName: secret785e2c`. Save aside the `secretName` value.

Run the following commands to set the environment variables that you captured in the previous steps. These environment variables are used later in this article.

### [Bash](#tab/in-bash)

```bash
export RESOURCE_GROUP_NAME=<your-resource-group-name>
export REGISTRY_NAME=<your-registry-nam-of-container-registry>
export LOGIN_SERVER=<your-login-server-of-container-registry>
export INGRESS_TLS_SECRET=<your-ingress-tls-secret-name>
```

### [PowerShell](#tab/in-powershell)

```powershell
$Env:RESOURCE_GROUP_NAME="<your-resource-group-name>"
$Env:REGISTRY_NAME="<your-registry-nam-of-container-registry>"
$Env:LOGIN_SERVER="<your-login-server-of-container-registry>"
$Env:INGRESS_TLS_SECRET="<your-ingress-tls-secret-name>"
```

---

## Create an Azure SQL Database instance

In this section, you create an Azure SQL Database single database for use with your app.

### [Bash](#tab/in-bash)

First, set database-related environment variables. Replace `<your-unique-sql-server-name>` with a unique name for your Azure SQL Database server.

```bash
export SQL_SERVER_NAME=<your-unique-sql-server-name>
export DB_NAME=demodb
```

Run the following command in your terminal to create a single database in Azure SQL Database and set the current signed-in user as a Microsoft Entra admin. For more information, see [Quickstart: Create a single database - Azure SQL Database](/azure/azure-sql/database/single-database-create-quickstart?view=azuresql-db&preserve-view=true&tabs=azure-cli).

```azurecli
export ENTRA_ADMIN_NAME=$(az account show --query user.name --output tsv)

az sql server create \
    --name $SQL_SERVER_NAME \
    --resource-group $RESOURCE_GROUP_NAME \
    --enable-ad-only-auth \
    --external-admin-principal-type User \
    --external-admin-name $ENTRA_ADMIN_NAME \
    --external-admin-sid $(az ad signed-in-user show --query id --output tsv)
az sql db create \
    --resource-group $RESOURCE_GROUP_NAME \
    --server $SQL_SERVER_NAME \
    --name $DB_NAME \
    --edition GeneralPurpose \
    --compute-model Serverless \
    --family Gen5 \
    --capacity 2
```

Then, add the local IP address to the Azure SQL Database server firewall rules to allow your local machine to connect to the database for local testing later.

```azurecli
export AZ_LOCAL_IP_ADDRESS=$(curl -s https://whatismyip.akamai.com)
az sql server firewall-rule create \
    --resource-group $RESOURCE_GROUP_NAME \
    --server $SQL_SERVER_NAME \
    --name AllowLocalIP \
    --start-ip-address $AZ_LOCAL_IP_ADDRESS \
    --end-ip-address $AZ_LOCAL_IP_ADDRESS
```

### [PowerShell](#tab/in-powershell)

First, set database-related environment variables. Replace `<your-unique-sql-server-name>` with a unique name for your Azure SQL Database server.

```powershell
$Env:SQL_SERVER_NAME = "<your-unique-sql-server-name>"
$Env:DB_NAME = "demodb"
```

Run the following command in your terminal to create a single database in Azure SQL Database and set the current signed-in user as Microsoft Entra admin. For more information, see [Quickstart: Create a single database - Azure SQL Database](/azure/azure-sql/database/single-database-create-quickstart?view=azuresql-db&preserve-view=true&tabs=azure-powershell).

```azurepowershell
$Env:ENTRA_ADMIN_NAME = $(az account show --query user.name --output tsv)

az sql server create --name $Env:SQL_SERVER_NAME --resource-group $Env:RESOURCE_GROUP_NAME --enable-ad-only-auth --external-admin-principal-type User --external-admin-name $Env:ENTRA_ADMIN_NAME --external-admin-sid $(az ad signed-in-user show --query id --output tsv)
az sql db create --resource-group $Env:RESOURCE_GROUP_NAME --server $Env:SQL_SERVER_NAME --name $Env:DB_NAME --edition GeneralPurpose --compute-model Serverless --family Gen5 --capacity 2
```

Then, add the local IP address to the Azure SQL Database server firewall rules to allow your local machine to connect to the database for local testing later.

```azurepowershell
$Env:AZ_LOCAL_IP_ADDRESS = (Invoke-WebRequest https://whatismyip.akamai.com).Content
az sql server firewall-rule create --resource-group $Env:RESOURCE_GROUP_NAME --server $Env:SQL_SERVER_NAME --name AllowLocalIP --start-ip-address $Env:AZ_LOCAL_IP_ADDRESS --end-ip-address $Env:AZ_LOCAL_IP_ADDRESS
```

---

> [!NOTE]
> You create an Azure SQL server with SQL authentication disabled for security considerations. Only Microsoft Entra ID is used to authenticate to the server. If you need to enable SQL authentication, see [az sql server create](/cli/azure/sql/server#az-sql-server-create) for more information.

## Create a service connection in AKS with Service Connector

In this section, you create a service connection between the AKS cluster and the Azure SQL Database using Microsoft Entra Workload ID with Service Connector. This connection allows the AKS cluster to access the Azure SQL Database without using SQL authentication.

First, grant app **Azure Service Connector Resource Provider** permissions to the Application Gateway deployed before. This step is required to successfully create a service connection between the AKS cluster and the Azure SQL Database.

1. Go to the Azure portal and navigate to the resource group that you created earlier.
1. In the list of resources in the resource group, select the resource with the **Type** value of **Application gateway**.
1. Select **Access control (IAM)**. Then, expand **Add** and select **Add role assignment**.
1. In **Role** tab, select **Priviledged administrator roles**. Then, select **Contributor**. Select **Next**.
1. In **Members** tab, select **Select members**. Then, search for the **Azure Service Connector Resource Provider** app. Select the app and select **Select**. Select **Next**.
1. Select **Review + assign**. Wait for a few seconds for the role assignment to complete.

Then, run the following commands to create a connection between the AKS cluster and the SQL database using Microsoft Entra Workload ID with Service Connector. For more information, see [Create a service connection in AKS with Service Connector (preview)](/azure/service-connector/tutorial-python-aks-sql-database-connection-string?tabs=azure-cli&pivots=workload-id#create-a-service-connection-in-aks-with-service-connector-preview).

### [Bash](#tab/in-bash)

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
export AZURE_SQL_SERVER_RESOURCE_ID=$(az sql server show \
    --resource-group $RESOURCE_GROUP_NAME \
    --name $SQL_SERVER_NAME \
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

# Create a service connection between your AKS cluster and your SQL database using Microsoft Entra Workload ID
az aks connection create sql \
    --connection akssqlconn \
    --client-type java \
    --source-id $AKS_CLUSTER_RESOURCE_ID \
    --target-id $AZURE_SQL_SERVER_RESOURCE_ID/databases/$DB_NAME \
    --workload-identity $UAMI_RESOURCE_ID
```

### [PowerShell](#tab/in-powershell)

```azurepowershell
# Register the Service Connector and Kubernetes Configuration resource providers
az provider register --namespace Microsoft.ServiceLinker --wait
az provider register --namespace Microsoft.KubernetesConfiguration --wait

# Install the Service Connector passwordless extension
az extension add --name serviceconnector-passwordless --upgrade --allow-preview true

# Retrieve the AKS cluster and Azure SQL Server resource IDs
$Env:AKS_CLUSTER_RESOURCE_ID = $(az aks show --resource-group $Env:RESOURCE_GROUP_NAME --name $Env:CLUSTER_NAME --query id --output tsv)
$Env:AZURE_SQL_SERVER_RESOURCE_ID = $(az sql server show --resource-group $Env:RESOURCE_GROUP_NAME --name $Env:SQL_SERVER_NAME --query id --output tsv)

# Create a user-assigned managed identity used for workload identity
$Env:USER_ASSIGNED_IDENTITY_NAME = "workload-identity-uami"
az identity create --resource-group $Env:RESOURCE_GROUP_NAME --name $Env:USER_ASSIGNED_IDENTITY_NAME

# Retrieve the user-assigned managed identity resource ID
$Env:UAMI_RESOURCE_ID = $(az identity show --resource-group $Env:RESOURCE_GROUP_NAME --name $Env:USER_ASSIGNED_IDENTITY_NAME --query id --output tsv)

# Create a service connection between your AKS cluster and your SQL database using Microsoft Entra Workload ID
az aks connection create sql --connection akssqlconn --client-type java --source-id $Env:AKS_CLUSTER_RESOURCE_ID --target-id $Env:AZURE_SQL_SERVER_RESOURCE_ID/databases/$Env:DB_NAME --workload-identity $Env:UAMI_RESOURCE_ID
```

---

> [!NOTE]
> It's recommneded to use Microsoft Entra Workload ID for secure access to your Azure SQL Database without using SQL authentication. If you need to use SQL authentication, ignore the above steps in this section and use the username and password to connect to the Azure SQL Database.

### Get servcie account and secret created by Service Connector

To authenticate to the Azure SQL Database, you need to get the service account and secret created by Service Connector. Follow the section [Update your container](/azure/service-connector/tutorial-python-aks-sql-database-connection-string?pivots=workload-id&tabs=azure-cli#update-your-container). Take the option **Directly create a deployment using the YAML sample code snippet provided** and execute the following steps:

1. From the highlighted sections in the sample Kubernetes deployment YAML, copy the `serviceAccountName` and `secretRef.name` values, as shown in the following example:

   ```yaml
   serviceAccountName: <service-account-name>
   containers:
   - name: raw-linux
      envFrom:
         - secretRef:
            name: <secret-name>
   ```

1. Replace `<service-account-name>` and `<secret-name>` with the values you copied in the previous step to define the following environment variables:

   ### [Bash](#tab/in-bash)

   ```bash
   export SERVICE_ACCOUNT_NAME=<service-account-name>
   export SECRET_NAME=<secret-name>
   ```

   ### [PowerShell](#tab/in-powershell)

   ```powershell
   $Env:SERVICE_ACCOUNT_NAME = "<service-account-name>"
   $Env:SECRET_NAME = "<secret-name>"
   ```

    ---

   These values are used in the next section to deploy the Liberty application to the AKS cluster.

> [!NOTE]
> The secret created by Service Connector contains the `AZURE_SQL_CONNECTIONSTRING`, which is a password free connection string to the Azure SQL Database. See sample value from [User-assigned managed identity authentication](/azure/service-connector/how-to-integrate-sql-database?tabs=sql-me-id-java#user-assigned-managed-identity) for more information.

Now that you set up the database and AKS cluster, you can proceed to preparing AKS to host your Open Liberty application.

## Configure and deploy the sample application

Follow the steps in this section to deploy the sample application on the Liberty runtime. These steps use Maven.

### Check out the application

Clone the sample code for this article. The sample is on [GitHub](https://github.com/Azure-Samples/open-liberty-on-aks).

There are a few samples in the repository. This article uses *java-app/*. Run the following commands to get the sample:

#### [Bash](#tab/in-bash)

```bash
git clone https://github.com/Azure-Samples/open-liberty-on-aks.git
cd open-liberty-on-aks
export BASE_DIR=$PWD
git checkout 20240220
```

#### [PowerShell](#tab/in-powershell)

```powershell
git clone https://github.com/Azure-Samples/open-liberty-on-aks.git
cd open-liberty-on-aks
$env:BASE_DIR=$PWD.Path
git checkout 20240109
```

---

If you see a message about being in "detached HEAD" state, you can safely ignore it. The message just means that you checked out a tag.

Here's the file structure of the application:

```
java-app
├─ src/main/
│  ├─ aks/
│  │  ├─ db-secret.yaml
│  │  ├─ openlibertyapplication-agic.yaml
│  │  ├─ openlibertyapplication.yaml
│  │  ├─ webspherelibertyapplication-agic.yaml
│  │  ├─ webspherelibertyapplication.yaml
│  ├─ docker/
│  │  ├─ Dockerfile
│  │  ├─ Dockerfile-wlp
│  ├─ liberty/config/
│  │  ├─ server.xml
│  ├─ java/
│  ├─ resources/
│  ├─ webapp/
├─ pom.xml
```

The directories *java*, *resources*, and *webapp* contain the source code of the sample application. The code declares and uses a data source named `jdbc/JavaEECafeDB`.

In the *aks* directory, there are five deployment files:

* *db-secret.xml*: Use this file to create [Kubernetes Secrets](https://kubernetes.io/docs/concepts/configuration/secret/) with database connection credentials.
* *openlibertyapplication-agic.yaml*: Use this file to deploy the Open Liberty application with AGIC. This article assumes that you use this file.
* *openlibertyapplication.yaml*: Use this file if you want to deploy the Open Liberty application without AGIC.
* *webspherelibertyapplication-agic.yaml*: Use this file to deploy the WebSphere Liberty application with AGIC if you deployed WebSphere Liberty Operator [earlier in this article](#create-a-liberty-on-aks-deployment-using-the-portal).
* *webspherelibertyapplication.yaml*: Use this file to deploy the WebSphere Liberty application without AGIC if you deployed WebSphere Liberty Operator earlier in this article.

In the *docker* directory, there are two files to create the application image:

* *Dockerfile*: Use this file to build the application image with Open Liberty in this article.
* *Dockerfile-wlp*: Use this file to build the application image with WebSphere Liberty if you deployed WebSphere Liberty Operator earlier in this article.

In the *liberty/config* directory, you use the *server.xml* file to configure the database connection for the Open Liberty and WebSphere Liberty cluster.

### Build the project

Now that you have the necessary properties, you can build the application. The POM file for the project reads many variables from the environment. As part of the Maven build, these variables are used to populate values in the YAML files located in *src/main/aks*. You can do something similar for your application outside Maven if you prefer.

#### [Bash](#tab/in-bash)

```bash
cd $BASE_DIR/java-app
# The following variables are used for deployment file generation into the target.
export LOGIN_SERVER=<Azure-Container-Registry-Login-Server-URL>
export REGISTRY_NAME=<Azure-Container-Registry-name>
export USER_NAME=<Azure-Container-Registry-username>
export PASSWORD='<Azure-Container-Registry-password>'
export DB_SERVER_NAME=<server-name>.database.windows.net
export DB_NAME=<database-name>
export DB_USER=<server-admin-login>@<server-name>
export DB_PASSWORD='<server-admin-password>'
export INGRESS_TLS_SECRET=<ingress-TLS-secret-name>

mvn clean install
```

#### [PowerShell](#tab/in-powershell)

```powershell
cd $env:BASE_DIR\java-app

# The following variables are used for deployment file generation into the target.
$Env:LOGIN_SERVER="<Azure-Container-Registry-Login-Server-URL>"
$Env:REGISTRY_NAME="<Azure-Container-Registry-name>"
$Env:USER_NAME="<Azure-Container-Registry-username>"
$Env:PASSWORD="<Azure-Container-Registry-password>"
$Env:DB_SERVER_NAME="<server-name>.database.windows.net"
$Env:DB_NAME="<database-name>"
$Env:DB_USER="<server-admin-login>@<server-name>"
$Env:DB_PASSWORD="<server-admin-password>"
$Env:INGRESS_TLS_SECRET="<ingress-TLS-secret-name>"

mvn clean install
```

---

### (Optional) Test your project locally

Run and test the project locally before deploying to Azure. For convenience, this article uses `liberty-maven-plugin`. To learn more about `liberty-maven-plugin`, see the Open Liberty article [Building a web application with Maven](https://openliberty.io/guides/maven-intro.html).

For your application, you can do something similar by using any other mechanism, such as your local development environment. You can also consider using the `liberty:devc` option intended for development with containers. You can read more about `liberty:devc` in the [Open Liberty documentation](https://openliberty.io/docs/latest/development-mode.html#_container_support_for_dev_mode).

1. Start the application by using `liberty:run`. `liberty:run` also uses the environment variables that you defined earlier.

   #### [Bash](#tab/in-bash)

   ```bash
   cd $BASE_DIR/java-app
   mvn liberty:run
   ```

   #### [PowerShell](#tab/in-powershell)

   ```powershell
   cd $env:BASE_DIR\java-app
   mvn liberty:run
   ```

    ---

1. If the test is successful, a message similar to `[INFO] [AUDIT] CWWKZ0003I: The application javaee-cafe updated in 1.930 seconds` appears in the command output. Go to `http://localhost:9080/` in your browser and verify that the application is accessible and all functions are working.

1. Select <kbd>Ctrl</kbd>+<kbd>C</kbd> to stop.

### Build the image for AKS deployment

You can now run the `docker build` command to build the image:

#### [Bash](#tab/in-bash)

```bash
cd $BASE_DIR/java-app/target

docker buildx build --platform linux/amd64 -t javaee-cafe:v1 --pull --file=Dockerfile .
```

#### [PowerShell](#tab/in-powershell)

```powershell
cd $env:BASE_DIR\java-app\target

docker build -t javaee-cafe:v1 --pull --file=Dockerfile .
```

---

### (Optional) Test the Docker image locally

Use the following steps to test the Docker image locally before deploying to Azure:

1. Run the image by using the following command. This command uses the environment variables that you defined previously.

   #### [Bash](#tab/in-bash)

   ```bash
   docker run -it --rm -p 9080:9080 \
      -e DB_SERVER_NAME=${DB_SERVER_NAME} \
      -e DB_NAME=${DB_NAME} \
      -e DB_USER=${DB_USER} \
      -e DB_PASSWORD=${DB_PASSWORD} \
      javaee-cafe:v1
   ```

   #### [PowerShell](#tab/in-powershell)

   ```powershell
   docker run -it --rm -p 9080:9080 `
      -e DB_SERVER_NAME=${Env:DB_SERVER_NAME} `
      -e DB_NAME=${Env:DB_NAME} `
      -e DB_USER=${Env:DB_USER} `
      -e DB_PASSWORD=${Env:DB_PASSWORD} `
      javaee-cafe:v1
   ```

    ---

1. After the container starts, go to `http://localhost:9080/` in your browser to access the application.

1. Select <kbd>Ctrl</kbd>+<kbd>C</kbd> to stop.

### Upload the image to Azure Container Registry

Upload the built image to the Container Registry instance that you created in the offer:

#### [Bash](#tab/in-bash)

```bash
docker tag javaee-cafe:v1 ${LOGIN_SERVER}/javaee-cafe:v1
docker login -u ${USER_NAME} -p ${PASSWORD} ${LOGIN_SERVER}
docker push ${LOGIN_SERVER}/javaee-cafe:v1
```

#### [PowerShell](#tab/in-powershell)

```powershell
docker tag javaee-cafe:v1 ${Env:LOGIN_SERVER}/javaee-cafe:v1
docker login -u ${Env:USER_NAME} -p ${Env:PASSWORD} ${Env:LOGIN_SERVER}
docker push ${Env:LOGIN_SERVER}/javaee-cafe:v1
```

---

### Deploy and test the application

Use the following steps to deploy and test the application:

1. Connect to the AKS cluster.

   Paste the value of `cmdToConnectToCluster` into a shell and run the command.

1. Apply the database secret:

   #### [Bash](#tab/in-bash)

   ```bash
   cd $BASE_DIR/java-app/target
   kubectl apply -f db-secret.yaml
   ```

   #### [PowerShell](#tab/in-powershell)

   ```powershell
   cd $env:BASE_DIR\java-app\target
   kubectl apply -f db-secret.yaml
   ```

    ---

   The output is `secret/db-secret-sql created`.

1. Apply the deployment file:

   #### [Bash](#tab/in-bash)

   ```bash
   kubectl apply -f openlibertyapplication-agic.yaml
   ```

   #### [PowerShell](#tab/in-powershell)

   ```powershell
   kubectl apply -f openlibertyapplication-agic.yaml
   ```

    ---

1. Wait until all pods are restarted successfully by using the following command:

   #### [Bash](#tab/in-bash)

   ```bash
   kubectl get pods --watch
   ```

   #### [PowerShell](#tab/in-powershell)

   ```powershell
   kubectl get pods --watch
   ```

    ---   

   Output similar to the following example indicates that all the pods are running:

   ```output
   NAME                                       READY   STATUS    RESTARTS   AGE
   javaee-cafe-cluster-agic-67cdc95bc-2j2gr   1/1     Running   0          29s
   javaee-cafe-cluster-agic-67cdc95bc-fgtt8   1/1     Running   0          29s
   javaee-cafe-cluster-agic-67cdc95bc-h47qm   1/1     Running   0          29s
   ```

1. Verify the results:

   1. Get the address of the ingress resource deployed with the application:

      #### [Bash](#tab/in-bash)

      ```bash
      kubectl get ingress
      ```

      #### [PowerShell](#tab/in-powershell)

      ```powershell
      kubectl get ingress
      ```

       ---      

      Copy the value of `ADDRESS` from the output. This value is the front-end public IP address of the deployed Application Gateway instance.

   1. Go to `https://<ADDRESS>` to test the application. For your convenience, this shell command creates an environment variable whose value you can paste straight into the browser:

      #### [Bash](#tab/in-bash)

      ```bash
      export APP_URL=https://$(kubectl get ingress | grep javaee-cafe-cluster-agic-ingress | cut -d " " -f14)/
      echo $APP_URL
      ```

      #### [PowerShell](#tab/in-powershell)

      ```powershell
      $APP_URL = "https://$(kubectl get ingress | Select-String 'javaee-cafe-cluster-agic-ingress' | ForEach-Object { $_.Line.Split(' ')[13] })/"
      $APP_URL
      ```

       ---

      If the webpage doesn't render correctly or returns a `502 Bad Gateway` error, the app is still starting in the background. Wait for a few minutes and then try again.

## Clean up resources

To avoid Azure charges, you should clean up unnecessary resources. When you no longer need the cluster, use the [az group delete](/cli/azure/group#az-group-delete) command to remove the resource group, the container service, the container registry, the database, and all related resources:

### [Bash](#tab/in-bash)

```bash
az group delete --name $RESOURCE_GROUP_NAME --yes --no-wait
```

### [PowerShell](#tab/in-powershell)

```powershell
az group delete --name $Env:RESOURCE_GROUP_NAME --yes --no-wait
```

---

## Next steps

You can learn more from the following references:

* [Azure Kubernetes Service](https://azure.microsoft.com/free/services/kubernetes-service/)
* [Open Liberty](https://openliberty.io/)
* [Open Liberty Operator](https://github.com/OpenLiberty/open-liberty-operator)
* [Open Liberty server configuration](https://openliberty.io/docs/ref/config/)

For more information about deploying the IBM WebSphere family on Azure, see [What are solutions to run the WebSphere family of products on Azure?](/azure/developer/java/ee/websphere-family)
