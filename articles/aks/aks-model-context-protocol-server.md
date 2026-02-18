---
title: Connect your Azure Kubernetes Service (AKS) cluster to AI agents using the Model Context Protocol (MCP) server
description: Learn how to install and use the Model Context Protocol (MCP) server to intelligently troubleshoot and manage your Azure Kubernetes Service (AKS) clusters.
author: juliayin
ms.topic: how-to
ms.date: 01/27/2026
ms.author: juliayin
ms.service: azure-kubernetes-service
# Customer intent: "As a developer managing Kubernetes clusters, I want to use the AKS extension for my code editor, so that I can efficiently view and manage my clusters directly from my development environment."
---

# Connect your Azure Kubernetes Service (AKS) cluster to AI agents using the Model Context Protocol (MCP) server

The AKS Model Context Protocol (MCP) server enables AI assistants to interact with Azure Kubernetes Service (AKS) clusters with clarity, safety, and control. It serves as a bridge between AI tools (like GitHub Copilot, Claude, and other MCP-compatible AI assistants) and AKS, translating natural language requests into AKS operations and returning the results in a format the AI tools can understand. 

The AKS MCP server connects to Azure using the Azure SDK and provides a set of tools that AI assistants can use to interact with AKS resources. These tools allow AI agents to perform tasks like:

- Troubleshooting and diagnostics
- Analyze the health of your cluster
- Operate (CRUD) AKS resources
- Retrieve details related to AKS clusters (VNets, Subnets, Network Security Groups (NSGs), Route Tables, etc.)
- Enabling best practices and recommended features
- Manage Azure Fleet operations for multi-cluster scenarios

The AKS MCP server is fully open-sourced project, with example templates and Helm configurations available in the GitHub repository.

## When to use the AKS MCP server

The AKS MCP server can be used with any compatible AI assistant, including the [agentic CLI for AKS](./agentic-cli-for-aks-overview.md) and Microsoft Copilot. Common use cases include:

- Asking AI assistants questions like:
  - "Why are pods pending in this cluster?"
  - "What is the network configuration of my AKS cluster?"
  - "Create a placement to deploy nginx workloads to clusters with app=frontend label."
- Allowing AI tools to:
  - Read cluster state and configuration
  - Inspect metrics, events, and logs
  - Correlate signals across Kubernetes and Azure resources
  - Apply changes and enable new features directly on your cluster

All actions performed through the AKS MCP server are constrained by Kubernetes Role-Based Access Control (RBAC) and Azure RBAC. By default, the AKS MCP server inherits the user's permissions when accessing cluster and Azure resources. To customize the roles and permissions of the AKS MCP server, deploy the remote AKS MCP server mode with built-in RBAC control.

## Available tools

The AKS MCP server provides a comprehensive set of tools for interacting with AKS clusters and associated resources. By default, the server uses **unified tools** (`call_az` for Azure operations and `call_kubectl` for Kubernetes operations) which provide a more flexible interface for interacting with Kubernetes and Azure resources.

There are three sets of permissions you can enable for the AKS MCP server: read-only (default), read-write, and admin. Some tools require read-write or admin permissions to perform actions like deploying debugging pods or CRUD actions on your cluster. To enable read-write or admin permissions for the AKS-MCP server, add the **access level** parameter to your MCP configuration file:

1. Navigate to your **mcp.json** file, or go to MCP: List Servers -> AKS-MCP -> Show Configuration Details in the **Command Palette** (For VS Code; `Ctrl+Shift+P` on Windows/Linux or `Cmd+Shift+P` on macOS).
2. In the "args" section of AKS-MCP, add the following parameters: "--access-level," "readwrite" or "admin"

For example:
```
"args": [
  "--transport",
  "stdio",
  "--access-level",
  "readwrite"
]
```

These tools are designed to provide comprehensive functionality through unified interfaces:

<details>
<summary>Azure CLI Operations (Unified Tool)</summary>

**Tool:** `call_az`

Unified tool for executing Azure CLI commands directly. This tool provides a flexible interface to run any Azure CLI command.

**Parameters:**
- `cli_command`: The complete Azure CLI command to execute. For example, `az aks list --resource-group myRG` or `az vm list --subscription <sub-id>`.
- `timeout`: Optional timeout in seconds (default: 120)

