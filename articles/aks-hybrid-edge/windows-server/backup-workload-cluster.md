---
title: Back up, restore workload clusters using Velero
description: Learn how to back up and restore workload clusters to Azure Blob Storage or MinIO using Velero in AKS.
author: davidsmatlak
ms.topic: how-to
ms.date: 09/01/2026
ms.author: davidsmatlak 
ms.custom: windows-server

# Intent: As an IT Pro, I want to learn how to perform a workload cluster backup or restore so I can recover from a failure or disaster.   
# Keyword: workload cluster backup restore Velero Azure Blob MinIO

---

# Back up and restore workload clusters by using Velero

[!INCLUDE [applies-to-azure stack-hci-and-windows-server-skus](../includes/aks-hci-applies-to-skus/aks-hybrid-applies-to-azure-stack-hci-windows-server-sku.md)]

This article describes how to install and use Velero to back up and restore workload and target clusters by using Azure Blob Storage or MinIO storage in AKS on Windows Server.

[Velero](https://velero.io/docs) is an open-source community standard tool for backing up and restoring Kubernetes cluster objects and persistent volumes. It supports various [storage providers](https://velero.io/docs/main/supported-providers/) to store its backups. If an AKS target Kubernetes cluster crashes and fails to recover, you can use a Velero backup to restore its contents and internal API objects to a new cluster.

If you don't want to store your backups in Azure Blob Storage, you can use MinIO with Velero. This article describes how to [install and configure Velero to use Azure Blob Storage](#install-velero-with-azure-blob-storage) or [install and configure Velero to use MinIO storage](#install-velero-with-minio-storage).

> [!NOTE]
> Velero doesn't officially support Microsoft Windows. In testing, the Velero team was able to back up stateless Windows applications only. `Restic` integration and backups of stateful applications or persistent volumes aren't supported.

## Prerequisites

Before you begin, make sure you have the following prerequisites:

- [Install the Azure CLI](/cli/azure/install-azure-cli).
- [Install `Chocolatey`](https://chocolatey.org/install). You can use `Chocolatey` to [install the Velero client](https://community.chocolatey.org/packages/velero), which includes the Velero CLI, on a Windows machine.

## Install Velero with Azure Blob Storage

The procedures in this section describe how to install Velero and use Azure Blob Storage for backups. If you don't want to store your backups in Azure, see [Install Velero with MiniO storage](#install-velero-with-minio-storage).

1. Open PowerShell as an administrator.

1. Sign in to Azure using the Azure CLI:

   ```azurecli
   az login --use-device-code   
   ```

1. Install the [Velero CLI](https://velero.io/docs/v1.9/basic-install/#install-the-cli) by running the following command:

   > [!NOTE]
   > The `--use-restic` flag isn't supported on Velero version 1.10 and later. The flag is only supported on version [1.9.x](https://github.com/vmware-tanzu/velero/releases/tag/v1.9.5).

   ```powershell
   choco install velero   
   ```

1. If needed, change to the Azure subscription you want to use for the backups.

   By default, Velero stores backups in the same Azure subscription as your VMs and disks and doesn't allow you to restore backups to a resource group in a different subscription. To enable backup and restore operations across subscriptions, specify a subscription to use for your backups. You can skip this step if you're already in the subscription you want to use for your backups.

   Switch to the subscription you want to use for your backups:

   1. Use the subscription name to find the subscription ID:

      ```azurecli
      $AZURE_BACKUP_SUBSCRIPTION_NAME="<NAME_OF_TARGET_SUBSCRIPTION>"
      $AZURE_BACKUP_SUBSCRIPTION_ID=$(az account list --query="[?name=='$AZURE_BACKUP_SUBSCRIPTION_NAME'].id | [0]" -o tsv)
      ```

   1. Then, change the subscription:

      ```azurecli
      az account set -s $AZURE_BACKUP_SUBSCRIPTION_ID
      ```

1. Create an Azure storage account and blob container.

   When you use Azure Blob Storage for backups, Velero requires a storage account and a blob container to store the backups. The following example shows the storage account created in a new **Velero_Backups** resource group.

   You must create the storage account with a globally unique ID that can be used in DNS. The sample script uses the `uuidgen` app to randomly generate a unique name. You can use any method as long as the name follows [Azure naming rules for storage accounts](/azure/storage/common/storage-account-overview#storage-account-name).

   The storage account is created with encryption at rest capabilities (using Microsoft managed keys) and is configured to only allow access over HTTPS connections.

   To create the storage account and blob container, follow these steps:

   1. Create a resource group for the backup storage account. Change directories to your preferred location, if needed, and run the following commands:

      ```azurecli
      $AZURE_BACKUP_RESOURCE_GROUP="Velero_Backups"
      az group create -n $AZURE_BACKUP_RESOURCE_GROUP --location WestUS
      ```

   1. Create the storage account:

      ```azurecli
      $AZURE_STORAGE_ACCOUNT_ID="<NAME_OF_ACCOUNT_TO_ASSIGN>"

      az storage account create --name $AZURE_STORAGE_ACCOUNT_ID --resource-group $AZURE_BACKUP_RESOURCE_GROUP --sku Standard_GRS --encryption-services blob --https-only true --kind BlobStorage --access-tier Hot
      ```

   1. Create a blob container:

      ```azurecli
      $BLOB_CONTAINER="velero"
      az storage container create -n $BLOB_CONTAINER --public-access off --account-name $AZURE_STORAGE_ACCOUNT_ID
      ```

      The example uses a blob container named `velero`. You can use a different name, preferably unique to a single Kubernetes cluster.

1. Create a service principal:

   1. Get the subscription ID and tenant ID for your Azure account:

      ```azurecli
      $AZURE_SUBSCRIPTION_ID=(az account list --query '[?isDefault].id' -o tsv)
      $AZURE_TENANT_ID=(az account list --query '[?isDefault].tenantId' -o tsv) 
      ```

   1. Create a service principal that has Contributor privileges.

      You can create a service principal with the **Contributor** role, or use a custom role:

      - **Contributor role:** The Contributor role grants subscription-wide access, so be sure protect this credential if you assign that role.
      - **Custom role:** If you need a more restrictive role, use a custom role.

      Assign the Contributor role:

      If you're using Velero to back up multiple clusters with multiple blob containers, you might want to create a unique username for each cluster instead of using the name `velero`.

      To create a service principal with the Contributor role, run the following command. Substitute your own subscription ID and optionally, your own service principal name. Microsoft Entra ID generates a secret for you:

      ```azurecli
      $AZURE_CLIENT_SECRET=(az ad sp create-for-rbac --name "velero" --role "Contributor" --query 'password' -o tsv --scopes  /subscriptions/$AZURE_SUBSCRIPTION_ID)
      ```

      Make these adjustments to the command if needed:

      - If you plan to use different subscriptions for your workload cluster and your Velero backup files, provide both subscription IDs, as in the following example:
  
        ```azurecli
        $AZURE_CLIENT_SECRET=(az ad sp create-for-rbac --name "velero" --role "Contributor" --query 'password' -o tsv --scopes  /subscriptions/$AZURE_SUBSCRIPTION_ID /subscriptions/$AZURE_BACKUP_SUBSCRIPTION_ID)
        ```

      - If you don't want to use `velero` as your service principal name, make sure the `--name` value you choose is unique in Microsoft Entra ID and doesn't conflict with other service principals or app registrations.

      > [!IMPORTANT]
      > The secret is only shown during this step, when the service principal is created. Be sure to make a note of the secret for use in future steps.

      If you want to enable the minimum resource provider actions, create a custom role, and assign that role to the service principal.

   1. Create a file named **azure-role.json** with following contents. Substitute your own custom role name and subscription ID:

      ```json
      {
          "Name": <CUSTOM_ROLE_NAME>,
          "Id": null,
          "IsCustom": true,
          "Description": "Velero related permissions to perform backups, restores and deletions",
          "Actions": [
              "Microsoft.Compute/disks/read",
              "Microsoft.Compute/disks/write",
              "Microsoft.Compute/disks/endGetAccess/action",
              "Microsoft.Compute/disks/beginGetAccess/action",
              "Microsoft.Compute/snapshots/read",
              "Microsoft.Compute/snapshots/write",
              "Microsoft.Compute/snapshots/delete",
              "Microsoft.Storage/storageAccounts/listkeys/action",
              "Microsoft.Storage/storageAccounts/regeneratekey/action",
              "Microsoft.Storage/storageAccounts/read"
          ],
          "NotActions": [],
          "AssignableScopes": [
            "<SUBSCRIPTION_ID>"
          ]
      }
      ```

   1. Create the custom role and service principal:

      ```azurecli
      az role definition create --role-definition azure-role.json
       $AZURE_CLIENT_SECRET=(az ad sp create-for-rbac --name "velero" --role "<CUSTOM_ROLE>" --query 'password' -o tsv --scopes  /subscriptions/$AZURE_SUBSCRIPTION_ID)
      ```

   For more information about creating custom roles, see [Set permissions for Velero](https://github.com/vmware-tanzu/velero-plugin-for-microsoft-azure#specify-role).

1. Get the service principal name, and assign that name to the **AZURE_CLIENT_ID** variable:

   ```azurecli
   $AZURE_CLIENT_ID=(az ad sp list --display-name "velero" --query '[0].appId' -o tsv)
   ```

   > [!NOTE]
   > Service principals expire. To find out when your new service principal expires, run this command: `az ad sp show --id $AZURE_CLIENT_ID`.

1. Create a file that contains the variables the Velero installation requires. The command looks similar to the following one:

   ```azurecli
   AZURE_SUBSCRIPTION_ID=${AZURE_SUBSCRIPTION_ID}
   AZURE_TENANT_ID=${AZURE_TENANT_ID}
   AZURE_CLIENT_ID=${AZURE_CLIENT_ID}
   AZURE_CLIENT_SECRET=${AZURE_CLIENT_SECRET}
   AZURE_RESOURCE_GROUP=${AZURE_BACKUP_RESOURCE_GROUP}
   AZURE_CLOUD_NAME=AzurePublicCloud" | Out-File -FilePath ./credentials-velero.txt
   ```

   > [!IMPORTANT]
   > Delete this file after you install Velero. The client secret is in plain text, which can pose a security risk.

   Before proceeding, verify that the file is properly formatted. The file name extension doesn't matter.
   - Remove any extra spaces or tabs.
   - Make sure the variable names are correct.

1. Install Velero on the cluster, and start the deployment. This procedure creates a namespace called `velero` and adds a deployment named `velero` to the namespace.

   1. Install Velero using the following command. Make sure to replace the placeholders in the example command with your own values:

      ```powershell
      velero install --provider azure --plugins velero/velero-plugin-for-microsoft-azure:v1.5.0 --bucket $BLOB_CONTAINER --secret-file ./credentials-velero.txt --backup-location-config resourceGroup=$AZURE_BACKUP_RESOURCE_GROUP,storageAccount=$AZURE_STORAGE_ACCOUNT_ID,subscriptionId=$AZURE_BACKUP_SUBSCRIPTION_ID --use-restic
      ```

      Set the following variables as needed:

      - The command installs the Microsoft Azure plugin, which must be compatible with the Velero CLI version you're using. The example command uses Microsoft Azure plugin version 1.5.0, which is compatible with the latest Velero CLI version, 1.9.0. To find out which version of the Microsoft Azure plugin to install with your Valero CLI version, see the [compatibility matrix](https://github.com/vmware-tanzu/velero-plugin-for-microsoft-azure#compatibility).

      - Be sure to include the `--use-restic` parameter to enable backup of Kubernetes volumes at the file system level using `Restic`. `Restic` can be used to back up any type of Kubernetes volume. By default, Velero supports taking snapshots of persistent volumes for Amazon EBS Volumes, Azure Managed Disks, and Google Persistent Disks. In AKS, Kubernetes volumes use Cluster Shared Volumes (CSVs) to store data. Hence, `Restic` is needed to enable persistent volume snapshots. AKS currently doesn't support volume snapshots.

      - `subscriptionId=$AZURE_BACKUP_SUBSCRIPTION_ID` is optional. You only need to include it if Velero and the workload cluster have different subscription IDs. If they use the same Azure subscription, you can remove the `subscriptionId` parameter, and the **credentials-velero.txt** file provides that information.

      The Velero service starts automatically on installation.

   1. Check whether the Velero service is running properly:

      ```powershell
      kubectl -n velero get pods
      kubectl logs deployment/velero -n velero
      ```

      The `get pods` command shows that the Velero pods are running.

## Install Velero with MinIO storage

The procedures in this section describe how to install Velero and use [MinIO](https://min.io/) storage for backups. If you prefer to use Azure Blob Storage for your backups, go to [Install Velero with Azure Blob Storage](#install-velero-with-azure-blob-storage).

If you don't want to store your backups in MinIO, go to [Set up Velero to use Azure Blob Storage](#install-velero-with-azure-blob-storage).

1. Install the Velero CLI by running the following command. [Install `Chocolately`](https://chocolatey.org/install) if you haven't already:

   ```powershell
   choco install velero
   ```

1. Install MinIO:

   1. Create a persistent volume to store the MinIO backup. The example creates a persistent volume in the default storage class in AKS, which already exists.  

      1. Create a YAML file named **minio-pvc-storage.yaml**, with the following contents:

         ```yaml
         kind: PersistentVolumeClaim
         apiVersion: v1
         metadata: 
         name: minio-pv-claim 
         spec: 
         storageClassName: default 
         accessModes: 
            - ReadWriteOnce 
         resources: 
            requests: 
               storage: 100Gi 
         ```

         Create the persistent volume by running this command:

         ```shell
         kubectl create -f minio-pvc-storage.yaml
         ```

      1. Create a deployment file, **minio-deployment.yaml**, for starting MinIO. Include the following contents. The deployment uses the persistent volume you created.

         ```yaml
         apiVersion: apps/v1
         kind: Deployment
         metadata:
         name: minio-deployment 
         spec: 
         selector: 
            matchLabels: 
               app: minio 
         strategy: 
            type: Recreate 
         template: 
            metadata: 
               labels: 
               app: minio 
            spec: 
               volumes: 
               - name: storage 
               persistentVolumeClaim: 
                  claimName: minio-pv-claim 
               containers: 
               - name: minio 
               image: minio/minio:latest 
               args:
               - server 
               - /storage 
               env: 
               - name: MINIO_ACCESS_KEY 
                 value: "<you can define this>" 
               - name: MINIO_SECRET_KEY 
                 value: "<you can define this>" 
               ports: 
               - containerPort: 9000 
                 hostPort: 9000 
               volumeMounts: 
               - name: storage  
                 mountPath: "/storage" 
         ```

         Then, create the deployment:

         ```shell
         kubectl create -f minio-deployment.yaml
         ```

   1. Create a Kubernetes service called **minio-service.yaml**. This service provides external IP addresses to the MinIO pod.

      Create a YAML file with the following settings to configure the service:

      ```yaml
      apiVersion: v1 
      kind: Service 
      metadata: 
      name: minio-service 
      spec: 
      type: LoadBalancer 
      ports: 
         - port: 9000 
           targetPort: 9000 
           protocol: TCP 
      selector: 
         app: minio 
      ```

      Then, create the service:

      ```shell
      kubectl create -f mino-service.yaml
      ```

   1. Get the MinIO pod's external IP address by running the following command. You use that address to install Velero:

      ```bash
      kubectl get svc
      ```

   1. To check whether MinIO is running, sign in to the IP address in a browser, or use the MinIO client, as described in this section. Install the MinIO client, and browse through the MinIO files.

      Download the MinIO client:

      ```powershell
      Invoke-WebRequest -Uri "https://dl.minio.io/client/mc/release/windows-amd64/mc.exe" -OutFile "C:\mc.exe
      ```

      Next, set an alias:

      ```powershell
      mc alias set minio http://10.10.77.6:9000 "minio_access_key" "minio_secret_key" --api s3v4
      ```

      Finally, browse through the MinIO installation:

      ```powershell
      mc ls minio
      ```

   1. Create a bucket to store Velero files. This bucket is used in the Velero installation.

      ```powershell
      mc mb minio/velero-backup
      ```

   1. Create a MinIO credentials file **minio.credentials** with the following contents:

      ```yaml
      [default] 
      aws_access_key_id=<minio_access_key> 
      aws_secret_access_key=<minio_secret_key> 
      ```

1. Install Velero:  

   ```azurecli
   velero install --provider aws --bucket velero-backup --secret-file .\minio.credentials --backup-location-config region=minio,s3ForcePathStyle=true,s3Url=http://10.10.77.6:9000 --plugins velero/velero-plugin-for-aws:v1.1.0 --use-restic
   ```

   Before you run this command, check the bucket name, your MinIO credentials, and the MinIO external IP address.

1. Check whether the Velero service is running properly:

   ```powershell
   kubectl -n velero get pods
   kubectl logs deployment/velero -n Velero
   ```

   The `get pods` command shows that the Velero pods are running.

## Back up a cluster

You can back up or restore all objects in your cluster, or you can filter objects by type, namespace, and/or label.

### Create a backup

Use the Velero `backup create` command to create backups to your chosen storage. The following examples use the `--default-volumes-to-restic` flag, which creates a snapshot of the persistent volumes. For other backup options, see the [Velero Backup Reference](https://velero.io/docs/v1.10/backup-reference/).

- On-demand backup of all namespaces in your cluster:

  ```powershell
  velero backup create <BACKUP-NAME> --default-volumes-to-restic
  ```

- On-demand backup of a single namespace in your cluster:

  ```powershell
  velero backup create <BACKUP-NAME> --include-namespaces <NAMESPACE1> --default-volumes-to-restic
  ```

- On-demand backup of multiple selected namespaces in your cluster:

  ```powershell
  velero backup create <BACKUP-NAME> --include-namespaces <NAMESPACE-1>, <NAMESPACE-2> --default-volumes-to-restic
  ```

### Check backup progress

- To check the progress of a backup, run this command:

  ```powershell
  velero backup describe <BACKUP-NAME>
  ```

- If you use Azure Blob Storage for your backups, you can view your backup in your Azure storage account under the **blob/container** that you created.

## Restore a cluster

To restore a cluster, you must create a new cluster to restore the old cluster to. You can't restore a cluster backup to an existing cluster.

The `restore` command lets you restore all objects and persistent volumes from a previously created backup. You can also restore only a filtered subset of objects and persistent volumes. For more backup options, see [Resource filtering](https://velero.io/docs/v1.9/resource-filtering/).

On the cluster to which you want to restore the backup (the *destination cluster*):

1. Deploy Velero by using the instructions in the preceding section. Use the same Azure credentials that you used for the source cluster.

1. Make sure the Velero backup object was created by running the following command. Velero resources are synchronized with the backup files in cloud storage.

   ```powershell
   velero backup describe <BACKUP-NAME>
   ```

1. After you confirm that the right backup (`BACKUP-NAME`) is present, restore all objects in the backup:

   ```powershell
   velero restore create --from-backup <BACKUP-NAME>
   ```

## Get help with Velero commands

To see all options associated with a specific Velero command, use the `--help` flag with the command. For example, `velero restore create --help` shows all options associated with the `velero restore create` command.

For example, to list all options of `velero restore`, run `velero restore --help`, which returns the following information:

  ```output
  velero restore [command]
  Available Commands:
  create      Create a restore
  delete      Delete restores
  describe    Describe restores
  get         Get restores
  logs        Get restore logs
  ```

## Uninstall Velero

To uninstall Velero from your cluster and remove all resources created by the Velero installation, run the following commands:

```powershell
kubectl delete namespace/velero clusterrolebinding/velero 
kubectl delete crds -l component=velero
```

## Next steps

- [Troubleshoot management and workload clusters](/azure/aks/aksarc/known-issues-workload-clusters)
- [Troubleshoot storage issues](/azure/aks/aksarc/known-issues-storage)
