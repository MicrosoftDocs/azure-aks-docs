---
title: Prepare a flex node host and identity (preview)
description: Learn how to prepare a Linux host, configure its Azure identity, and grant access to an AKS cluster before attachment.
ms.topic: how-to
ms.date: 09/22/2026
author: leslielin-5
ms.author: leslielin
ms.subservice: aks-nodes
ms.service: azure-kubernetes-service
ai-usage: ai-assisted
# Customer intent: "As a platform engineer, I want to prepare a Linux host and its Azure identity before I attach it as a flex node."
---

# Prepare a flex node host and identity (preview)

[!INCLUDE [preview features callout](~/reusable-content/ce-skilling/azure/includes/aks/includes/preview/preview-callout.md)]

Before you attach a Linux host as a flex node, prepare the host, configure the identity you selected during planning, and grant that identity access to the Azure Kubernetes Service (AKS) cluster.

In this article, you:

- Review the host requirements, and then provision or select the Linux host and its Azure identity.
- Prepare and inspect the host, and record the values used by the attachment workflow.
- Assign the identity access at the AKS cluster scope, and verify that identity.

Run the management commands in this article in a Linux-compatible Bash environment that has the required tools and network access. This article calls that environment your **Bash environment**. The separate machine that joins the cluster is the **flex node host**; run commands there only when a step explicitly directs you to.

## Before you begin

- Complete [Configure networking and create a flex node pool in AKS](./configure-flex-nodes-networking.md).
- Review [Identity and access concepts for flex nodes](./flex-nodes-identity-access-concepts.md) and select one identity option.
- Use an Azure account that can inspect the host resource and create a role assignment at the AKS cluster scope. `Role Based Access Control Administrator` and `User Access Administrator` are examples of roles that can create the assignment.
- Install Azure CLI and an OpenSSH client in your Bash environment.
- Prepare an SSH key pair accepted by the host.

## Load the deployment environment

Start a new Bash session, identify the environment file from the planning article, and load it. Replace `<deployment-name>` with your deployment label.

```bash
export FLEXNODE_DEPLOYMENT="<deployment-name>"
export FLEXNODE_ENV_FILE="${HOME}/.config/aks-flexnode/${FLEXNODE_DEPLOYMENT}.env"
test -s "${FLEXNODE_ENV_FILE}"
source "${FLEXNODE_ENV_FILE}"
```

The environment file supplies the shared deployment values that this article reads, including `WORK_DIR`, the directory in your Bash environment where this article stores downloads and generated files. By default, `WORK_DIR` is `~/.local/share/aksflexnode/<deployment-name>`. The article derives any other variables that it needs. If you haven't created the environment file yet, complete [Plan your flex nodes deployment](./plan-flex-nodes-deployment.md) first.

If the file isn't found or can't be loaded, stop and return to the planning article before you continue.

Set the active subscription and confirm the selected cluster:

```azurecli
az account set --subscription "${SUBSCRIPTION_ID}"

az aks show \
    --resource-group "${RESOURCE_GROUP}" \
    --name "${CLUSTER_NAME}" \
    --query "{Name:name,ResourceId:id,ProvisioningState:provisioningState}" \
    --output table
```

Continue when the resource ID matches `AKS_RESOURCE_ID` and the provisioning state is `Succeeded`.

## 1. Review the host requirements

Use a dedicated host that meets the following requirements:

- Ubuntu 24.04 LTS or Azure Linux 3 on AMD64 or ARM64.
- A unique host name that is a valid DNS subdomain name. The agent converts it to lowercase when it registers the node.
- At least four vCPUs and at least 8 GiB free under `/var/lib`.
- An SSH account with root or passwordless `sudo` access on the host.
- Network access to the AKS API server, Azure Resource Manager, Microsoft Entra ID, the selected flex node release and artifact mirror, and the required container registries.
- Existing Layer 3 connectivity between the flex node host network and the AKS-managed node network. The host and AKS cluster don't have to be in the same Azure region.

Your Bash environment must also be able to connect to the flex node host through SSH. A public IP address isn't required when you have another approved management path.

## 2. Provision or select the host and identity

Complete only the section for the identity option selected in [Identity and access concepts for flex nodes](./flex-nodes-identity-access-concepts.md). Don't configure more than one durable Azure identity mode for the same host.

