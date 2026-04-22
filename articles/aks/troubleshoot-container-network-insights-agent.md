---
title: Troubleshoot Container Network Insights Agent on AKS
description: Troubleshoot common issues you might encounter when deploying, configuring, or using Container Network Insights Agent on Azure Kubernetes Service (AKS).
author: shaifaligargmsft
ms.author: shaifaligarg
ms.date: 03/05/2026
ms.topic: troubleshooting
ms.service: azure-kubernetes-service
---

# Troubleshoot Container Network Insights Agent on AKS

This article covers common issues you might encounter when deploying, setting up, or using Container Network Insights Agent on AKS. Each section follows a **Symptom → Cause → Resolution** format.

For deployment instructions, see [Deploy and use Container Network Insights Agent on AKS](./how-to-configure-container-network-insights-agent.md).

## Extension installation fails

**Symptom:** The `az k8s-extension create` command fails, or the extension provisioning state shows `Failed`.

**Cause:** Unsupported region, missing cluster features, or insufficient permissions.

**Resolution:**

1. Check the extension provisioning state for details:

   ```azurecli-interactive
   az k8s-extension show \
       --cluster-name $CLUSTER_NAME \
       --resource-group $RESOURCE_GROUP \
       --cluster-type managedClusters \
       --name containernetworkingagent \
       --query "{state:provisioningState, statuses:statuses}" -o json
   ```

1. Verify your cluster is in a supported region: `centralus`, `eastus`, `eastus2`, `uksouth`, `westus2`.

1. Verify your cluster has [workload identity](/azure/aks/workload-identity-overview) and [OIDC issuer](/azure/aks/use-oidc-issuer) enabled:

   ```azurecli-interactive
   az aks show \
       --resource-group $RESOURCE_GROUP \
       --name $CLUSTER_NAME \
       --query "{oidcEnabled:oidcIssuerProfile.enabled, workloadIdentityEnabled:securityProfile.workloadIdentity.enabled}"
   ```

1. Check that you have `Contributor` and `User Access Administrator` roles on the resource group.

1. If you already ran `az k8s-extension create` once, running it again returns an error because the extension already exists. Use `az k8s-extension update` to change configuration settings on an existing extension:

   ```azurecli-interactive
   az k8s-extension update \
     --cluster-name $CLUSTER_NAME \
     --resource-group $RESOURCE_GROUP \
     --cluster-type managedClusters \
     --name containernetworkingagent \
     --configuration-settings config.SOME_SETTING=new-value
   ```

---

## Identity and permissions errors

**Symptom:** The agent pod starts but returns `401 Unauthorized` or `403 Forbidden` errors when processing requests. Pod logs show authentication or authorization failures.

**Cause:** The managed identity is missing required RBAC role assignments, or the federated credential subject doesn't match the agent's service account.

**Resolution:**

1. Verify the managed identity has all four required role assignments:

   ```azurecli-interactive
   az role assignment list --assignee <identity-principal-id> --all -o table
   ```

   Confirm these roles are present:

   | Role | Scope |
   |------|-------|
   | `Cognitive Services OpenAI User` | Azure OpenAI resource |
   | `Azure Kubernetes Service Cluster User Role` | AKS cluster |
   | `Azure Kubernetes Service Contributor Role` | AKS cluster |
   | `Reader` | Resource group |

1. Verify workload identity is enabled on the cluster:

   ```azurecli-interactive
   az aks show \
       --resource-group $RESOURCE_GROUP \
       --name $CLUSTER_NAME \
       --query "securityProfile.workloadIdentity.enabled"
   ```

1. Verify the federated credential subject matches the service account:

   ```azurecli-interactive
   az identity federated-credential list \
       --identity-name $IDENTITY_NAME \
       --resource-group $RESOURCE_GROUP
   ```

   The `subject` field should be `system:serviceaccount:kube-system:container-networking-agent-reader`.

1. Verify the Kubernetes service account has the correct workload identity annotation:

   ```azurecli-interactive
   kubectl get serviceaccount container-networking-agent-reader -n kube-system -o yaml
   ```

   The `azure.workload.identity/client-id` annotation must match your managed identity's client ID. If it doesn't match, correct it and restart the pod:

   ```azurecli-interactive
   kubectl annotate serviceaccount container-networking-agent-reader \
     -n kube-system \
     azure.workload.identity/client-id=$IDENTITY_CLIENT_ID \
     --overwrite

   kubectl rollout restart deployment container-networking-agent -n kube-system
   ```

