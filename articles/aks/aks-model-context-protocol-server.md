---
title: Connect your Azure Kubernetes Service (AKS) cluster to AI agents using the Model Context Protocol (MCP) server
description: Learn how to install and use the Model Context Protocol (MCP) server to intelligently troubleshoot and manage your Azure Kubernetes Service (AKS) clusters.
author: juliayin
ms.topic: how-to
ms.date: 10/06/2026
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

The AKS MCP server is a fully open-source project. For source code and releases, see the [AKS MCP GitHub repository](https://github.com/Azure/aks-mcp).

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

All actions you perform through the AKS MCP server are constrained by Kubernetes Role-Based Access Control (RBAC) and Azure RBAC. The AKS MCP server inherits your permissions when accessing cluster and Azure resources.

## Available tools

The AKS MCP server provides a comprehensive set of tools for interacting with AKS clusters and associated resources. By default, the server uses **unified tools** (`call_az` for Azure operations and `call_kubectl` for Kubernetes operations) which provide a more flexible interface for interacting with Kubernetes and Azure resources.

There are three sets of permissions you can enable for the AKS MCP server: read-only (default), read-write, and admin. Some tools require read-write or admin permissions to perform actions like deploying debugging pods or CRUD actions on your cluster. To enable read-write or admin permissions for the AKS-MCP server, add the **access level** parameter to your MCP configuration file:

1. Navigate to your **mcp.json** file, or go to MCP: List Servers -> AKS-MCP -> Show Configuration Details in the **Command Palette** (For VS Code; `Ctrl+Shift+P` on Windows/Linux or `Cmd+Shift+P` on macOS).
2. In the "args" section of AKS-MCP, add the following parameters: "--access-level," "readwrite" or "admin"

For example:
```
"args": [
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

The MCP server runs on your local machine and connects to AKS by using your existing permissions. You can quickly set up your local AI agent with AKS expertise and tooling. The server uses the current cluster context and enforces your Kubernetes and Azure RBAC permissions.

> [!NOTE]
> As of version 0.0.20, remote deployments with Helm or containers aren't supported. Use the local binary.

### Prerequisites

Before installing the AKS MCP server, set up [Azure CLI](/cli/azure/install-azure-cli) and authenticate:

```bash
az login
```

### [Visual Studio Code with GitHub Copilot (Recommended)](#tab/vscode)

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

### [Manual Binary Installation](#tab/manual)

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

### [Custom Client Installation](#tab/custom)

For other MCP-compatible AI clients like Claude Desktop, configure the server in your MCP configuration:

```json
{
  "mcpServers": {
    "aks": {
      "command": "<path-to-binary>",
      "args": [
      ]
    }
  }
}
```

You can also run the server directly from the command line:

```bash
./aks-mcp
```

**Command-line options:**

| Option | Description | Default |
| ------ | ----------- | ------- |
| `--access-level` | Access level (`readonly`, `readwrite`, `admin`) | `readonly` |
| `--enabled-components` | Comma-separated list of enabled components | all |
| `--allow-namespaces` | Comma-separated list of allowed Kubernetes namespaces | all |
| `--timeout` | Timeout for command execution in seconds | `600` |
| `--log-level` | Log level (`debug`, `info`, `warn`, `error`) | `info` |

**Environment variables:**

- `USE_LEGACY_TOOLS`: Set to `true` to use legacy specialized tools instead of unified tools (default: `false`)
- Standard Azure authentication environment variables are supported (`AZURE_TENANT_ID`, `AZURE_CLIENT_ID`, `AZURE_CLIENT_SECRET`, `AZURE_SUBSCRIPTION_ID`).

---

## Uninstall the AKS MCP server

### VS Code with AKS Extension

1. Open the **Command Palette** (`Ctrl+Shift+P` on Windows/Linux or `Cmd+Shift+P` on macOS).
1. Run **MCP: List Servers**.
1. Select **AKS MCP** from the list.
1. Select **Stop Server** to stop the running server.
1. To remove the configuration, select **Delete Server Configuration**.

Alternatively, manually remove the server configuration:

1. Open your `.vscode/mcp.json` file or VS Code User Settings.
1. Delete the `aks-mcp-server` entry from the `servers` or `github.copilot.chat.mcp.servers` object.
1. Delete the AKS-MCP binary from your system (location varies based on installation method).

### Other MCP Clients

Remove the `aks` or `aks-mcp` entry from your MCP client configuration file (for example, Claude Desktop's `claude_desktop_config.json`).

## Common issues and troubleshooting

This section outlines common setup and runtime issues, their symptoms, and how to resolve them.

### AKS MCP server can't access the cluster

Symptoms:
- Tools return authorization errors
- No resources are visible

Likely causes:
- User doesn't have sufficient permissions
- Misconfigured kubeconfig context

Resolution:
- Check that you have sufficient permissions to access the cluster. Verify that you are in the right cluster and subscription context.

## Next steps
Learn more about the intelligent features built natively for AKS:
- About the agentic CLI for AKS
- Install and use the agentic CLI for AKS