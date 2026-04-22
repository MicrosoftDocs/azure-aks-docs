---
title: Container Network Insights Agent for AKS overview (Public Preview)
description: Learn about Container Network Insights Agent, an AI-powered diagnostic assistant that helps you troubleshoot networking issues in Azure Kubernetes Service (AKS) clusters.
author: shaifaligargmsft
ms.author: shaifaligarg
ms.date: 02/18/2026
ms.topic: overview
ms.service: azure-kubernetes-service
---

# What is Container Network Insights Agent for AKS? (Public Preview)

Container Network Insights Agent is an AI-powered diagnostic assistant that helps you identify and resolve networking issues in your Azure Kubernetes Service (AKS) clusters. Describe a problem in natural language, such as DNS failures, packet drops, unreachable services, or blocked traffic. The agent collects evidence from your cluster and returns a structured report with root cause analysis and remediation guidance.

Unlike tools that operate only at the Kubernetes layer, Container Network Insights Agent can also gather **host-level network statistics** through its Linux Networking plugin. The agent can inspect NIC ring buffers, kernel packet counters, SoftIRQ distribution, and socket buffer utilization across your cluster nodes. This surfaces low-level issues such as packet drops, network bottlenecks, and hardware-level saturation that are otherwise difficult to diagnose in a Kubernetes environment.

The agent runs as an in-cluster web application deployed as an [AKS cluster extension](/azure/aks/cluster-extensions). You access it through your browser. It provides insights, analysis, and recommended actions. You review the findings and apply any suggested changes yourself.

> [!NOTE]
> Container Network Insights Agent is a cloud-only feature for Azure Kubernetes Service (AKS). It isn't supported on AKS hybrid, AKS on Azure Stack HCI, or Arc-enabled Kubernetes clusters.

[!INCLUDE [preview features callout](~/reusable-content/ce-skilling/azure/includes/aks/includes/preview/preview-callout.md)]

## What can you do with Container Network Insights Agent?

Container Network Insights Agent helps you troubleshoot the most common and most time-consuming categories of AKS networking issues:

| Capability | What it does |
|-----------|-------------|
| **DNS troubleshooting** | Diagnoses CoreDNS failures, misconfigured DNS policies, network policies blocking DNS traffic, NodeLocal DNS issues, and Cilium FQDN egress restrictions |
| **Packet drop analysis** | Investigates NIC-level RX drops, kernel packet loss, socket buffer overflow, SoftIRQ saturation, and ring buffer exhaustion across cluster nodes |
| **Kubernetes networking diagnostics** | Identifies pod connectivity failures, service port misconfigurations, network policy conflicts, missing endpoints, and Hubble flow analysis |
| **Cluster resource queries** | Answers questions about pods, services, deployments, nodes, and namespaces to give you quick situational awareness |

Each diagnostic produces a structured report that includes what was checked, what's healthy, what failed, the identified root cause, and the exact commands to fix and verify the issue.

## When to use Container Network Insights Agent

### Use Container Network Insights Agent when you need to

- **Describe the problem in plain English**: No need to construct CLI commands or know which tool handles each networking layer. The agent determines the right diagnostic steps automatically.
- **Trace issues across Kubernetes and host networking in one conversation**: Go from network policies and pod scheduling down to NIC ring buffers and kernel counters without switching tools or SSH-ing into nodes.
- **Detect active issues, not just stale counters**: Delta-based measurements distinguish problems happening right now from historical noise.
- **Get automated root cause analysis with ready-to-use fixes**: The agent correlates evidence from multiple cluster data sources and delivers a structured report with remediation commands you can copy and run.
- **Troubleshoot on any AKS cluster with no additional setup**: DNS, packet drop, and Kubernetes networking diagnostics work out of the box. Enable [Advanced Container Networking Services (ACNS)](/azure/aks/advanced-container-networking-services-overview) for Cilium policy and Hubble flow analysis.

### Container Network Insights Agent isn't designed for

- Application code debugging or software development assistance
- Storage, PersistentVolume, or disk troubleshooting
- RBAC configuration, secrets management, or security auditing (except network policies)
- Workload scheduling, resource optimization, or cost management
- Non-Azure cloud environments (AWS, GCP)
- Making changes to your cluster (the agent provides recommendations only; you apply them)

## How it works

When you describe a networking issue, Container Network Insights Agent follows a structured diagnostic workflow:

```
You describe the issue → Agent classifies it → Collects evidence from the cluster → Analyzes findings → Reports results
```
:::image type="content" source="./media/advanced-container-networking-services/container-networking-agent-working.png" alt-text="Architecture diagram showing the Container Network Insights Agent inside an AKS cluster, its connections to cluster data sources, and its integration with Azure OpenAI Service." lightbox="./media/advanced-container-networking-services/container-networking-agent-working.png":::

Container Network Insights Agent runs as a pod inside your AKS cluster. You interact with it through a web browser over HTTPS. Inside the cluster, the agent executes diagnostic commands through the [AKS MCP server](/azure/aks/aks-model-context-protocol-server) and connects to five data sources through specialized plugins:

- **Kubernetes API Server**: Queries pods, services, nodes, network policies, and other cluster resources via `kubectl` through the AKS MCP server.
- **CoreDNS**: Collects DNS health status and metrics through the DNS plugin.
- **Cilium Agent**: Inspects Cilium network policies and endpoint state via the AKS MCP server through the Kubernetes Networking plugin.
- **Hubble**: Observes live network flows and identifies dropped traffic via the AKS MCP server through the Kubernetes Networking plugin.
- **Node Network Stack**: Gathers host-level network statistics (RX/TX buffers, ring buffer state, softnet counters) through the Linux Networking plugin.

The agent communicates bidirectionally with Azure OpenAI Service: it sends your natural language query and collected diagnostic evidence for reasoning, and receives structured diagnostic insights in return.

The diagnostic workflow follows four steps:

1. **Classify**: The agent determines the issue category (DNS, connectivity, network policy, service routing, or packet drops) based on your description.
2. **Collect evidence**: The agent runs diagnostic commands against your cluster through the [AKS MCP server](/azure/aks/aks-model-context-protocol-server), using `kubectl`, `cilium`, and `hubble`. Each diagnostic category uses a dedicated evidence collection workflow to gather the right data automatically.
3. **Analyze**: The agent examines collected evidence to separate healthy signals from anomalies. The agent bases all conclusions on actual command output, never on speculation.
4. **Report**: You receive a structured report that includes:
- A summary of the issue and its status
- An evidence table showing each check, its result, and whether it passed or failed
- Analysis of what's working and what's broken
- Root cause identification with specific evidence citations
- Exact commands to fix the issue and verify the fix

### Integrations

Container Network Insights Agent works with the AKS networking tools you already use:

| Integration | How it's used |
|------------|---------------|
| **[AKS MCP server](/azure/aks/aks-model-context-protocol-server)** | Provides the execution layer for cluster operations; routes `kubectl`, `cilium`, and `hubble` commands from the agent to the cluster |
| **kubectl** | Queries pods, services, endpoints, nodes, network policies, and other Kubernetes resources |
| **Cilium** | Analyzes CiliumNetworkPolicy, CiliumClusterWideNetworkPolicy, and Cilium agent health |
| **Hubble** | Observes network flows between pods and identifies dropped traffic |
| **CoreDNS** | Checks pod health, service endpoints, configuration, and Prometheus metrics |
| **Azure OpenAI** | Powers the conversational AI that interprets your questions and generates diagnostic reports |

> [!TIP]
> For the full diagnostic feature set, including Hubble flow analysis and Cilium policy diagnostics, deploy Container Network Insights Agent on an AKS cluster with [Azure CNI powered by Cilium](/azure/aks/azure-cni-powered-by-cilium) and [Advanced Container Networking Services (ACNS)](/azure/aks/advanced-container-networking-services-overview) enabled.

## Safety model and limitations

### How the agent interacts with your cluster

Container Network Insights Agent collects diagnostic data from your cluster to generate insights, reports, and recommended actions. It executes cluster operations through the [AKS MCP server](/azure/aks/aks-model-context-protocol-server) and uses a dedicated Kubernetes service account (`container-networking-agent-reader`) with minimal permissions scoped to the data it needs for diagnostics.

Container Network Insights Agent doesn't make changes to your cluster. It provides remediation commands and recommendations, but you review and apply them yourself.

### Scope restrictions

The agent responds only to networking and Kubernetes-related questions and doesn't respond to off-topic requests. The system also includes prompt injection defenses to prevent misuse.

### Session and conversation limits