> [!TIP]
> Azure RBAC role assignments can take up to 10 minutes to propagate. If you see `401` or `403` errors immediately after setup, wait a few minutes and restart the pod.

---

## Azure OpenAI connectivity issues

**Symptom:** The agent pod starts but chat requests fail. Pod logs show `401 Unauthorized`, `404 Not Found`, or connection errors referencing the Azure OpenAI endpoint.

**Cause:** The Azure OpenAI endpoint, deployment name, or managed identity credentials are misconfigured, or network traffic to the endpoint is blocked.

**Resolution:**

1. Check pod logs for specific error patterns:

   | Log message | Cause | Fix |
   |-------------|-------|-----|
   | `401 Unauthorized` | Managed identity missing `Cognitive Services OpenAI User` role | Assign the role on the OpenAI resource |
   | `404 Not Found` | Wrong endpoint URL or deployment name | Verify `AZURE_OPENAI_ENDPOINT` and `AZURE_OPENAI_DEPLOYMENT` |
   | `Connection refused` / `Name resolution failed` | Network or DNS issue | Check NSG/firewall rules and verify the endpoint hostname |
   | `Token acquisition failed` | Workload identity not configured | Check service account annotation and federated credential |

1. Verify the managed identity has the `Cognitive Services OpenAI User` role on the Azure OpenAI resource:

   ```azurecli-interactive
   az role assignment list \
     --assignee <managed-identity-principal-id> \
     --scope /subscriptions/<subscription-id>/resourceGroups/<resource-group>/providers/Microsoft.CognitiveServices/accounts/<openai-resource-name> \
     --output table
   ```

1. If you use network policies, Azure Firewall, or NSGs, ensure outbound HTTPS traffic (port 443) is allowed from the `kube-system` namespace to your Azure OpenAI endpoint. Verify no network policies are blocking outbound traffic:

   ```azurecli-interactive
   kubectl get networkpolicies -n kube-system
   ```

---

## App Registration and Entra ID authentication errors

**Symptom:** The Microsoft Entra ID (MSAL) login flow fails, login redirects return errors, or the pod logs show the placeholder value `44444444-4444-4444-4444-444444444444` for `ENTRA_CLIENT_ID`.

**Cause:** The App Registration isn't configured correctly, or the `ENTRA_CLIENT_ID` wasn't set during extension deployment.

**Resolution:**

1. If pod logs show the placeholder value `44444444-4444-4444-4444-444444444444`, update the extension with your actual App Registration client ID:

   ```azurecli-interactive
   az k8s-extension update \
     --cluster-name $CLUSTER_NAME \
     --resource-group $RESOURCE_GROUP \
     --cluster-type managedClusters \
     --name containernetworkingagent \
     --configuration-settings config.ENTRA_CLIENT_ID=<your-app-registration-client-id>
   ```

1. If the login callback fails with a `redirect_uri mismatch` error, verify the redirect URI in the Azure portal under **App Registrations > Your App > Authentication > Redirect URIs**. For port-forwarded local access, the URI must be `http://localhost:8080/auth/callback`.

   > [!NOTE]
   > Only `localhost` redirect URIs are currently supported. Public LoadBalancer URLs aren't supported for redirect URIs.

1. Ensure the App Registration has the required Microsoft Graph delegated permissions: `openid`, `profile`, `User.Read`, `offline_access`. If admin consent is required, grant it:

   ```azurecli-interactive
   az ad app permission admin-consent --id <app-registration-object-id>
   ```

1. Check pod logs for authentication-specific errors:

   ```azurecli-interactive
   kubectl logs -n kube-system -l app=container-networking-agent | grep -i "auth\|msal\|entra"
   ```

---

## Missing environment variables at startup

**Symptom:** The agent pod crashes immediately on startup with:

```
RuntimeError: Missing required Azure OpenAI environment variable(s): AZURE_OPENAI_ENDPOINT, AZURE_OPENAI_DEPLOYMENT, AZURE_OPENAI_API_VERSION.
```

**Cause:** One or more required configuration values weren't set when the extension was deployed.

**Resolution:**

1. Check the ConfigMap for placeholder values or missing settings:

   ```azurecli-interactive
   kubectl get configmap -n kube-system -l app=container-networking-agent -o yaml
   ```

