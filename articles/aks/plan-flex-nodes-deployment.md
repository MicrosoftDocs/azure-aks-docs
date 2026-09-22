---
title: Plan flex nodes for AKS (preview)
description: Learn how to plan identity, API access, network connectivity, address ranges, and shared configuration before you add flex nodes to an AKS cluster.
ms.topic: how-to
ms.date: 09/22/2026
author: leslielin-5
ms.author: leslielin
ms.subservice: aks-nodes
ms.service: azure-kubernetes-service
ai-usage: ai-assisted
# Customer intent: "As a platform engineer, I want to make the required design decisions and record deployment values before I configure flex nodes for an AKS cluster."
---

# Plan flex nodes for AKS (preview)

[!INCLUDE [preview features callout](~/reusable-content/ce-skilling/azure/includes/aks/includes/preview/preview-callout.md)]

Flex nodes extend an Azure Kubernetes Service (AKS) cluster to Linux machines that you manage outside the cluster's Azure-managed node pools. Before you add a flex node, choose how the host authenticates to Azure, how it reaches the Kubernetes API server, and how network traffic moves between the AKS and flex node environments.

This article helps you make these decisions, plan nonoverlapping address ranges, and create a shared environment file for the remaining deployment articles.

## Before you begin

- Review the [flex nodes for AKS overview](./flex-nodes-for-aks-overview.md).
- Review [identity and access concepts for flex nodes](./flex-nodes-identity-access-concepts.md).
- Review [networking concepts for flex nodes](./flex-nodes-networking-concepts.md).
- Use a Linux-compatible Bash environment that has the required tools and network access. This deployment series calls that environment your **Bash environment**. The separate machine that joins the cluster is the **flex node host**.
- Install the Azure CLI. Run `az --version` to find the installed version. To install or upgrade, see [Install the Azure CLI](/cli/azure/install-azure-cli).
- Sign in to Azure with an account that can read the target subscription and virtual network configuration.
- Prepare an existing Azure virtual network and subnet for the Azure-managed AKS nodes. The virtual network can be in a different resource group from the AKS cluster. When it is, ensure that the AKS cluster identity has the required permissions on the subnet.

## Make the deployment decisions

Plan the following decisions before you create or configure resources.

| Decision | Options | What the decision controls |
| --- | --- | --- |
| Host identity | Managed identity, Azure Arc managed identity, or service principal | How the flex node agent authenticates to Azure |
| AKS API access | Public or private AKS cluster | How your Bash environment and flex node hosts resolve and reach the Kubernetes API server |
| Flex node connectivity | Layer 3 connectivity or an Unbounded-Net WireGuard gateway | How AKS-managed nodes, flex nodes, pods, and Kubernetes services communicate |

These decisions address different parts of the deployment. For example, selecting a public AKS API endpoint doesn't create network connectivity between AKS-managed nodes and flex node hosts.

### Choose the host identity

Use the decision table in [identity and access concepts for flex nodes](./flex-nodes-identity-access-concepts.md) to choose the Azure identity that the flex node agent uses.

The host identity authorizes Azure operations. It doesn't replace the network connectivity or Kubernetes bootstrap configuration that the host needs to join the cluster. Don't store credentials in the shared environment file.

### Choose public or private AKS API access

The Kubernetes API server is the management endpoint for the cluster. Your Bash environment and each flex node host must be able to resolve and connect to this endpoint.

- **Public AKS API access** uses a secured public endpoint. Kubernetes authentication and authorization still control access to the cluster. A public API endpoint doesn't expose the applications running in the cluster.
- **Private AKS API access** uses a private endpoint in the AKS virtual network. Run Azure CLI, `kubectl`, and cluster setup commands in your Bash environment, which must run on a machine connected to that private network. The flex node network must also be able to resolve the cluster's private DNS name and route traffic to the private endpoint.

Flex node deployments support both public and private access to the API server. The private path requires additional DNS, routing, and command-execution configuration, called out where it applies. For general AKS guidance, see [Plan control plane networking for AKS](./plan-control-plane-networking.md), [Create a private AKS cluster](./private-clusters.md), and [Connect to a private AKS cluster](./private-cluster-connect.md).

