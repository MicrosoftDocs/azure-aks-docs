---
title: Attach a flex node to an AKS cluster (preview)
description: Learn how to download the flex node release, bootstrap and attach a prepared Linux host, and validate the Kubernetes node and Azure Machine resource.
author: leslielin-5
ms.author: leslielin
ms.topic: how-to
ms.date: 09/22/2026
ms.subservice: aks-nodes
ms.service: azure-kubernetes-service
ai-usage: ai-assisted
# Customer intent: "As a platform engineer, I want to securely bootstrap a prepared Linux host, attach it to a flex node pool, and verify that the node works."
---

# Attach a flex node to an AKS cluster (preview)

[!INCLUDE [preview features callout](~/reusable-content/ce-skilling/azure/includes/aks/includes/preview/preview-callout.md)]

After you prepare the Azure Kubernetes Service (AKS) cluster, networking, flex node pool, host, and identity, bootstrap the host and attach it to the target pool.

In this article, you:

- Download and verify the flex node release.
- Bootstrap the host by using its selected Azure identity to retrieve fresh pool data.
- Verify the Kubernetes Node, Azure Machine, networking state, and agent service.
- Validate workload placement, Kubernetes callbacks, and cross-node connectivity.

Run the management commands in this article in a Linux-compatible Bash environment that has the required tools and network access. This article calls that environment your **Bash environment**. The separate machine that joins the cluster is the **flex node host**; run commands there only when a step explicitly directs you to.

For a private AKS cluster, run every `kubectl` command from a Bash environment that can resolve and reach the private API server. You can run Azure CLI, artifact download, SSH, and SCP commands from your Bash environment when it has the required Azure and host access. The flex node host network must also resolve and reach the private API endpoint.

## Before you begin

- Complete [Configure networking and create a flex node pool in AKS](./configure-flex-nodes-networking.md).
- Complete [Prepare a flex node host and identity](./prepare-flex-node-host-identity.md).
- Install Azure CLI, the `aks-preview` extension, a `kubectl` version within one minor version of `AKS_VERSION`, `jq`, `curl`, `sha256sum`, an OpenSSH client, and `scp` in your Bash environment.
- For managed identity or service principal, use an Azure account that can retrieve bootstrap data for the selected flex node pool.
- Ensure that your Bash environment can reach the flex node host through the approved SSH management path.
- Ensure that the flex node host can reach the release and bootstrap artifact endpoints returned in the pool bootstrap data, Azure Resource Manager, Microsoft Entra ID, and the selected AKS API endpoint over HTTPS.

> [!NOTE]
> Don't store credentials, certificates, private keys, access tokens, bootstrap data, or kubeconfig content in the shared environment file.

## Load the deployment environment

Start a new Bash session, identify the environment file, and load it. Replace `<deployment-name>` with the deployment label used in the preceding articles.

```bash
export FLEXNODE_DEPLOYMENT="<deployment-name>"
export FLEXNODE_ENV_FILE="${HOME}/.config/aks-flexnode/${FLEXNODE_DEPLOYMENT}.env"
test -s "${FLEXNODE_ENV_FILE}"
source "${FLEXNODE_ENV_FILE}"
export KUBECONFIG="${FLEXNODE_KUBECONFIG}"
install -d -m 0700 "${WORK_DIR:?Load the deployment environment first.}"
```

The environment file supplies the shared deployment values that this article reads, including `WORK_DIR`, the directory in your Bash environment where this article stores downloads and generated files. By default, `WORK_DIR` is `~/.local/share/aksflexnode/<deployment-name>`. The article derives any other variables that it needs. If you didn't create the environment file yet, complete [Plan your flex nodes deployment](./plan-flex-nodes-deployment.md) first. Don't continue past this step if the shell reports an error.

Set the active subscription and display the Azure, Kubernetes, and host targets:

```azurecli
az account set --subscription "${SUBSCRIPTION_ID}"

az aks show \
    --resource-group "${RESOURCE_GROUP}" \
    --name "${CLUSTER_NAME}" \
    --query "{Cluster:name,ResourceId:id,ApiServer:(privateFqdn || fqdn)}" \
    --output table
```