**Example Usage:**
```json
{
  "cli_command": "az aks list --resource-group myResourceGroup --output json"
}
```

**Access Control:**
- **readonly**: Only read operations are allowed
- **readwrite/admin**: Both read and write operations are allowed

> [!IMPORTANT]
> Commands must be simple Azure CLI invocations without shell features like pipes (|), redirects (>, <), command substitution, or semicolons (;).

</details>

<details>
<summary>Kubernetes Operations (Unified Tool)</summary>

### Unified kubectl Tool

**Tool:** `call_kubectl`

Unified tool for executing kubectl commands directly. This tool provides a flexible interface to run any `kubectl` command with full argument support.

**Parameters:**
- `args`: The kubectl command arguments. For example, `get pods`, `describe node mynode`, or `apply -f deployment.yaml`.

**Example Usage:**
```json
{
  "args": "get pods -n kube-system -o wide"
}
```

**Access Control:** Operations are restricted based on the configured access level:
- **readonly**: Only read operations (get, describe, logs, etc.) are allowed
- **readwrite/admin**: All operations including mutating commands (create, delete, apply, etc.)

### Helm

**Tool:** `call_helm`

Helm package manager for Kubernetes.

### Cilium

**Tool:** `call_cilium`

Cilium CLI for eBPF-based networking and security.

### Hubble

**Tool:** `call_hubble`

Hubble network observability for Cilium.

</details>

<details>
<summary>Network Resource Management</summary>

**Tool:** `aks_network_resources`

Unified tool for getting Azure network resource information used by AKS clusters.

**Available Resource Types:**

- `all`: Get information about all network resources
- `vnet`: Virtual Network information
- `subnet`: Subnet information
- `nsg`: Network Security Group information
- `route_table`: Route Table information
- `load_balancer`: Load Balancer information
- `private_endpoint`: Private endpoint information

</details>

<details>
<summary>Monitoring and Diagnostics</summary>

**Tool:** `aks_monitoring`

Unified tool for Azure monitoring and diagnostics operations for AKS clusters.

**Available Operations:**

- `metrics`: List metric values for resources
- `resource_health`: Retrieve resource health events for AKS clusters
- `app_insights`: Execute KQL queries against Application Insights telemetry data
- `diagnostics`: Check if AKS cluster has diagnostic settings configured
- `control_plane_logs`: Query AKS control plane logs with safety constraints and time range validation

</details>

<details>
<summary>Compute Resources</summary>

**Tool:** `get_aks_vmss_info`

- Get detailed configuration of your Virtual Machine Scale Sets (node pools) in the AKS cluster

</details>

<details>
<summary>Fleet Management</summary>

**Tool:** `az_fleet`

Comprehensive Azure Fleet management for multi-cluster scenarios.

**Available Operations:**

- **Fleet Operations**: list, show, create, update, delete, get-credentials
- **Member Operations**: list, show, create, update, delete
- **Update Run Operations**: list, show, create, start, stop, delete
- **Update Strategy Operations**: list, show, create, delete
- **ClusterResourcePlacement Operations**: list, show, get, create, delete

Supports both Azure Fleet management and Kubernetes ClusterResourcePlacement CRD operations.

</details>

<details>
<summary>Diagnostic Detectors</summary>

**Tool:** `aks_detector`

Unified tool for executing AKS diagnostic detector operations.

**Available Operations:**

- `list`: List all available AKS cluster detectors
- `run`: Run a specific AKS diagnostic detector
- `run_by_category`: Run all detectors in a specific category

**Parameters:**

- `operation` (required): Operation to perform (`list`, `run`, or `run_by_category`)
- `aks_resource_id` (required): AKS cluster resource ID
- `detector_name` (required for `run` operation): Name of the detector to run
- `category` (required for `run_by_category` operation): Detector category
- `start_time` (required for `run` and `run_by_category` operations): Start time in UTC ISO format (within last 30 days)
- `end_time` (required for `run` and `run_by_category` operations): End time in UTC ISO format (within last 30 days, max 24 hours from start)

**Available Categories:**

