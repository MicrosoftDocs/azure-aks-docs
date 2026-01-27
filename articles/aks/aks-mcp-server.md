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
- Retrieve details related to AKS clusters (VNets, Subnets, NSGs, Route Tables, etc.)
- Enabling best practices and recommended features
- Manage Azure Fleet operations for multi-cluster scenarios

## When to use the AKS MCP server

Common use cases include:

- Asking AI assistants questions like:
  - “Why are pods pending in this cluster?”
  - “What changed recently that could explain this issue?”
  - “Which workloads are unhealthy and why?”
- Allowing AI tools to:
  - Read cluster state and configuration
  - Inspect metrics, events and logs
  - Correlate signals across Kubernetes and Azure resources
  - Suggest remediation steps

All actions performed through the MCP server are constrained by Kubernetes RBAC and (when applicable) Azure RBAC. By default, the AKS MCP server inherits the user's permissions when accessing cluster and Azure resources. To provide a custom set of permissions to the MCP server, you will need to deploy the remote AKS MCP server.

## Available tools

The AKS MCP server provides a comprehensive set of tools for interacting with AKS clusters and associated resources. By default, the server uses **unified tools** (`call_az` for Azure operations and `call_kubectl` for Kubernetes operations) which provide a more flexible interface for interacting with Kubernetes and Azure resources.

There are three sets of permissions you can enable for the AKS MCP server: read-only (default), read-write, and admin. Some tools require read-write or admin permissions to perform actions like deploying debugging pods or CRUD actions on your cluster. To enable read-write or admin permissions for the AKS-MCP server, add the **access level** parameter to your MCP configuration file:

1. Navigate to your **mcp.json** file, or go to MCP: List Servers -> AKS-MCP -> Show Configuration Details in the **Command Palette** (For VSCode; `Ctrl+Shift+P` on Windows/Linux or `Cmd+Shift+P` on macOS).
2. In the "args" section of AKS-MCP, add the following parameters: "--access-level", "readwrite" / "admin"

For example:
```
"args": [
  "--transport",
  "stdio",
  "--access-level",
  "readwrite"
]
```

These tools have been designed to provide comprehensive functionality
through unified interfaces:

<details>
<summary>Azure CLI Operations (Unified Tool)</summary>

**Tool:** `call_az`

Unified tool for executing Azure CLI commands directly. This tool provides a flexible interface to run any Azure CLI command.

**Parameters:**
- `cli_command`: The complete Azure CLI command to execute (e.g., `az aks list --resource-group myRG`, `az vm list --subscription <sub-id>`)
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

**Important:** Commands must be simple Azure CLI invocations without shell features like pipes (|), redirects (>, <), command substitution, or semicolons (;).

</details>

<details>
<summary>Network Resource Management</summary>

**Tool:** `az_network_resources`

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

**Tool:** `az_monitoring`

Unified tool for Azure monitoring and diagnostics operations for AKS clusters.

**Available Operations:**

- `metrics`: List metric values for resources
- `resource_health`: Retrieve resource health events for AKS clusters
- `app_insights`: Execute KQL queries against Application Insights telemetry data
- `diagnostics`: Check if AKS cluster has diagnostic settings configured
- `control_plane_logs`: Query AKS control plane logs with safety constraints
  and time range validation

</details>

<details>
<summary>Compute Resources</summary>

**Tool:** `get_aks_vmss_info`

- Get detailed VMSS configuration for node pools in the AKS cluster

**Tool:** `az_compute_operations`

Unified tool for managing Azure Virtual Machines (VMs) and Virtual Machine Scale Sets (VMSS) used by AKS.

**Available Operations:**

- `show`: Get details of a VM/VMSS
- `list`: List VMs/VMSS in subscription or resource group
- `get-instance-view`: Get runtime status
- `start`: Start VM
- `stop`: Stop VM
- `restart`: Restart VM/VMSS instances
- `reimage`: Reimage VMSS instances (VM not supported for reimage)

**Resource Types:** `vm` (single virtual machines), `vmss` (virtual machine scale sets)

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

**Tool:** `list_detectors`

- List all available AKS cluster detectors

**Tool:** `run_detector`

- Run a specific AKS diagnostic detector

**Tool:** `run_detectors_by_category`

- Run all detectors in a specific category
- **Categories**: Best Practices, Cluster and Control Plane Availability and Performance, Connectivity Issues, Create/Upgrade/Delete and Scale, Deprecations, Identity and Security, Node Health, Storage

</details>

<details>
<summary>Azure Advisor</summary>

**Tool:** `az_advisor_recommendation`

Retrieve and manage Azure Advisor recommendations for AKS clusters.

**Available Operations:**

- `list`: List recommendations with filtering options
- `report`: Generate recommendation reports
- **Filter Options**: resource_group, cluster_names, category (Cost,
  HighAvailability, Performance, Security), severity (High, Medium, Low)

</details>

<details>
<summary>Kubernetes Operations</summary>

*Note: All Kubernetes tools (kubectl, helm, cilium, hubble) are enabled by default. Use `--enabled-components` to selectively enable specific components.*

### Unified kubectl Tool (Default)

**Tool:** `call_kubectl`

Unified tool for executing kubectl commands directly. This tool provides a flexible interface to run any `kubectl` command with full argument support.

**Parameters:**
- `args`: The kubectl command arguments (e.g., `get pods`, `describe node mynode`, `apply -f deployment.yaml`)

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

**Tool:** `helm`

Helm package manager for Kubernetes.

### Cilium

**Tool:** `cilium`

Cilium CLI for eBPF-based networking and security.

### Hubble

**Tool:** `hubble`

Hubble network observability for Cilium.

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

The AKS MCP server has two modes: local and remote. In this section, we will cover the use cases and installation processes for both modes.

### Local MCP server

In local mode, the MCP server runs on a developer’s local machine and connects to AKS using the developer’s existing permissions. This mode is best for quickly setting up your local AI agent with AKS expertise and tooling without requiring any cluster-side components. Local mode can use the current cluster context and enforces the developer’s Kubernetes and Azure RBAC permissions.

SSE or STDIO

[TODO: add recommended pathways to install local mcp]

### Remote MCP server

In remote mode, the MCP server runs as a workload inside the AKS cluster or any compute of your choosing. This mode is best for production environments with shared tooling, consistent permissions across users, and full access control using Kubernetes ServiceAccount and Workload Identity. The remote AKS MCP server uses the HTTP protocol to facilitate interactions between your AI assistant and AKS cluster.

[TODO: add recommended process for deploying and connecting to remote MCP server]

## Common issues and troubleshooting

This section lists common setup and runtime issues, their symptoms, and how to resolve them.

### AKS MCP server cannot access the cluster

Symptoms:
- Tools return authorization errors
- No resources are visible

Likely causes:
- User or MCP identity does not have sufficient permissions
- Incorrect ServiceAccount binding
- Misconfigured kubeconfig context (local mode)

Resolution:
- Local mode: Check that you have sufficent permissions to access the cluster. Verify that you are in the right cluster and subscription context.
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