```bash
kubectl cluster-info

printf 'Recorded flex host: %s\n' "${FLEX_HOST_NAME}"
ssh -i "${SSH_PRIVATE_KEY_PATH}" "${FLEX_HOST_SSH_TARGET}" hostname
```

Confirm that **ResourceId** matches `AKS_RESOURCE_ID`, the Kubernetes control-plane hostname matches **ApiServer**, and the SSH command returns `FLEX_HOST_NAME`. If any target doesn't match, stop and correct the environment file, kubeconfig, or SSH target before you transfer or run files.

## Download and verify the flex node release

1. Identify the host architecture and select the matching release archive.

    ```bash
    HOST_ARCH="$(ssh \
        -i "${SSH_PRIVATE_KEY_PATH}" \
        "${FLEX_HOST_SSH_TARGET}" \
        uname -m)"
    export HOST_ARCH

    case "${HOST_ARCH}" in
        x86_64) export AGENT_ARCH="amd64" ;;
        aarch64|arm64) export AGENT_ARCH="arm64" ;;
        *)
            printf 'Unsupported host architecture: %s\n' "${HOST_ARCH}" >&2
            false
            ;;
    esac

    export AGENT_ARCHIVE="aks-flex-node-linux-${AGENT_ARCH}.tar.gz"
    printf 'Selected release archive: %s\n' "${AGENT_ARCHIVE}"
    ```

1. Download the archive and checksum manifest from the selected release.

    ```bash
    curl --fail --location --silent --show-error \
        --proto '=https' \
        --tlsv1.2 \
        "https://github.com/Azure/AKSFlexNode/releases/download/${AKS_FLEX_NODE_VERSION}/${AGENT_ARCHIVE}" \
        --output "${WORK_DIR}/${AGENT_ARCHIVE}"

    curl --fail --location --silent --show-error \
        --proto '=https' \
        --tlsv1.2 \
        "https://github.com/Azure/AKSFlexNode/releases/download/${AKS_FLEX_NODE_VERSION}/checksums.txt" \
        --output "${WORK_DIR}/checksums.txt"
    ```

1. Select exactly one checksum entry for the archive and verify the file.

    ```bash
    AGENT_CHECKSUM_ENTRY="$(awk \
        -v file="${AGENT_ARCHIVE}" \
        '$2 == file {print}' \
        "${WORK_DIR}/checksums.txt")"
    export AGENT_CHECKSUM_ENTRY

    test "$(printf '%s\n' "${AGENT_CHECKSUM_ENTRY}" |
        sed '/^$/d' |
        wc -l)" -eq 1

    (
        cd "${WORK_DIR:?Load the deployment environment first.}"
        printf '%s\n' "${AGENT_CHECKSUM_ENTRY}" |
            sha256sum --check --strict -
    )

    export AGENT_SHA256="${AGENT_CHECKSUM_ENTRY%% *}"
    test -n "${AGENT_SHA256}"
    ```

    Don't continue unless the checksum command reports that the archive is `OK`.

1. Download the bootstrap script from the same release tag and validate its Bash syntax.

    ```bash
    curl --fail --location --silent --show-error \
        --proto '=https' \
        --tlsv1.2 \
        "https://raw.githubusercontent.com/Azure/AKSFlexNode/${AKS_FLEX_NODE_VERSION}/scripts/bootstrap.sh" \
        --output "${WORK_DIR}/bootstrap.sh"

    chmod 0700 "${WORK_DIR}/bootstrap.sh"
    bash -n "${WORK_DIR}/bootstrap.sh"
    ```

    The release doesn't currently publish a separate checksum for this script. Download it without piping it to a shell, keep it version-matched with the verified agent archive, and stop if the syntax check fails.

## Fetch current pool bootstrap data

The managed identity and service principal paths use bootstrap data that you retrieve in your Bash environment. If you selected Azure Arc managed identity, skip this section. The Arc bootstrap command retrieves fresh data through the Arc machine identity.

For managed identity or service principal, fetch the data immediately before you transfer files to the host. The response contains a bootstrap token that expires after one hour. Don't print the response or store it in notes.