- Best Practices
- Cluster and Control Plane Availability and Performance
- Connectivity Issues
- Create, Upgrade, Delete, and Scale
- Deprecations
- Identity and Security
- Node Health
- Storage

**Example Usage:**

**Tool:** `run_detectors_by_category`
```json
{
  "operation": "list",
  "aks_resource_id": "/subscriptions/xxx/resourceGroups/xxx/providers/Microsoft.ContainerService/managedClusters/xxx"
}
```

```json
{
  "operation": "run",
  "aks_resource_id": "/subscriptions/xxx/resourceGroups/xxx/providers/Microsoft.ContainerService/managedClusters/xxx",
  "detector_name": "node-health-detector",
  "start_time": "2025-01-15T10:00:00Z",
  "end_time": "2025-01-15T12:00:00Z"
}
```

</details>

<details>
<summary>Azure Advisor</summary>

**Tool:** `aks_advisor_recommendation`

Retrieve and manage Azure Advisor recommendations for AKS clusters.

**Available Operations:**

- `list`: List recommendations with filtering options
- `report`: Generate recommendation reports
- **Filter Options**: resource_group, cluster_names, category (Cost,
  HighAvailability, Performance, Security), severity (High, Medium, Low)

</details>

<details>
<summary>Real-time Observability</summary>

**Tool:** `inspektor_gadget_observability`

Real-time observability tool for Azure Kubernetes Service (AKS) clusters using
eBPF.

**Available Actions:**

- `deploy`: Deploy Inspektor Gadget to cluster
- `undeploy`: Remove Inspektor Gadget from cluster
- `is_deployed`: Check deployment status
- `run`: Run one-shot gadgets
- `start`: Start continuous gadgets
- `stop`: Stop running gadgets
- `get_results`: Retrieve gadget results
- `list_gadgets`: List available gadgets

**Available Gadgets:**

- `observe_dns`: Monitor DNS requests and responses
- `observe_tcp`: Monitor TCP connections
- `observe_file_open`: Monitor file system operations
- `observe_process_execution`: Monitor process execution
- `observe_signal`: Monitor signal delivery
- `observe_system_calls`: Monitor system calls
- `top_file`: Top files by I/O operations
- `top_tcp`: Top TCP connections by traffic
- `tcpdump`: Capture network packets

</details>

## Getting started with the AKS MCP server

The AKS MCP server has two modes: local and remote. In this section, we cover the use cases and installation processes for both modes.

### Local MCP server

In local mode, the MCP server runs on a developer’s local machine and connects to AKS using the developer’s existing permissions. This mode is best for quickly setting up your local AI agent with AKS expertise and tooling without requiring any cluster-side components. Local mode can use the current cluster context and enforces the developer’s Kubernetes and Azure RBAC permissions. By default, the local AKS MCP server supports the STDIO and SSE transport modes.

#### Prerequisites

Before installing the AKS MCP server, set up [Azure CLI](/cli/azure/install-azure-cli) and authenticate:

```bash
az login
```

#### [Visual Studio Code with GitHub Copilot (Recommended)](#tab/vscode)

The easiest way to get started with AKS-MCP is through the **Azure Kubernetes Service Extension for VS Code**. The AKS extension handles binary downloads, updates, and configuration automatically, ensuring you always have the latest version with optimal settings.

**Step 1: Install the AKS Extension**

