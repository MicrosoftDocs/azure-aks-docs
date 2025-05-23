---
title: "Set up FQDN filtering feature for Container Network Security in Advanced Container Networking Services (ACNS)"
description: Get started with FQDN Filtering Feature for Advanced Container Networking Services (ACNS) for your AKS cluster using Azure managed Cilium Network Policies.
author: sf-msft
ms.author: samfoo
ms.service: azure-kubernetes-service
ms.subservice: aks-networking
ms.topic: how-to
ms.date: 07/30/2024
ms.custom: template-how-to-pattern, devx-track-azurecli
---

# Set up FQDN filtering feature for Container Network Security in Advanced Container Networking Services

This article shows you how to set up Advanced Container Networking Services with Container Network Security feature in AKS clusters.

## Prerequisites

* An Azure account with an active subscription. If you don't have one, create a [free account](https://azure.microsoft.com/free/?WT.mc_id=A261C142F) before you begin.
[!INCLUDE [azure-CLI-prepare-your-environment-no-header.md](~/reusable-content/azure-cli/azure-cli-prepare-your-environment-no-header.md)]

 The minimum version of Azure CLI required for the steps in this article is 2.71.0. Run `az --version` to find the version. If you need to install or upgrade, see [Install Azure CLI](/cli/azure/install-azure-cli).

## Limitations:

* Wildcard FQDN policies are partially supported. This means you can create policies that match specific patterns with a leading wildcard (for example, *.example.com), but you can't use a universal wildcard (*) to match all domains on the field `spec.egress.toPorts.rules.dns.matchPattern`
- Supported Pattern:

    `*.example.com` - This allows traffic to all subdomains under example.com.

    `app*.example.com` - This rule is more specific and only allows traffic to subdomains that start with "app" under example.com

- Unsupported Pattern
    
    `*` This attempt to match any domain name, which isn't supported.

* FQDN filtering is currently not supported with node-local DNS.
* Kubernetes service names aren't supported.
* Other L7 policies aren't supported.
* FQDN pods might exhibit performance degradation when handling more than 1,000 requests per second.
* If Advanced Container Networking Services(ACNS) security is disabled, FQDN and L7 policies (HTTP, HTTPS, Kafka, and gRPC) will be blocked.
* Alpine-based container images might encounter DNS resolution issues when used with Cilium Network Policies. This is due to musl libc's limited search domain iteration. To work around this, explicitly define all search domains in the Network Policy's DNS rules using wildcard patterns, like the below example

```yml
rules:
  dns:
  - matchPattern: "*.example.com"
  - matchPattern: "*.example.com.*.*"
  - matchPattern: "*.example.com.*.*.*"
  - matchPattern: "*.example.com.*.*.*.*"
  - matchPattern: "*.example.com.*.*.*.*.*"
- toFQDNs:
  - matchPattern: "*.example.com"
```

### Enable Advanced Container Networking Services

To proceed, you must have an AKS cluster with [Advanced Container Networking Services](./advanced-container-networking-services-overview.md) enabled.