| Limit | Default | Notes |
|-------|---------|-------|
| Chat context window | ~15 exchanges | The agent drops older messages from the working context. Start a new conversation for unrelated issues. |
| Messages per conversation | 100 | The agent automatically removes older messages when reaching this limit |
| Conversations per user | 20 | The system cleans up least-recently-used conversations at 90% capacity |
| Session idle timeout | 30 minutes | Sessions expire after 30 minutes of inactivity |
| Session absolute timeout | 8 hours | Sessions expire after 8 hours regardless of activity |

### Concurrency

Container Network Insights Agent supports 1–7 concurrent users under typical conditions. Packet drop diagnostics on larger clusters (25+ nodes) may require limiting concurrent users to avoid API server load. For details, see [Scale guidance](#scale-guidance).

## Example scenarios and sample prompts

### DNS troubleshooting

DNS resolution failures are one of the most common networking issues in Kubernetes. When pods can't resolve service names, external domains, or both, Container Network Insights Agent runs a comprehensive DNS diagnostic that checks CoreDNS health, configuration, DNS resolution from multiple paths, and network policies that might block DNS traffic.

**Common situations:**

- Pods log `Name or service not known` or `NXDOMAIN` errors
- Applications time out reaching services by name
- DNS works for some pods but not others
- External domain resolution fails while internal resolution works (or vice versa)

**Sample prompts:**

| What you're seeing | Prompt |
|-------------------|--------|
| DNS completely broken | *"All DNS is broken in the cluster"* |
| Pod can't resolve names | *"A pod in namespace `my-app` cannot resolve any DNS names"* |
| Specific name not resolving | *"DNS resolution for `backend.default.svc.cluster.local` is failing"* |
| Intermittent DNS failures | *"Pods in `production` have intermittent DNS failures"* |
| External DNS blocked | *"External DNS fails for pods in `my-namespace`"* |
| NodeLocal DNS issues | *"Can you check if NodeLocal DNS is working?"* |

**What the agent checks:**

The DNS diagnostic checks CoreDNS pod health, service endpoints, and CoreDNS configuration, including custom ConfigMaps. It also tests DNS resolution across multiple paths: same-namespace, cross-namespace, FQDN, and external. The agent evaluates CoreDNS Prometheus metrics and network policy rules, including Cilium toFQDN egress policies that might silently restrict external domain resolution.

**Example root causes the agent identifies:**

- CoreDNS pods not running or not ready
- Custom CoreDNS ConfigMap with misconfigured rewrite or forward rules
- Network policy blocking UDP/TCP port 53 (DNS traffic)
- Cilium toFQDNs policy missing a required domain in its allow list
- NodeLocal DNS DaemonSet deployed without a Cilium LocalRedirectPolicy
- Application configured with the wrong service DNS name

### RX / Packet drop troubleshooting

Packet drops are difficult to diagnose because they can occur at multiple layers: NIC hardware, the kernel networking stack, or application socket buffers. Container Network Insights Agent deploys a lightweight debug pod to each node to collect host-level network statistics. It then uses delta measurements to identify where packets are lost.

**Common situations:**

- Applications report intermittent connection resets or timeouts
- Tools like `iperf` show packet loss between nodes
- Network latency spikes appear on specific nodes
- High CPU usage correlated with network processing
- `ethtool -S` shows incrementing RX drop counters

**Sample prompts:**

| What you're seeing | Prompt |
|-------------------|--------|
| Drops on a specific node | *"I see packet drops on node `aks-nodepool1-12345678-vmss000000`"* |
| Latency spikes | *"My application is experiencing intermittent latency spikes"* |
| Cluster-wide performance issues | *"Network performance is degraded cluster-wide"* |
| Packet loss detected | *"I'm seeing packet drops and high latency. The iperf tests show significant packet loss."* |
| Proactive health check | *"Check network health on node `my-node`"* |

**What the agent checks:**

The packet drop diagnostic examines NIC ring buffer utilization (`ethtool`), kernel softnet statistics (`/proc/net/softnet_stat`), per-CPU SoftIRQ distribution, and socket buffer saturation. It also reviews network interface statistics (`/proc/net/dev`), kernel buffer tunables (`tcp_rmem`, `rmem_max`, `netdev_max_backlog`), RPS/XPS/RFS configuration, and CNI-specific interface analysis. The agent uses delta measurements (before-and-after snapshots) to detect active drops versus historical counters.

**Example root causes the agent identifies:**

- NIC ring buffer exhaustion: active `rx_dropped` counters incrementing
- Kernel packet drops: non-zero values in `/proc/net/softnet_stat` drop column
- Socket buffer overflow: socket receive queue growing beyond buffer limits
- SoftIRQ CPU bottleneck: high `%soft` on a single CPU with imbalanced interrupt distribution
- All checks passing: agent reports "No issue detected" rather than guessing

> [!IMPORTANT]
> The packet drop diagnostic deploys a debug DaemonSet (`rx-troubleshooting-debug`) to your cluster's `kube-system` namespace. This DaemonSet requires `hostNetwork`, `hostPID`, `hostIPC`, and `NET_ADMIN` capabilities to access host-level network data. It runs as a non-root user with a read-only root filesystem. It's shared across diagnostic sessions and cleaned up automatically, but may persist if the agent pod crashes unexpectedly. See [Known issues](#known-issues-and-product-limitations) for cleanup guidance.

### Kubernetes networking troubleshooting

When pods can't communicate with services, network policies block expected traffic, or services have no endpoints, Container Network Insights Agent investigates the full networking path. The agent checks pod scheduling and readiness, service endpoint registration, network policy evaluation, and Hubble flow observation.

**Common situations:**

- Pod-to-pod or pod-to-service communication fails
- Services are unreachable from certain namespaces
- Network policies unexpectedly block traffic
- Service endpoints exist but connections still time out
- Hubble shows `DROPPED` verdict on flows between pods

**Sample prompts:**

| What you're seeing | Prompt |
|-------------------|--------|
| Service unreachable | *"My client pod cannot connect to the backend-service in `production`. The connection times out."* |
| Traffic blocked | *"My client pod can't reach the backend-service anymore. It was working before."* |
| No endpoints | *"Service has no endpoints in namespace `my-app`"* |
| Pod stuck | *"I deployed my app but the service has no endpoints and the pod doesn't have an IP"* |
| Pods not ready | *"Pods are not ready in namespace `staging`"* |
| Proactive health check | *"Everything looks fine in namespace `production` — can you verify?"* |

**What the agent checks:**

The Kubernetes networking diagnostic examines pod status and scheduling, service configuration and endpoint registration, and network policies (both Kubernetes NetworkPolicy and CiliumNetworkPolicy). It also analyzes Hubble flows, including dropped traffic, and service-to-pod port mapping. A common misconfiguration the agent catches is a service `targetPort` that doesn't match the pod `containerPort`. This mismatch causes connection timeouts even though endpoints appear healthy.

**Example root causes the agent identifies:**

- Network policy (or CiliumNetworkPolicy) blocking ingress or egress traffic
- Service `targetPort` doesn't match the pod's `containerPort`
- Service selector labels don't match any pod labels (empty endpoints)
- Pod stuck in Pending due to unschedulable resource requests
- Readiness probe failing, causing pods to be excluded from service endpoints
- Cilium agent pods not healthy

> [!NOTE]
> Hubble flow analysis (`hubble observe`) requires [Advanced Container Networking Services (ACNS)](/azure/aks/advanced-container-networking-services-overview) to be enabled on your cluster. On clusters without ACNS, Container Network Insights Agent still provides full diagnostics using `kubectl` and standard Kubernetes resources, but flow-level visibility is unavailable.

## Known issues and product limitations

### Scale guidance

| Cluster size | Recommended concurrent users | Notes |
|-------------|------------------------------|-------|
| 1–3 nodes | Up to 7 | Optimal for most diagnostics |
| 25 nodes | Up to 3 | Packet drop diagnostics generate per-node evidence bundles |
| 50 nodes | 1 | Large evidence bundles approach AI model context limits |

The first query from a new user might take longer if all agents in the pre-warmed pool (default: three agents) are in use. Subsequent queries from the same session use the already-initialized agent.

### Known issues

| Issue | Description | Workaround |
|-------|-------------|------------|
| **Debug DaemonSet persists after crash** | If the Container Network Insights Agent pod crashes during a packet drop diagnostic, the `rx-troubleshooting-debug` DaemonSet may remain in `kube-system` | Run `kubectl delete ds rx-troubleshooting-debug -n kube-system` |
| **First packet drop diagnostic is slower** | The debug DaemonSet takes 30–60 seconds to schedule and become ready on first use | Subsequent diagnostics reuse existing pods and are faster |
| **Non-Cilium clusters have reduced diagnostics** | Cilium policy analysis and Hubble flow observation aren't available | Agent still provides full DNS, packet drop, and standard Kubernetes diagnostics |
| **Non-ACNS clusters lack Hubble** | `hubble observe` commands fail on clusters without Advanced Container Networking Services | Enable ACNS, or rely on `kubectl`-based diagnostics |
| **DNS tests run from agent pod** | DNS resolution tests execute from the Container Network Insights Agent pod, which may have a different DNS policy than the affected pod | Agent notes its own DNS policy in the evidence for comparison |
| **Session data is in-memory** | Session state (chat history, agent assignments) is lost if the pod restarts | Log back in to start a new session; no persistent conversation history |
| **Chat context window** | The agent retains only the last ~15 exchanges in its working context | For unrelated issues, start a new conversation to avoid context confusion |

### Extension availability

When deployed as an AKS extension (`microsoft.containernetworkingagent`), Container Network Insights Agent is available in: **centralus**, **eastus**, **eastus2**, **uksouth**, **westus2**.

## Pricing

Container Network Insights Agent runs as a pod in your AKS cluster. Direct costs include:

- **Azure OpenAI usage**: Token consumption depends on conversation length and diagnostic complexity. See [Azure OpenAI pricing](https://azure.microsoft.com/pricing/details/cognitive-services/openai-service/) for current rates.
- **AKS node compute**: The Container Network Insights Agent pod and (for packet drop diagnostics) the debug DaemonSet consume cluster compute resources.

Container Network Insights Agent itself has no separate licensing fee during public preview.

## Access and use Container Network Insights Agent

Container Network Insights Agent is a browser-based chatbot that runs inside your AKS cluster. After deployment, open the application URL in any modern browser to start a conversation. You don't need a CLI tool on your workstation or a portal blade to navigate. It's a standalone chat interface designed for network diagnostics.

### Sign up

When you first open the Container Network Insights Agent URL, the application prompts you to sign in. Depending on how your administrator configured the deployment, you sign in with either a simple username (development environments) or your Microsoft Entra ID credentials (production environments).

:::image type="content" source="./media/advanced-container-networking-services/container-networking-signup-page.png" alt-text="Screenshot of the Container Network Insights Agent sign-up page where users enter credentials to access the diagnostic assistant." lightbox="./media/advanced-container-networking-services/container-networking-signup-page.png":::

### Grant permissions

After signing in, the application might prompt you to grant permissions. Review the requested permissions and select **Accept** to continue.

:::image type="content" source="./media/advanced-container-networking-services/container-networking-agent-permission-page.png" alt-text="Screenshot of the Container Network Insights Agent permission authorization page requesting user consent." lightbox="./media/advanced-container-networking-services/container-networking-agent-permission-page.png":::

### Chat interface

After you authenticate, you land on the chat interface. The server maintains your session, so you can close and reopen the browser tab within the session timeout window without losing your conversation.

:::image type="content" source="./media/advanced-container-networking-services/container-networking-agent-home-page.png" alt-text="Screenshot of the Container Network Insights Agent chat interface showing a user prompt and a structured diagnostic response." lightbox="./media/advanced-container-networking-services/container-networking-agent-home-page.png":::

The chat interface is where you:

- **Ask questions in natural language**: Type prompts like *"Why can't my pod resolve DNS?"* or *"Check packet drops on node aks-nodepool1-vmss000000"*. No special syntax is required.
- **Receive structured diagnostic reports**: Responses include evidence tables, root cause analysis, and remediation commands you can copy and run.
- **Start new conversations**: Each conversation maintains its own context. Switch topics by starting a new conversation.
- **Submit feedback**: After each diagnostic response, use the built-in feedback controls (thumbs-up and thumbs-down) to rate the quality of the diagnosis. Your feedback helps improve future diagnostic accuracy.

### Report issues

If you encounter a problem with Container Network Insights Agent:

1. Note the **session ID** and **timestamp** of the issue (visible in the chat interface)
2. Check the health endpoints: `/health`, `/ready`, `/live`
3. Review pod logs: `kubectl logs -l app=container-networking-agent -n kube-system`
4. File an issue through your standard Azure support channel

## Next steps

- [Quickstart: Deploy Container Network Insights Agent](./how-to-configure-container-network-insights-agent.md)
- [Troubleshoot Container Network Insights Agent on AKS](./troubleshoot-container-network-insights-agent.md)
- [Advanced Container Networking Services overview](/azure/aks/advanced-container-networking-services-overview)
- [Azure CNI powered by Cilium](/azure/aks/azure-cni-powered-by-cilium)
