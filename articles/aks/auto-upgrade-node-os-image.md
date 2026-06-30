---
title: Autoupgrade Node OS Images in Azure Kubernetes Service (AKS)
description: Learn how to choose an upgrade channel that best supports your needs for cluster's node OS security and maintenance. For AKS Automatic clusters, node OS upgrades are preconfigured using the NodeImage channel with security fixes and bug fixes. For AKS Standard clusters, select the channel that best fits your requirements.
ms.topic: how-to
ms.custom: build-2023, devx-track-azurecli, innovation-engine
ms.author: kaarthis
author: kaarthis
ms.subservice: aks-upgrade
ms.service: azure-kubernetes-service
ms.date: 06/26/2026
# Customer intent: As a cloud administrator, I want to select the appropriate node OS auto-upgrade channel for my Kubernetes cluster, so that I can ensure timely security updates and manage maintenance effectively while minimizing disruptions.
---

# Autoupgrade node OS images in Azure Kubernetes Service (AKS)

> [!div class="nextstepaction"]
> [Deploy and Explore](https://go.microsoft.com/fwlink/?linkid=2321852)

AKS provides multiple autoupgrade channels dedicated to timely node-level OS security updates. This channel is different from cluster-level Kubernetes version upgrades and supersedes it.

> [!TIP]
> If you're using **AKS Automatic**, node OS upgrades are preconfigured to use the **NodeImage** channel with security fixes and bug fixes applied on a weekly cadence. No configuration is needed. For AKS Automatic clusters with custom virtual networks, you can adjust maintenance windows if needed. To learn more, see [What is Azure Kubernetes Service (AKS) Automatic?][intro-aks-automatic] For AKS Standard clusters, continue reading to select the channel that best fits your requirements.

[!INCLUDE [azure linux 2.0 retirement](./includes/azure-linux-retirement.md)]

## Interactions between node OS autoupgrade and cluster autoupgrade

Node-level OS security updates are released at a faster rate than Kubernetes patch or minor version updates. The node OS autoupgrade channel grants you flexibility and enables a customized strategy for node-level OS security updates. Then, you can choose a separate plan for cluster-level Kubernetes version [autoupgrades][Autoupgrade].
It's best to use both cluster-level [autoupgrades][Autoupgrade] and the node OS autoupgrade channel together. Scheduling can be fine-tuned by applying two separate sets of [maintenance windows][planned-maintenance] - `aksManagedAutoUpgradeSchedule` for the cluster [autoupgrade][Autoupgrade] channel and `aksManagedNodeOSUpgradeSchedule` for the node OS autoupgrade channel.

## Channels for node OS image upgrades

The selected channel determines the timing of upgrades. When making changes to node OS auto-upgrade channels, allow up to 24 hours for the changes to take effect.

> [!NOTE]
>
> - Node OS image autoupgrades don't affect the cluster's Kubernetes version. 
> - Starting with API version 2023-06-01, the default for any new **AKS Standard** cluster is `NodeImage`.
> - **AKS Automatic** clusters always use the `NodeImage` channel by default.

### Node OS channel changes that cause a reimage

The following node os channel transitions will trigger reimage on the nodes:

|From|To
|----|---|
| Unmanaged | None |
| Unspecified | Unmanaged |
| SecurityPatch | Unmanaged |
| NodeImage | Unmanaged |
| None | Unmanaged |

### Available node OS upgrade channels

The following upgrade channels are available for AKS Standard clusters. (AKS Automatic clusters use the NodeImage channel by default.)

|Channel|Description|OS-specific behavior|
|---|---|---|
| `None`| Your nodes don't have security updates applied automatically. This means you're solely responsible for your security updates.|N/A|
| `Unmanaged`|The OS built-in patching infrastructure automatically applies OS updates. Newly allocated machines are initially unpatched. The OS's infrastructure patches them at some point.|Ubuntu and Azure Linux (CPU node pools) apply security patches through unattended upgrade/dnf-automatic roughly once per day around 06:00 UTC. Windows doesn't automatically apply security patches, so this option behaves equivalently to `None`. You need to manage the reboot process using a tool like [kured][kured]. [Azure Linux with OS Guard on AKS][os-guard] doesn't support `Unmanaged`.|
| `SecurityPatch`|OS security patches, which are AKS-tested, fully managed, and applied with safe deployment practices. AKS regularly updates the node's virtual hard disk (VHD) with patches from the image maintainer labeled "security only." There might be disruptions when the security patches are applied to the nodes. However AKS is limiting disruptions by only reimaging your nodes only when necessary, such as for certain kernel security packages. When the patches are applied, the VHD is updated and existing machines are upgraded to that VHD, honoring maintenance windows and surge settings. If AKS decides that reimaging nodes isn't necessary, it patches nodes live without draining pods and performs no VHD update. This option incurs the extra cost of hosting the VHDs in your node resource group. If you use this channel, Linux [unattended upgrades][unattended-upgrades] are disabled by default.| Azure Linux doesn't support this channel on GPU-enabled VMs. `SecurityPatch` works on kubernetes patch versions that are deprecated, so long as the minor Kubernetes version is still supported. [Flatcar Container Linux for AKS][flatcar] and [Azure Linux with OS Guard on AKS][os-guard] do not support `SecurityPatch`.|
| `NodeImage`| AKS updates the nodes with a newly patched VHD containing security fixes and bug fixes on a weekly cadence. The update to the new VHD is disruptive, following maintenance windows and surge settings. No extra VHD cost is incurred when choosing this option. If you use this channel, Linux [unattended upgrades][unattended-upgrades] are disabled by default. Node image upgrades are supported as long as cluster Kubernetes minor version is still in support. Node images are AKS-tested, fully managed, and applied with safe deployment practices.|

## What to choose - SecurityPatch Channel or NodeImage Channel?

### For AKS Automatic clusters

AKS Automatic uses the **NodeImage** channel by default. This channel provides the best balance of security fixes, bug fixes, and manageability for production workloads. The weekly cadence aligns with AKS best practices and is tuned for optimal cluster performance without manual intervention.

**No configuration is required** - upgrades happen automatically within your maintenance window. You can [adjust maintenance windows][planned-maintenance] if you want to control when updates occur, but the channel choice is fixed.

**Why NodeImage for AKS Automatic?**

- Includes both security fixes and bug fixes for comprehensive stability
- Weekly cadence provides predictable update timing
- Fully managed by AKS with safe deployment practices
- No extra VHD hosting costs
- Optimized for production workloads with recommended defaults

### For AKS Standard clusters

If you're using AKS Standard, evaluate your requirements using the comparison below to choose between `SecurityPatch` or `NodeImage` channels.

There are two important considerations for you to choose between `SecurityPatch` or `NodeImage` channels:

|Property|NodeImage Channel|SecurityPatch Channel|Recommended Channel|
|---|---|---|---|
| `Speed of shipping`|The typical build, test, release, and rollout timelines for a new VHD can take approximately two weeks following safe deployment practices. Although in the event of CVEs, accelerated rollouts can occur on a case by case basis. The exact timing when a new VHD hits a region can be monitored via [release-tracker]. | SecurityPatch releases are relatively faster than `NodeImage`, even with safe deployment practices. SecurityPatch has the advantage of 'Live-patching' in Linux environments, where patching leads to selective 'reimaging' and doesn't reimage every time a patch gets applied. Re-image if it happens is controlled by maintenance windows. |`SecurityPatch`|
| `Bugfixes`| Carries bug fixes in addition to security fixes.| Strictly carries only security fixes.| `NodeImage`|

## Cluster mode comparison

The following table summarizes node OS autoupgrade configuration by cluster mode:

| Aspect | AKS Automatic | AKS Standard |
|--------|---------------|--------------|
| **Default channel** | NodeImage (preconfigured) | Manual selection required |
| **Update cadence** | Weekly (fixed) | Based on your selected channel |
| **Configuration required** | None - upgrades automatic | Yes - select channel and schedule |
| **Includes bug fixes** | Yes | Only if NodeImage channel selected |
| **Recommended for** | Most production workloads | Custom requirements or specific constraints |
| **Maintenance window control** | Optional | Highly recommended |

## Set the node OS autoupgrade channel on a new cluster

> [!NOTE]
> If you're creating an **AKS Automatic cluster**, skip these steps. The NodeImage channel is already preconfigured. These steps apply to AKS Standard clusters only.

### [Azure CLI](#tab/azure-cli)

Set the node OS autoupgrade channel on a new cluster using the [`az aks create`][az-aks-create] command with the `--node-os-upgrade-channel` parameter. The following example sets the node OS autoupgrade channel to `SecurityPatch`.

```text
export RANDOM_SUFFIX=$(openssl rand -hex 3)
export RESOURCE_GROUP="myResourceGroup$RANDOM_SUFFIX"
export AKS_CLUSTER="myAKSCluster$RANDOM_SUFFIX"
az aks create \
    --resource-group $RESOURCE_GROUP \
    --name $AKS_CLUSTER \
    --node-os-upgrade-channel SecurityPatch \
    --generate-ssh-keys
```

### [Azure portal](#tab/azure-portal)

1. In the Azure portal, select **Create a resource** > **Containers** > **Azure Kubernetes Service (AKS)**.
1. In the **Basics** tab, under **Cluster details**, select the desired channel type from the **Node security channel type** dropdown.

    :::image type="content" source="./media/auto-upgrade-node-os-image/set-nodeimage-channel-portal.png" alt-text="A screenshot of the Azure portal showing the node security channel type option in the Basics tab of the AKS cluster creation page.":::

1. Select **Security channel scheduler** and choose the desired maintenance window using the [Planned Maintenance feature](./planned-maintenance.md). We recommend selecting the default option **Every week on Sunday (recommended)**.

    :::image type="content" source="./media/auto-upgrade-node-os-image/set-nodeimage-maintenance-window-portal.png" alt-text="A screenshot of the Azure portal showing the security channel scheduler option in the Basics tab of the AKS cluster creation page.":::

1. Complete the remaining steps to create the cluster.

---

## Set the node OS autoupgrade channel on an existing cluster

> [!NOTE]
> If you're using an AKS Automatic cluster, you can't change the node OS autoupgrade channel - it's preconfigured to use NodeImage. These steps apply to AKS Standard clusters only. You can adjust maintenance windows for your AKS Automatic cluster if needed.

### [Azure CLI](#tab/azure-cli)

Set the node OS autoupgrade channel on an existing cluster by using the [`az aks update`][az-aks-update] command with the `--node-os-upgrade-channel` parameter. The following example sets the node OS autoupgrade channel to `SecurityPatch`.

```azurecli-interactive
az aks update --resource-group $RESOURCE_GROUP --name $AKS_CLUSTER --node-os-upgrade-channel SecurityPatch
```

Results:

<!-- expected_similarity=0.3 -->
```JSON
{
  "autoUpgradeProfile": {
      "nodeOsUpgradeChannel": "SecurityPatch"
  }
}
```

### [Azure portal](#tab/azure-portal)

1. In the Azure portal, navigate to your AKS cluster.
1. In the **Settings** section, select **Cluster configuration**.
1. Under **Security updates**, select the desired channel type from the **Node security channel type** dropdown.

    :::image type="content" source="./media/auto-upgrade-node-os-image/set-nodeimage-channel-portal-existing.png" alt-text="A screenshot of the Azure portal showing the node security channel type option in the Cluster configuration page of an existing AKS cluster.":::

1. For **Security channel scheduler**, select **Add schedule**.
1. On the **Add maintenance schedule** page, configure the following maintenance window settings using the [Planned Maintenance feature](./planned-maintenance.md):

    - **Repeats**: Select the desired frequency for the maintenance window. We recommend selecting **Weekly**.
    - **Frequency**: Select the desired day of the week for the maintenance window. We recommend selecting **Sunday**.
    - **Maintenance start date**: Select the desired start date for the maintenance window.
    - **Maintenance start time**: Select the desired start time for the maintenance window.
    - **UTC offset**: Select the desired UTC offset for the maintenance window. If you don't set this value, the default is **+00:00**.

    :::image type="content" source="./media/auto-upgrade-node-os-image/set-nodeimage-maintenance-window-portal-existing.png" alt-text="A screenshot of the Azure portal showing the maintenance schedule configuration options in the Add maintenance schedule page of an existing AKS cluster.":::

1. Select **Save** > **Apply**.

---

## Adjust maintenance windows for AKS Automatic clusters

> [!NOTE]
> AKS Automatic clusters use the preconfigured NodeImage channel and can't change this selection. However, you can adjust when upgrades occur by configuring maintenance windows.

### [Azure CLI](#tab/azure-cli)

Set a maintenance window for node OS autoupgrades using the [`az aks update`][az-aks-update] command with the `--node-os-upgrade-channel NodeImage` parameter and `--schedule-config` options:

```azurecli-interactive
az aks update \
    --resource-group $RESOURCE_GROUP \
    --name $AKS_CLUSTER \
    --node-os-upgrade-channel NodeImage \
    --schedule-config "scheduled-maintenance-window=true" \
    --maintenance-window "frequency=Weekly,day-of-week=Sunday,utc-offset=+00:00,duration-hours=4,start-hour=2"
```

### [Azure portal](#tab/azure-portal)

1. In the Azure portal, go to your AKS cluster.
1. In the **Settings** section, select **Cluster configuration**.
1. Under **Security updates**, you see that the **Node security channel type** is set to **NodeImage** (preconfigured).
1. For **Security channel scheduler**, select **Add schedule** or edit an existing schedule.
1. Configure the maintenance window settings as described in [Planned Maintenance][planned-maintenance].

---

## Update ownership and cadence by channel

The default cadence means there's no planned maintenance window applied.

|Channel|Updates ownership|Default cadence|
|---|---|---|
| `Unmanaged`|OS driven security updates. AKS has no control over these updates.|Nightly around 6AM UTC for Ubuntu and Azure Linux. Monthly for Windows.|
| `SecurityPatch`|AKS-tested, fully managed, and applied with safe deployment practices. For more information, see [Increased security and resiliency of Canonical workloads on Azure][Blog].|Typically faster than weekly, AKS determined cadence.|
| `NodeImage`|AKS-tested, fully managed, and applied with safe deployment practices. For more real time information on releases, look up [AKS Node Images in Release tracker][release-tracker] |Weekly.|

> [!NOTE]
> While Windows security updates are released on a monthly basis, using the `Unmanaged` channel won't automatically apply these updates to Windows nodes. If you choose the `Unmanaged` channel, you need to manage the reboot process for Windows nodes. 

## Node OS autoupgrade channel known limitations

- Currently, when you set the [cluster autoupgrade channel][Autoupgrade] to `node-image`, it also automatically sets the node OS autoupgrade channel to `NodeImage`. You can't change the node OS autoupgrade channel value if your cluster autoupgrade channel is `node-image`. To set the node OS autoupgrade channel value, check the [cluster autoupgrade channel][Autoupgrade] value isn't `node-image`. 
- The `SecurityPatch` channel isn't supported on Windows OS node pools.

<<<<<<< main
- The `SecurityPatch` channel isn't supported on Windows OS node pools. 

- The `SecurityPatch` channel isn't compatible with an Azure Policy that uses a `deny` effect to require customer-managed keys (CMK) for OS disk encryption. While applying a security patch, AKS temporarily creates a virtual machine scale set (VMSS) (prefixed with `copy-`) in the node resource group (`MC_`) that such a policy disallows, so the upgrade fails with a `RequestDisallowedByPolicy` error. Using customer-managed keys on your node pools is still supported with `SecurityPatch`; the conflict is only with a `deny`-effect policy. If you require an organization-wide `deny` policy for CMK OS disk encryption, use the `NodeImage` channel instead.
 
 > [!NOTE]
 >  Use CLI version 2.61.0 or above for the `SecurityPatch` channel.
=======
> [!NOTE]
> Use CLI version 2.61.0 or later for the `SecurityPatch` channel.
>>>>>>> main

## Node OS planned maintenance windows

Planned maintenance for the node OS autoupgrade starts at your specified maintenance window.

> [!NOTE]
> To ensure proper functionality, use a maintenance window of four hours or more.

For more information on Planned Maintenance, see [Use Planned Maintenance to schedule maintenance windows for your Azure Kubernetes Service (AKS) cluster][planned-maintenance].

## Node OS autoupgrades FAQ

### How can I check the current nodeOsUpgradeChannel value on a cluster?

Run the `az aks show` command and check the "autoUpgradeProfile" to determine what value the `nodeOsUpgradeChannel` is set to:

```azurecli-interactive
az aks show --resource-group $RESOURCE_GROUP --name $AKS_CLUSTER --query "autoUpgradeProfile"
```

Results:

<!-- expected_similarity=0.3 -->
```JSON
{
  "nodeOsUpgradeChannel": "SecurityPatch"
}
```

### Is node OS autoupgrade configured differently for AKS Automatic?

Yes. AKS Automatic clusters are preconfigured to use the NodeImage channel by default - you don't need to configure anything. This configuration provides:

- Weekly security fixes and bug fixes
- Automatic reimage with safe deployment practices
- Maintenance window control (optional)
- Production-ready defaults optimized for most workloads
- No extra VHD hosting costs

AKS Standard clusters require you to select a channel based on your specific needs. To migrate from AKS Standard to AKS Automatic and benefit from these preconfigured defaults, see [What is Azure Kubernetes Service (AKS) Automatic?][intro-aks-automatic]

### Can I change the node OS autoupgrade channel on an AKS Automatic cluster?

No. AKS Automatic clusters use the NodeImage channel, and you can't change this channel. If you need a different channel, use an AKS Standard cluster. However, you can adjust maintenance windows to control when upgrades occur on your AKS Automatic cluster.

### How can I monitor the status of node OS autoupgrades?

To view the status of your node OS auto upgrades, look up [activity logs][monitor-aks] on your cluster. You can also look up specific upgrade-related events as mentioned in [Upgrade an AKS cluster][aks-upgrade]. AKS also emits upgrade-related Event Grid events. To learn more, see [AKS as an Event Grid source][aks-eventgrid].

### Can I change the node OS autoupgrade channel value if my cluster autoupgrade channel is set to `node-image`?

 No. Currently, when you set the [cluster autoupgrade channel][Autoupgrade] to `node-image`, it also automatically sets the node OS autoupgrade channel to `NodeImage`. You can't change the node OS autoupgrade channel value if your cluster autoupgrade channel is `node-image`. To change the node OS autoupgrade channel values, make sure the [cluster autoupgrade channel][Autoupgrade] isn't `node-image`.

### Why is `SecurityPatch` recommended over `Unmanaged` channel?

On the `Unmanaged` channel, AKS has no control over how and when the security updates are delivered. With `SecurityPatch`, the security updates are fully tested and follow safe deployment practices. `SecurityPatch` also honors maintenance windows. For more information, see [Increased security and resiliency of Canonical workloads on Azure][Blog].

### Does `SecurityPatch` always lead to a reimage of my nodes?

AKS limits reimages to only when necessary, such as certain kernel packages that may require a reimage to get fully applied. `SecurityPatch` is designed to minimize disruptions as much as possible. If AKS decides reimaging nodes isn't necessary, it patches nodes live without draining pods and no VHD update is performed in such cases.

### Why does `SecurityPatch` channel requires to reach `snapshot.ubuntu.com` endpoint?

With the `SecurityPatch` channel, the Linux cluster nodes have to download the required security patches and updates from ubuntu snapshot service described in [ubuntu-snapshots-on-azure-ensuring-predictability-and-consistency-in-cloud-deployments](https://ubuntu.com/blog/ubuntu-snapshots-on-azure-ensuring-predictability-and-consistency-in-cloud-deployments).

### How do I know if a `SecurityPatch` or `NodeImage` upgrade is applied on my node?

Run the `kubectl get nodes --show-labels` command to list the nodes in your cluster and their labels.

Among the returned labels, you should see a line similar to the following output:

```output
kubernetes.azure.com/node-image-version=AKSUbuntu-2204gen2containerd-202410.27.0-2024.12.01
```

Here, the base node image version is `AKSUbuntu-2204gen2containerd-202410.27.0`. If applicable, the security patch version typically follows. In the preceding example, it's `2024.12.01`.   

The same details also be looked up in the Azure portal under the node label view:

:::image type="content" source="./media/auto-upgrade-node-os-image/nodeimage-securitypatch-inline.png" alt-text="A screenshot of the nodes page for an AKS cluster in the Azure portal. The label for node image version clearly shows the base node image and the latest applied security patch date." lightbox="./media/auto-upgrade-node-os-image/nodeimage-securitypatch.png":::

## Related content

For a detailed discussion of upgrade best practices and other considerations, see [AKS patch and upgrade guidance][upgrade-operators-guide].

To learn more about AKS Automatic's preconfigured settings and production-ready defaults, see [What is Azure Kubernetes Service (AKS) Automatic?][intro-aks-automatic]

<!-- LINKS -->
[planned-maintenance]: planned-maintenance.md
[release-tracker]: release-tracker.md
[unattended-upgrades]: https://help.ubuntu.com/community/AutomaticSecurityUpdates
[Autoupgrade]: auto-upgrade-cluster.md
[kured]: node-updates-kured.md
[monitor-aks]: ./monitor-aks-reference.md
[aks-eventgrid]: ./quickstart-event-grid.md
[aks-upgrade]: ./upgrade-cluster.md
[upgrade-operators-guide]: /azure/architecture/operator-guides/aks/aks-upgrade-practices
[az-aks-create]: /cli/azure/aks#az-aks-create
[az-aks-update]: /cli/azure/aks#az-aks-update
[flatcar]: ./flatcar-container-linux-for-aks.md
[os-guard]: ./use-azure-linux-os-guard.md
[intro-aks-automatic]: ./intro-aks-automatic.md

<!-- LINKS - external -->
[Blog]: https://techcommunity.microsoft.com/t5/linux-and-open-source-blog/increased-security-and-resiliency-of-canonical-workloads-on/ba-p/3970623