### Choose the flex node connectivity

This deployment series creates the AKS cluster without a built-in network plugin and installs Unbounded-Net on both the AKS-managed nodes and flex nodes. Unbounded-Net assigns pod address ranges and configures routing between the AKS and flex node environments. This article describes that workflow. Other CNI or network configurations might require different routing, firewall, DNS, gateway, security, and lifecycle configuration. For an explanation of the public-preview networking model, see [networking concepts for flex nodes](./flex-nodes-networking-concepts.md).

You provide the underlying network connection between the AKS and flex node environments. Layer 3 connectivity means that both node networks can already route IP packets to each other's node addresses, in both directions. Choose the method that fits your existing network:

| Connectivity method | When to use it |
| --- | --- |
| [Virtual network peering](/azure/virtual-network/tutorial-connect-virtual-networks) | The AKS cluster and flex node hosts are in Azure virtual networks, including virtual networks in different regions. |
| [VPN Gateway](/azure/vpn-gateway/tutorial-site-to-site-portal) | The flex node hosts are in an on-premises environment or another network that connects to Azure through an encrypted site-to-site VPN. |
| [ExpressRoute](/azure/expressroute/expressroute-howto-circuit-portal-resource-manager) | Your organization uses a dedicated private connection between its network and Azure. |
| Unbounded-Net WireGuard gateway | The AKS and flex node networks don't have a private routed connection. You configure and operate the WireGuard tunnels on an AKS gateway node pool, and those gateway nodes must be publicly accessible. Plan for gateway capacity and availability, because cross-environment pod traffic depends on this pool. See the [public AKS cluster with Unbounded-Net WireGuard lab](https://aka.ms/aks-flex-node/wireguard-lab). |

The Microsoft Learn walkthrough uses Layer 3 connectivity with Unbounded-Net.

| AKS API | Flex node connectivity | Guidance |
| --- | --- | --- |
| Public | Layer 3 connectivity | Recommended configuration |
| Private | Layer 3 connectivity | Requires additional DNS, routing, and command-execution configuration |
| Public | Public WireGuard gateway | Alternative topology; see the AKSFlexNode labs |
| Private | Public WireGuard gateway | Not covered by this documentation |