1. Confirm these required variables are set with real values (not placeholders like `00000000-0000-0000-0000-000000000000`):

   | Variable | Description | Example |
   |----------|-------------|---------|
   | `AZURE_OPENAI_ENDPOINT` | Azure OpenAI resource endpoint | `https://your-instance.openai.azure.com/` |
   | `AZURE_OPENAI_DEPLOYMENT` | Model deployment name | `gpt-4o` |
   | `AZURE_OPENAI_API_VERSION` | API version | `2025-03-01-preview` |
   | `AZURE_CLIENT_ID` | Managed identity client ID | UUID |
   | `AZURE_TENANT_ID` | Azure tenant ID | UUID |
   | `AZURE_SUBSCRIPTION_ID` | Azure subscription ID | UUID |
   | `AKS_CLUSTER_NAME` | AKS cluster name | Your cluster name |
   | `AKS_RESOURCE_GROUP` | Cluster resource group | Your resource group |

1. If values show placeholders, update the extension with the correct settings:

   ```azurecli-interactive
   az k8s-extension update \
     --cluster-name $CLUSTER_NAME \
     --resource-group $RESOURCE_GROUP \
     --cluster-type managedClusters \
     --name containernetworkingagent \
     --configuration-settings config.AZURE_OPENAI_ENDPOINT=<your-endpoint> \
     --configuration-settings config.AZURE_OPENAI_DEPLOYMENT=<your-deployment>
   ```

---

## Agent pod not running or crashing

**Symptom:** The agent pod is in `CrashLoopBackOff`, `Error`, or `Pending` state.

**Cause:** Misconfiguration, missing Azure OpenAI connectivity, or insufficient cluster resources.

**Resolution:**

1. Check pod events for immediate errors:

   ```azurecli-interactive
   kubectl describe pod -n kube-system -l app=container-networking-agent
   ```

1. Check pod logs for error messages:

   ```azurecli-interactive
   kubectl logs -n kube-system -l app=container-networking-agent --tail=200
   ```

1. Match log messages to known causes:

   | Log message | Cause | Fix |
   |-------------|-------|-----|
   | `Missing required Azure OpenAI environment variable(s)` | ConfigMap has placeholder values | Set correct values via `az k8s-extension update` |
   | `bootstrap.validation_agent_failed` | Can't connect to Azure OpenAI | Check network, endpoint URL, and managed identity RBAC |
   | `AKS MCP binary not found` | Binary missing from image | Use the official extension image from `acnpublic.azurecr.io` |
   | `FailedMount` / volume mount error | Missing Hubble certificate secrets | Deploy with `hubble.enabled=false` or ensure ACNS is enabled |
   | `Token acquisition failed` | Workload identity not configured | Check service account annotation and federated credential |

1. Verify that the Azure OpenAI endpoint is reachable from the cluster. If you use egress restrictions, ensure outbound HTTPS (port 443) is allowed from the `kube-system` namespace to your Azure OpenAI endpoint.

---

## Readiness probe failures

**Symptom:** The pod is `Running` but shows `0/1` ready status. The `/ready` endpoint returns HTTP 503.

**Cause:** One or more startup checks haven't completed: the warmup agent pool isn't initialized yet, cluster properties have errors, or there are no pre-warmed agents available.

**Resolution:**

1. Wait up to 2-3 minutes after deployment for the warmup pool to create pre-warmed agents.

1. Check the readiness response for specific failure reasons:

   ```azurecli-interactive
   kubectl port-forward svc/container-networking-agent-service -n kube-system 8080:80
   curl -s http://localhost:8080/ready | jq
   ```

1. Check pod logs for warmup-related issues:

   ```azurecli-interactive
   kubectl logs -n kube-system -l app=container-networking-agent | grep -i "warmup\|ready\|error"
   ```

1. If cluster properties are failing, verify that `AKS_CLUSTER_NAME`, `AKS_RESOURCE_GROUP`, and `AZURE_SUBSCRIPTION_ID` are correctly set in the extension configuration.

---

## Warmup pool keeps failing

**Symptom:** The pod is `Running` but never becomes ready. Pod logs show repeated `"Failed to create warmed agent"` errors even after waiting several minutes.

**Cause:** The background warmup pool is failing to create pre-warmed agent instances. This is typically caused by an unresolved Azure OpenAI connectivity issue or a MCP initialization failure that prevents agents from being created.

**Resolution:**

