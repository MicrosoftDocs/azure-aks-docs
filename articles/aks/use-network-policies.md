---
title: Secure Pod Traffic with Network Policies in Azure Kubernetes Service (AKS)
description: Learn how to implement network policies in AKS to control and secure pod traffic by restricting communication according to the principle of least privilege.
author: schaffererin
ms.author: schaffererin
ms.date: 06/10/2025
ms.service: azure-kubernetes-service
ms.topic: how-to
ms.custom:
  - devx-track-azurecli
  - build-2025
  - biannual
# Customer intent: As a DevOps engineer, I want to implement network policies in Azure Kubernetes Service, so that I can control and secure pod traffic by restricting communication according to the principle of least privilege.
---

# Secure traffic between pods with network policies in Azure Kubernetes Service (AKS)

[!INCLUDE [azure-network-policy-manager-windows-retirement](./includes/azure-network-policy-manager-windows-retirement.md)]

[!INCLUDE [azure-network-policy-manager-linux-retirement](./includes/azure-network-policy-manager-linux-retirement.md)]

[!INCLUDE [kubenet-retirement](./includes/kubenet-retirement.md)]

Install a network policy engine and create Kubernetes network policies to control the flow of traffic between pods in AKS clusters.

## Overview of network policy

By default, all pods in an AKS cluster can send and receive traffic without limitations. To improve security, you can define rules that control the flow of traffic.

Network policy is a Kubernetes specification that defines access policies for communication between pods. When you use network policies, you define an ordered set of rules to send and receive traffic. You apply the rules to a collection of pods that match one or more label selectors. 

You define the network policy rules as YAML manifests, and you can include them in wider manifests that also create a deployment or service.

## Network policy options in AKS

Azure provides three network policy engines for enforcing network policies:

- **Cilium** (for AKS clusters using [Azure CNI Powered by Cilium](./azure-cni-powered-by-cilium.md))
- **Azure Network Policy Manager (NPM)**
- **Calico** (an open-source network and network security solution founded by [Tigera][tigera])

We recommend using Cilium. Cilium enforces network policy on the traffic using Linux Berkeley Packet Filter (BPF), which is more efficient than _IPTables_.

To enforce the specified policies, Azure NPM uses _IPTables_ for Linux and _Host Network Service (HNS) ACLPolicies_ for Windows. Policies are translated into sets of allowed and disallowed IP pairs. These pairs are then programmed as `IPTable` or `HNS ACLPolicy` filter rules.

## Differences between network policy engines: Cilium, Azure NPM, and Calico