1. Open VS Code and go to Extensions (`Ctrl+Shift+X` on Windows/Linux or `Cmd+Shift+X` on macOS).
1. Search for **Azure Kubernetes Service**.
1. Install the official [Microsoft AKS extension](https://marketplace.visualstudio.com/items?itemName=ms-kubernetes-tools.vscode-aks-tools).

**Step 2: Launch the AKS-MCP Server**

1. Open the **Command Palette** (`Ctrl+Shift+P` on Windows/Linux or `Cmd+Shift+P` on macOS).
1. Search and run: **AKS: Setup AKS MCP Server**.

Upon successful installation, the server appears in **MCP: List Servers** (via Command Palette). From there, you can start the MCP server or view its status.

**Step 3: Start Using AKS-MCP**

Once started, the MCP server appears in the **Copilot Chat: Configure Tools** dropdown under `MCP Server: AKS MCP`, ready to enhance contextual prompts based on your AKS environment. By default, all AKS-MCP server tools are enabled. You can review the list of available tools and disable any that aren't required for your scenario.

Try a prompt like *"List all my AKS clusters"* to start using tools from the AKS-MCP server.

> [!TIP]
> **WSL Configuration**: If you're using VS Code on Windows with WSL, use `"command": "wsl"` to invoke the WSL binary. If VS Code is running inside WSL (Remote-WSL), call the binary directly or use a bash wrapper instead.

#### [Manual Binary Installation](#tab/manual)

For direct binary usage without the VS Code extension:

**Step 1: Download the Binary**

Choose your platform and download the latest AKS-MCP binary:

| Platform | Architecture | Download Link |
| -------- | ------------ | ------------- |
| **Windows** | AMD64 | [aks-mcp-windows-amd64.exe](https://github.com/Azure/aks-mcp/releases/latest/download/aks-mcp-windows-amd64.exe) |
| | ARM64 | [aks-mcp-windows-arm64.exe](https://github.com/Azure/aks-mcp/releases/latest/download/aks-mcp-windows-arm64.exe) |
| **macOS** | Intel (AMD64) | [aks-mcp-darwin-amd64](https://github.com/Azure/aks-mcp/releases/latest/download/aks-mcp-darwin-amd64) |
| | Apple Silicon (ARM64) | [aks-mcp-darwin-arm64](https://github.com/Azure/aks-mcp/releases/latest/download/aks-mcp-darwin-arm64) |
| **Linux** | AMD64 | [aks-mcp-linux-amd64](https://github.com/Azure/aks-mcp/releases/latest/download/aks-mcp-linux-amd64) |
| | ARM64 | [aks-mcp-linux-arm64](https://github.com/Azure/aks-mcp/releases/latest/download/aks-mcp-linux-arm64) |

**Step 2: Configure VS Code**

Create a `.vscode/mcp.json` file in your workspace root with the path to your downloaded binary:

**Workspace-specific configuration** (recommended for project-specific usage):

```json
{
  "servers": {
    "aks-mcp-server": {
      "type": "stdio",
      "command": "<path-to-binary>",
      "args": [
        "--transport", "stdio"
      ]
    }
  }
}
```

**User-level configuration** (persistent across all workspaces):

Add to your VS Code User Settings JSON (`Ctrl+,` or `Cmd+,`, then search for "mcp"):

```json
{
  "github.copilot.chat.mcp.servers": {
    "aks-mcp-server": {
      "type": "stdio",
      "command": "<path-to-binary>",
      "args": [
        "--transport", "stdio"
      ]
    }
  }
}
```

**Step 3: Load the AKS-MCP server tools**

1. Restart VS Code to load the new MCP server configuration.
1. Open GitHub Copilot in VS Code and [switch to Agent mode](https://code.visualstudio.com/docs/copilot/chat/chat-agent-mode).
1. Select the **Tools** button to see the list of available tools.
1. Verify that the AKS-MCP tools appear in the list.
1. Try a prompt like: *"List all my AKS clusters in subscription xxx."*

> [!TIP]
> If you don't see the AKS-MCP tools after restarting, check the VS Code output panel for any MCP server connection errors and verify your binary path in `.vscode/mcp.json`.

#### [Docker](#tab/docker)

You can run the AKS-MCP server using the official Docker image from Docker MCP Toolkit or as a containerized MCP configuration.

**Option 1: Docker MCP Toolkit**

1. Open Docker Desktop.
1. Select **MCP Toolkit** in the left sidebar.
1. Search for "aks" in Catalog tab.
1. Select the AKS-MCP server card.
1. Enable the server by selecting **+** in the top right corner.
1. Configure the server using **Configuration** tab:
   - **azure_dir** `[REQUIRED]`: Absolute path to your Azure credentials directory (for example, `/home/user/.azure`)
   - **kubeconfig** `[REQUIRED]`: Absolute path to your kubeconfig file (for example, `/home/user/.kube/config`)
   - **access_level** `[REQUIRED]`: Set to `readonly`, `readwrite`, or `admin` as needed
   - **container_user** `[OPTIONAL]`: Username or UID to run the container as (default is `mcp`). Use your host user ID (for example, `1000`) if running Docker Engine on Linux.

> [!NOTE]
> On Windows, Azure credentials don't work by default. Configure a custom Azure directory with token cache encryption disabled, or use the long-lived servers option to authenticate inside the container.

**Option 2: Containerized MCP configuration**

Mount credentials from host (recommended):

```json
{
  "mcpServers": {
    "aks": {
      "type": "stdio",
      "command": "docker",
      "args": [
        "run", "-i", "--rm",
        "--user", "<your-user-id>",
        "-v", "~/.azure:/home/mcp/.azure",
        "-v", "~/.kube:/home/mcp/.kube",
        "ghcr.io/azure/aks-mcp:latest",
        "--transport", "stdio"
      ]
    }
  }
}
```

To fetch credentials inside the container instead, omit the volume mounts and run the following commands after starting the container:

```bash
# Login to Azure CLI
docker exec -it <container-id> az login --use-device-code

# Get kubeconfig
docker exec -it <container-id> az aks get-credentials -g <resource-group> -n <cluster-name>
```

#### [Custom Client Installation](#tab/custom)

For other MCP-compatible AI clients like Claude Desktop, configure the server in your MCP configuration:

```json
{
  "mcpServers": {
    "aks": {
      "command": "<path-to-binary>",
      "args": [
        "--transport", "stdio"
      ]
    }
  }
}
```

You can also run the server directly from the command line:

```bash
./aks-mcp --transport stdio
```

**Command-line options:**

| Option | Description | Default |
| ------ | ----------- | ------- |
| `--access-level` | Access level (`readonly`, `readwrite`, `admin`) | `readonly` |
| `--enabled-components` | Comma-separated list of enabled components | all |
| `--allow-namespaces` | Comma-separated list of allowed Kubernetes namespaces | all |
| `--host` | Host to listen (SSE/HTTP transport only) | `127.0.0.1` |
| `--port` | Port to listen (SSE/HTTP transport only) | `8000` |
| `--transport` | Transport mechanism (`stdio`, `sse`, `streamable-http`) | `stdio` |
| `--timeout` | Timeout for command execution in seconds | `600` |
| `--log-level` | Log level (`debug`, `info`, `warn`, `error`) | `info` |

**Environment variables:**

- `USE_LEGACY_TOOLS`: Set to `true` to use legacy specialized tools instead of unified tools (default: `false`)
- Standard Azure authentication environment variables are supported (`AZURE_TENANT_ID`, `AZURE_CLIENT_ID`, `AZURE_CLIENT_SECRET`, `AZURE_SUBSCRIPTION_ID`)

---

### Remote MCP server

In remote mode, the MCP server runs as a workload inside the AKS cluster or any compute of your choosing. This mode is best for production environments with shared tooling, consistent permissions across users, and full access control using Kubernetes ServiceAccount and Workload Identity. The remote AKS MCP server uses the HTTP protocol to facilitate interactions between your AI assistant and AKS cluster.

#### Prerequisites

- AKS cluster with Kubernetes 1.19+
- Helm 3.8+
- Azure CLI installed and authenticated (`az login`)

#### Install with the Helm chart

Clone the repository and install the AKS-MCP Helm chart:

```bash
git clone https://github.com/Azure/aks-mcp.git
cd aks-mcp/chart

helm install aks-mcp . --namespace aks-mcp --create-namespace
```

For the complete list of configuration parameters, see the [Helm chart documentation](https://github.com/Azure/aks-mcp/tree/main/chart).

#### Configure authentication

Choose an authentication method based on your environment and security requirements:

##### [Workload Identity (Recommended)](#tab/workload-identity)

Workload Identity provides passwordless authentication by linking a Kubernetes ServiceAccount to an Azure Managed Identity.

**1. Enable OIDC on your AKS cluster**

```bash
az aks update \
  --resource-group <your-resource-group> \
  --name <your-aks-cluster> \
  --enable-oidc-issuer \
  --enable-workload-identity
```

**2. Create a Managed Identity and assign RBAC permissions**

```bash
# Create identity
az identity create --resource-group <your-resource-group> --name aks-mcp-identity --location <your-location>

# Get IDs
IDENTITY_CLIENT_ID=$(az identity show --resource-group <your-resource-group> --name aks-mcp-identity --query "clientId" -o tsv)
IDENTITY_PRINCIPAL_ID=$(az identity show --resource-group <your-resource-group> --name aks-mcp-identity --query "principalId" -o tsv)

# Assign Reader role (use Contributor for readwrite access)
az role assignment create --role "Reader" --assignee-object-id $IDENTITY_PRINCIPAL_ID --assignee-principal-type ServicePrincipal --scope "/subscriptions/<subscription-id>"
```

**3. Create a federated identity credential**

```bash
AKS_OIDC_ISSUER=$(az aks show --resource-group <your-resource-group> --name <your-aks-cluster> --query "oidcIssuerProfile.issuerUrl" -o tsv)

az identity federated-credential create \
  --name "aks-mcp-federated-credential" \
  --identity-name aks-mcp-identity \
  --resource-group <your-resource-group> \
  --issuer $AKS_OIDC_ISSUER \
  --subject "system:serviceaccount:aks-mcp:aks-mcp" \
  --audience api://AzureADTokenExchange
```

> [!IMPORTANT]
> Create the federated credential **before** installing the Helm chart.

**4. Install with Workload Identity enabled**

```bash
helm install aks-mcp . \
  --namespace aks-mcp \
  --create-namespace \
  --set workloadIdentity.enabled=true \
  --set azure.clientId=$IDENTITY_CLIENT_ID \
  --set azure.subscriptionId=<your-subscription-id>
```

##### [OAuth for Read-Write Access](#tab/oauth)

Enable OAuth authentication to require user sign-in for read-write or admin operations:

```bash
helm install aks-mcp . \
  --namespace aks-mcp \
  --create-namespace \
  --set app.accessLevel=readwrite \
  --set oauth.enabled=true \
  --set oauth.tenantId=<your-tenant-id> \
  --set oauth.clientId=<your-oauth-client-id> \
  --set azure.subscriptionId=<your-subscription-id>
```

##### [Service Principal with Existing Secret](#tab/service-principal)

Use a Kubernetes secret containing Service Principal credentials:

```bash
# Create secret first
kubectl create secret generic azure-credentials \
  --namespace aks-mcp \
  --from-literal=tenant-id=<your-tenant-id> \
  --from-literal=client-id=<your-client-id> \
  --from-literal=client-secret=<your-client-secret> \
  --from-literal=subscription-id=<your-subscription-id>

# Install with existing secret
helm install aks-mcp . \
  --namespace aks-mcp \
  --set app.accessLevel=readonly \
  --set azure.existingSecret=azure-credentials
```

##### [Direct Credentials](#tab/direct)

Pass credentials directly via Helm values (not recommended for production):

```bash
helm install aks-mcp . \
  --namespace aks-mcp \
  --create-namespace \
  --set azure.tenantId=<your-tenant-id> \
  --set azure.clientId=<your-client-id> \
  --set azure.clientSecret=<your-client-secret>
```

---

#### Enable Ingress with Azure App Routing

Expose the MCP server externally using Azure App Routing:

```bash
# Enable App Routing on your cluster
az aks approuting enable --resource-group <your-resource-group> --name <your-cluster-name>

# Install with Ingress enabled
helm install aks-mcp . \
  --namespace aks-mcp \
  --create-namespace \
  --set ingress.enabled=true \
  --set ingress.hosts[0].host=aks-mcp.example.com \
  --set ingress.hosts[0].paths[0].path=/ \
  --set ingress.hosts[0].paths[0].pathType=Prefix \
  --set azure.existingSecret=azure-credentials
```

#### Connect your MCP client

After deployment, connect your AI assistant to the remote MCP server:

```bash
# Port forward for local testing
kubectl port-forward svc/aks-mcp 8000:8000 -n aks-mcp
```

Configure your MCP client to connect:

```json
{
  "mcpServers": {
    "aks-mcp": {
      "url": "http://localhost:8000",
      "transport": "streamable-http"
    }
  }
}
```

For in-cluster access, use: `http://aks-mcp.aks-mcp.svc.cluster.local:8000`

#### Helm configuration reference

| Parameter | Description | Default |
| --------- | ----------- | ------- |
| `workloadIdentity.enabled` | Enable Azure Workload Identity | `false` |
| `azure.clientId` | Azure Client ID | `""` |
| `azure.tenantId` | Azure Tenant ID | `""` |
| `azure.clientSecret` | Azure Client Secret | `""` |
| `azure.subscriptionId` | Azure Subscription ID | `""` |
| `azure.existingSecret` | Use an existing Kubernetes secret | `""` |
| `app.accessLevel` | Access level: `readonly`, `readwrite`, `admin` | `readonly` |
| `app.transport` | Transport: `stdio`, `sse`, `streamable-http` | `streamable-http` |
| `oauth.enabled` | Enable OAuth authentication | `false` |
| `ingress.enabled` | Enable Ingress | `false` |

## Uninstall the AKS MCP server

The process of uninstalling the AKS MCP server depends on the deployment mode and where it's currently running.

### [Local Installation](#tab/uninstall-local)

#### VS Code with AKS Extension

1. Open the **Command Palette** (`Ctrl+Shift+P` on Windows/Linux or `Cmd+Shift+P` on macOS).
1. Run **MCP: List Servers**.
1. Select **AKS MCP** from the list.
1. Select **Stop Server** to stop the running server.
1. To remove the configuration, select **Delete Server Configuration**.

Alternatively, manually remove the server configuration:

1. Open your `.vscode/mcp.json` file or VS Code User Settings.
1. Delete the `aks-mcp-server` entry from the `servers` or `github.copilot.chat.mcp.servers` object.
1. Delete the AKS-MCP binary from your system (location varies based on installation method).

#### Docker

If using Docker MCP Toolkit:

1. Open Docker Desktop.
1. Select **MCP Toolkit** in the left sidebar.
1. Find the AKS-MCP server and disable it.

If using a containerized configuration, stop and remove the container:

```bash
docker stop <container-id>
docker rm <container-id>
```

#### Other MCP Clients

Remove the `aks` or `aks-mcp` entry from your MCP client configuration file (for example, Claude Desktop's `claude_desktop_config.json`).

### [Remote Installation](#tab/uninstall-remote)

#### Remove the Helm release

```bash
helm uninstall aks-mcp --namespace aks-mcp
```

#### Clean up the namespace (optional)

```bash
kubectl delete namespace aks-mcp
```

#### Clean up Azure resources (Workload Identity only)

If you configured Workload Identity, remove the associated Azure resources:

```bash
# Delete the federated credential
az identity federated-credential delete \
  --name "aks-mcp-federated-credential" \
  --identity-name aks-mcp-identity \
  --resource-group <your-resource-group>

# Remove role assignments
IDENTITY_PRINCIPAL_ID=$(az identity show --resource-group <your-resource-group> --name aks-mcp-identity --query "principalId" -o tsv)
az role assignment delete --assignee $IDENTITY_PRINCIPAL_ID --scope "/subscriptions/<subscription-id>"

# Delete the managed identity
az identity delete --resource-group <your-resource-group> --name aks-mcp-identity
```

#### Delete the Kubernetes secret (Service Principal only)

If you created a secret for Service Principal credentials:

```bash
kubectl delete secret azure-credentials --namespace aks-mcp
```

---

## Common issues and troubleshooting

This section outlines common setup and runtime issues, their symptoms, and how to resolve them.

### AKS MCP server can't access the cluster

Symptoms:
- Tools return authorization errors
- No resources are visible

Likely causes:
- User or MCP identity doesn't have sufficient permissions
- Incorrect ServiceAccount binding
- Misconfigured kubeconfig context (local mode)

Resolution:
- Local mode: Check that you have sufficient permissions to access the cluster. Verify that you are in the right cluster and subscription context.
- Remote mode: Verify the ClusterRole bindings for the ServiceAccount used by the MCP server

### Azure API calls fail

Symptoms:
- call_az tools return authentication or authorization errors

Likely causes:
- Workload Identity not enabled for your cluster
- ServiceAccount not federated
- Missing Azure RBAC assignments

Resolution:
- Check that Workload Identity is enabled on your cluster
- Verify federated identity configuration
- Assign appropriate Azure roles to the managed identity

## Next steps
Learn more about the intelligent features built natively for AKS:
- About the agentic CLI for AKS
- Install and use the agentic CLI for AKS