```azurecli
az aks nodepool get-bootstrap-data \
    --resource-group "${RESOURCE_GROUP}" \
    --cluster-name "${CLUSTER_NAME}" \
    --name "${FLEX_POOL_NAME}" \
    --output json \
    > "${WORK_DIR}/base-config.json"

chmod 0600 "${WORK_DIR}/base-config.json"
test -s "${WORK_DIR}/base-config.json"
```

Continue when `${WORK_DIR}/base-config.json` exists and isn't empty. Complete the transfer and host bootstrap within one hour. If the token expires, run the command again and replace the old file.

## Transfer files and prepare the host

1. Create a nonsecret host handoff file.

    ```bash
    {
        printf 'export AGENT_ARCHIVE=%q\n' "${AGENT_ARCHIVE}"
        printf 'export AGENT_SHA256=%q\n' "${AGENT_SHA256}"
        printf 'export AKS_FLEX_NODE_VERSION=%q\n' "${AKS_FLEX_NODE_VERSION}"
        printf 'export AKS_RESOURCE_ID=%q\n' "${AKS_RESOURCE_ID}"
        printf 'export FLEX_POOL_NAME=%q\n' "${FLEX_POOL_NAME}"
        printf 'export FLEX_HOST_PRIVATE_IP=%q\n' "${FLEX_HOST_PRIVATE_IP}"
        printf 'export HOST_IDENTITY_CLIENT_ID=%q\n' "${HOST_IDENTITY_CLIENT_ID:-}"
        printf 'export SP_TENANT_ID=%q\n' "${SP_TENANT_ID:-}"
        printf 'export SP_CLIENT_ID=%q\n' "${SP_CLIENT_ID:-}"
    } > "${WORK_DIR}/host-bootstrap.env"

    chmod 0600 "${WORK_DIR}/host-bootstrap.env"
    ```

1. Copy the verified release files and handoff file to the host.

    ```bash
    scp -i "${SSH_PRIVATE_KEY_PATH}" \
        "${WORK_DIR}/${AGENT_ARCHIVE}" \
        "${WORK_DIR}/bootstrap.sh" \
        "${WORK_DIR}/host-bootstrap.env" \
        "${FLEX_HOST_SSH_TARGET}:/tmp/"
    ```

1. For managed identity or service principal, also copy the protected bootstrap data:

    ```bash
    scp -i "${SSH_PRIVATE_KEY_PATH}" \
        "${WORK_DIR}/base-config.json" \
        "${FLEX_HOST_SSH_TARGET}:/tmp/"
    ```

1. Connect to the host and start a root shell:

    ```bash
    ssh -i "${SSH_PRIVATE_KEY_PATH}" "${FLEX_HOST_SSH_TARGET}"
    sudo -i
    ```

1. Load the nonsecret handoff values and validate the transferred files:

    ```bash
    source /tmp/host-bootstrap.env
    chmod 0600 "/tmp/${AGENT_ARCHIVE}" /tmp/host-bootstrap.env
    chmod 0700 /tmp/bootstrap.sh
    bash -n /tmp/bootstrap.sh
    printf '%s  %s\n' \
        "${AGENT_SHA256}" \
        "/tmp/${AGENT_ARCHIVE}" |
        sha256sum --check --strict -
    ```

    Continue when the checksum command reports that the archive is `OK`. Stop if the checksum or script syntax check fails.

1. For managed identity or service principal, install the bootstrap data:

    ```bash
    install -d -o root -g root -m 0700 /etc/aks-flex-node
    install -o root -g root -m 0600 \
        /tmp/base-config.json \
        /etc/aks-flex-node/base-config.json
    test -s /etc/aks-flex-node/base-config.json
    ```

## Bootstrap the host

Complete only the section that matches the identity configured in the preceding article.

# [Azure Arc managed identity](#tab/arc-managed-identity)

Use this section only after the Arc machine resource matches the SSH host, `himdsd` is active, the HIMDS verification returns HTTP 200 for the exact AKS resource, and the AKS-scoped role assignment is present, as verified in the preceding article. This path retrieves fresh bootstrap data through the Arc machine identity and doesn't use the `base-config.json` file from your Bash environment.