> [!NOTE]
> For additional topology examples, see the [AKSFlexNode labs](https://aka.ms/aks-flex-node/labs), including examples that use a public AKS API server with a WireGuard gateway and a private AKS API server with customer-managed networking. These labs supplement the configuration documented in this article.
> These labs might use different networking components and have different operational or support responsibilities. Before using a lab, review its prerequisites, limitations, applicable component versions, and customer responsibilities. A GitHub lab doesn't expand the support scope documented in Microsoft Learn.
>
> To provide feedback about a topology that isn't represented, [open an issue in the AKSFlexNode repository](https://aka.ms/aks-flex-node/issues). Include the flex node host location, AKS API access model, proposed connectivity method, proposed CNI, and the network paths required by the scenario.

### Plan the required network connectivity

Work with your network administrator to ensure the network design provides the following connectivity:

| Requirement | Why it's required |
| --- | --- |
| Your Bash environment can resolve and reach the AKS API server. | You need this connection to configure and manage the cluster. |
| Each flex node host can resolve and reach the AKS API server. | The flex node agent and kubelet use this connection to join the cluster and communicate with the Kubernetes control plane. |
| AKS-managed nodes and flex node hosts can reach each other's private IP addresses. | For most connectivity methods, Unbounded-Net uses the node networks as the underlying path between the two environments. |
| Pod and Kubernetes service traffic can route between AKS-managed nodes and flex nodes. | Workloads need cross-node communication, cluster DNS, and Kubernetes service access. |
| The AKS control plane can connect to the kubelet on a flex node. | AKS uses this path for kubelet operations, including `kubectl logs`, `kubectl exec`, and `kubectl port-forward`. |

You configure and operate the external host network, including routing, virtual network peering, VPN or ExpressRoute connections, firewall and network security group rules, DNS, proxy settings, and the Unbounded-Net configuration documented in this series. For the full responsibility model, see [support policy for flex nodes](./flex-nodes-support-policy.md).

Restrict host management access to approved source addresses. For an Azure VM, associate a network security group with the host subnet or network interface. For a host outside Azure, apply equivalent firewall controls. If you use `az vm create` to create a flex node host, review any public IP address and network security group rules that the command creates. Unless you restrict the SSH rule, it can allow connections to TCP port 22 from any public source.

## Collect the deployment values

The remaining articles reuse the following values.

### Common Azure resource values

| Variable | Description | When it's used |
| --- | --- | --- |
| `SUBSCRIPTION_ID` | Subscription that contains the AKS cluster and related Azure resources. | Every deployment |
| `RESOURCE_GROUP` | Resource group that contains the AKS cluster. | Every deployment |
| `CLUSTER_NAME` | Name of the AKS cluster. | Every deployment |
| `FLEX_POOL_NAME` | Name of the flex node pool. Use letters and digits only. | Every deployment |
| `AKS_API_ACCESS` | API access model for the AKS cluster. Set the value to `public` or `private`. | Cluster preparation and API connectivity validation |
| `AKS_RESOURCE_ID` | Azure resource ID of the AKS cluster. Azure provides this value after the cluster exists. | Later articles |

### AKS cluster and virtual network values

| Variable | Description | When it's used |
| --- | --- | --- |
| `LOCATION` | Azure region for the AKS cluster. Confirm that this region meets the [regional availability](#regional-availability) requirement. | Creating the AKS cluster |
| `AKS_VNET_NAME` | Name of the virtual network that contains the AKS subnet. | Finding and validating the AKS subnet |
| `AKS_VNET_RESOURCE_GROUP` | Resource group that contains the AKS virtual network. It can differ from `RESOURCE_GROUP`. | Finding and validating the AKS subnet |
| `AKS_SUBNET_NAME` | Name of the subnet used by the Azure-managed AKS nodes. | Finding and validating the AKS subnet |
| `AKS_SUBNET_ID` | Azure resource ID of the AKS subnet. | Creating the AKS cluster |
| `AKS_NODE_VM_SIZE` | Azure VM size for the Azure-managed AKS system node pool. This value doesn't size the flex node host. | Creating the AKS cluster |
| `SERVICE_CIDR` | Address range for Kubernetes services. | Configuring the AKS cluster network profile |
| `DNS_SERVICE_IP` | IP address for the Kubernetes DNS service. | Configuring the AKS cluster network profile |

Retrieve the AKS subnet resource ID and address ranges before you create the environment file:

```azurecli
az network vnet subnet show \
    --resource-group '<virtual-network-resource-group>' \
    --vnet-name '<virtual-network-name>' \
    --name '<aks-subnet-name>' \
    --query "{ResourceId:id,AddressPrefix:addressPrefix,AddressPrefixes:addressPrefixes}" \
    --output json
```

### AKS and Unbounded-Net address values

You use `SERVICE_CIDR` and `DNS_SERVICE_IP` to configure the AKS cluster network profile. Configure the node and pod CIDRs to set up the Unbounded-Net Sites used by this walkthrough.

The AKS node, AKS pod, flex node, flex pod, and Kubernetes service ranges must follow the selected network design and must not overlap one another or any network reachable through virtual network peering, VPN, or ExpressRoute. Coordinate the final values with your network administrator.

Don't copy example CIDRs from another deployment. CIDRs identify routable address space, so reusing an example that overlaps your Azure or connected networks can make traffic ambiguous or prevent nodes and pods from reaching each other.

| Variable | Description | Used by |
| --- | --- | --- |
| `AKS_SUBNET_CIDR` | Address range assigned to the subnet for Azure-managed AKS nodes. | Azure virtual network and AKS subnet validation |
| `AKS_NODE_CIDR` | Unbounded-Net Site node range that contains the AKS node subnet. | Unbounded-Net primary cluster Site |
| `AKS_POD_CIDR` | Address pool for pods on Azure-managed AKS nodes. | Unbounded-Net primary cluster Site |
| `FLEX_HOST_SUBNET_CIDR` | Address range that contains the flex node hosts. | Flex node host network validation |
| `FLEX_NODE_CIDR` | Unbounded-Net Site node range that contains the flex node host subnet. | Unbounded-Net Site for flex nodes |
| `FLEX_POD_CIDR` | Address pool for pods on flex nodes. | Unbounded-Net Site for flex nodes |
| `SERVICE_CIDR` | Address range for Kubernetes services. | AKS cluster network profile |
| `DNS_SERVICE_IP` | IP address for the Kubernetes DNS service. | AKS cluster network profile |

Apply the following rules to the address plan:

- `AKS_SUBNET_CIDR` must be contained within `AKS_NODE_CIDR`.
- `FLEX_HOST_SUBNET_CIDR` must be contained within `FLEX_NODE_CIDR`.
- `DNS_SERVICE_IP` must be inside `SERVICE_CIDR`.

These eight values aren't eight separate ranges. Five are independent ranges that must not overlap, two are subnet ranges contained within their corresponding Site node range, and one is a single IP address inside the service range.

The following values satisfy every rule in this section. Treat them as an illustration of the relationships, not as defaults. Confirm your own values against your Azure and connected network address space before you use them.

| Variable | Example | Relationship |
| --- | --- | --- |
| `AKS_NODE_CIDR` | `10.10.0.0/16` | Independent range |
| `AKS_SUBNET_CIDR` | `10.10.1.0/24` | Contained within `AKS_NODE_CIDR` |
| `AKS_POD_CIDR` | `10.244.0.0/16` | Independent range |
| `FLEX_NODE_CIDR` | `10.20.0.0/16` | Independent range |
| `FLEX_HOST_SUBNET_CIDR` | `10.20.1.0/24` | Contained within `FLEX_NODE_CIDR` |
| `FLEX_POD_CIDR` | `10.245.0.0/16` | Independent range |
| `SERVICE_CIDR` | `10.96.0.0/16` | Independent range |
| `DNS_SERVICE_IP` | `10.96.0.10` | Inside `SERVICE_CIDR` |

Review the current Azure virtual network address spaces:

```azurecli
az network vnet list \
    --query "[].{ResourceGroup:resourceGroup,Name:name,AddressPrefixes:addressSpace.addressPrefixes}" \
    --output table
```

Azure can identify conflicts within the resources that it manages, but it can't validate address ranges in every connected on-premises or external network.

### Component version values

Flex nodes require compatible versions of AKS, the Azure CLI extension, Unbounded-Net, and the flex node agent. Use the versions listed in this article, and don't select or upgrade these components independently.

| Variable | Description |
| --- | --- |
| `AKS_VERSION` | Supported Kubernetes version for the AKS cluster. |
| `AKS_PREVIEW_VERSION` | `aks-preview` Azure CLI extension version `22.0.0b8` or later. |
| `UNBOUNDED_VERSION` | Supported Unbounded-Net version. |
| `AKS_FLEX_NODE_VERSION` | Supported flex node agent version. |

### Regional availability

Flex nodes require AKS release `v20260904` or later in the region that hosts your cluster. AKS applies these date-based releases automatically, and they're separate from the Kubernetes version that you set in `AKS_VERSION`.

Before you create or select a cluster, open the **AKS Release** tab of the [AKS release tracker](https://releases.aks.azure.com/AKSRelease), find your region, and check the version under **Currently in Operation**. AKS release versions use the `vYYYYMMDD` format. If your region shows an earlier version, wait for the release to reach the region or, if your deployment requirements allow, select a region where the required release is available.

### Local workspace value

| Variable | Description |
| --- | --- |
| `WORK_DIR` | Directory in your Bash environment where the remaining articles store downloads, generated files, and the cluster kubeconfig file. The default value is `~/.local/share/aksflexnode/<deployment-name>`. To keep these files somewhere else, such as a temporary directory that you remove after the deployment, change the `WORK_DIR` value in the environment file. |

## Create the shared environment file

Create one environment file for each deployment. The file keeps the nonsecret values consistent across the remaining articles and terminal sessions.

Don't store access tokens, bootstrap data, kubeconfig content, service principal credentials, certificates, certificate private keys, or SSH private keys in this file.

1. Choose a short deployment label and create a protected directory for the environment file.

    ```bash
    export FLEXNODE_DEPLOYMENT="flexnode-demo"
    export FLEXNODE_ENV_DIR="${HOME}/.config/aks-flexnode"
    export FLEXNODE_ENV_FILE="${FLEXNODE_ENV_DIR}/${FLEXNODE_DEPLOYMENT}.env"

    install -d -m 0700 "${FLEXNODE_ENV_DIR}"
    ```

1. Create the environment file.

    ```bash
    if [[ -e "${FLEXNODE_ENV_FILE}" ]]; then
        printf 'Environment file already exists: %s\n' "${FLEXNODE_ENV_FILE}" >&2
        false
    else
        install -m 0600 /dev/null "${FLEXNODE_ENV_FILE}"

        cat > "${FLEXNODE_ENV_FILE}" <<'EOF'
    set_flexnode_env() {
        if [[ "$#" -ne 2 || ! "$1" =~ ^[A-Za-z_][A-Za-z0-9_]*$ ]]; then
            printf 'Usage: set_flexnode_env NAME VALUE\n' >&2
            return 2
        fi

        local name="$1"
        local value="$2"
        local temporary_file

        temporary_file="$(mktemp "$(dirname "${FLEXNODE_ENV_FILE}")/flexnode.env.XXXXXX")" || return 1
        awk -v prefix="export ${name}=" 'index($0, prefix) != 1 { print }' \
            "${FLEXNODE_ENV_FILE}" > "${temporary_file}" || {
            rm -f "${temporary_file}"
            return 1
        }

        printf 'export %s=%q\n' "${name}" "${value}" >> "${temporary_file}" || {
            rm -f "${temporary_file}"
            return 1
        }

        install -m 0600 "${temporary_file}" "${FLEXNODE_ENV_FILE}" || {
            rm -f "${temporary_file}"
            return 1
        }

        rm -f "${temporary_file}"
        export "${name}=${value}"
    }

    # Customer inputs
    export SUBSCRIPTION_ID='<subscription-id>'
    export LOCATION='<supported-aks-region>'
    export RESOURCE_GROUP='<aks-resource-group>'
    export CLUSTER_NAME='<aks-cluster-name>'
    export FLEX_POOL_NAME='<flex-node-pool-name>'
    export AKS_API_ACCESS='<public-or-private>'

    # AKS virtual network
    export AKS_VNET_NAME='<virtual-network-name>'
    export AKS_VNET_RESOURCE_GROUP='<virtual-network-resource-group>'
    export AKS_SUBNET_NAME='<aks-subnet-name>'
    export AKS_SUBNET_ID='<aks-subnet-resource-id>'

    # Network address ranges
    export AKS_SUBNET_CIDR='<aks-node-subnet-cidr>'
    export AKS_POD_CIDR='<aks-pod-cidr>'
    export AKS_NODE_CIDR='<aks-site-node-cidr>'
    export FLEX_HOST_SUBNET_CIDR='<flex-host-subnet-cidr>'
    export FLEX_NODE_CIDR='<flex-site-node-cidr>'
    export FLEX_POD_CIDR='<flex-node-pod-cidr>'
    export SERVICE_CIDR='<kubernetes-service-cidr>'
    export DNS_SERVICE_IP='<kubernetes-dns-service-ip>'

    # Azure-managed AKS system node pool
    export AKS_NODE_VM_SIZE='<supported-and-available-aks-node-vm-size>'

    # Compatible component versions for flex nodes (preview)
    export AKS_VERSION='1.36.2'
    export AKS_PREVIEW_VERSION='22.0.0b8'
    export UNBOUNDED_VERSION='v0.8.0'
    export AKS_FLEX_NODE_VERSION='v0.2.0'

    # Local paths
    export WORK_DIR="${HOME}/.local/share/aksflexnode/${FLEXNODE_DEPLOYMENT}"

    # Values recorded by later articles
    export AKS_RESOURCE_ID=''
    export FLEXNODE_KUBECONFIG=''
    export FLEX_POOL_RESOURCE_ID=''
    export FLEX_MACHINE_NAME=''
    export FLEX_HOST_NAME=''
    export FLEX_HOST_SSH_TARGET=''
    export FLEX_HOST_PRIVATE_IP=''
    export HOST_PRINCIPAL_OBJECT_ID=''
    export HOST_IDENTITY_CLIENT_ID=''
    export SSH_PUBLIC_KEY_PATH=''
    export SSH_PRIVATE_KEY_PATH=''
    export VM_RESOURCE_GROUP=''
    export VM_NAME=''
    export VM_RESOURCE_ID=''
    export ARC_RESOURCE_GROUP=''
    export ARC_MACHINE_NAME=''
    export ARC_RESOURCE_ID=''
    export SP_TENANT_ID=''
    export SP_CLIENT_ID=''
    export SP_OBJECT_ID=''
    EOF
    fi
    ```

    The `set_flexnode_env` helper lets later articles record Azure-generated values without adding duplicate definitions to the file.

1. Open `${FLEXNODE_ENV_FILE}` in an editor and replace each value enclosed in angle brackets. Leave the values under **Values recorded by later articles** empty.

1. Check that no placeholders remain.

    ```bash
    if grep -n '<[^>]*>' "${FLEXNODE_ENV_FILE}"; then
        printf 'Replace the unresolved placeholders before you continue.\n' >&2
        false
    else
        printf 'No unresolved placeholders found.\n'
    fi
    ```

1. Load the environment file, create the working directory, and set the active Azure subscription.

    ```bash
    source "${FLEXNODE_ENV_FILE}"
    install -d -m 0700 "${WORK_DIR:?Load the deployment environment first.}"
    az account set --subscription "${SUBSCRIPTION_ID}"
    az account show \
        --query "{Name:name,SubscriptionId:id}" \
        --output table
    ```

    Confirm that the returned subscription ID matches `SUBSCRIPTION_ID`.

    Confirm that `AKS_API_ACCESS` identifies a supported path:

    ```bash
    case "${AKS_API_ACCESS}" in
        public|private)
            printf 'AKS API access: %s\n' "${AKS_API_ACCESS}"
            ;;
        *)
            printf 'Set AKS_API_ACCESS to public or private.\n' >&2
            false
            ;;
    esac
    ```

    Start each new terminal session by setting the deployment label and loading its environment file:

    ```bash
    export FLEXNODE_DEPLOYMENT="flexnode-demo"
    export FLEXNODE_ENV_FILE="${HOME}/.config/aks-flexnode/${FLEXNODE_DEPLOYMENT}.env"
    test -s "${FLEXNODE_ENV_FILE}"
    source "${FLEXNODE_ENV_FILE}"
    install -d -m 0700 "${WORK_DIR:?Load the deployment environment first.}"
    ```

## Validate the planning values

Verify the selected AKS subnet.

```azurecli
az network vnet subnet show \
    --resource-group "${AKS_VNET_RESOURCE_GROUP}" \
    --vnet-name "${AKS_VNET_NAME}" \
    --name "${AKS_SUBNET_NAME}" \
    --query "{AddressPrefix:addressPrefix,AddressPrefixes:addressPrefixes,ResourceId:id}" \
    --output json
```

Confirm that the returned resource ID and address range match `AKS_SUBNET_ID` and `AKS_SUBNET_CIDR`.

## Next step

Next, [prepare an AKS cluster for flex nodes](./prepare-aks-cluster-for-flex-nodes.md). The next article creates the public or private AKS cluster and records the cluster resource ID.
