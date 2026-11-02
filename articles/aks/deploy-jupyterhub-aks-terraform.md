---
title: Deploy JupyterHub on Azure Kubernetes Service with Terraform
description: Learn how to deploy the infrastructure required to run JupyterHub on AKS by using Terraform, the Zero to JupyterHub Helm chart, Azure Files, and Microsoft Entra Workload ID.
ms.topic: concept-article
ms.subservice: aks-storage
ms.date: 10/14/2026
author: codefinite-vri
ms.author: vritikanaik

# Customer intent: As a Kubernetes developer, I want to deploy jupyterhyb on Azure Kubernetes service by using Terraform.
---


# Deploy JupyterHub on Azure Kubernetes Service by using Terraform

JupyterHub gives teams a central, multiuser environment for running Jupyter notebooks. This article describes how to deploy the infrastructure required to run [JupyterHub](https://jupyter.org/hub) on Azure Kubernetes Service (AKS) by using Terraform and the official [Zero to JupyterHub](https://z2jh.jupyter.org/) Helm chart.

> [!IMPORTANT]
> This configuration is a sample. Review your organization's networking, identity, security, reliability, and data-protection requirements before using it in production. TLS isn't included in the sample configuration.

## Architecture

This configuration creates the following resources:

- An Azure storage account configured with zone-redundant storage (ZRS) and an Azure file share for shared user storage.
- An AKS cluster with a single node pool, Microsoft Entra Workload ID, and an OpenID Connect (OIDC) issuer.
- A Standard SKU public IP address for the JupyterHub proxy `LoadBalancer`. The address is created before JupyterHub so it can be used in the OAuth callback URL.

```text
Azure resource group (existing)
├── Azure storage account, ZRS (shared user storage)
│   └── Azure file share: shared (100 GiB)
└── AKS cluster
    ├── 3 nodes (Standard_D4ds_v6), availability zones 2 and 3
    ├── Azure CNI networking
    ├── Microsoft Entra Workload ID and OIDC issuer
    └── Public IP address (Standard SKU, in the node resource group)
        └── JupyterHub proxy LoadBalancer
```

The deployment uses the following storage configuration:

- **Per-user home directories**: Azure Files persistent volume claims (PVCs), provisioned automatically by the JupyterHub Helm chart through the `azurefile-csi-wi` StorageClass.
- **Shared storage**: An Azure file share mounted at `/home/jovyan/shared` in all user pods for datasets and course materials.

## Prerequisites

Before you begin, ensure you have:

- An Azure subscription with appropriate permissions.
- An existing resource group. The Terraform configuration references the resource group and doesn't create or delete it.
- [Terraform](https://developer.hashicorp.com/terraform/install) version 1.0 or later.
- [Azure CLI](/cli/azure/install-azure-cli) version 2.56 or later.
- [kubectl](https://kubernetes.io/docs/tasks/tools/) version 1.28 or later.
- [Helm](https://helm.sh/docs/intro/install/) version 3.5 or later.
- [just](https://github.com/casey/just), if you want to use the included `Justfile` recipes.
- An authenticated Azure CLI session. Run `az login`, or authenticate by using a service principal.

## Deploy by using the Justfile

Run the following commands from the directory that contains the Terraform configuration and `Justfile`:

```bash
# Initialize, validate, format, and plan the Terraform configuration.
just tf-workflow

# Deploy the infrastructure.
just tf-apply

# Get the AKS credentials.
just tf-get-aks-creds

# Display the OAuth callback URL required by the GitHub App.
terraform output jupyterhub_oauth_callback_url

# Deploy the namespace, storage resources, and JupyterHub.
GITHUB_CLIENT_ID="xxx" GITHUB_CLIENT_SECRET="yyy" just deploy-all

# Display the Terraform outputs.
just tf-output
```

Run `just` in the configuration directory to list all available recipes. Terraform recipes use the `tf-*` prefix. The `Justfile` also includes Kubernetes deployment recipes.

## Configure GitHub authentication

JupyterHub uses a GitHub App for OAuth authentication. You can create the app automatically or manually.

### Create the GitHub App automatically

```bash
# Generate the GitHub App creation page.
just create-github-app

# After GitHub redirects you with a code, convert the app.
just convert-github-app <CODE>

# Edit .env and set GITHUB_ADMIN_USERS and GITHUB_ALLOWED_USERS.
# Then deploy the Kubernetes resources and JupyterHub.
just deploy-all
```

Open `github-app-create.html` in a browser and select **Create GitHub App** before you run `just convert-github-app`.

### Create the GitHub App manually

1. Go to [GitHub Developer settings](https://github.com/settings/developers), and create a GitHub App.
1. For **Application name**, enter `JupyterHub AKS` or another name.
1. For **Homepage URL**, enter `http://<PUBLIC_IP>`.
1. For **Callback URL**, enter `http://<PUBLIC_IP>/hub/oauth_callback`.
1. Record the client ID and generate a client secret.
1. Save the values in the `.env` file:

   ```dotenv
   GITHUB_CLIENT_ID=xxx
   GITHUB_CLIENT_SECRET=yyy
   GITHUB_ADMIN_USERS=your-github-username
   GITHUB_ALLOWED_USERS=your-github-username
   ```

1. Deploy JupyterHub:

   ```bash
   just deploy-all
   ```

> [!CAUTION]
> Don't commit the `.env` file, client secret, Terraform state, or kubeconfig to source control. Store secrets in an approved secret-management system.

### Manage the GitHub App

Use these GitHub pages to manage the app:

- [GitHub Developer settings](https://github.com/settings/developers) to edit the app.
- [GitHub App installations](https://github.com/settings/installations) to manage the accounts where the app is installed.

If the public IP address changes, get the new callback URL and update it in the app settings:

```bash
terraform output jupyterhub_oauth_callback_url
```

### Access JupyterHub

Go to `http://<PUBLIC_IP>`, and then select **Sign in with GitHub**.

## Deploy manually

### Initialize Terraform

```bash
terraform init
```

This command downloads the required providers, including AzureRM 4.x and Random 3.x.

### Review the deployment plan

```bash
terraform plan
```

The included `terraform.tfvars` file contains sample values that allow Terraform to create a plan.

### Customize the variables

Edit `terraform.tfvars` for your environment:

```hcl
resource_group_name = "260300-ai-4"
location            = "eastus2"
aks_cluster_name    = "jhub-aks-260300-ai-4"
public_ip_name      = "jhub-ip-260300ai4"
```

### Deploy the infrastructure

```bash
terraform apply
```

Review the plan, and then enter `yes` to continue.

### Get the AKS credentials

```bash
az aks get-credentials \
  --resource-group $(terraform output -raw resource_group_name) \
  --name $(terraform output -raw aks_cluster_name) \
  --overwrite-existing
```

### Deploy the Kubernetes resources

```bash
GITHUB_CLIENT_ID="xxx" GITHUB_CLIENT_SECRET="yyy" just deploy-all
```

## Configuration file structure

```text
stateful-workloads-jupyterhub-terraform/
├── provider.tf
├── variables.tf
├── main.tf
├── kubernetes.tf
├── outputs.tf
├── terraform.tfvars
├── .gitignore
├── validate.sh
├── Justfile
├── k8s/
│   ├── namespace.yaml
│   ├── shared-storage.yaml.tpl
│   ├── storageclass-wi.yaml.tpl
│   ├── service-account.yaml.tpl
│   └── jupyterhub-values.yaml.tpl
├── PLAN.md
└── README.md
```

## Understand the storage configuration

### Shared storage

All users share an Azure Files mount at `/home/jovyan/shared`. The mount uses `ReadWriteMany` access and is intended for shared datasets, course materials, and notebooks. Don't use the shared directory for sensitive per-user data.

### Per-user storage

Each user gets a dedicated home-directory PVC with the following configuration:

- The JupyterHub Helm chart provisions the PVC automatically.
- The PVC uses the `azurefile-csi-wi` StorageClass and Azure Files SMB.
- `ReadWriteMany` access supports named servers and multiple pods per user.
- The default capacity is 10 GiB per user and can be changed in the Helm values.

> [!NOTE]
> Azure Files SMB mounts don't support POSIX file permissions in the same way as a native Linux file system. The configuration sets `JUPYTER_ALLOW_INSECURE_WRITES=1` to prevent Jupyter Server from failing when it checks permissions for runtime files.

## Configure workload identity for Azure Files

The configuration uses Microsoft Entra Workload ID so that storage account keys don't need to be stored in Kubernetes secrets. AKS Standard clusters must have workload identity and the OIDC issuer enabled before pods can use workload identity. For more information, see [Use Microsoft Entra Workload ID with AKS](workload-identity-overview.md).

The repository supports two SMB authentication modes. Token-based mounting is the default.

### Token-based SMB mount

- The CSI driver authenticates the SMB mount by using the workload identity token and Kerberos (`sec=krb5`).
- The cluster doesn't retrieve the storage account key.
- The StorageClass sets `mountWithWorkloadIdentityToken: "true"`.
- The configuration installs Azure Files CSI driver version 1.35.2 and disables the AKS-managed Azure Files CSI driver for this sample.
- The storage account must have Microsoft Entra Kerberos enabled for Azure Files.
- The workload identity requires the **Storage File Data SMB MI Admin** role.

### Key-retrieval SMB mount

- The CSI driver uses the workload identity to call `listKeys` at mount time, and then mounts the share by using the storage account key.
- The key is held in driver memory and isn't persisted to a Kubernetes secret.
- The workload identity requires the **Storage Account Contributor** role.
- Use this mode if your CSI driver or environment doesn't support token-based SMB mounting.

### Select an authentication mode

| Configuration | Effect |
|---|---|
| `STORAGE_AUTH_MODE=token` | Default. Adds `mountWithWorkloadIdentityToken: "true"` to the StorageClass. |
| `STORAGE_AUTH_MODE=key` | Omits the parameter and uses key retrieval at mount time. |

Set the mode in `.env`:

```bash
STORAGE_AUTH_MODE=token
# STORAGE_AUTH_MODE=key
```

Or specify it when you create the StorageClass:

```bash
STORAGE_AUTH_MODE=key just create-storageclass
```

> [!NOTE]
> StorageClass parameters are immutable. The `create-storageclass` recipe deletes and recreates the StorageClass when you switch modes. Existing persistent volumes keep their original mount parameters.

### Required Azure roles

| Identity | Role | Purpose |
|---|---|---|
| AKS kubelet identity | Storage Account Contributor | Allows the CSI controller to create and delete file shares during provisioning. |
| Workload managed identity | Storage Account Contributor | Supports dynamic provisioning and key-retrieval mounting. |
| Workload managed identity | Storage File Data SMB MI Admin | Supports the default token-based SMB mount. |

> [!IMPORTANT]
> The CSI controller uses the AKS kubelet identity for provisioning. The `clientID` value in the StorageClass controls mount-time authentication. Assign the required roles to both identities at the appropriate scope.

For the upstream implementation details, see [Mount Azure Files by using workload identity](https://github.com/kubernetes-sigs/azurefile-csi-driver/blob/master/docs/workload-identity-static-pv-mount.md).

## Configure the reclaim policy

The `azurefile-csi-wi` StorageClass uses `Retain` by default. When a PVC is deleted, the persistent volume remains in the `Released` state and the underlying Azure file share isn't deleted.

Set a different policy in `.env`:

```bash
STORAGE_RECLAIM_POLICY=Retain
# STORAGE_RECLAIM_POLICY=Delete
```

Or specify it when you create the StorageClass:

```bash
STORAGE_RECLAIM_POLICY=Delete just create-storageclass
```

| Policy | When to use | Trade-off |
|---|---|---|
| **Retain** | Production or teaching environments where user data must survive accidental PVC deletion or Helm removal. | Orphaned `pvc-<uuid>` shares must be managed manually. |
| **Delete** | Ephemeral development, test, or continuous integration environments. | Deleting the PVC permanently deletes its dynamically provisioned share. |

The reclaim policy is immutable on an existing StorageClass. The `create-storageclass` recipe deletes and recreates the StorageClass when you switch policies. Existing persistent volumes retain the policy that was set when they were provisioned. To update an individual persistent volume, run:

```bash
kubectl patch pv <name> -p '{"spec":{"persistentVolumeReclaimPolicy":"Retain"}}'
```

The Terraform-managed `shared` file share is independent of this setting because Terraform manages its lifecycle.

## Named servers and idle culling

Users can run up to three notebook servers at the same time. Named servers share the user's Azure Files home-directory PVC and can be managed from the JupyterHub control panel. Change the limit through `named_server_limit_per_user` in the Helm values.

Inactive notebook servers are stopped after one hour to reduce resource consumption.

## View deployment outputs

```bash
# Display all outputs.
terraform output

# Display specific outputs.
terraform output public_ip_address
terraform output jupyterhub_oauth_callback_url

# Write the sensitive kubeconfig output.
terraform output -raw aks_kube_config > ~/.kube/config
```

Important outputs include:

- `public_ip_address`: The IP address used to access JupyterHub.
- `jupyterhub_url`: The complete JupyterHub URL.
- `jupyterhub_oauth_callback_url`: The callback URL used to register the GitHub App.
- `storage_account_name`: The storage account that contains the shared Azure file share.
- `aks_cluster_name`: The AKS cluster name used for `kubectl` access.

## Configure TLS

This configuration doesn't include TLS. For HTTPS, configure a domain name and use the [AKS application routing add-on](app-routing.md) with Azure DNS:

```bash
az aks approuting enable \
  --name <cluster-name> \
  --resource-group <resource-group>
```

> [!IMPORTANT]
> Don't use plain HTTP for a production deployment or transmit OAuth credentials over an unencrypted connection. Configure HTTPS and update the GitHub App homepage and callback URLs to use `https://`.

## Clean up resources

Remove the Kubernetes resources before destroying the Terraform-managed infrastructure:

```bash
just teardown
terraform destroy
```

> [!WARNING]
> Destroying the deployment can permanently delete resources and user data. Review retained persistent volumes, Azure file shares, and Terraform's planned deletions before you continue.

## Troubleshoot

### Terraform provider initialization fails

Upgrade the initialized providers:

```bash
terraform init -upgrade
```

### The subscription has insufficient VM quota

Use the repository's quota-check recipe:

```bash
cd ../az && just az-quota-check
```

### JupyterHub pods don't start

```bash
just pods
just events
just logs <pod-name>
```

### A server doesn't respond within 30 seconds

Azure Files PVC provisioning can take longer during the first sign-in. The sample sets the spawn timeout to 120 seconds. If the deployment still times out, increase `KubeSpawner.http_timeout` and `KubeSpawner.start_timeout` in the Helm values.

### A notebook crashes with a secure-file permissions error

Azure Files SMB doesn't provide native POSIX permission semantics. Jupyter Server might report an error similar to:

```text
RuntimeError: Permissions assignment failed for secure file:
'/home/jovyan/.local/share/jupyter/runtime/jpserver-7.json'.
Got '0o677' instead of '0o0600'.
```

The sample Helm values set `JUPYTER_ALLOW_INSECURE_WRITES` to `1`. If the error occurs, confirm that the environment variable is present in the single-user container.

### GitHub reports an OAuth callback error

Get the configured callback URL and verify that it exactly matches the callback URL in the GitHub App settings:

```bash
terraform output jupyterhub_oauth_callback_url
```

### The VM size isn't available in the selected zones

Verify the availability of the VM size in the selected region:

```bash
az vm list-skus \
  --location eastus2 \
  --size Standard_D4ds_v6 \
  --output table
```

## Related content

- [Zero to JupyterHub with Kubernetes](https://z2jh.jupyter.org/)
- [JupyterHub Helm chart](https://jupyterhub.github.io/helm-chart/)
- [Use Microsoft Entra Workload ID with AKS](workload-identity-overview.md)
- [Use Azure Files for Azure Kubernetes workloads](/azure/storage/files/azure-kubernetes-service-workloads)
- [Use CSI storage drivers on AKS](csi-storage-drivers.md)
- [AzureRM provider documentation](https://registry.terraform.io/providers/hashicorp/azurerm/latest/docs)