1. Check logs for the specific underlying error:

   ```azurecli-interactive
   kubectl logs -n kube-system -l app=container-networking-agent | grep -i "warmup\|Failed to create"
   ```

1. Match the error to its fix:

   | Error in logs | Fix |
   |---------------|-----|
   | `401 Unauthorized` or `403 Forbidden` | See [Azure OpenAI connectivity issues](#azure-openai-connectivity-issues) and verify the managed identity role assignment |
   | `Token acquisition failed` | See [Identity and permissions errors](#identity-and-permissions-errors) |
   | `404 Not Found` on endpoint | Verify `AZURE_OPENAI_ENDPOINT` and `AZURE_OPENAI_DEPLOYMENT` in the ConfigMap |
   | `AKS MCP binary not found` | See [Agent pod not running or crashing](#agent-pod-not-running-or-crashing) |

1. Once the underlying issue is resolved, the warmup pool retries automatically. You don't need to restart the pod unless the error persists after fixing the root cause.

---

## Hubble commands fail

**Symptom:** The agent reports errors for Hubble-related diagnostics, or Hubble flow analysis isn't available.

**Cause:** The cluster doesn't have Advanced Container Networking Services (ACNS) or the Cilium dataplane enabled.

**Resolution:**

- If your cluster doesn't use ACNS, deploy the extension with `hubble.enabled=false` and `config.AKS_MCP_ENABLED_COMPONENTS=kubectl`. The agent still provides DNS, packet drop, and standard Kubernetes networking diagnostics without Hubble.
- To enable Hubble, your cluster must use [Azure CNI powered by Cilium](/azure/aks/azure-cni-powered-by-cilium) with [Advanced Container Networking Services (ACNS)](/azure/aks/advanced-container-networking-services-overview) enabled.
- Verify Hubble is running on your cluster:

  ```azurecli-interactive
  kubectl get pods -n kube-system -l k8s-app=hubble-relay
  ```

  If no pods return, Hubble isn't enabled. Enable ACNS on your cluster or set `hubble.enabled=false` in the extension configuration.

---

## Chat rate limiting

**Symptom:** Chat requests return HTTP 429 with `X-RateLimit-*` or `X-LLM-RateLimit-*` response headers.

**Cause:** The built-in rate limiter is throttling requests to protect the service.

**Resolution:**

Container Network Insights Agent has three rate limiting layers:

| Rate limiter | Default | Behavior |
|--------------|---------|----------|
| Chat | 13 requests/second, burst of 13 | Per-session throttle on chat messages |
| Auth | 1 request/second, burst of 20 | Throttle on login and callback endpoints |
| LLM (adaptive) | 100 requests/second global, shared across users | Global throughput control with fair share per active user |

- For chat 429 errors: reduce message frequency and wait for the rate limit bucket to refill.
- For LLM 429 errors: check your Azure OpenAI Tokens-Per-Minute (TPM) quota in the Azure portal. Request a quota increase under **Cognitive Services > Quotas** if you need higher throughput.

---

## Chat message sent but no response

**Symptom:** A chat message is sent but no response appears. The request hangs or eventually returns a timeout error.

**Cause:** Azure OpenAI may be rate-limited or unreachable, no pre-warmed agents may be available yet, or a long-running diagnostic command is still executing.

**Resolution:**

1. Check whether the pod has active sessions and whether an agent is assigned:

   ```azurecli-interactive
   kubectl port-forward svc/container-networking-agent-service -n kube-system 8080:80
   curl -s http://localhost:8080/api/status/sessions | jq
   ```

1. Check pod logs for error patterns:

   ```azurecli-interactive
   kubectl logs -n kube-system -l app=container-networking-agent --tail=50
   ```

   | Log indicator | Cause | Fix |
   |---------------|-------|-----|
   | `429` errors | Azure OpenAI rate limited | Wait for the rate limit to reset; check your TPM quota |
   | `"No pre-warmed agents available"` | Warmup pool not ready | Wait for initialization; see [Warmup pool keeps failing](#warmup-pool-keeps-failing) |
   | Connection timeouts | Network or NSG issue | Check pod network, DNS, and NSG rules |

1. If the request is still pending after 2 minutes, start a new conversation and send a simple query first (for example, "list pods in the default namespace") to verify the agent is responding before asking a complex diagnostic question.

---

## Slow first request

**Symptom:** The first chat message after deployment or pod restart takes 10-30 seconds to respond.

**Cause:** Container Network Insights Agent maintains a pool of pre-warmed agents to reduce latency. After a pod restart, the warmup pool needs time to initialize each agent, which requires MCP plugin startup, Azure credential setup, and AI framework initialization.

**Resolution:** This is expected behavior. Wait for the `/ready` endpoint to return HTTP 200 before sending requests — that confirms at least one pre-warmed agent is available. Subsequent requests use the pre-warmed pool and respond faster (typically 5-10 seconds for simple queries).

```azurecli-interactive
kubectl port-forward svc/container-networking-agent-service -n kube-system 8080:80
curl -s http://localhost:8080/ready | jq
```

---

## Slow responses for complex diagnostics

**Symptom:** Diagnostic responses take 30 seconds to 2 minutes to complete.

**Cause:** Multi-step diagnostics involve sequential operations: an initial LLM classification call to Azure OpenAI, multiple kubectl/cilium/hubble commands run against the cluster, and a final LLM analysis of the collected evidence. Each step adds latency.

**Resolution:** This is expected for complex diagnostics. The following table shows typical response times:

| Query type | Expected time |
|------------|---------------|
| Simple cluster queries (listing pods, services) | 5–10 seconds |
| Single-domain diagnostics (specific pod DNS check, service endpoint check) | 15–30 seconds |
| Multi-node packet drop analysis or broad networking diagnostics | 30–120 seconds |

To reduce latency:
- Use a specific query that targets a known symptom instead of a broad question. For example, "check DNS resolution for service `my-svc` in namespace `my-ns`" is faster than "diagnose all networking issues."
- Ensure your Azure OpenAI resource is in the same Azure region as your AKS cluster to minimize network round-trip time.
- Check your Azure OpenAI TPM quota — higher quota allows more parallel token processing.

---

## Diagnostic commands time out

**Symptom:** The agent reports a command timed out, or the chat stops responding for more than 10 minutes before returning an error.

**Cause:** The default timeout for diagnostic commands (kubectl, cilium, hubble) is 600 seconds (10 minutes). Broad queries — such as collecting statistics from every node in a large cluster — can exceed this limit.

**Resolution:**

- Scope your query to a specific node, pod, or namespace instead of the entire cluster. For example:
  - Instead of: "Check packet drops across all nodes"
  - Ask: "Check packet drops on node `<specific-node-name>`"
- If timeouts happen consistently on a type of query, the cluster may have performance or connectivity issues that are independently slowing down command responses.
- Check pod logs for timeout-related entries:

  ```azurecli-interactive
  kubectl logs -n kube-system -l app=container-networking-agent | grep -i "timeout\|timed out"
  ```

---

## Session data lost after pod restart

**Symptom:** All chat history and active sessions disappear after the pod restarts.

**Cause:** Session data is stored in-memory only. All data is lost when the pod restarts.

**Resolution:** This is expected behavior for the current architecture. Start a new session after a pod restart.

---

## Session expires unexpectedly

**Symptom:** You are logged out without warning during an active session, or your session ends after a period of inactivity even though you were using the extension.

**Cause:** Container Network Insights Agent enforces session timeouts for security. Two independent limits apply:

| Timeout type | Default | Behavior |
|--------------|---------|----------|
| Idle timeout | 30 minutes | Session ends if there's no activity for 30 minutes |
| Absolute timeout | 8 hours | Session ends regardless of activity after 8 hours |

**Resolution:** Log in again to start a new session. Chat history from the expired session isn't recoverable.

> [!NOTE]
> Session data is stored in-memory only. Even within an active session, a pod restart clears all session history.

---

## Chat context appears lost after many exchanges

**Symptom:** After approximately 15 exchanges, the agent seems to forget earlier parts of the conversation or doesn't reference context from earlier in the session.

**Cause:** Container Network Insights Agent summarizes conversation history to stay within the Azure OpenAI token limit. When the context window reaches approximately 15 messages, older messages are replaced by an automatically generated summary. The most recent messages and the summary are retained and passed to the model.

**Resolution:** This is expected behavior. The summarization preserves key diagnostic context while managing Azure OpenAI token limits. If you need to reference something from much earlier in the conversation:
- Repeat the relevant context: "Earlier you found X — can you investigate further?"
- Start a new conversation with a concise recap of the known findings.

---

## Conversation limit reached

**Symptom:** The interface shows an error that you can't create a new conversation, or the oldest conversations disappear without being explicitly deleted.

**Cause:** Each user account is limited to 20 active conversations. When this limit is reached, the two oldest conversations are automatically removed to make room, starting when the count reaches 18 (90% of the 20-conversation limit).

**Resolution:** This automatic cleanup is expected behavior. If you can't create a new conversation, wait briefly for the background cleanup to run, then try again. The two least-recently-used conversations are removed automatically.

> [!NOTE]
> Conversations are stored in-memory per pod. All conversations are lost if the pod restarts, regardless of how many exist.

---

## Debug DaemonSet persists after a crash

**Symptom:** The `rx-troubleshooting-debug` DaemonSet remains in the `kube-system` namespace after a diagnostic session.

**Cause:** Container Network Insights Agent deploys a lightweight debug DaemonSet during packet drop diagnostics. If the agent pod crashes unexpectedly during this diagnostic, the cleanup step doesn't run.

**Resolution:** Manually delete the DaemonSet:

```azurecli-interactive
kubectl delete ds rx-troubleshooting-debug -n kube-system
```

---

## Packet drop diagnostic fails

**Symptom:** When asking the agent to investigate packet drops, it reports errors deploying diagnostic pods or cannot collect node-level statistics.

**Cause:** Packet drop diagnostics deploy a lightweight DaemonSet (`rx-troubleshooting-debug`) to each node to collect host-level network statistics (ethtool stats, softnet counters, ring buffer state). Failures occur if the agent's service account doesn't have permission to create DaemonSets in `kube-system`, or if nodes block the required privileged access to collect host network statistics.

**Resolution:**

1. Check whether the DaemonSet was created:

   ```azurecli-interactive
   kubectl get daemonset -n kube-system rx-troubleshooting-debug
   ```

   If it doesn't exist, the deployment step failed. Check pod logs:

   ```azurecli-interactive
   kubectl logs -n kube-system -l app=container-networking-agent | grep -i "daemonset\|rx\|packet\|error"
   ```

1. If the DaemonSet was created but its pods aren't starting, describe them to find the cause:

   ```azurecli-interactive
   kubectl describe pods -n kube-system -l app=cna-diagnostic
   ```

1. Verify the ClusterRole assigned to the agent includes DaemonSet creation permissions:

   ```azurecli-interactive
   kubectl get clusterrole -l app=container-networking-agent -o yaml | grep -A2 daemonset
   ```

1. If the DaemonSet is left over from a failed run, delete it manually and ask the agent to retry:

   ```azurecli-interactive
   kubectl delete daemonset -n kube-system -l app=cna-diagnostic
   ```

---

## DNS diagnostics return incomplete or no results

**Symptom:** When troubleshooting a DNS issue, the agent returns partial diagnostic data, reports errors running DNS checks, or exits the investigation without results.

**Cause:** The agent's DNS diagnostic tools run resolution tests and inspect CoreDNS from inside the cluster. Incomplete results can occur if the agent's service account lacks cluster-level read access, CoreDNS pods aren't accessible, or individual commands hit the 30-second per-command timeout.

**Resolution:**

1. Verify CoreDNS is running:

   ```azurecli-interactive
   kubectl get pods -n kube-system -l k8s-app=kube-dns
   ```

   If CoreDNS pods aren't running, that's the root cause. Describe them for details:

   ```azurecli-interactive
   kubectl describe pods -n kube-system -l k8s-app=kube-dns
   ```

1. Verify the managed identity has the `Azure Kubernetes Service Cluster User Role` assignment on the cluster. This role allows the agent to retrieve kubeconfig and run kubectl commands:

   ```azurecli-interactive
   az role assignment list --assignee <identity-principal-id> --all -o table
   ```

1. If the agent reports command timeouts during DNS checks, narrow the scope of your question. For example, instead of "diagnose all DNS issues," ask "check DNS resolution for pod `<pod-name>` in namespace `<namespace>`."

---

## Agent stops mid-investigation

**Symptom:** The agent begins a diagnostic investigation but stops before completing it, without providing a root cause analysis or a final report.

**Cause:** Several factors can interrupt a multi-step investigation:
- A diagnostic command timed out.
- The Azure OpenAI rate limit or token limit was hit mid-investigation.
- The conversation history context window reached its summarization threshold, causing the agent to lose thread of the current plan.

**Resolution:**

- Ask the agent to continue in the same conversation: `"Please continue the investigation"` or `"What other checks can you run?"` The agent can resume from the current state.
- If timeouts are the cause, scope the next query more narrowly. For example, "check the specific namespace `<name>`" rather than the full cluster.
- If the investigation stopped due to rate limiting, wait a minute and ask the agent to proceed.
- For a fresh start, open a new conversation and provide a concise summary of what was already found: "I've confirmed DNS resolution is failing in namespace X. Can you investigate the NetworkPolicy for that namespace?"

---

## Workload identity not enabled on the cluster

**Symptom:** Federated credential setup fails, or the agent pod cannot authenticate to Azure. Pod logs show `"Failed to acquire token"` or `"AADSTS..."` errors.

**Cause:** The AKS cluster was created without the OIDC issuer or workload identity enabled.

**Resolution:** Enable both features on your existing cluster using the [`az aks update`](/cli/azure/aks#az-aks-update) command:

```azurecli-interactive
az aks update \
  --resource-group $RESOURCE_GROUP \
  --name $CLUSTER_NAME \
  --enable-oidc-issuer \
  --enable-workload-identity
```

After enabling, re-run the federated credential setup steps from the deployment guide to link the managed identity to the Kubernetes service account.

---

## Azure OpenAI model not available in the selected region

**Symptom:** Azure OpenAI deployment creation fails, or the Container Network Insights Agent startup fails with an endpoint or model error immediately after deployment.

**Cause:** The Azure OpenAI model you selected isn't available in your chosen Azure region.

**Resolution:**

1. Check which models are available in your region:

   ```azurecli-interactive
   az cognitiveservices model list -l <your-region> --output table
   ```

1. Use a region where your target model is available. Consult the [Azure OpenAI model region support](/azure/ai-foundry/openai/concepts/models) reference for current availability.

1. Verify your subscription has sufficient Tokens-Per-Minute (TPM) quota for the model. If model deployment fails with a quota error, request a quota increase in the Azure portal under **Cognitive Services > Quotas**.

---

## Quick diagnostic commands

Use these commands to quickly diagnose common issues:

```azurecli-interactive
# ──── Pod Status ────
kubectl get pods -n kube-system -l app=container-networking-agent
kubectl describe pod -n kube-system -l app=container-networking-agent
kubectl top pod -n kube-system -l app=container-networking-agent

# ──── Application Logs ────
kubectl logs -n kube-system -l app=container-networking-agent --tail=200
kubectl logs -n kube-system -l app=container-networking-agent -f              # Stream live
kubectl logs -n kube-system -l app=container-networking-agent | grep ERROR     # Errors only

# ──── Health Checks (requires port-forward) ────
kubectl port-forward svc/container-networking-agent-service -n kube-system 8080:80
curl -s http://localhost:8080/ready | jq
curl -s http://localhost:8080/live | jq
curl -s http://localhost:8080/api/status/sessions | jq

# ──── Configuration ────
kubectl get configmap -n kube-system -l app=container-networking-agent -o yaml
kubectl get serviceaccount container-networking-agent-reader -n kube-system -o yaml

# ──── Workload Identity ────
kubectl describe serviceaccount container-networking-agent-reader -n kube-system
az identity show --name $IDENTITY_NAME -g $RESOURCE_GROUP --query "{clientId:clientId, principalId:principalId}"

# ──── RBAC ────
az role assignment list --assignee <principal-id> --output table

# ──── Extension Status ────
az k8s-extension show \
  --cluster-name $CLUSTER_NAME \
  --resource-group $RESOURCE_GROUP \
  --cluster-type managedClusters \
  --name containernetworkingagent \
  --query "{state:provisioningState, version:version}" -o table

# ──── Cleanup Stuck Resources ────
kubectl delete daemonset rx-troubleshooting-debug -n kube-system    # Leftover diagnostic DaemonSet
kubectl delete pod -n kube-system -l app=container-networking-agent    # Force pod restart
```

---

## Next steps

- [Deploy and use Container Network Insights Agent on AKS](./how-to-configure-container-network-insights-agent.md)
- [Container Network Insights Agent overview](./container-network-insights-agent-overview.md)
- [Advanced Container Networking Services overview](/azure/aks/advanced-container-networking-services-overview)
- [Azure CNI powered by Cilium](/azure/aks/azure-cni-powered-by-cilium)