The `az aks create` command with the Advanced Container Networking Services flag, `--enable-acns`, creates a new AKS cluster with all Advanced Container Networking Services features. These features encompass:
* **Container Network Observability:**  Provides insights into your network traffic. To learn more visit [Container Network Observability](./advanced-container-networking-services-overview.md?tabs=cilium#container-network-observability).

* **Container Network Security:** Offers security features like Fully Qualified Domain Name (FQDN) filtering. To learn more visit  [Container Network Security](./advanced-container-networking-services-overview.md?tabs=cilium#container-network-security).

#### [**Cilium**](#tab/cilium)

```azurecli-interactive
# Set an environment variable for the AKS cluster name. Make sure to replace the placeholder with your own value.
export CLUSTER_NAME="<aks-cluster-name>"

# Create an AKS cluster
az aks create \
    --name $CLUSTER_NAME \
    --resource-group $RESOURCE_GROUP \
    --generate-ssh-keys \
    --location eastus \
    --network-plugin azure \
    --network-dataplane cilium \
    --node-count 2 \
    --enable-acns
```

#### [**Non-Cilium**](#tab/non-cilium)

> [!NOTE]
> [FQDN filtering](./container-network-security-fqdn-filtering-concepts.md) feature isn't available for Non-cilium clusters

---

### Enable Advanced Container Networking Services on an existing cluster

The [`az aks update`](/cli/azure/aks#az_aks_update) command with the Advanced Container Networking Services flag, `--enable-acns`, updates an existing AKS cluster with all Advanced Container Networking Services features which includes [Container Network Observability](./advanced-container-networking-services-overview.md?tabs=cilium#container-network-observability) and the [Container Network Security](./advanced-container-networking-services-overview.md?tabs=cilium#container-network-security) feature


> [!NOTE]
> Only clusters with the Cilium data plane support Container Network Security features of Advanced Container Networking Services.

```azurecli-interactive
az aks update \
    --resource-group $RESOURCE_GROUP \
    --name $CLUSTER_NAME \
    --enable-acns
```

---    

## Get cluster credentials 

Get your cluster credentials using the [`az aks get-credentials`](/cli/azure/aks#az_aks_get_credentials) command.

```azurecli-interactive
az aks get-credentials --name $CLUSTER_NAME --resource-group $RESOURCE_GROUP
```

## Test connectivity with a policy

This section demonstrates how to observe a policy being enforced through the Cilium Agent. A DNS request is made to an allowed FQDN and another case where it's blocked.

Create a file named `demo-policy.yaml` and paste the following YAML manifest:
> [!NOTE]
>The field `spec.egress.toPorts.rules.dns.matchPattern` is **mandatory** when using to FQDNs in a policy. This section tells Cilium to inspect DNS queries and match them against specified patterns. Without this section, Cilium only allows the DNS traffic and not inspect its contents to learn which IPs are associated with the FQDNs. As a result, connections to those IPs (i.e., non-DNS traffic) are blocked because Cilium can't associate them with the allowed domain.
>
>Make sure to check the [limitations](#limitations) section first. 

```yaml
apiVersion: "cilium.io/v2"
kind: CiliumNetworkPolicy
metadata:
  name: "allow-bing-fqdn"
spec:
  endpointSelector:
    matchLabels:
      app: demo-container
  egress:
    - toEndpoints:
      - matchLabels:
          "k8s:io.kubernetes.pod.namespace": kube-system
          "k8s:k8s-app": kube-dns
      toPorts:
        - ports:
           - port: "53"
             protocol: ANY
          rules:
            dns:
              - matchPattern: "*.bing.com"
    - toFQDNs:
      - matchPattern: "*.bing.com"
```
Specify the name of your YAML manifest and apply it by using [kubectl apply][kubectl-apply]:
```console
kubectl create ns demo
kubectl apply -f demo-policy.yaml -n demo
```

### Create a demo pod

Create a `client` pod running Bash:

```bash
kubectl run -it client -n demo --image=k8s.gcr.io/e2e-test-images/agnhost:2.43 --labels="app=demo-container" --command -- bash
```

A shell with utilities for testing FQDN should open with the following output:

```output
If you don't see a command prompt, try pressing enter.
bash-5.0#
```

In a separate window, run the following command to get the node of the running pod.

```bash
kubectl get po -n demo --sort-by="{spec.nodeName}" -o wide
```

The output should look similar to the following example:

```output
NAME     READY   STATUS    RESTARTS   AGE     IP              NODE                                NOMINATED NODE   READINESS GATES
client   1/1     Running   0          5m50s   192.168.0.139   aks-nodepool1-22058664-vmss000001   <none>           <none>
```

The pod is running on a node named `aks-nodepool1-22058664-vmss000001`. Obtain the Cilium Agent instance running on that node:

```bash
kubectl get po -n kube-system -o wide --field-selector spec.nodeName="aks-nodepool1-22058664-vmss000001" | grep "cilium"
```

The expected `cilium-s4x24` should be in the output.

```output
cilium-s4x24                          1/1     Running   0          47m   10.224.0.4      aks-nodepool1-22058664-vmss000001   <none>           <none>
```

### Inspect a Cilium Agent

Use the `cilium` CLI to monitor traffic being blocked.

```bash
kubectl exec -it -n kube-system cilium-s4x24 -- sh
```

```output
Defaulted container "cilium-agent" out of: cilium-agent, install-cni-binaries (init), mount-cgroup (init), apply-sysctl-overwrites (init), mount-bpf-fs (init), clean-cilium-state (init), block-wireserver (init)
#
```

Inside this shell, run `cilium monitor -t drop`:

```output
Listening for events on 2 CPUs with 64x4096 of shared memory
Press Ctrl-C to quit
time="2024-10-08T17:48:27Z" level=info msg="Initializing dissection cache..." subsys=monitor
```

### Verify policy

From the first shell, create a request to the allowed FQDN, `*.bing.com`, as specified by the policy. This request should succeed and allowed by the agent.

```bash
./agnhost connect www.bing.com:80
```

Then create another request to an FQDN expected to be blocked:

```bash
./agnhost connect www.example.com:80
```

Cilium Agent blocked the request with the output:

```output
xx drop (Policy denied) flow 0xfddd76f6 to endpoint 0, ifindex 29, file bpf_lxc.c:1274, , identity 48447->world: 192.168.0.149:45830 -> 93.184.215.14:80 tcp SYN
```

---

## Clean up resources

If you don't plan on using this application, delete the other resources you created in this article using the [`az group delete`](/cli/azure/#az_group_delete) command.

```azurecli-interactive
  az group delete --name $RESOURCE_GROUP
```

## Next steps

In this how-to article, you learned how to install and enable security features with Advanced Container Networking Services for your AKS cluster.

* For more information about Advanced Container Networking Services for Azure Kubernetes Service (AKS), see [What is Advanced Container Networking Services for Azure Kubernetes Service (AKS)?](advanced-container-networking-services-overview.md).