```bash
CONFIG_OVERRIDES="$(jq -cn \
    --arg nodeIP "${FLEX_HOST_PRIVATE_IP}" \
    '{node:{kubelet:{nodeIP:$nodeIP}}}')"
export CONFIG_OVERRIDES

bash /tmp/bootstrap.sh \
    --auth arc \
    --fetch-bootstrap-data \
    --cluster-resource-id "${AKS_RESOURCE_ID}" \
    --agent-pool-name "${FLEX_POOL_NAME}" \
    --agent-url "file:///tmp/${AGENT_ARCHIVE}" \
    --agent-sha256 "${AGENT_SHA256}" \
    --config-overrides "${CONFIG_OVERRIDES}"
```

Continue when the output reports `Arc preflight: OK`, machine registration completes, and the bootstrap script reports that the flex node agent service started. If bootstrap can't retrieve data, verify the Arc connection, `himdsd`, AKS-scoped role assignment, and host access to Azure Resource Manager.

# [Service principal](#tab/service-principal)

Before you continue, make the combined PEM certificate and private key available on the host at `/etc/aks-flex-node/credentials/sp-client-certificate` through your approved credential-management process. The credentials directory must be root-owned with permissions `700`. Don't store the credential or its path in the shared environment file.

In the host root shell, set the certificate path and verify its owner and permissions:

```bash
export FLEX_SP_CLIENT_CERTIFICATE_FILE="/etc/aks-flex-node/credentials/sp-client-certificate"
test -s "${FLEX_SP_CLIENT_CERTIFICATE_FILE}"
stat -c '%U %G %a %n' "${FLEX_SP_CLIENT_CERTIFICATE_FILE}"
```

Continue only when the file exists, is owned by `root root`, and has permissions `600`. Keep it available after bootstrap because the running agent uses it for Azure Machine reconciliation.

Run bootstrap with the protected `base-config.json` file that you retrieved in your Bash environment:

```bash
env AKS_FLEX_NODE_BASE_CONFIG_FILE=/etc/aks-flex-node/base-config.json \
    bash /tmp/bootstrap.sh \
    --auth service-principal \
    --sp-tenant-id "${SP_TENANT_ID}" \
    --sp-client-id "${SP_CLIENT_ID}" \
    --sp-client-certificate-file "${FLEX_SP_CLIENT_CERTIFICATE_FILE}" \
    --agent-url "file:///tmp/${AGENT_ARCHIVE}" \
    --agent-sha256 "${AGENT_SHA256}"
```

Continue when machine registration completes and the bootstrap script reports that the flex node agent service started. If bootstrap fails, don't remove the service principal credential while the host remains attached or the agent still uses it.

### Inspect the rendered service principal configuration

Run the commands in the host root shell after the bootstrap process succeeds.

The service principal identifiers and certificate file are inputs to the bootstrap process. The script merges them with the pool bootstrap data to produce the agent's configuration:

| File | Purpose | Handling |
| --- | --- | --- |
| `/etc/aks-flex-node/base-config.json` | Pool bootstrap data retrieved before attachment, including a short-lived bootstrap token. | Keep protected; don't print or share its contents. |
| `/etc/aks-flex-node/config.json` | Rendered flex node configuration, including the target cluster and pool, node settings, artifact sources, and Azure authentication settings. | Root-owned with mode `0600`; don't print or share the complete file. |
| `/etc/aks-flex-node/credentials/sp-client-certificate` | Combined PEM certificate and private key used by the running agent. | Root-owned with mode `0600` in the protected credentials directory; retain while attached. |

In the `bootstrap.sh` script for the agent version that your deployment pins in `AKS_FLEX_NODE_VERSION`, `--sp-client-certificate-file` writes the certificate path to **`azure.servicePrincipal.clientSecretFile`**. Despite its name, this field references the certificate file in this workflow, not a client secret value. Don't rename it to `clientCertificateFile`. The script removes `azure.managedIdentity` and sets `azure.arc.enabled` to `false` when selecting service principal authentication.