| Network policy engine | Supported platforms | Supported networking options | Kubernetes specification compliance | Other features | Support |
| --------------------- | ------------------- | ---------------------------- | ----------------------------------- | -------------- | ------- |
| Cilium | Linux | Azure CNI | Supports all policy types | [FQDN](./container-network-security-fqdn-filtering-concepts.md), L3/4, [L7](./container-network-security-l7-policy-concepts.md) | Azure support and engineering team |
| Azure NPM | Linux, Windows Server 2022 | Azure CNI | Supports all policy types | N/A | Azure support and engineering team |
| Calico | Linux, Windows Server 2019, Windows Server 2022 | Azure CNI (Linux, Windows Server 2019, Windows Server 2022) and kubenet (Linux) | Supports all policy types | While Calico has many features that AKS doesn't block, AKS doesn't test or support them. For more information, see [Calico Network Policy issue](https://github.com/Azure/AKS/issues/4038). | Azure support and engineering team |

## Azure Network Policy Manager limitations (Linux)

Azure NPM for Linux has the following limitations:

- Scaling beyond _250 nodes_ and _20,000 pods_ isn't supported. If you attempt to scale beyond these limits, you might experience _Out of Memory (OOM)_ errors. For better scalability and IPv6 support, we recommend using or upgrading to [Azure CNI Powered by Cilium](./update-azure-cni.md) for your network policy engine.
- IPv6 isn't supported. Otherwise, it fully supports the network policy specifications in Linux.

## Azure Network Policy Manager limitations (Windows)

Azure NPM for Windows doesn't support the following features of the network policy specifications:

- Named ports.
- Stream Control Transmission Protocol (SCTP).
- Negative match label or namespace selectors. For example, all labels except `debug=true`.
- `except` classless interdomain routing (CIDR) blocks (CIDR with exceptions).

## Known issues with Azure Network Policy Manager

You might experience temporary connectivity issues for new connections to/from pods on impacted nodes when either editing or deleting a "large enough" network policy. Hitting this race condition never impacts active connections.

If this race condition occurs for a node, the Azure NPM pod on that node enters a state where it can't update security rules, which might lead to unexpected connectivity for new connections to/from pods on the impacted node. To mitigate the issue, the Azure NPM pod automatically restarts ~15 seconds after entering this state. While Azure NPM is rebooting on the impacted node, it deletes all security rules, then reapplies security rules for all network policies. While all the security rules are being reapplied, there's a chance of temporary, unexpected connectivity for new connections to/from pods on the impacted node.

To limit the chance of hitting this race condition, you can reduce the size of the network policy. This issue is most likely to happen for a network policy with several `ipBlock` sections. A network policy with _four or fewer_ `ipBlock` sections is less likely to hit the issue.

## Load balancer services and network policies

Kubernetes service routing for both inbound and outbound services often involves rewriting the source and destination IPs on traffic that's being processed, including traffic that comes into the cluster from a `LoadBalancer` service. This rewrite behavior means that the network policies might not properly process traffic being received from or sent to an external service. For more information, see the [Kubernetes Network Policies documentation][kubernetes-network-policies].

To restrict what sources can send traffic to a load balancer service, use `spec.loadBalancerSourceRanges` to configure traffic blocking that applies before any rewrites occur. For more information, see the [AKS Standard load balancer documentation](/azure/aks/load-balancer-standard#restrict-inbound-traffic-to-specific-ip-ranges).

## Before you begin

You need the Azure CLI version 2.0.61 or later installed and configured. Find the version using the `az --version` command. If you need to install or upgrade, see [Install Azure CLI][install-azure-cli].

Instead of using a system-assigned identity, you can also use a user-assigned identity. For more information, see [Use managed identities](use-managed-identity.md).

## Create an AKS cluster with Azure Network Policy Manager (Linux)

1. Set environment variables for the resource group name, cluster name, and location. Replace the values as needed.

    ```bash
    export RESOURCE_GROUP=myResourceGroup
    export CLUSTER_NAME=myAKSCluster
    export LOCATION=eastus
    ```

1. Create an AKS cluster using the [`az aks create`][az-aks-create] and specify `azure` for the `network-plugin` and `network-policy`.

    ```azurecli-interactive
    az aks create \
        --resource-group $RESOURCE_GROUP \
        --name $CLUSTER_NAME \
        --node-count 1 \
        --network-plugin azure \
        --network-policy azure \
        --generate-ssh-keys
    ```

## Create an AKS cluster with Azure Network Policy Manager (Windows Server 2022 (preview))

[!INCLUDE [preview features callout](~/reusable-content/ce-skilling/azure/includes/aks/includes/preview/preview-callout.md)]

### Install the `aks-preview` Azure CLI extension

1. Install the `aks-preview` extension using the [`az extension add`][az-extension-add] command.

    ```azurecli-interactive
    az extension add --name aks-preview
    ```

1. Update to the latest version of the extension using the [`az extension update`][az-extension-update] command.

    ```azurecli-interactive
    az extension update --name aks-preview
    ```

### Register the `WindowsNetworkPolicyPreview` feature flag

1. Register the `WindowsNetworkPolicyPreview` feature flag using the [`az feature register`][az-feature-register] command.

    ```azurecli-interactive
    az feature register --namespace "Microsoft.ContainerService" --name "WindowsNetworkPolicyPreview"
    ```

    It takes a few minutes for the status to show _Registered_.

1. Verify the registration status using the [`az feature show`][az-feature-show] command.

    ```azurecli-interactive
    az feature show --namespace "Microsoft.ContainerService" --name "WindowsNetworkPolicyPreview"
    ```

1. When the status reflects _Registered_, refresh the registration of the `Microsoft.ContainerService` resource provider using the [`az provider register`][az-provider-register] command.

    ```azurecli-interactive
    az provider register --namespace Microsoft.ContainerService
    ```

### Create administrator credentials for Windows Server containers

- Create a username to use as administrator credentials for your Windows Server containers on your cluster. The following command prompts you for a username. Set it to `WINDOWS_USERNAME`.

    ```bash
    echo "Please enter the username to use as administrator credentials for Windows Server containers on your cluster: " && read WINDOWS_USERNAME
    ```

### Create the AKS cluster

1. Set environment variables for the resource group name, cluster name, and location. Replace the values as needed.

    ```bash
    export RESOURCE_GROUP=myResourceGroup
    export CLUSTER_NAME=myAKSCluster
    export LOCATION=eastus
    ```

1. Create an AKS cluster using the [`az aks create`][az-aks-create] and specify `azure` for the `network-plugin` and `network-policy`.

    ```azurecli-interactive
    az aks create \
        --resource-group $RESOURCE_GROUP \
        --name $CLUSTER_NAME \
        --node-count 1 \
        --windows-admin-username $WINDOWS_USERNAME \
        --network-plugin azure \
        --network-policy azure \
        --generate-ssh-keys
    ```

## Create an AKS cluster with Calico

Create an AKS cluster using the [`az aks create`][az-aks-create] command and specify `--network-plugin azure` and `--network-policy calico`. Specifying `--network-policy calico` enables Calico on both Linux and Windows node pools.

If you plan on adding Windows node pools to your cluster, include the `windows-admin-username` and `windows-admin-password` parameters that meet the [Windows Server password requirements][windows-server-password]. To create administrator credentials for Windows Server containers on your cluster, see [Create administrator credentials for Windows Server containers](#create-administrator-credentials-for-windows-server-containers).

> [!IMPORTANT]
> At this time, using Calico network policies with Windows nodes is available on new clusters using Kubernetes version 1.20 or later with Calico 3.17.2 and requires that you use Azure CNI networking. Windows nodes on AKS clusters with Calico enabled also have Floating IP enabled by default.
>
> For clusters with only Linux node pools running Kubernetes 1.20 with earlier versions of Calico, the Calico version automatically upgrades to 3.17.2.

## Install Azure Network Policy Manager or Calico on an existing cluster

> [!WARNING]
> Keep the following information in mind when installing Azure NPM or Calico on an existing cluster:
>
> - The upgrade process triggers each node pool to be reimaged simultaneously. Upgrading each node pool separately isn't supported.
> - Within each node pool, nodes follow the same reimaging process as standard Kubernetes version upgrade operations. This behavior means that buffer nodes are temporarily added to minimize disruption to running applications during the node reimaging process. Any disruptions that might occur are similar to what you might encounter during a node image upgrade or [Kubernetes version upgrade](./upgrade-cluster.md).
>
> The following information applies to upgrades from kubenet with Calico to Azure CNI Overlay with Calico:
>
> - In kubenet clusters with Calico enabled, Calico is used as both a CNI and network policy engine.
> - In Azure CNI clusters, Calico is used only for network policy enforcement, not as a CNI. This can cause a short delay between when the pod starts and when Calico allows outbound traffic from the pod.

- Update an existing cluster to install Azure NPM or Calico using the [`az aks update`][az-aks-update] command and specifying `azure` or `calico` for the `--network-policy` parameter. The following example command shows how to install either Azure NPM:

    ```azurecli-interactive
    az aks update
        --resource-group $RESOURCE_GROUP \
        --name $CLUSTER_NAME \
        --network-policy azure
    ```

## Upgrade an existing cluster with Azure NPM or Calico to Cilium

To upgrade an existing cluster to Azure CNI Powered by Cilium, see [Upgrade an existing cluster to Azure CNI Powered by Cilium](upgrade-aks-ipam-and-dataplane.md)

## Connect to the AKS cluster

- Configure `kubectl` to connect to your cluster using the [`az aks get-credentials`][az-aks-get-credentials] command. This command downloads credentials and configures the Kubernetes CLI to use them.

    ```azurecli-interactive
    az aks get-credentials --resource-group $RESOURCE_GROUP --name $CLUSTER_NAME
    ```

## Verify network policy setup

To begin verification of network policy, you create a sample application and set traffic rules.

1. Create a namespace named `demo` to run the sample pods using the `kubectl create namespace` command.

    ```bash
    kubectl create namespace demo
    ```

1. Create a pod named `server` to server on TCP port 80 using the `kubectl run` command.

    ```bash
    kubectl run server -n demo --image=k8s.gcr.io/e2e-test-images/agnhost:2.33 --labels="app=server" --port=80 --command -- /agnhost serve-hostname --tcp --http=false --port "80"
    ```

1. Create a pod named `client` to run Bash using the `kubectl run` command.

    ```bash
    kubectl run -it client -n demo --image=k8s.gcr.io/e2e-test-images/agnhost:2.33 --command -- bash
    ```

    > [!NOTE]
    > If you want to schedule the client or server on a particular node, add the following bit before the `--command` argument in the pod creation [`kubectl run`][kubectl-run] command: `--overrides='{"spec": { "nodeSelector": {"kubernetes.io/os": "linux|windows"}}}'`.

1. In a separate window, get the IP address of the `server` pod using the `kubectl get pod` command.

    ```bash
    kubectl get pod --output=wide -n demo
    ```

    Your output should resemble the following example output:

    ```output
    NAME     READY   STATUS    RESTARTS   AGE   IP            NODE             NOMINATED NODE   READINESS GATES
    server   1/1     Running   0          30s   10.224.0.72   akswin22000001   <none>           <none>
    ```

## Test connectivity with network policies

> [!TIP]
> To test connectivity without network policies, run the following command in the client shell: `/agnhost connect <server-ip>:80 --timeout=3s --protocol=tcp`. Replace `<server-ip>` with the IP address of the server pod. If the connection is successful, there's no output.

1. Create a file named `demo-policy.yaml` and paste the following YAML manifest:

    ```yaml
    apiVersion: networking.k8s.io/v1
    kind: NetworkPolicy
    metadata:
      name: demo-policy
      namespace: demo
    spec:
      podSelector:
        matchLabels:
          app: server
      ingress:
      - from:
        - podSelector:
            matchLabels:
              app: client
        ports:
        - port: 80
          protocol: TCP
    ```

1. Apply the network policy manifest using the [`kubectl apply`][kubectl-apply] command.

    ```bash
    kubectl apply –f demo-policy.yaml
    ```

1. In the client shell, verify connectivity with the server using the following `/agnhost` command:

    ```bash
    /agnhost connect <server-ip>:80 --timeout=3s --protocol=tcp
    ```

    Connectivity with traffic is blocked because the server is labeled with `app=server`, but the client isn't labeled. Your output should resemble the following example output:

    ```output
    TIMEOUT
    ```

1. Label the `client` and verify connectivity with the server using the `kubectl label` command.

    ```bash
    kubectl label pod client -n demo app=client
    ```

    If the connection is successful, there's no output.

## Migrate to self-managed Calico

AKS only supports Calico for standard Kubernetes network policies and doesn't test other features. If you want to move to self-managed Calico, follow the Tigera instructions at [Migrate from Azure-managed Calico to self-managed Calico][calico-self-managed]. The Tigera documentation mentions that for self-managed Calico you set `--network-policy none` like in the [uninstall section](#uninstall-azure-network-policy-manager-or-calico).

## Uninstall Azure Network Policy Manager or Calico

> [!NOTE]
> Keep the following information in mind when uninstalling Azure NPM or Calico from a cluster:
>
> - The uninstall process **doesn't remove** Custom Resource Definitions (CRDs) and Custom Resources (CRs) used by Calico. These CRDs and CRs all have names ending with either _projectcalico.org_ or _tigera.io_. You can manually remove these CRDs and associated CRs _after_ successfully uninstalling Calico.
> - The upgrade doesn't remove any network policy resources in the cluster, but the policies are no longer enforced after the uninstall process.

- Remove Azure Network Policy Manager or Calico from an existing cluster using the [`az aks update`][az-aks-update] command and specifying `none` for the `--network-policy` parameter.

    ```azurecli-interactive
    az aks update
        --resource-group $RESOURCE_GROUP \
        --name $CLUSTER_NAME \
        --network-policy none
    ```

## Clean up resources

In this article, you created a namespace and two pods and applied a network policy. If you no longer need these resources, you can delete them.

- Delete the resources using the [`kubectl delete`][kubectl-delete] command.

    ```bash
    kubectl delete namespace demo
    ```

## Related content

- [Network concepts for applications in Azure Kubernetes Service (AKS)][concepts-network]
- [Kubernetes network policies][kubernetes-network-policies]

<!-- LINKS - external -->
[kubectl-apply]: https://kubernetes.io/docs/reference/generated/kubectl/kubectl-commands#apply
[kubectl-delete]: https://kubernetes.io/docs/reference/generated/kubectl/kubectl-commands#delete
[kubectl-run]: https://kubernetes.io/docs/reference/generated/kubectl/kubectl-commands#run
[kubernetes-network-policies]: https://kubernetes.io/docs/concepts/services-networking/network-policies/
[tigera]: https://www.tigera.io/
[calico-support]: https://www.tigera.io/tigera-products/calico/
[calico-self-managed]: https://docs.tigera.io/calico/latest/getting-started/kubernetes/managed-public-cloud/aks-migrate

<!-- LINKS - internal -->
[install-azure-cli]: /cli/azure/install-azure-cli
[az-aks-get-credentials]: /cli/azure/aks#az-aks-get-credentials
[concepts-network]: concepts-network.md
[az-feature-register]: /cli/azure/feature#az-feature-register
[az-feature-show]: /cli/azure/feature#az-feature-show
[az-provider-register]: /cli/azure/provider#az-provider-register
[windows-server-password]: /windows/security/threat-protection/security-policy-settings/password-must-meet-complexity-requirements#reference
[az-extension-add]: /cli/azure/extension#az-extension-add
[az-extension-update]: /cli/azure/extension#az-extension-update
[az-aks-create]: /cli/azure/aks#az-aks-create
[az-aks-update]: /cli/azure/aks#az-aks-update
