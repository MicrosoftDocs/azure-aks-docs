---
title: "Deploy WebLogic Server on Azure Kubernetes Service using the Azure portal"
description: Shows how to quickly stand up WebLogic Server on Azure Kubernetes Service.
author: KarlErickson
ms.author: edburns
ms.topic: how-to
ms.date: 12/24/2024
ms.subservice: aks-developer
ms.custom: devx-track-java, devx-track-javaee, devx-track-javaee-wls, devx-track-javaee-wls-aks, devx-track-extended-java
---

# Deploy a Java application with WebLogic Server on an Azure Kubernetes Service (AKS) cluster

This article demonstrates how to:

- Run your Java application on Oracle WebLogic Server (WLS).
- Stand up a WebLogic Server cluster on AKS using an Azure Marketplace offer.
- Build an application Docker image that includes WebLogic Deploy Tooling (WDT) models.
- Deploy the containerized application to the WebLogic Server cluster on AKS with connection to Microsoft Azure SQL.

This article uses the [Azure Marketplace offer for WebLogic Server](https://aka.ms/wlsaks) to accelerate your journey to AKS. The offer automatically provisions several Azure resources, including the following resources:

- An Azure Container Registry instance
- An AKS cluster
- An Azure App Gateway Ingress Controller (AGIC) instance
- The WebLogic Kubernetes Operator
- A container image including the WebLogic runtime
- A WebLogic Server cluster without an application

Then, the article introduces building an image to update the WebLogic Server cluster. The image provides the application and WDT models.

If you prefer a less automated approach to deploying WebLogic on AKS, see the step-by-step guidance included in the official documentation from Oracle for [Azure Kubernetes Service](https://oracle.github.io/weblogic-kubernetes-operator/samples/azure-kubernetes-service/).

If you're interested in providing feedback or working closely on your migration scenarios with the engineering team developing WebLogic on AKS solutions, fill out this short [survey on WebLogic migration](https://aka.ms/wls-on-azure-survey) and include your contact information. The team of program managers, architects, and engineers will promptly get in touch with you to initiate close collaboration.

## Prerequisites

- [!INCLUDE [quickstarts-free-trial-note](~/reusable-content/ce-skilling/azure/includes/quickstarts-free-trial-note.md)]
- Ensure the Azure identity you use to sign in and complete this article has either the [Owner](/azure/role-based-access-control/built-in-roles#owner) role in the current subscription or the [Contributor](/azure/role-based-access-control/built-in-roles#contributor) and [User Access Administrator](/azure/role-based-access-control/built-in-roles#user-access-administrator) roles in the current subscription. For an overview of Azure roles, see [What is Azure role-based access control (Azure RBAC)?](/azure/role-based-access-control/overview) For details on the specific roles required by WLS on AKS, see [Azure built-in roles](/azure/role-based-access-control/built-in-roles).
- Have the credentials for an Oracle single sign-on (SSO) account. To create one, see [Create Your Oracle Account](https://aka.ms/wls-aks-create-sso-account).
- Accept the license terms for WebLogic Server.
  - Visit the [Oracle Container Registry](https://container-registry.oracle.com/) and sign in.
  - If you have a support entitlement, select **Middleware**, then search for and select **weblogic_cpu**.
  - If you don't have a support entitlement from Oracle, select **Middleware**, then search for and select **weblogic**.
  - Accept the license agreement.
  > [!NOTE]
  > Get a support entitlement from Oracle before going to production. Failure to do so results in running insecure images that are not patched for critical security flaws. For more information on Oracle's critical patch updates, see [Critical Patch Updates, Security Alerts and Bulletins](https://www.oracle.com/security-alerts/) from Oracle.
- Prepare a local machine with Unix-like operating system installed - for example, Ubuntu, Azure Linux, macOS, Windows Subsystem for Linux.
  - [Azure CLI](/cli/azure). Use `az --version` to test whether az works. This document was tested with version 2.55.1.
  - [kubectl](https://kubernetes.io/docs/tasks/tools/#kubectl). Use `kubectl version` to test whether kubectl works. This document was tested with version v1.21.2.
  - A Java Development Kit (JDK). The article directs you to install [Microsoft Build of OpenJDK 11](/java/openjdk/download). Ensure that your `JAVA_HOME` environment variable is set correctly in the shells in which you run the commands.
  - [Maven](https://maven.apache.org/download.cgi) 3.5.0 or higher.
  - Ensure that you have the zip/unzip utility installed. Use `zip/unzip -v` to test whether `zip/unzip` works.

## Create an Azure SQL Database

### [Passwordless (Recommended)](#tab/passwordless)

[!INCLUDE [create-azure-sql-database](includes/jakartaee/create-azure-sql-database-passwordless.md)]

Use the following command to get the connection string that you use in the next section:

```azurecli-interactive
export CONNECTION_STRING="jdbc:sqlserver://${AZURESQL_SERVER_NAME}.database.windows.net:1433;database=${DATABASE_NAME};encrypt=true;trustServerCertificate=false;hostNameInCertificate=*.database.windows.net;loginTimeout=30;"
echo ${CONNECTION_STRING}
```

### [Password](#tab/password)

[!INCLUDE [create-azure-sql-database](includes/jakartaee/create-azure-sql-database.md)]

Open the **Query editor** pane by following the steps in the [Query the database](/azure/azure-sql/database/single-database-create-quickstart#query-the-database) section of [Quickstart: Create a single database - Azure SQL Database](/azure/azure-sql/database/single-database-create-quickstart).

---

### Create a schema for the sample application

Select **New Query** and then, in the query editor, run the following query:

```sql
CREATE TABLE COFFEE (ID NUMERIC(19) NOT NULL, NAME VARCHAR(255) NULL, PRICE FLOAT(32) NULL, PRIMARY KEY (ID));
CREATE TABLE SEQUENCE (SEQ_NAME VARCHAR(50) NOT NULL, SEQ_COUNT NUMERIC(28) NULL, PRIMARY KEY (SEQ_NAME));
INSERT INTO SEQUENCE VALUES ('SEQ_GEN',0);
```

After a successful run, you should see the message **Query succeeded: Affected rows: 1**. If you don't see this message, troubleshoot and resolve the problem before proceeding.

You can proceed to deploy WLS on AKS offer.

## Deploy WebLogic Server on AKS

Use the following steps to find the WebLogic Server on AKS offer and fill out the **Basics** pane:

1. In the search bar at the top of the Azure portal, enter *weblogic*. In the autosuggested search results, in the **Marketplace** section, select **WebLogic Server on AKS**.

   :::image type="content" source="media/howto-deploy-java-wls-app/marketplace-search-results.png" alt-text="Screenshot of the Azure portal that shows WebLogic Server in the search results." lightbox="media/howto-deploy-java-wls-app/marketplace-search-results.png":::

   You can also go directly to the [WebLogic Server on AKS](https://aka.ms/wlsaks) offer.

1. On the offer page, select **Create**.
1. On the **Basics** pane, ensure the value shown in the **Subscription** field is the same one that you logged into in Azure. Make sure you have the roles listed in the prerequisites section for the subscription.

   :::image type="content" source="media/howto-deploy-java-wls-app/portal-start-experience.png" alt-text="Screenshot of the Azure portal that shows WebLogic Server on AKS." lightbox="media/howto-deploy-java-wls-app/portal-start-experience.png":::

1. In the **Resource group** field, select **Create new** and then fill in a value for the resource group. Because resource groups must be unique within a subscription, pick a unique name. An easy way to have unique names is to use a combination of your initials, today's date, and some identifier - for example, `ejb0723wls`.
1. Under **Instance details**, select the region for the deployment. For a list of Azure regions where AKS is available, see [AKS region availability](https://azure.microsoft.com/global-infrastructure/services/?products=kubernetes-service).
1. Under **Credentials for WebLogic**, leave the default value for **Username for WebLogic Administrator**.
1. Fill in `wlsAksCluster2022` for the **Password for WebLogic Administrator**. Use the same value for the confirmation and **Password for WebLogic Model encryption** fields.
1. Select **Next**.

Use the following steps start the deployment process:

1. Scroll to the section labeled **Provide an Oracle Single Sign-On (SSO) account**. Fill in your Oracle SSO credentials from the preconditions.

   :::image type="content" source="media/howto-deploy-java-wls-app/configure-single-sign-on.png" alt-text="Screenshot of the Azure portal that shows the configured SSO pane." lightbox="media/howto-deploy-java-wls-app/configure-single-sign-on.png":::

1. Make sure you note the steps in the info box starting with **Before moving forward, you must accept the Oracle Standard Terms and Restrictions.**

1. Depending on whether or not the Oracle SSO account has an Oracle support entitlement, select the appropriate option for **Select the type of WebLogic Server Images**. If the account has a support entitlement, select **Patched WebLogic Server Images**. Otherwise, select **General WebLogic Server Images**.

1. Leave the value in **Select desired combination of WebLogic Server...** at its default value. You have a broad range of choices for WebLogic Server, JDK, and OS version.

1. In the **Application** section, next to **Deploy an application?**, select **No**.

The following steps make it so the WebLogic Server admin console and the sample app are exposed to the public Internet with a built-in Application Gateway ingress add-on. For a more information, see [What is Application Gateway Ingress Controller?](/azure/application-gateway/ingress-controller-overview)

1. Select **Next** to see the **TLS/SSL** pane.
1. Select **Next** to see the **Load balancing** pane.
1. Next to **Load Balancing Options**, select **Application Gateway Ingress Controller**.

   :::image type="content" source="media/howto-deploy-java-wls-app/configure-load-balancing.png" alt-text="Screenshot of the Azure portal that shows the simplest possible load balancer configuration on the Create Oracle WebLogic Server on Azure Kubernetes Service page." lightbox="media/howto-deploy-java-wls-app/configure-load-balancing.png":::

1. Under the **Application Gateway Ingress Controller**, you should see all fields prepopulated with the defaults for **Virtual network** and **Subnet**. Leave the default values.
1. For **Create ingress for Administration Console**, select **Yes**.

   :::image type="content" source="media/howto-deploy-java-wls-app/configure-appgateway-ingress-admin-console.png" alt-text="Screenshot of the Azure portal that shows the Application Gateway Ingress Controller configuration on the Create Oracle WebLogic Server on Azure Kubernetes Service page." lightbox="media/howto-deploy-java-wls-app/configure-appgateway-ingress-admin-console.png":::

1. Select **Next** to see the **DNS** pane.
1. Select **Next** to see the **Database** pane.


### [Passwordless (Recommended)](#tab/passwordless)

Use the following steps to configure a database connection using a managed identity:

1. For **Connect to database?**, select **Yes**.
1. Under **Connection settings**, for **Choose database type**, open the dropdown menu and then select **Microsoft SQL Server (with support for passwordless connection)**.
1. For **JNDI Name**, input *jdbc/WebLogicCafeDB*.
1. For **DataSource Connection String**, input the connection string you obtained in last section.
1. Select **Use passwordless datasource connection**.
1. For **User assigned managed identity**, select the managed identity you created in previous step. In this example, its name is `myManagedIdentity`.
1. Select **Add**.

The **Connection settings** section should look like the following screenshot:

:::image type="content" source="media/howto-deploy-java-wls-app/azure-portal-azure-sql-configuration.png" alt-text="Screenshot of the Azure portal that shows the Database tab of the Create Oracle WebLogic Server on Azure Kubernetes Service page." lightbox="media/howto-deploy-java-wls-app/azure-portal-azure-sql-configuration.png":::

### [Password](#tab/password)

To configure a database connection using a password, follow the instructions shown later in this article.

---

Use the following steps to complete the deployment:

1. Select **Review + create**. Ensure that validation doesn't fail. If it fails, fix any validation problems, then select **Review + create** again.
1. Select **Create**.
1. Track the progress of the deployment on the **Deployment is in progress** page.

Depending on network conditions and other activity in your selected region, the deployment might take up to 50 minutes to complete.

> [!NOTE]
> If your organization requires you to deploy the workload within a corporate virtual network with no public IPs allowed, you can choose the internal Load Balancer service. To configure the internal Load Balancer service, use the following steps in the **Load balancing** tab:
>
> 1. For **Load Balancing Options**, select **Standard Load Balancer Service**.
> 1. Select **Use Internal Load Balancer**.
> 1. Add the following rows to the table:
>
>    | Service name prefix    | Target         | Port |
>    |------------------------|----------------|------|
>    | `wls-admin-internal`   | `admin-server` | 7001 |
>    | `wls-cluster-internal` | `cluster-1`    | 8001 |
>
> The **Load balancing** tab should look like the following screenshot:
>
> :::image type="content" source="media/howto-deploy-java-wls-app/azure-portal-internal-load-balancer.png" alt-text="Screenshot of the Azure portal that shows the Load balancing tab of the Create Oracle WebLogic Server on Azure Kubernetes Service page." lightbox="media/howto-deploy-java-wls-app/azure-portal-internal-load-balancer.png":::
>
> After the deployment, you can find the access URLs of the admin server and cluster from the output, labeled **adminConsoleExternalUrl** and **clusterExternalUrl**.

## Examine the deployment output

Use the steps in this section to verify that the deployment was successful.

If you navigated away from the **Deployment is in progress** page, the following steps show you how to get back to that page. If you're still on the page that shows **Your deployment is complete**, you can skip to step 5 after the next screenshot.

1. In the corner of any Azure portal page, select the hamburger menu and select **Resource groups**.
1. In the box with the text **Filter for any field**, enter the first few characters of the resource group you created previously. If you followed the recommended convention, enter your initials, then select the appropriate resource group.
1. In the navigation pane, in the **Settings** section, select **Deployments**. You see an ordered list of the deployments to this resource group, with the most recent one first.
1. Scroll to the oldest entry in this list. This entry corresponds to the deployment you started in the preceding section. Select the oldest deployment, as shown in the following screenshot.

   :::image type="content" source="media/howto-deploy-java-wls-app/resource-group-deployments.png" alt-text="Screenshot of the Azure portal that shows the resource group deployments list." lightbox="media/howto-deploy-java-wls-app/resource-group-deployments.png":::

1. In the navigation pane, select **Outputs**. This list shows the output values from the deployment. Useful information is included in the outputs.
1. The **adminConsoleExternalUrl** value is the fully qualified, public Internet visible link to the WebLogic Server admin console for this AKS cluster. Select the copy icon next to the field value to copy the link to your clipboard. Save this value aside for later.
1. The **clusterExternalUrl** value is the fully qualified, public Internet visible link to the sample app deployed in WebLogic Server on this AKS cluster. Select the copy icon next to the field value to copy the link to your clipboard. Save this value aside for later.
1. The **shellCmdtoOutputWlsImageModelYaml** value is the base64 string of the WDT model that is used to build the container image. Save this value aside for later.
1. The **shellCmdtoOutputWlsImageProperties** value is the base64 string of the WDT model properties that is used to build the container image. Save this value aside for later.
1. The **shellCmdtoConnectAks** value is the Azure CLI command to connect to this specific AKS cluster.

The other values in the outputs are beyond the scope of this article, but are explained in detail in the [WebLogic on AKS user guide](https://aka.ms/wls-aks-docs).

## Configure and deploy the sample application

The offer provisions the WebLogic Server cluster via [model in image](https://oracle.github.io/weblogic-kubernetes-operator/samples/domains/model-in-image/). Currently, the WebLogic Server cluster has no application deployed.

This section updates the WebLogic Server cluster by deploying a sample application using [auxiliary image](https://oracle.github.io/weblogic-kubernetes-operator/managing-domains/model-in-image/auxiliary-images/#using-docker-to-create-an-auxiliary-image).

### Check out the application

In this section, you clone the sample code for this guide. The sample is on GitHub in the [weblogic-on-azure](https://github.com/microsoft/weblogic-on-azure) repository in the *javaee/weblogic-cafe/* folder. Here's the file structure of the application.

```text
weblogic-cafe
├── pom.xml
└── src
    └── main
        ├── java
        │   └── cafe
        │       ├── model
        │       │   ├── CafeRepository.java
        │       │   └── entity
        │       │       └── Coffee.java
        │       └── web
        │           ├── rest
        │           │   └── CafeResource.java
        │           └── view
        │               └── Cafe.java
        ├── resources
        │   ├── META-INF
        │   │   └── persistence.xml
        │   └── cafe
        │       └── web
        │           ├── messages.properties
        │           └── messages_es.properties
        └── webapp
            ├── WEB-INF
            │   ├── beans.xml
            │   ├── faces-config.xml
            │   └── web.xml
            ├── index.xhtml
            └── resources
                └── components
                    └── inputPrice.xhtml
```

Use the following commands to clone the repository:

```bash
# cd <parent-directory-to-check-out-sample-code>
export BASE_DIR=$PWD

git clone --single-branch https://github.com/microsoft/weblogic-on-azure.git --branch 20240201 $BASE_DIR/weblogic-on-azure
```

If you see a message about being in "detached HEAD" state, this message is safe to ignore. It just means you checked out a tag.

Use the following command to build *javaee/weblogic-cafe/*:

```bash
mvn clean package --file $BASE_DIR/weblogic-on-azure/javaee/weblogic-cafe/pom.xml
```

The package should be successfully generated and located at *$BASE_DIR/weblogic-on-azure/javaee/weblogic-cafe/target/weblogic-cafe.war*. If you don't see the package, you must troubleshoot and resolve the issue before you continue.

### Use Azure Container Registry to create an auxiliary image

The steps in this section show you how to build an auxiliary image. This image includes the following components:

- The *Model in Image* model files
- Your application
- The Java Database Connectivity (JDBC) driver archive file
- The WebLogic Deploy Tooling installation

An *auxiliary image* is a Docker container image containing your app and configuration. The WebLogic Kubernetes Operator combines your auxiliary image with the `domain.spec.image` in the AKS cluster that contains the WebLogic Server, JDK, and operating system. For more information about auxiliary images, see [Auxiliary images](https://oracle.github.io/weblogic-kubernetes-operator/managing-domains/model-in-image/auxiliary-images/) in the Oracle documentation.

This section requires a Linux terminal with Azure CLI and kubectl installed.

Use the following steps to build the image:

1. Use the following commands to create a directory to stage the models and application:

   ```bash
   mkdir -p ${BASE_DIR}/mystaging/models
   cd ${BASE_DIR}/mystaging/models
   ```

1. Copy the **shellCmdtoOutputWlsImageModelYaml** value that you saved from the deployment outputs, paste it into the Bash window, and run the command. The command should look similar to the following example:

   ```bash
   echo -e IyBDb3B5cmlna...Cgo= | base64 -d > model.yaml
   ```

   This command produces a *${BASE_DIR}/mystaging/models/model.yaml* file with contents similar to the following example:

   ```yaml
   # Copyright (c) 2020, 2021, Oracle and/or its affiliates.
   # Licensed under the Universal Permissive License v 1.0 as shown at https://oss.oracle.com/licenses/upl.

   # Based on ./kubernetes/samples/scripts/create-weblogic-domain/model-in-image/model-images/model-in-image__WLS-v1/model.10.yaml
   # in https://github.com/oracle/weblogic-kubernetes-operator.

   domainInfo:
     AdminUserName: "@@SECRET:__weblogic-credentials__:username@@"
     AdminPassword: "@@SECRET:__weblogic-credentials__:password@@"
     ServerStartMode: "prod"

   topology:
     Name: "@@ENV:CUSTOM_DOMAIN_NAME@@"
     ProductionModeEnabled: true
     AdminServerName: "admin-server"
     Cluster:
       "cluster-1":
         DynamicServers:
           ServerTemplate: "cluster-1-template"
           ServerNamePrefix: "@@ENV:MANAGED_SERVER_PREFIX@@"
           DynamicClusterSize: "@@PROP:CLUSTER_SIZE@@"
           MaxDynamicClusterSize: "@@PROP:CLUSTER_SIZE@@"
           MinDynamicClusterSize: "0"
           CalculatedListenPorts: false
     Server:
       "admin-server":
         ListenPort: 7001
     ServerTemplate:
       "cluster-1-template":
         Cluster: "cluster-1"
         ListenPort: 8001
     SecurityConfiguration:
       NodeManagerUsername: "@@SECRET:__weblogic-credentials__:username@@"
       NodeManagerPasswordEncrypted: "@@SECRET:__weblogic-credentials__:password@@"

   resources:
     SelfTuning:
       MinThreadsConstraint:
         SampleMinThreads:
           Target: "cluster-1"
           Count: 1
       MaxThreadsConstraint:
         SampleMaxThreads:
           Target: "cluster-1"
           Count: 10
       WorkManager:
         SampleWM:
           Target: "cluster-1"
           MinThreadsConstraint: "SampleMinThreads"
           MaxThreadsConstraint: "SampleMaxThreads"
   ```

1. In a similar way, copy the **shellCmdtoOutputWlsImageProperties** value, paste it into the Bash window, and run the command. The command should look similar to the following example:

   ```bash
   echo -e IyBDb3B5cml...pFPTUK | base64 -d > model.properties
   ```

   This command produces a *${BASE_DIR}/mystaging/models/model.properties* file with contents similar to the following example:

   ```properties
   # Copyright (c) 2021, Oracle Corporation and/or its affiliates.
   # Licensed under the Universal Permissive License v 1.0 as shown at https://oss.oracle.com/licenses/upl.

   # Based on ./kubernetes/samples/scripts/create-weblogic-domain/model-in-image/model-images/model-in-image__WLS-v1/model.10.properties
   # in https://github.com/oracle/weblogic-kubernetes-operator.

   CLUSTER_SIZE=5
   ```

1. Use the following steps to create the application model file.

   1. Use the following commands to copy *weblogic-cafe.war* and save it to *wlsdeploy/applications*:

      ```bash
      mkdir -p ${BASE_DIR}/mystaging/models/wlsdeploy/applications
      cp $BASE_DIR/weblogic-on-azure/javaee/weblogic-cafe/target/weblogic-cafe.war ${BASE_DIR}/mystaging/models/wlsdeploy/applications/weblogic-cafe.war
      ```

   1. Use the following commands to create the application model file with the contents shown. Save the model file to *${BASE_DIR}/mystaging/models/appmodel.yaml*.

      ```bash
      cat <<EOF >appmodel.yaml
      appDeployments:
        Application:
          weblogic-cafe:
            SourcePath: 'wlsdeploy/applications/weblogic-cafe.war'
            ModuleType: ear
            Target: 'cluster-1'
      EOF
      ```
1. Use the following steps to configure the data source connection.

   ### [Passwordless (Recommended)](#tab/passwordless)

   1. Use the following steps to download and install the Microsoft SQL Server JDBC driver and Azure Identity Extension that enables database connections using Azure Managed Identity.

      1. Use the following commands to download and install Microsoft SQL Server JDBC driver to `wlsdeploy/externalJDBCLibraries`:

         ```bash
         export DRIVER_VERSION="10.2.1.jre8"
         export MSSQL_DRIVER_URL="https://repo.maven.apache.org/maven2/com/microsoft/sqlserver/mssql-jdbc/${DRIVER_VERSION}/mssql-jdbc-${DRIVER_VERSION}.jar"

         mkdir ${BASE_DIR}/mystaging/models/wlsdeploy/externalJDBCLibraries
         curl -m 120 -fL ${MSSQL_DRIVER_URL} -o ${BASE_DIR}/mystaging/models/wlsdeploy/externalJDBCLibraries/mssql-jdbc-${DRIVER_VERSION}.jar
         ```

      1. Use the following commands to install Azure Identity Extension to `wlsdeploy/classpathLibraries`:

         ```bash
         curl -LO https://github.com/oracle/weblogic-azure/raw/refs/heads/main/weblogic-azure-aks/src/main/resources/azure-identity-extensions.xml

         mvn dependency:copy-dependencies -f azure-identity-extensions.xml

         mkdir -p ${BASE_DIR}/mystaging/models/wlsdeploy/classpathLibraries/azureLibraries
         mkdir ${BASE_DIR}/mystaging/models/wlsdeploy/classpathLibraries/jackson
         # fix JARs conflict issue in GA images, put jackson libraries to PRE_CLASSPATH to upgrade the existing libs.
         mv target/dependency/jackson-annotations-*.jar ${BASE_DIR}/mystaging/models/wlsdeploy/classpathLibraries/jackson/
         mv target/dependency/jackson-core-*.jar ${BASE_DIR}/mystaging/models/wlsdeploy/classpathLibraries/jackson/
         mv target/dependency/jackson-databind-*.jar ${BASE_DIR}/mystaging/models/wlsdeploy/classpathLibraries/jackson/
         mv target/dependency/jackson-dataformat-xml-*.jar ${BASE_DIR}/mystaging/models/wlsdeploy/classpathLibraries/jackson/
         # Thoes jars will be appended to CLASSPATH
         mv target/dependency/*.jar ${BASE_DIR}/mystaging/models/wlsdeploy/classpathLibraries/azureLibraries/
         ```

      1. Use the following commands to clean up resources:

         ```bash
         rm target -f -r
         rm azure-identity-extensions.xml
         ```

   1. Connect to the AKS cluster by copying the **shellCmdtoConnectAks** value that you saved aside previously, pasting it into the Bash window, then running the command. The command should look similar to the following example:

      ```bash
      az account set --subscription <subscription>;
      az aks get-credentials \
          --resource-group <resource-group> \
          --name <name>
      ```

      You should see output similar to the following example. If you don't see this output, troubleshoot and resolve the problem before continuing.

      ```output
      Merged "<name>" as current context in /Users/<username>/.kube/config
      ```

   1. Export the database connection model and save it to *${BASE_DIR}/mystaging/models/dbmodel.yaml*. The following steps extract the database configuration model from the ConfigMap `sample-domain1-wdt-config-map`. The name follows the format `<domain-uid>-wdt-config-map`, where `<domain-uid>` is set during the offer deployment. If you modified the default value, replace it with your own domain UID.

      1. The data key is *\<db-secret-name>.yaml*. Use the following command to retrieve the database secret name:

         ```bash
         export WLS_DOMAIN_UID=sample-domain1
         export WLS_DOMAIN_NS=${WLS_DOMAIN_UID}-ns
         export DB_K8S_SECRET_NAME=$(kubectl get secret -n ${WLS_DOMAIN_NS} | grep "ds-secret" | awk '{print $1}')
         ```

      1. Next, extract the database model with this command:

         ```bash
         kubectl get configmap sample-domain1-wdt-config-map -n ${WLS_DOMAIN_NS} -o=jsonpath="{['data']['${DB_K8S_SECRET_NAME}\.yaml']}" >${BASE_DIR}/mystaging/models/dbmodel.yaml
         ```

      1. Finally, use the following command to verify the content of *dbmodel.yaml*.

         ```bash
         cat ${BASE_DIR}/mystaging/models/dbmodel.yaml
         ```

         The output of this command should resemble the following structure:

         ```yaml
         # Copyright (c) 2020, 2021, Oracle and/or its affiliates.
         # Licensed under the Universal Permissive License v 1.0 as shown at https://oss.oracle.com/licenses/upl.

         resources:
           JDBCSystemResource:
             jdbc/WebLogicCafeDB:
               Target: 'cluster-1'
               JdbcResource:
               JDBCDataSourceParams:
                  JNDIName: [
                     jdbc/WebLogicCafeDB
                  ]
                  GlobalTransactionsProtocol: OnePhaseCommit
               JDBCDriverParams:
                  DriverName: com.microsoft.sqlserver.jdbc.SQLServerDriver
                  URL: '@@SECRET:ds-secret-sqlserver-1727147748:url@@'
                  PasswordEncrypted: '@@SECRET:ds-secret-sqlserver-1727147748:password@@'
                  Properties:
                     user:
                     Value: '@@SECRET:ds-secret-sqlserver-1727147748:user@@'
               JDBCConnectionPoolParams:
                     TestTableName: SQL SELECT 1
                     TestConnectionsOnReserve: true
         ```

   ### [Password](#tab/password)

   1. Use the following commands to download and install Microsoft SQL Server JDBC driver to *wlsdeploy/externalJDBCLibraries*:

      ```bash
      export DRIVER_VERSION="10.2.1.jre8"
      export MSSQL_DRIVER_URL="https://repo.maven.apache.org/maven2/com/microsoft/sqlserver/mssql-jdbc/${DRIVER_VERSION}/mssql-jdbc-${DRIVER_VERSION}.jar"

      mkdir ${BASE_DIR}/mystaging/models/wlsdeploy/externalJDBCLibraries
      curl -m 120 -fL ${MSSQL_DRIVER_URL} -o ${BASE_DIR}/mystaging/models/wlsdeploy/externalJDBCLibraries/mssql-jdbc-${DRIVER_VERSION}.jar
      ```

   1. Next, use the following commands to create the database connection model file with the contents shown. Save the model file to *${BASE_DIR}/mystaging/models/dbmodel.yaml*. The model uses placeholders - secret `sqlserver-secret` - for database username, password, and URL. Make sure the following fields are set correctly. The following model names the resource with `jdbc/WebLogicCafeDB`.

      | Item Name         | Field                                                                                     | Value                                          |
      |-------------------|-------------------------------------------------------------------------------------------|------------------------------------------------|
      | JNDI name         | `resources.JDBCSystemResource.<resource-name>.JdbcResource.JDBCDataSourceParams.JNDIName` | `jdbc/WebLogicCafeDB`                          |
      | driver name       | `resources.JDBCSystemResource.<resource-name>.JDBCDriverParams.DriverName`                | `com.microsoft.sqlserver.jdbc.SQLServerDriver` |
      | database URL      | `resources.JDBCSystemResource.<resource-name>.JDBCDriverParams.URL`                       | `@@SECRET:sqlserver-secret:url@@`              |
      | database password | `resources.JDBCSystemResource.<resource-name>.JDBCDriverParams.PasswordEncrypted`         | `@@SECRET:sqlserver-secret:password@@`         |
      | database username | `resources.JDBCSystemResource.<resource-name>.JDBCDriverParams.Properties.user.Value`     | `'@@SECRET:sqlserver-secret:user@@'`           |

      ```bash
      cat <<EOF >dbmodel.yaml
      resources:
        JDBCSystemResource:
          jdbc/WebLogicCafeDB:
            Target: 'cluster-1'
            JdbcResource:
              JDBCDataSourceParams:
                JNDIName: [
                  jdbc/WebLogicCafeDB
                ]
                GlobalTransactionsProtocol: None
              JDBCDriverParams:
                DriverName: com.microsoft.sqlserver.jdbc.SQLServerDriver
                URL: '@@SECRET:sqlserver-secret:url@@'
                PasswordEncrypted: '@@SECRET:sqlserver-secret:password@@'
                Properties:
                  user:
                    Value: '@@SECRET:sqlserver-secret:user@@'
              JDBCConnectionPoolParams:
                TestTableName: SQL SELECT 1
                TestConnectionsOnReserve: true
      EOF
      ```

1. Use the following commands to create an archive file and then remove the *wlsdeploy* folder, which you don't need anymore:

   ```bash
   cd ${BASE_DIR}/mystaging/models
   zip -r archive.zip wlsdeploy

   rm -f -r wlsdeploy
   ```

1. Use the following commands to download and install [WebLogic Deploy Tooling](https://oracle.github.io/weblogic-deploy-tooling/) (WDT) in the staging directory and remove its *weblogic-deploy/bin/\*.cmd* files, which aren't used in UNIX environments:

   ```bash
   cd ${BASE_DIR}/mystaging
   curl -m 120 -fL https://github.com/oracle/weblogic-deploy-tooling/releases/latest/download/weblogic-deploy.zip -o weblogic-deploy.zip

   unzip weblogic-deploy.zip -d .
   rm ./weblogic-deploy/bin/*.cmd
   ```

1. Use the following command to clean up the WDT installer:

   ```bash
   rm weblogic-deploy.zip
   ```

1. Use the following commands to create a docker file:

   ```bash
   cd ${BASE_DIR}/mystaging
   cat <<EOF >Dockerfile
   FROM busybox
   ARG AUXILIARY_IMAGE_PATH=/auxiliary
   ARG USER=oracle
   ARG USERID=1000
   ARG GROUP=root
   ENV AUXILIARY_IMAGE_PATH=\${AUXILIARY_IMAGE_PATH}
   RUN adduser -D -u \${USERID} -G \$GROUP \$USER
   COPY --chown=\$USER:\$GROUP ./ \${AUXILIARY_IMAGE_PATH}/
   USER \$USER
   EOF
   ```

1. Run the `az acr build` command using *${BASE_DIR}/mystaging/Dockerfile*, as shown in the following example:

   ```bash
   export ACR_NAME=<value-from-clipboard>
   export IMAGE="wlsaks-auxiliary-image:1.0"
   ```

1. Use the following commands to double-check the staging files:

   ```bash
   cd ${BASE_DIR}/mystaging
   find -maxdepth 2 -type f -print
   ```

   These commands produce output similar to the following example:

   ```output
   ./models/model.properties
   ./models/model.yaml
   ./models/appmodel.yaml
   ./models/dbmodel.yaml
   ./models/archive.zip
   ./Dockerfile
   ./weblogic-deploy/VERSION.txt
   ./weblogic-deploy/LICENSE.txt
   ```

1. Build the image with `az acr build`, as shown in the following example:


   ```bash
   az acr build -t ${IMAGE} --build-arg AUXILIARY_IMAGE_PATH=/auxiliary -r ${ACR_NAME} --platform linux/amd64 .
   ```

   When you build the image successfully, the output looks similar to the following example:

   ```output
   ...
   Step 1/9 : FROM busybox
   latest: Pulling from library/busybox
   Digest: sha256:9ae97d36d26566ff84e8893c64a6dc4fe8ca6d1144bf5b87b2b85a32def253c7
   Status: Image is up to date for busybox:latest
   ---> 65ad0d468eb1
   Step 2/9 : ARG AUXILIARY_IMAGE_PATH=/auxiliary
   ---> Running in 1f8f4e82ccb6
   Removing intermediate container 1f8f4e82ccb6
   ---> 947fde618be9
   Step 3/9 : ARG USER=oracle
   ---> Running in dda021591e41
   Removing intermediate container dda021591e41
   ---> f43d84be4517
   Step 4/9 : ARG USERID=1000
   ---> Running in cac4df6dfd13
   Removing intermediate container cac4df6dfd13
   ---> e5513f426c74
   Step 5/9 : ARG GROUP=root
   ---> Running in 8fec1763270c
   Removing intermediate container 8fec1763270c
   ---> 9ef233dbe279
   Step 6/9 : ENV AUXILIARY_IMAGE_PATH=${AUXILIARY_IMAGE_PATH}
   ---> Running in b7754f58157a
   Removing intermediate container b7754f58157a
   ---> 4a26a97eb572
   Step 7/9 : RUN adduser -D -u ${USERID} -G $GROUP $USER
   ---> Running in b6c1f1a81af1
   Removing intermediate container b6c1f1a81af1
   ---> 97d3e5ad7540
   Step 8/9 : COPY --chown=$USER:$GROUP ./ ${AUXILIARY_IMAGE_PATH}/
   ---> 21088171876f
   Step 9/9 : USER $USER
   ---> Running in 825e0abc9f6a
   Removing intermediate container 825e0abc9f6a
   ---> b81d6430fcda
   Successfully built b81d6430fcda
   Successfully tagged wlsaksacru6jyly7kztoqu.azurecr.io/wlsaks-auxiliary-image:1.0
   2024/08/28 03:06:19 Successfully executed container: build
   2024/08/28 03:06:19 Executing step ID: push. Timeout(sec): 3600, Working directory: '', Network: ''
   2024/08/28 03:06:19 Pushing image: wlsaksacru6jyly7kztoqu.azurecr.io/wlsaks-auxiliary-image:1.0, attempt 1
   The push refers to repository [wlsaksacru6jyly7kztoqu.azurecr.io/wlsaks-auxiliary-image]
   ee589b3cda86: Preparing
   c1fd1adab3b9: Preparing
   d51af96cf93e: Preparing
   c1fd1adab3b9: Pushed
   d51af96cf93e: Pushed
   ee589b3cda86: Pushed
   1.0: digest: sha256:c813eb75576eb07a179c3cb4e70106ca7dd280f933ab33a2f6858de673b12eac size: 946
   2024/08/28 03:06:21 Successfully pushed image: wlsaksacru6jyly7kztoqu.azurecr.io/wlsaks-auxiliary-image:1.0
   2024/08/28 03:06:21 Step ID: build marked as successful (elapsed time in seconds: 8.780235)
   2024/08/28 03:06:21 Populating digests for step ID: build...
   2024/08/28 03:06:22 Successfully populated digests for step ID: build
   2024/08/28 03:06:22 Step ID: push marked as successful (elapsed time in seconds: 1.980158)
   2024/08/28 03:06:22 The following dependencies were found:
   2024/08/28 03:06:22
   - image:
      registry: wlsaksacru6jyly7kztoqu.azurecr.io
      repository: wlsaks-auxiliary-image
      tag: "1.0"
      digest: sha256:c813eb75576eb07a179c3cb4e70106ca7dd280f933ab33a2f6858de673b12eac
   runtime-dependency:
      registry: registry.hub.docker.com
      repository: library/busybox
      tag: latest
      digest: sha256:9ae97d36d26566ff84e8893c64a6dc4fe8ca6d1144bf5b87b2b85a32def253c7
   git: {}

   Run ID: ca1 was successful after 14s
   ```

   The image is pushed to ACR after a success build.

1. You can run `az acr repository show` to test whether the image is pushed to the remote repository successfully, as shown in the following example:

   ```bash
   az acr repository show --name ${ACR_NAME} --image ${IMAGE}
   ```

   This command should produce output similar to the following example:

   ```output
   {
      "changeableAttributes": {
         "deleteEnabled": true,
         "listEnabled": true,
         "readEnabled": true,
         "writeEnabled": true
      },
      "createdTime": "2024-01-24T06:14:19.4546321Z",
      "digest": "sha256:a1befbefd0181a06c6fe00848e76f1743c1fecba2b42a975e9504ba2aaae51ea",
      "lastUpdateTime": "2024-01-24T06:14:19.4546321Z",
      "name": "1.0",
      "quarantineState": "Passed",
      "signed": false
   }
   ```

### Apply the auxiliary image

In the previous steps, you created the auxiliary image including models and WDT. Apply the auxiliary image to the WebLogic Server cluster with the following steps.

#### [Passwordless (Recommended)](#tab/passwordless)

1. Apply the auxiliary image by patching the domain custom resource definition (CRD) using the `kubectl patch` command.

   The auxiliary image is defined in `spec.configuration.model.auxiliaryImages`, as shown in the following example:

   ```yaml
   spec:
     clusters:
     - name: sample-domain1-cluster-1
     configuration:
       model:
         auxiliaryImages:
         - image: wlsaksacrafvzeyyswhxek.azurecr.io/wlsaks-auxiliary-image:1.0
           imagePullPolicy: IfNotPresent
           sourceModelHome: /auxiliary/models
           sourceWDTInstallHome: /auxiliary/weblogic-deploy
   ```

   Use the following commands to increase the `restartVersion` value and use `kubectl patch` to apply the auxiliary image to the domain CRD using the definition shown:

   ```bash
   export VERSION=$(kubectl -n ${WLS_DOMAIN_NS} get domain ${WLS_DOMAIN_UID} -o=jsonpath='{.spec.restartVersion}' | tr -d "\"")
   export VERSION=$((VERSION+1))

   export ACR_LOGIN_SERVER=$(az acr show --name ${ACR_NAME} --query "loginServer" --output tsv)

   cat <<EOF >patch-file.json
   [
     {
       "op": "replace",
       "path": "/spec/restartVersion",
       "value": "${VERSION}"
     },
     {
       "op": "add",
       "path": "/spec/configuration/model/auxiliaryImages",
       "value": [{"image": "$ACR_LOGIN_SERVER/$IMAGE", "imagePullPolicy": "IfNotPresent", "sourceModelHome": "/auxiliary/models", "sourceWDTInstallHome": "/auxiliary/weblogic-deploy"}]
     },
     {
      "op": "remove",
      "path": "/spec/configuration/model/configMap"
     }
   ]
   EOF

   kubectl -n ${WLS_DOMAIN_NS} patch domain ${WLS_DOMAIN_UID} \
       --type=json \
       --patch-file patch-file.json
   ```

1. Because the database connection is configured in the auxiliary image, run the following command to remove the ConfigMap:

   ```bash
   kubectl delete configmap sample-domain1-wdt-config-map -n ${WLS_DOMAIN_NS}
   ```

#### [Password](#tab/password)

1. Connect to the AKS cluster by copying the **shellCmdtoConnectAks** value that you saved aside previously, pasting it into the Bash window, then running the command. The command should look similar to the following example:

   ```bash
   az account set --subscription <subscription>;
   az aks get-credentials \
       --resource-group <resource-group> \
       --name <name>
   ```

   You should see output similar to the following example. If you don't see this output, troubleshoot and resolve the problem before continuing.

   ```output
   Merged "<name>" as current context in /Users/<username>/.kube/config
   ```

1. Use the following steps to get values for the variables shown in the following table. You use these values to create the secret for the datasource connection.

   | Variable               | Description                                | Example                                                                                       |
   |------------------------|--------------------------------------------|-----------------------------------------------------------------------------------------------|
   | `DB_CONNECTION_STRING` | The connection string of the SQL server.   | `jdbc:sqlserver://server-name.database.windows.net:1433;database=wlsaksquickstart0125` |
   | `DB_USER`              | The username to sign in to the SQL server. | `welogic@sqlserverforwlsaks`                                                                  |
   | `DB_PASSWORD`          | The password to sign in to the SQL server. | `Secret123456`                                                                                |

   1. Visit the SQL database resource in the Azure portal.

   1. In the navigation pane, under **Settings**, select **Connection strings**.

   1. Select the **JDBC** tab.

   1. Select the copy icon to copy the connection string to the clipboard.

   1. For `DB_CONNECTION_STRING`, use the entire connection string, but replace the placeholder `{your_password_here}` with your database password.

   1. For `DB_USER`, use the portion of the connection string from `azureuser` up to but not including `;password={your_password_here}`.

   1. For `DB_PASSWORD`, use the value you entered when you created the database.

1. Use the following commands to create the Kubernetes Secret. This article uses the secret name `sqlserver-secret` for the secret of the datasource connection. If you use a different name, make sure the value is the same as the one in *dbmodel.yaml*.

   In the following commands, be sure to set the variables `DB_CONNECTION_STRING`, `DB_USER`, and `DB_PASSWORD` correctly by replacing the placeholder examples with the values described in the previous steps. To prevent the shell from interfering with them, enclose the value of the `DB_` variables in single quotes.

   ```bash
   export DB_CONNECTION_STRING='<example-jdbc:sqlserver://server-name.database.windows.net:1433;database=wlsaksquickstart0125>'
   export DB_USER='<example-welogic@sqlserverforwlsaks>'
   export DB_PASSWORD='<example-Secret123456>'
   export WLS_DOMAIN_NS=sample-domain1-ns
   export WLS_DOMAIN_UID=sample-domain1
   export SECRET_NAME=sqlserver-secret

   kubectl -n ${WLS_DOMAIN_NS} create secret generic \
       ${SECRET_NAME} \
       --from-literal=password="${DB_PASSWORD}" \
       --from-literal=url="${DB_CONNECTION_STRING}" \
       --from-literal=user="${DB_USER}"

   kubectl -n ${WLS_DOMAIN_NS} label secret \
       ${SECRET_NAME} \
       weblogic.domainUID=${WLS_DOMAIN_UID}
   ```

   You must see the following output before you continue. If you don't see this output, troubleshoot and resolve the problem before you continue.

   ```output
   secret/sqlserver-secret created
   secret/sqlserver-secret labeled
   ```

1. Apply the auxiliary image by patching the domain custom resource definition (CRD) using the `kubectl patch` command.

   The auxiliary image is defined in `spec.configuration.model.auxiliaryImages`, as shown in the following example.

   ```yaml
   spec:
     clusters:
     - name: sample-domain1-cluster-1
     configuration:
       model:
         auxiliaryImages:
         - image: wlsaksacrafvzeyyswhxek.azurecr.io/wlsaks-auxiliary-image:1.0
           imagePullPolicy: IfNotPresent
           sourceModelHome: /auxiliary/models
           sourceWDTInstallHome: /auxiliary/weblogic-deploy
   ```

   Use the following commands to increase the `restartVersion` value and use `kubectl patch` to apply the auxiliary image to the domain CRD using the definition shown:

   ```bash
   export VERSION=$(kubectl -n ${WLS_DOMAIN_NS} get domain ${WLS_DOMAIN_UID} -o=jsonpath='{.spec.restartVersion}' | tr -d "\"")
   export VERSION=$((VERSION+1))
   export ACR_LOGIN_SERVER=$(az acr show --name ${ACR_NAME} --query "loginServer" --output tsv)

   cat <<EOF >patch-file.json
   [
     {
       "op": "replace",
       "path": "/spec/restartVersion",
       "value": "${VERSION}"
     },
     {
       "op": "add",
       "path": "/spec/configuration/model/auxiliaryImages",
       "value": [{"image": "$ACR_LOGIN_SERVER/$IMAGE", "imagePullPolicy": "IfNotPresent", "sourceModelHome": "/auxiliary/models", "sourceWDTInstallHome": "/auxiliary/weblogic-deploy"}]
     },
     {
       "op": "add",
       "path": "/spec/configuration/secrets",
       "value": ["${SECRET_NAME}"]
     }
   ]
   EOF

   kubectl -n ${WLS_DOMAIN_NS} patch domain ${WLS_DOMAIN_UID} \
       --type=json \
       --patch-file patch-file.json
   ```

---

Before you proceed, wait until the following command produces the following output for the admin server and managed servers:

```bash
kubectl get pod -n ${WLS_DOMAIN_NS} -w
```

```output
NAME                             READY   STATUS    RESTARTS   AGE
sample-domain1-admin-server      1/1     Running   0          20m
sample-domain1-managed-server1   1/1     Running   0          19m
sample-domain1-managed-server2   1/1     Running   0          18m
```

It might take 5-10 minutes for the system to reach this state. The following list provides an overview of what's happening while you wait:

- You should see the `sample-domain1-introspector` running first. This software looks for changes to the domain custom resource so it can take the necessary actions on the Kubernetes cluster.
- When changes are detected, the domain introspector kills and starts new pods to roll out the changes.
- Next, you should see the `sample-domain1-admin-server` pod terminate and restart.
- Then, you should see the two managed servers terminate and restart.
- Only when all three pods show the `1/1 Running` state, is it ok to proceed.

## Verify the functionality of the deployment

Use the following steps to verify the functionality of the deployment by viewing the WebLogic Server admin console and the sample app:

1. Paste the **adminConsoleExternalUrl** value into the address bar of an Internet-connected web browser. You should see the familiar WebLogic Server admin console sign-in screen.

1. Sign in with the username `weblogic` and the password you entered when deploying WebLogic Server from the Azure portal. Recall that this value is `wlsAksCluster2022`.

1. In the **Domain Structure** box, select **Services**.

1. Under the **Services**, select **Data Sources**.

1. In the **Summary of JDBC Data Sources** panel, select **Monitoring**. Your screen should look similar to the following example. You find the state of data source is running on managed servers.

   :::image type="content" source="media/howto-deploy-java-wls-app/datasource-state.png" alt-text="Screenshot of data source state." border="false":::

1. In the **Domain Structure** box, select **Deployments**.

1. In the **Deployments** table, there should be one row. The name should be the same value as the `Application` value in your *appmodel.yaml* file. Select the name.

1. Select the **Testing** tab.

1. Select **weblogic-cafe**.

1. In the **Settings for weblogic-cafe** panel, select the **Testing** tab.

1. Expand the **+** icon next to **weblogic-cafe**. Your screen should look similar to the following example. In particular, you should see values similar to `http://sample-domain1-managed-server1:8001/weblogic-cafe/index.xhtml` in the **Test Point** column.

   :::image type="content" source="media/howto-deploy-java-wls-app/weblogic-cafe-deployment.png" alt-text="Screenshot of weblogic-cafe test points." border="false":::

   > [!NOTE]
   > The hyperlinks in the **Test Point** column are not selectable because we did not configure the admin console with the external URL on which it is running. This article shows the WebLogic Server admin console merely by way of demonstration. Don't use the WebLogic Server admin console for any durable configuration changes when running WebLogic Server on AKS. The cloud-native design of WebLogic Server on AKS requires that any durable configuration must be represented in the initial docker images or applied to the running AKS cluster using CI/CD techniques such as updating the model, as described in the [Oracle documentation](https://aka.ms/wls-aks-docs-update-model).

1. Understand the `context-path` value of the sample app you deployed. If you deployed the recommended sample app, the `context-path` is `weblogic-cafe`.
1. Construct a fully qualified URL for the sample app by appending the `context-path` to the **clusterExternalUrl** value. If you deployed the recommended sample app, the fully qualified URL should be something like `http://wlsgw202401-wls-aks-domain1.eastus.cloudapp.azure.com/weblogic-cafe/`.
1. Paste the fully qualified URL in an Internet-connected web browser. If you deployed the recommended sample app, you should see results similar to the following screenshot:

   :::image type="content" source="media/howto-deploy-java-wls-app/weblogic-cafe-app.png" alt-text="Screenshot of test web app." border="false":::

## Clean up resources

To avoid Azure charges, you should clean up unnecessary resources. When you no longer need the cluster, use the [az group delete](/cli/azure/group#az-group-delete) command. The following command removes the resource group, container service, container registry, database, and all related resources:

```azurecli
az group delete --name <resource-group-name> --yes --no-wait
az group delete --name <db-resource-group-name> --yes --no-wait
```

## Next steps

Learn more about running WebLogic Server on AKS or virtual machines by following these links:

* [WebLogic Server on AKS](/azure/virtual-machines/workloads/oracle/weblogic-aks?toc=/azure/java/ee/toc.json&bc=/azure/java/ee/breadcrumb/toc.json)
* [WebLogic Server on virtual machines](/azure/virtual-machines/workloads/oracle/oracle-weblogic?toc=/azure/java/ee/toc.json&bc=/azure/java/ee/breadcrumb/toc.json)

For more information about the Oracle WebLogic offers at Azure Marketplace, see [Oracle WebLogic Server on Azure](https://aka.ms/wls-contact-me). These offers are all _Bring-Your-Own-License_. They assume that you already have the appropriate licenses with Oracle and are properly licensed to run offers in Azure.