The following redacted example shows the shape of a certificate-based service principal configuration. It isn't a complete configuration schema or a file to copy onto a host. Continue to generate the configuration with the version-matched bootstrap script.

```json
{
  "azure": {
    "bootstrapToken": {
      "token": "<redacted-bootstrap-token>"
    },
    "resourceManagerEndpoint": "https://management.azure.com",
    "targetAgentPoolName": "<flex-node-pool-name>",
    "targetCluster": {
      "resourceId": "<aks-cluster-resource-id>"
    },
    "arc": {
      "enabled": false
    },
    "servicePrincipal": {
      "tenantId": "<microsoft-entra-tenant-id>",
      "clientId": "<application-client-id>",
      "clientSecretFile": "/etc/aks-flex-node/credentials/sp-client-certificate"
    }
  },
  "components": {
    "kubernetes": "<kubernetes-version-from-bootstrap-data>"
  },
  "networking": {
    "dnsServiceIP": "<kubernetes-dns-service-ip>"
  },
  "node": {
    "kubelet": {
      "caCertData": "<cluster-ca-data>",
      "clusterFQDN": "<aks-api-server-fqdn>"
    },
    "labels": {
      "pool-generation": "initial"
    },
    "maxPods": 75,
    "taints": [
      "pool-generation=initial:NoSchedule"
    ]
  },
  "bootstrap": {
    "ociImage": "<published-root-filesystem-artifact-url>",
    "offlineArtifacts": {
      "source": "<published-kubernetes-bootstrap-artifact-url>"
    }
  },
  "agent": {
    "nodeName": "<linux-host-name>"
  }
}
```

The Kubernetes bootstrap token and the Azure service principal serve different purposes. The token establishes initial Kubernetes trust; the service principal supplies durable Azure authentication. The service principal object ID used for the Azure role assignment isn't the application client ID stored in this configuration.

1. Inspect only an allowlisted set of nonsecret target and identity fields. Don't replace this projection with `cat` or `jq .` on the full configuration.

    ```bash
    jq '{
        azure: {
            targetCluster: {resourceId: .azure.targetCluster.resourceId},
            targetAgentPoolName: .azure.targetAgentPoolName,
            arc: {enabled: .azure.arc.enabled},
            servicePrincipal: {
                tenantId: .azure.servicePrincipal.tenantId,
                clientId: .azure.servicePrincipal.clientId,
                clientSecretFile: .azure.servicePrincipal.clientSecretFile
            }
        },
        agent: {nodeName: .agent.nodeName}
    }' /etc/aks-flex-node/config.json
    ```

    Confirm the expected cluster, pool, host name, tenant ID, application client ID, and certificate path. These fields aren't credentials, but review resource identifiers before sharing diagnostic output.

1. Verify that the generated configuration selects the intended service principal and certificate, with the other Azure identity modes disabled.

    ```bash
    if jq -e \
        --arg tenantId "${SP_TENANT_ID}" \
        --arg clientId "${SP_CLIENT_ID}" \
        --arg certificateFile "${FLEX_SP_CLIENT_CERTIFICATE_FILE}" \
        '
        .azure.servicePrincipal.tenantId == $tenantId and
        .azure.servicePrincipal.clientId == $clientId and
        .azure.servicePrincipal.clientSecretFile == $certificateFile and
        (.azure | has("managedIdentity") | not) and
        .azure.arc.enabled == false
        ' /etc/aks-flex-node/config.json >/dev/null; then
        printf 'Service principal configuration matches the selected certificate identity.\n'
    else
        printf 'Service principal configuration mismatch; stop and review bootstrap inputs.\n' >&2
        false
    fi
    ```

    Stop if the check fails. Don't manually edit the generated file to bypass an identity mismatch.

1. Verify the configuration and certificate file permissions.

    ```bash
    stat -c '%U %G %a %n' \
        /etc/aks-flex-node/config.json \
        "${FLEX_SP_CLIENT_CERTIFICATE_FILE}"
    ```

    Both files must be owned by `root root` with permissions `600`. This inspection confirms the selected configuration; the following Node, Machine, and workload checks validate runtime behavior.

# [Azure VM managed identity](#tab/managed-identity)