> [!TIP]
> **Connecting a machine outside Azure?** Use an [Azure Arc managed identity](#use-an-azure-arc-managed-identity) if the machine is already Arc-enabled, or use a [service principal](#use-a-service-principal). Use [Azure VM managed identity](#use-an-azure-virtual-machine-managed-identity) only when the flex node host is an Azure VM.

Set the SSH key paths used by every identity option:

```bash
export SSH_PRIVATE_KEY_PATH="<path-to-private-key>"
export SSH_PUBLIC_KEY_PATH="<path-to-public-key>"
```

Each identity option also establishes two host addresses. `FLEX_HOST_SSH_TARGET` is the address used by your Bash environment. `FLEX_HOST_PRIVATE_IP` is the host address reachable from the AKS-managed node network. Confirm with your network administrator that `FLEX_HOST_PRIVATE_IP` belongs to `FLEX_HOST_SUBNET_CIDR` and is the address reachable from the AKS-managed node network. Don't use a separate public or management-only address as the flex node address.

### Use an Azure Arc managed identity

Use this option for a host that's already connected to Azure Arc. If necessary, follow [Connect hybrid machines with Azure Arc-enabled servers](/azure/azure-arc/servers/learn/quick-enable-hybrid-vm).

Set the Arc resource values and the host addresses:

```bash
export ARC_RESOURCE_GROUP="<arc-machine-resource-group>"
export ARC_MACHINE_NAME="<arc-machine-name>"
export FLEX_HOST_SSH_TARGET="<admin-user>@<reachable-host-address>"
export FLEX_HOST_PRIVATE_IP="<private-ip-reachable-from-aks>"
```

Retrieve the resource ID, connection status, and principal object ID:

```azurecli
ARC_RESOURCE_ID="/subscriptions/${SUBSCRIPTION_ID}/resourceGroups/${ARC_RESOURCE_GROUP}/providers/Microsoft.HybridCompute/machines/${ARC_MACHINE_NAME}"
export ARC_RESOURCE_ID

HOST_PRINCIPAL_OBJECT_ID="$(az resource show \
    --ids "${ARC_RESOURCE_ID}" \
    --query identity.principalId \
    --output tsv)"
export HOST_PRINCIPAL_OBJECT_ID

az resource show \
    --ids "${ARC_RESOURCE_ID}" \
    --query "{Name:name,Status:properties.status,IdentityType:identity.type,PrincipalId:identity.principalId}" \
    --output yaml
```

Continue when **Status** is `Connected` and **PrincipalId** is populated.

Verify the Connected Machine agent and Hybrid Instance Metadata Service on the host:

```bash
ssh -i "${SSH_PRIVATE_KEY_PATH}" "${FLEX_HOST_SSH_TARGET}" \
    'sudo azcmagent show && systemctl is-active himdsd'
```

Confirm that `azcmagent show` reports the same subscription ID, resource group, and machine name as `ARC_RESOURCE_ID`, `ARC_RESOURCE_GROUP`, and `ARC_MACHINE_NAME`. Also confirm that `himdsd` is active. If the resource doesn't match, stop and correct the Arc resource values before assigning access.

Record the Arc and identity values:

```bash
set_flexnode_env ARC_RESOURCE_GROUP "${ARC_RESOURCE_GROUP}"
set_flexnode_env ARC_MACHINE_NAME "${ARC_MACHINE_NAME}"
set_flexnode_env ARC_RESOURCE_ID "${ARC_RESOURCE_ID}"
set_flexnode_env FLEX_HOST_SSH_TARGET "${FLEX_HOST_SSH_TARGET}"
set_flexnode_env FLEX_HOST_PRIVATE_IP "${FLEX_HOST_PRIVATE_IP}"
set_flexnode_env HOST_PRINCIPAL_OBJECT_ID "${HOST_PRINCIPAL_OBJECT_ID}"
set_flexnode_env HOST_IDENTITY_CLIENT_ID ""
```

### Use a service principal

Use this option for another supported virtual machine or bare-metal host. Prefer a certificate credential over a long-lived client secret. The following steps create a dedicated application and service principal with a self-signed certificate for evaluation. They don't create a client secret or assign an Azure role. You grant access to the target AKS cluster in step 4.

Before you continue:

- Install OpenSSL in your Bash environment, and use an up-to-date Azure CLI that supports `az login --certificate`.
- Sign in with an account that can register applications and create service principals in the Microsoft Entra tenant associated with the target subscription. Azure subscription ownership alone doesn't grant these directory permissions. If your tenant restricts application registration, ask your tenant administrator for help. See [Create an Azure service principal with the Azure CLI](/cli/azure/azure-cli-sp-tutorial-1).
- Confirm that your organization permits self-signed certificates for evaluation. For an existing approved identity, use its tenant ID, application client ID, service principal object ID, and protected PEM file, and skip to **Record the service principal and host values**.

Don't store the credential, private key, or credential path in the shared environment file. Don't print the PEM file or include it in source control. The PEM file contains an unencrypted private key so that the agent can authenticate without an interactive password prompt. Protect it with file permissions and approved host access controls.

#### Create a certificate-based service principal

Run these commands in your Bash environment while signed in with your operator account.

1. Confirm the subscription, tenant, and signed-in account.

    ```azurecli
    az account set --subscription "${SUBSCRIPTION_ID}"
    az account show \
        --query "{SubscriptionId:id,TenantId:tenantId,Account:user.name}" \
        --output table

    SP_TENANT_ID="$(az account show --query tenantId --output tsv)"
    export SP_TENANT_ID
    ```

    Continue only when the subscription and tenant are the intended targets.

1. Choose a unique application display name and create a protected credential directory.

    ```bash
    export SP_DISPLAY_NAME="aks-flexnode-${FLEXNODE_DEPLOYMENT}-$(date -u +%Y%m%dT%H%M%SZ)"
    install -d -m 0700 "${WORK_DIR:?Load the deployment environment first.}"
    SP_CREDENTIAL_DIR="$(mktemp -d "${WORK_DIR}/sp-credential.XXXXXXXX")"
    export SP_CREDENTIAL_DIR
    export SP_CLIENT_CERTIFICATE_FILE="${SP_CREDENTIAL_DIR:?Credential directory wasn't created.}/sp-client.pem"
    ```

1. Create a 30-day certificate and a combined PEM file that contains the certificate and private key.

    ```bash
    (
        set -e
        umask 077

        openssl req -x509 -newkey rsa:2048 -sha256 -days 30 -nodes \
            -keyout "${SP_CREDENTIAL_DIR}/sp-client.key" \
            -out "${SP_CREDENTIAL_DIR}/sp-client.crt" \
            -subj "/CN=${SP_DISPLAY_NAME}"

        cat "${SP_CREDENTIAL_DIR}/sp-client.crt" \
            "${SP_CREDENTIAL_DIR}/sp-client.key" \
            > "${SP_CLIENT_CERTIFICATE_FILE}"
        chmod 0600 "${SP_CLIENT_CERTIFICATE_FILE}"
        rm -f "${SP_CREDENTIAL_DIR}/sp-client.key"
    )

    openssl x509 \
        -in "${SP_CREDENTIAL_DIR}/sp-client.crt" \
        -noout -subject -dates
    stat -c '%a %n' "${SP_CLIENT_CERTIFICATE_FILE}"
    ```

    Stop if certificate creation fails. Confirm that the PEM permissions are `600`. The 30-day validity is for evaluation, not a rotation policy. Replace the credential through your approved process before it expires if the host remains attached.

1. Create the application and service principal by uploading only the public certificate.

    ```azurecli
    SP_CLIENT_ID="$(az ad sp create-for-rbac \
        --name "${SP_DISPLAY_NAME}" \
        --cert "@${SP_CREDENTIAL_DIR}/sp-client.crt" \
        --query appId \
        --output tsv)"
    export SP_CLIENT_ID
    ```

    Continue only when the command succeeds and returns an application client ID. The command can report that it adjusted the credential end date to match the certificate's expiration. Don't add `--role` or `--scopes`; the later role assignment is limited to the AKS cluster. Don't rerun creation against an existing application to rotate its credentials.

1. Retrieve the service principal object ID and inspect the registered credentials.

    ```azurecli
    SP_OBJECT_ID="$(az ad sp show \
        --id "${SP_CLIENT_ID}" \
        --query id \
        --output tsv)"
    export SP_OBJECT_ID

    az ad sp show \
        --id "${SP_CLIENT_ID}" \
        --query "{ClientId:appId,ServicePrincipalObjectId:id}" \
        --output table

    az ad app show \
        --id "${SP_CLIENT_ID}" \
        --query "{ClientId:appId,PasswordCredentials:length(passwordCredentials),Certificates:keyCredentials[].{KeyId:keyId,Expires:endDateTime}}" \
        --output json
    ```

    Confirm that the service principal object ID is populated, both client IDs match `SP_CLIENT_ID`, **PasswordCredentials** is `0`, and exactly one certificate is registered with the expected expiration. If directory replication delays the lookup, wait briefly and retry the lookup rather than creating another application.

For a credential-only test, run just the certificate-authentication check in [Verify a service principal](#verify-a-service-principal). You don't need to assign an Azure role or prepare a host for that check. When the test is complete, [delete the dedicated test application and local credential](./manage-and-remove-flex-nodes.md#delete-a-dedicated-service-principal-application).

#### Record the service principal and host values

Set the host addresses. If you selected an existing identity, first set `SP_TENANT_ID`, `SP_CLIENT_ID`, and `SP_OBJECT_ID` to its identifiers.

```bash
export FLEX_HOST_SSH_TARGET="<admin-user>@<reachable-host-address>"
export FLEX_HOST_PRIVATE_IP="<private-ip-reachable-from-aks>"

: "${SP_TENANT_ID:?Set the Microsoft Entra tenant ID.}"
: "${SP_CLIENT_ID:?Set the application client ID.}"
: "${SP_OBJECT_ID:?Set the service principal object ID.}"
export HOST_IDENTITY_CLIENT_ID=""
export HOST_PRINCIPAL_OBJECT_ID="${SP_OBJECT_ID}"

set_flexnode_env FLEX_HOST_SSH_TARGET "${FLEX_HOST_SSH_TARGET}"
set_flexnode_env FLEX_HOST_PRIVATE_IP "${FLEX_HOST_PRIVATE_IP}"
set_flexnode_env SP_TENANT_ID "${SP_TENANT_ID}"
set_flexnode_env SP_CLIENT_ID "${SP_CLIENT_ID}"
set_flexnode_env SP_OBJECT_ID "${SP_OBJECT_ID}"
set_flexnode_env HOST_IDENTITY_CLIENT_ID "${HOST_IDENTITY_CLIENT_ID}"
set_flexnode_env HOST_PRINCIPAL_OBJECT_ID "${HOST_PRINCIPAL_OBJECT_ID}"
```

`SP_OBJECT_ID` is the object ID of the **Enterprise application**, also called the service principal object ID. It isn't the object ID of the App registration. Confirm that `SP_CLIENT_ID`, `SP_OBJECT_ID`, and the certificate belong to the same service principal.

Bootstrap maps `SP_TENANT_ID` and `SP_CLIENT_ID` to `azure.servicePrincipal.tenantId` and `azure.servicePrincipal.clientId` in the generated agent configuration. `SP_OBJECT_ID` is used for the Azure role assignment, not as the agent's client ID. For the certificate-file field, full redacted configuration shape, and safe verification commands, see [Inspect the rendered service principal configuration](./attach-flex-node-to-aks.md?tabs=service-principal#inspect-the-rendered-service-principal-configuration).

Keep the protected PEM file for identity verification and host bootstrap. Make it available on the host through your approved credential-management process before attachment. Record its location through your approved credential-management process, not in the shared environment file. Continue with **Prepare and inspect the host**, and then assign the AKS role.

### Use an Azure virtual machine managed identity

Use this option for an Azure VM. Create a VM by following [Quickstart: Create a Linux virtual machine with the Azure CLI](/azure/virtual-machines/linux/quick-create-cli), or select an existing VM. Place the VM in the flex node host network planned for this deployment. You don't need a public IP address when your Bash environment has another approved SSH path.

Set the VM values:

```bash
export VM_RESOURCE_GROUP="<vm-resource-group>"
export VM_NAME="<vm-name>"
export VM_ADMIN_USER="<vm-admin-user>"
```

Retrieve the VM resource ID and the host addresses. The SSH target uses the public IP address when the VM has one, and the private address otherwise:

```azurecli
VM_RESOURCE_ID="$(az vm show \
    --resource-group "${VM_RESOURCE_GROUP}" \
    --name "${VM_NAME}" \
    --query id \
    --output tsv)"
export VM_RESOURCE_ID

FLEX_HOST_PRIVATE_IP="$(az vm show \
    --resource-group "${VM_RESOURCE_GROUP}" \
    --name "${VM_NAME}" \
    --show-details \
    --query privateIps \
    --output tsv)"
export FLEX_HOST_PRIVATE_IP

VM_PUBLIC_IP="$(az vm show \
    --resource-group "${VM_RESOURCE_GROUP}" \
    --name "${VM_NAME}" \
    --show-details \
    --query publicIps \
    --output tsv)"
export VM_PUBLIC_IP

export FLEX_HOST_SSH_TARGET="${VM_ADMIN_USER}@${VM_PUBLIC_IP:-${FLEX_HOST_PRIVATE_IP}}"
```

Confirm the private address returned for the VM:

```azurecli
az vm list-ip-addresses \
    --resource-group "${VM_RESOURCE_GROUP}" \
    --name "${VM_NAME}" \
    --query "[0].virtualMachine.{Name:name,PrivateAddresses:network.privateIpAddresses}" \
    --output table
```

Continue only when `FLEX_HOST_PRIVATE_IP` contains a single private address that belongs to `FLEX_HOST_SUBNET_CIDR` and is reachable from the AKS-managed node network. If Azure returns more than one address, set `FLEX_HOST_PRIVATE_IP` to the planned flex node address before you continue.

If the VM has no public IP address, or your Bash environment reaches the host through another approved management path, set `FLEX_HOST_SSH_TARGET` to the address or host name that your Bash environment can reach.

Complete one of the following managed identity options.

#### System-assigned managed identity

Enable the system-assigned managed identity:

```azurecli
az vm identity assign \
    --resource-group "${VM_RESOURCE_GROUP}" \
    --name "${VM_NAME}" \
    --output none
```

Retrieve its principal object ID:

```azurecli
HOST_PRINCIPAL_OBJECT_ID="$(az vm show \
    --resource-group "${VM_RESOURCE_GROUP}" \
    --name "${VM_NAME}" \
    --query identity.principalId \
    --output tsv)"
export HOST_PRINCIPAL_OBJECT_ID

export HOST_IDENTITY_CLIENT_ID=""
```

#### User-assigned managed identity

Create or select an identity by following [Manage user-assigned managed identities by using the Azure CLI](/entra/identity/managed-identities-azure-resources/how-manage-user-assigned-managed-identities?pivots=identity-mi-methods-azcli).

Set the identity values:

```bash
export USER_ASSIGNED_IDENTITY_RESOURCE_GROUP="<identity-resource-group>"
export USER_ASSIGNED_IDENTITY_NAME="<identity-name>"
```

Retrieve the identity identifiers:

```azurecli
USER_ASSIGNED_IDENTITY_RESOURCE_ID="$(az identity show \
    --resource-group "${USER_ASSIGNED_IDENTITY_RESOURCE_GROUP}" \
    --name "${USER_ASSIGNED_IDENTITY_NAME}" \
    --query id \
    --output tsv)"
export USER_ASSIGNED_IDENTITY_RESOURCE_ID

HOST_PRINCIPAL_OBJECT_ID="$(az identity show \
    --resource-group "${USER_ASSIGNED_IDENTITY_RESOURCE_GROUP}" \
    --name "${USER_ASSIGNED_IDENTITY_NAME}" \
    --query principalId \
    --output tsv)"
export HOST_PRINCIPAL_OBJECT_ID

HOST_IDENTITY_CLIENT_ID="$(az identity show \
    --resource-group "${USER_ASSIGNED_IDENTITY_RESOURCE_GROUP}" \
    --name "${USER_ASSIGNED_IDENTITY_NAME}" \
    --query clientId \
    --output tsv)"
export HOST_IDENTITY_CLIENT_ID
```

Assign the identity to the VM:

```azurecli
az vm identity assign \
    --resource-group "${VM_RESOURCE_GROUP}" \
    --name "${VM_NAME}" \
    --identities "${USER_ASSIGNED_IDENTITY_RESOURCE_ID}" \
    --output none
```

Verify that the VM lists the selected identity:

```azurecli
az vm identity show \
    --resource-group "${VM_RESOURCE_GROUP}" \
    --name "${VM_NAME}" \
    --query "{Type:type,UserAssignedIdentities:userAssignedIdentities}" \
    --output yaml
```

Continue when the output includes `USER_ASSIGNED_IDENTITY_RESOURCE_ID`.

#### Record the VM identity

Record the VM and identity values:

```bash
set_flexnode_env VM_RESOURCE_GROUP "${VM_RESOURCE_GROUP}"
set_flexnode_env VM_NAME "${VM_NAME}"
set_flexnode_env VM_ADMIN_USER "${VM_ADMIN_USER}"
set_flexnode_env VM_RESOURCE_ID "${VM_RESOURCE_ID}"
set_flexnode_env VM_PUBLIC_IP "${VM_PUBLIC_IP}"
set_flexnode_env FLEX_HOST_SSH_TARGET "${FLEX_HOST_SSH_TARGET}"
set_flexnode_env FLEX_HOST_PRIVATE_IP "${FLEX_HOST_PRIVATE_IP}"
set_flexnode_env HOST_PRINCIPAL_OBJECT_ID "${HOST_PRINCIPAL_OBJECT_ID}"
set_flexnode_env HOST_IDENTITY_CLIENT_ID "${HOST_IDENTITY_CLIENT_ID}"
```

## 3. Prepare and inspect the host

Connect to the host:

```bash
ssh -i "${SSH_PRIVATE_KEY_PATH}" "${FLEX_HOST_SSH_TARGET}"
```

On the host, inspect the operating system, architecture, host name, CPU, and available storage:

```bash
source /etc/os-release
printf 'Operating system: %s %s\n' "${NAME}" "${VERSION_ID}"
printf 'Architecture: %s\n' "$(uname -m)"
printf 'Host name: %s\n' "$(hostname)"
printf 'vCPUs: %s\n' "$(nproc)"
free -h
df -h /var/lib
```

Compare the results with the host requirements in step 1. Resolve any difference before you continue.

The bootstrap script requires `curl`, `jq`, and `tar` on the host and stops if any of them is missing. The flex node agent installs the remaining runtime packages during bootstrap.

Install any of the three that your image doesn't already include:

```bash
# Ubuntu
sudo apt-get update && sudo apt-get install -y curl jq tar

# Azure Linux 3
sudo tdnf install -y curl jq tar
```

Exit the host session:

```bash
exit
```

Read the actual Linux host name from your Bash environment:

```bash
FLEX_HOST_NAME="$(ssh \
    -i "${SSH_PRIVATE_KEY_PATH}" \
    "${FLEX_HOST_SSH_TARGET}" \
    hostname)"
export FLEX_HOST_NAME

printf 'Flex host name: %s\n' "${FLEX_HOST_NAME}"
```

Continue when the command returns the expected host name.

Retrieve the AKS API server FQDN and verify name resolution and HTTPS connectivity from the host:

```azurecli
AKS_API_FQDN="$(az aks show \
    --resource-group "${RESOURCE_GROUP}" \
    --name "${CLUSTER_NAME}" \
    --query '(privateFqdn || fqdn)' \
    --output tsv)"
export AKS_API_FQDN
```

```bash
ssh -i "${SSH_PRIVATE_KEY_PATH}" "${FLEX_HOST_SSH_TARGET}" \
    "getent hosts '${AKS_API_FQDN}' && \
    timeout 5 bash -c '</dev/tcp/${AKS_API_FQDN}/443'"
```

If name resolution or the TCP connection fails, correct DNS, routing, or network controls before you continue. A public AKS cluster uses its public API FQDN. For a private AKS cluster, your Bash environment and flex node host network must resolve and route to the private API FQDN.

Record the host values. The shared environment file stores paths and nonsecret identifiers, not key or credential contents.

```bash
set_flexnode_env SSH_PRIVATE_KEY_PATH "${SSH_PRIVATE_KEY_PATH}"
set_flexnode_env SSH_PUBLIC_KEY_PATH "${SSH_PUBLIC_KEY_PATH}"
set_flexnode_env FLEX_HOST_NAME "${FLEX_HOST_NAME}"
```

## 4. Assign the AKS role

The current preview workflow uses **Azure Kubernetes Service Contributor Role** at the exact AKS cluster scope. All three identity options use a service principal object ID for Azure role-based access control. Use a dedicated host identity, and remove this assignment when you remove the host as described in [Manage and remove flex nodes in AKS](./manage-and-remove-flex-nodes.md).

Display the selected principal object ID:

```bash
printf 'Principal object ID: %s\n' "${HOST_PRINCIPAL_OBJECT_ID}"
```

Continue only when the value is populated and belongs to the selected VM identity, Arc machine, or service principal.

Check whether the assignment already exists:

```azurecli
az role assignment list \
    --assignee-object-id "${HOST_PRINCIPAL_OBJECT_ID}" \
    --scope "${AKS_RESOURCE_ID}" \
    --fill-principal-name false \
    --query "[?roleDefinitionName=='Azure Kubernetes Service Contributor Role'].{PrincipalId:principalId,Role:roleDefinitionName,Scope:scope}" \
    --output table
```

If the command returns no row, create the assignment:

```azurecli
az role assignment create \
    --assignee-object-id "${HOST_PRINCIPAL_OBJECT_ID}" \
    --assignee-principal-type ServicePrincipal \
    --role "Azure Kubernetes Service Contributor Role" \
    --scope "${AKS_RESOURCE_ID}" \
    --output none
```

Run the list command again. Continue when the principal ID and scope match the selected identity and `AKS_RESOURCE_ID`. Role assignment propagation can take several minutes.

## 5. Verify the selected identity

Before you bootstrap the host, confirm that the selected identity can authenticate and read the exact target AKS cluster. Complete only the section for your identity option.

### Verify an Azure Arc managed identity

In your Bash environment, pass the nonsecret AKS resource ID to the Azure Arc-enabled server:

```bash
[[ "${AKS_RESOURCE_ID}" == /subscriptions/*/providers/Microsoft.ContainerService/managedClusters/* ]]
printf -v AKS_RESOURCE_ID_QUOTED '%q' "${AKS_RESOURCE_ID}"

ssh -t \
    -i "${SSH_PRIVATE_KEY_PATH}" \
    "${FLEX_HOST_SSH_TARGET}" \
    "export AKS_RESOURCE_ID=${AKS_RESOURCE_ID_QUOTED}; \
    exec bash -l"
```

On the Azure Arc-enabled server, request an Azure Resource Manager token from the Hybrid Instance Metadata Service (HIMDS) and use it to read the AKS resource. Reading the challenge token requires root or membership in the `himds` group:

```bash
TOKEN_URL="${IDENTITY_ENDPOINT:-http://127.0.0.1:40342/metadata/identity/oauth2/token}?api-version=2019-11-01&resource=https%3A%2F%2Fmanagement.azure.com"

CHALLENGE_TOKEN_PATH="$(curl --silent --show-error \
    --dump-header - \
    --output /dev/null \
    --header Metadata:true \
    "${TOKEN_URL}" |
    sed -n 's/^[Ww][Ww][Ww]-[Aa]uthenticate: Basic realm=//p' |
    tr -d '\r')"

test -n "${CHALLENGE_TOKEN_PATH}"
CHALLENGE_TOKEN="$(sudo cat "${CHALLENGE_TOKEN_PATH}")"

TOKEN="$(curl --fail --silent --show-error \
    --header Metadata:true \
    --header "Authorization: Basic ${CHALLENGE_TOKEN}" \
    "${TOKEN_URL}" |
    jq -r '.access_token // empty')"

test -n "${TOKEN}"

AKS_ARM_HTTP="$(curl --silent --show-error \
    --output /dev/null \
    --write-out '%{http_code}' \
    --header "Authorization: Bearer ${TOKEN}" \
    "https://management.azure.com${AKS_RESOURCE_ID}?api-version=2025-07-01")"

unset CHALLENGE_TOKEN TOKEN
printf 'AKS_ARM_HTTP=%s\n' "${AKS_ARM_HTTP}"
```

Expected output: `AKS_ARM_HTTP=200`. Run `exit` to leave the Azure Arc-enabled server session.

### Verify a service principal

In your Bash environment, use the combined PEM file from the service principal preparation steps. If you started a new session or selected an existing identity, set its protected path again:

```bash
export SP_CLIENT_CERTIFICATE_FILE="<protected-path-to-sp-client.pem>"
test -s "${SP_CLIENT_CERTIFICATE_FILE}"
```

Stop if the file doesn't exist or is empty. Don't add this path to the shared environment file.

First verify certificate authentication with an isolated Azure CLI profile. The subshell removes its temporary token cache even when a command fails and doesn't change your normal Azure CLI sign-in.

```bash
(
    set -e
    SP_AZURE_CONFIG_DIR="$(mktemp -d)"
    chmod 0700 "${SP_AZURE_CONFIG_DIR}"
    trap 'rm -rf -- "${SP_AZURE_CONFIG_DIR}"' EXIT
    export AZURE_CONFIG_DIR="${SP_AZURE_CONFIG_DIR}"

    az login \
        --service-principal \
        --username "${SP_CLIENT_ID}" \
        --certificate "${SP_CLIENT_CERTIFICATE_FILE}" \
        --tenant "${SP_TENANT_ID}" \
        --allow-no-subscriptions \
        --output none

    az account get-access-token \
        --resource https://management.azure.com/ \
        --query "{Tenant:tenant,ExpiresOn:expiresOn}" \
        --output table
)
```

Confirm that **Tenant** matches `SP_TENANT_ID` and that the token hasn't expired. This command prints only the tenant and expiration, not the access token. `--allow-no-subscriptions` lets you test authentication before granting Azure access. Successful authentication doesn't prove permission to read or register with the AKS cluster.

After the AKS role assignment in step 4 has propagated, verify access to the exact target cluster:

```bash
(
    set -e
    SP_AZURE_CONFIG_DIR="$(mktemp -d)"
    chmod 0700 "${SP_AZURE_CONFIG_DIR}"
    trap 'rm -rf -- "${SP_AZURE_CONFIG_DIR}"' EXIT
    export AZURE_CONFIG_DIR="${SP_AZURE_CONFIG_DIR}"

    az login \
        --service-principal \
        --username "${SP_CLIENT_ID}" \
        --certificate "${SP_CLIENT_CERTIFICATE_FILE}" \
        --tenant "${SP_TENANT_ID}" \
        --output none

    az account set --subscription "${SUBSCRIPTION_ID}"

    az aks show \
        --resource-group "${RESOURCE_GROUP}" \
        --name "${CLUSTER_NAME}" \
        --query "{Name:name,ResourceId:id,ProvisioningState:provisioningState}" \
        --output table
)
```

Continue only when the returned resource ID matches `AKS_RESOURCE_ID` and the provisioning state is `Succeeded`. If authentication succeeds but the cluster request is denied, verify the service principal object ID, exact role assignment scope, and propagation before retrying. This check proves that the service principal and its certificate can read the target cluster. The host uses the prepared credential in [Attach a flex node to an AKS cluster](./attach-flex-node-to-aks.md).

### Verify an Azure VM managed identity

In your Bash environment, pass the nonsecret AKS resource ID and identity client ID to the Azure VM:

```bash
[[ "${AKS_RESOURCE_ID}" == /subscriptions/*/providers/Microsoft.ContainerService/managedClusters/* ]]
printf -v AKS_RESOURCE_ID_QUOTED '%q' "${AKS_RESOURCE_ID}"
printf -v HOST_IDENTITY_CLIENT_ID_QUOTED '%q' "${HOST_IDENTITY_CLIENT_ID}"

ssh -t \
    -i "${SSH_PRIVATE_KEY_PATH}" \
    "${FLEX_HOST_SSH_TARGET}" \
    "export AKS_RESOURCE_ID=${AKS_RESOURCE_ID_QUOTED}; \
    export HOST_IDENTITY_CLIENT_ID=${HOST_IDENTITY_CLIENT_ID_QUOTED}; \
    exec bash -l"
```

On the Azure VM, request an Azure Resource Manager token from the selected managed identity and use it to read the AKS resource:

```bash
TOKEN_URL="http://169.254.169.254/metadata/identity/oauth2/token?api-version=2018-02-01&resource=https%3A%2F%2Fmanagement.azure.com%2F"

if [ -n "${HOST_IDENTITY_CLIENT_ID}" ]; then
    ENCODED_CLIENT_ID="$(jq -rn \
        --arg value "${HOST_IDENTITY_CLIENT_ID}" \
        '$value|@uri')"
    TOKEN_URL="${TOKEN_URL}&client_id=${ENCODED_CLIENT_ID}"
fi

TOKEN="$(curl --fail --silent --show-error \
    --header Metadata:true \
    "${TOKEN_URL}" |
    jq -r '.access_token // empty')"

test -n "${TOKEN}"

AKS_ARM_HTTP="$(curl --silent --show-error \
    --output /dev/null \
    --write-out '%{http_code}' \
    --header "Authorization: Bearer ${TOKEN}" \
    "https://management.azure.com${AKS_RESOURCE_ID}?api-version=2025-07-01")"

unset TOKEN
printf 'AKS_ARM_HTTP=%s\n' "${AKS_ARM_HTTP}"
```

Expected output: `AKS_ARM_HTTP=200`. For a user-assigned identity, the request uses the same `HOST_IDENTITY_CLIENT_ID` that the attachment workflow passes to `--msi-client-id`. Run `exit` to leave the Azure VM session.

The [attachment workflow](./attach-flex-node-to-aks.md) performs the final end-to-end check when the host uses the selected identity to register its Azure Machine resource.

## Next step

Next, [attach and verify the prepared host as a flex node](./attach-flex-node-to-aks.md).