For a system-assigned managed identity, `HOST_IDENTITY_CLIENT_ID` remains empty. A user-assigned managed identity uses the client ID recorded in the shared environment. Both options use the protected `base-config.json` file that you retrieved in your Bash environment.

For a system-assigned managed identity, run:

```bash
env AKS_FLEX_NODE_BASE_CONFIG_FILE=/etc/aks-flex-node/base-config.json \
    bash /tmp/bootstrap.sh \
    --auth msi \
    --agent-url "file:///tmp/${AGENT_ARCHIVE}" \
    --agent-sha256 "${AGENT_SHA256}"
```

For a user-assigned managed identity, add its client ID:

```bash
env AKS_FLEX_NODE_BASE_CONFIG_FILE=/etc/aks-flex-node/base-config.json \
    bash /tmp/bootstrap.sh \
    --auth msi \
    --msi-client-id "${HOST_IDENTITY_CLIENT_ID}" \
    --agent-url "file:///tmp/${AGENT_ARCHIVE}" \
    --agent-sha256 "${AGENT_SHA256}"
```

Continue when machine registration completes and the bootstrap script reports that the flex node agent service started.

---

## Remove temporary release files

After bootstrap succeeds, remove the transient script, archive, and handoff file from the host:

```bash
rm -f \
    "/tmp/${AGENT_ARCHIVE}" \
    /tmp/bootstrap.sh \
    /tmp/base-config.json \
    /tmp/host-bootstrap.env
exit
exit
```

The first `exit` leaves the root shell. The second closes the SSH session and returns to your Bash environment.

Remove the copies in your Bash environment:

```bash
rm -f \
    "${WORK_DIR:?Load the deployment environment first.}/${AGENT_ARCHIVE}" \
    "${WORK_DIR}/bootstrap.sh" \
    "${WORK_DIR}/base-config.json" \
    "${WORK_DIR}/host-bootstrap.env" \
    "${WORK_DIR}/checksums.txt"
```

Keep `/etc/aks-flex-node` and the service principal credential while the host remains attached. The running agent uses this configuration for node and Azure Machine reconciliation.

## Verify the Kubernetes node

Set the node name to the Linux hostname recorded in the shared environment. First, wait for the Node object to be created, and then wait for it to become ready:

```bash
export FLEX_NODE_NAME="$(printf '%s' "${FLEX_HOST_NAME}" | tr -d '[:space:]' | tr '[:upper:]' '[:lower:]')"

kubectl wait \
    --for=create \
    "node/${FLEX_NODE_NAME}" \
    --timeout=5m

kubectl wait \
    --for=condition=Ready \
    "node/${FLEX_NODE_NAME}" \
    --timeout=10m

kubectl get node "${FLEX_NODE_NAME}" -o wide
```

Continue when the node is `Ready`. If the node isn't created or doesn't become ready, verify the bootstrap output, API connectivity, and agent service before retrying bootstrap.

## Verify the Azure Machine resource

1. List the Machines in the target flex node pool.

    ```azurecli
    az aks machine list \
        --resource-group "${RESOURCE_GROUP}" \
        --cluster-name "${CLUSTER_NAME}" \
        --nodepool-name "${FLEX_POOL_NAME}" \
        --query "[].{name:name,state:properties.provisioningState,nodeName:properties.kubernetes.nodeName,version:properties.kubernetes.currentOrchestratorVersion}" \
        --output table
    ```

1. Find the Machine that registered the prepared Kubernetes node:

    ```azurecli
    FLEX_MACHINE_NAME="$(az aks machine list \
        --resource-group "${RESOURCE_GROUP}" \
        --cluster-name "${CLUSTER_NAME}" \
        --nodepool-name "${FLEX_POOL_NAME}" \
        --query "[?properties.kubernetes.nodeName=='${FLEX_NODE_NAME}'].name | [0]" \
        --output tsv)"
    export FLEX_MACHINE_NAME

    printf 'Machine: %s\n' "${FLEX_MACHINE_NAME}"
    ```

    Continue when the command returns exactly one Machine name.

1. Show that Machine:

    ```azurecli
    az aks machine show \
        --resource-group "${RESOURCE_GROUP}" \
        --cluster-name "${CLUSTER_NAME}" \
        --nodepool-name "${FLEX_POOL_NAME}" \
        --machine-name "${FLEX_MACHINE_NAME}" \
        --output yaml
    ```

    Continue when the Machine exists, references `FLEX_NODE_NAME`, and reports a successful provisioning state. Record the Machine name for lifecycle operations:

    ```bash
    set_flexnode_env FLEX_MACHINE_NAME "${FLEX_MACHINE_NAME}"
    ```

## Verify flex node networking

1. Display the flex site, pod CIDR, and WireGuard public key.

    ```bash
    kubectl get node "${FLEX_NODE_NAME}" \
        -L net.unbounded-cloud.io/site \
        -o wide

    kubectl get node "${FLEX_NODE_NAME}" \
        -o jsonpath='{.metadata.name}{" site="}{.metadata.labels.net\.unbounded-cloud\.io/site}{" podCIDR="}{.spec.podCIDR}{" wg="}{.metadata.annotations.net\.unbounded-cloud\.io/wg-pubkey}{"\n"}'
    ```

1. Verify the Sites and related Unbounded-Net networking resources.

    ```bash
    kubectl get \
        sites,sitenodeslices,gatewaypools,sitegatewaypoolassignments,gatewaypoolpeerings \
        -o wide
    ```

1. Display the Unbounded-Net pods scheduled to the flex node.

    ```bash
    kubectl get pods --all-namespaces \
        --field-selector "spec.nodeName=${FLEX_NODE_NAME}" \
        -o wide
    ```

Don't continue to workload validation unless:

- The node is `Ready`.
- The Site is the Unbounded-Net flex site configured in the networking article.
- The pod CIDR belongs to the planned `FLEX_POD_CIDR` range.
- The WireGuard public key is populated.
- The `cluster-flex-private-l3` SitePeering references the `cluster` and `flex-site` Sites.
- Every returned Unbounded-Net pod on the node is `Running`.
- For a public WireGuard topology, the expected gateway pool peering exists.

## Verify the flex node agent

Wait up to one minute for the service to become active. If it doesn't, display the service state and recent logs:

```bash
ssh -i "${SSH_PRIVATE_KEY_PATH}" "${FLEX_HOST_SSH_TARGET}" \
    'set -euo pipefail
     for attempt in {1..12}; do
         if sudo systemctl is-active --quiet aks-flex-node-agent; then
             sudo systemctl show aks-flex-node-agent \
                 -p ActiveState \
                 -p SubState \
                 -p Result \
                 -p NRestarts
             exit 0
         fi
         sleep 5
     done

     sudo systemctl show aks-flex-node-agent \
         -p ActiveState \
         -p SubState \
         -p Result \
         -p NRestarts
     sudo journalctl -u aks-flex-node-agent --no-pager -n 80
     exit 1'
```

Continue when the output contains `ActiveState=active`, `SubState=running`, and `Result=success`.

If the agent repeatedly restarts because it can't list `MachineOperation` resources, return to the temporary flex daemon RBAC step in [Configure networking and create a flex node pool in AKS](./configure-flex-nodes-networking.md), verify that the role and binding exist, and then restart the agent:

```bash
ssh -i "${SSH_PRIVATE_KEY_PATH}" "${FLEX_HOST_SSH_TARGET}" \
    'sudo systemctl restart aks-flex-node-agent'
```

## Validate workload placement and connectivity

### Create a validation workload

Create a dedicated namespace. If this namespace already exists, clean up the previous validation run before you retry.

```bash
export VALIDATION_NAMESPACE="flex-node-validation"

if kubectl get namespace "${VALIDATION_NAMESPACE}" >/dev/null 2>&1; then
    printf 'Validation namespace already exists: %s\n' \
        "${VALIDATION_NAMESPACE}" >&2
    false
fi

kubectl create namespace "${VALIDATION_NAMESPACE}"
kubectl label namespace "${VALIDATION_NAMESPACE}" \
    app.kubernetes.io/managed-by=flex-node-article
```

Create an HTTP server that the Kubernetes scheduler places on the flex node, and expose it through a ClusterIP Service:

```bash
kubectl --namespace "${VALIDATION_NAMESPACE}" run flex-http-server \
    --image=busybox:1.36 \
    --restart=Never \
    --labels app=flex-http \
    --overrides="{\"spec\":{\"nodeSelector\":{\"kubernetes.io/hostname\":\"${FLEX_NODE_NAME}\"},\"tolerations\":[{\"operator\":\"Exists\"}]}}" \
    --command -- sh -c \
    'mkdir -p /www; echo flex-network-ok >/www/index.html; exec httpd -f -p 8080 -h /www'

kubectl --namespace "${VALIDATION_NAMESPACE}" wait \
    --for=condition=Ready \
    pod/flex-http-server \
    --timeout=3m

kubectl --namespace "${VALIDATION_NAMESPACE}" expose pod flex-http-server \
    --name=flex-http-service \
    --port=8080 \
    --target-port=8080
```

### Verify callbacks and local service connectivity

Check logs and command execution by using the Kubernetes API server callback path:

```bash
kubectl --namespace "${VALIDATION_NAMESPACE}" logs flex-http-server --tail=5
kubectl --namespace "${VALIDATION_NAMESPACE}" exec flex-http-server -- \
    sh -c 'printf "exec-callback-ok\n"'
```

Get the ClusterIP and request the service from the flex node workload:

```bash
SERVICE_IP="$(kubectl --namespace "${VALIDATION_NAMESPACE}" \
    get service flex-http-service \
    --output jsonpath='{.spec.clusterIP}')"
export SERVICE_IP

kubectl --namespace "${VALIDATION_NAMESPACE}" exec flex-http-server -- \
    wget -qO- "http://${SERVICE_IP}:8080"
```

The expected response is:

```text
flex-network-ok
```

### Verify port forwarding

In the current terminal, forward a local port through the Kubernetes API server. This command uses the deployment environment and kubeconfig that you loaded earlier:

```bash
kubectl --namespace "${VALIDATION_NAMESPACE}" \
    port-forward pod/flex-http-server 18080:8080
```

In a second terminal, request the forwarded endpoint:

```bash
curl -fsS http://127.0.0.1:18080
```

The expected response is `flex-network-ok`. Press <kbd>Ctrl</kbd>+<kbd>C</kbd> in the first terminal after the check.

### Verify connectivity from an AKS-managed node

Find a ready AKS-managed system node:

```bash
SYSTEM_NODE="$(kubectl get nodes \
    --selector agentpool=systempool \
    --output json |
    jq -r '
        .items[]
        | select(any(.status.conditions[];
            .type == "Ready" and .status == "True"))
        | .metadata.name
    ' |
    head -n 1)"
export SYSTEM_NODE

test -n "${SYSTEM_NODE}"
printf 'Managed-node test target: %s\n' "${SYSTEM_NODE}"
```

Run a client pod on that node and check for the expected response:

```bash
kubectl --namespace "${VALIDATION_NAMESPACE}" run system-http-client \
    --image=busybox:1.36 \
    --restart=Never \
    --overrides="{\"spec\":{\"nodeSelector\":{\"kubernetes.io/hostname\":\"${SYSTEM_NODE}\"}}}" \
    --command -- sh -c \
    "test \"\$(wget -qO- http://${SERVICE_IP}:8080)\" = flex-network-ok"

kubectl --namespace "${VALIDATION_NAMESPACE}" wait \
    --for=jsonpath='{.status.phase}'=Succeeded \
    pod/system-http-client \
    --timeout=3m

kubectl --namespace "${VALIDATION_NAMESPACE}" \
    get pod flex-http-server system-http-client -o wide
```

A Kubernetes node in `Ready` state shows node registration. It doesn't by itself prove workload networking, callback operations, or Azure lifecycle operations.

## Clean up the validation workload

Remove only the temporary resources that you created in this article.

```bash
kubectl delete namespace "${VALIDATION_NAMESPACE}"
```

## Next step

Next, [manage, update, upgrade, or remove the attached flex node](./manage-and-remove-flex-nodes.md).
