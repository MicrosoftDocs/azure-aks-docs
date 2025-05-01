---
title: 'Overview of deploying a highly available PostgreSQL database on AKS with Azure CLI'
description: Learn how to deploy a highly available PostgreSQL database on AKS using the CloudNativePG operator.
ms.topic: overview
ms.date: 06/07/2024
author: kenkilty
ms.author: kkilty
ms.custom: aks-related-content
#Customer intent: As a developer or cluster operator, I want to deploy a highly available PostgreSQL database on AKS so I can see how to run a stateful database workload using the managed Kubernetes service in Azure.
---
# Deploy a highly available PostgreSQL database on AKS with Azure CLI

In this guide, you deploy a highly available PostgreSQL cluster that spans multiple Azure availability zones on AKS with Azure CLI.

This article walks through the prerequisites for setting up a PostgreSQL cluster on [Azure Kubernetes Service (AKS)][what-is-aks] and provides an overview of the full deployment process and architecture.

[!INCLUDE [open source disclaimer](./includes/open-source-disclaimer.md)]

## Prerequisites

* This guide assumes a basic understanding of [core Kubernetes concepts][core-kubernetes-concepts] and [PostgreSQL][postgresql].
* You need the **Owner** or **User Access Administrator** and the **Contributor** [Azure built-in roles][azure-roles] on a subscription in your Azure account.

[!INCLUDE [azure-CLI-prepare-your-environment-no-header.md](~/reusable-content/azure-cli/azure-cli-prepare-your-environment-no-header.md)]

* You also need the following resources installed:

  * [Azure CLI](/cli/azure/install-azure-cli) version 2.56 or later.
  * [Azure Kubernetes Service (AKS) preview extension][aks-preview].
  * [jq][jq], version 1.5 or later.
  * [kubectl][install-kubectl] version 1.21.0 or later.
  * [Helm][install-helm] version 3.0.0 or later.
  * [openssl][install-openssl] version 3.3.0 or later.
  * [Visual Studio Code][install-vscode] or equivalent.
  * [Krew][install-krew] version 0.4.4 or later.
  * [kubectl CloudNativePG (CNPG) Plugin][cnpg-plugin].

## Deployment process

In this guide, you learn how to:

* Use Azure CLI to create a multi-zone AKS cluster.
* Deploy a highly available PostgreSQL cluster and database using the [CNPG operator][cnpg-plugin].
* Set up monitoring for PostgreSQL using Prometheus and Grafana.
* Deploy a sample dataset to a PostgreSQL database.
* Perform PostgreSQL and AKS cluster upgrades.
* Simulate a cluster interruption and PostgreSQL replica failover.
* Perform backup and restore of a PostgreSQL database.

## Deployment architecture

This diagram illustrates a PostgreSQL cluster setup with one primary replica and two read replicas managed by the [CloudNativePG (CNPG)](https://cloudnative-pg.io/) operator. The architecture provides a highly available PostgreSQL running on an AKS cluster that can withstand a zone outage by failing over across replicas.

Backups are stored on [Azure Blob Storage](/azure/storage/blobs/), providing another way to restore the database in the event of an issue with streaming replication from the primary replica.

:::image source="./media/postgresql-ha-overview/postgres-architecture-diagram.png" alt-text="Diagram of CNPG architecture." lightbox="./media/postgresql-ha-overview/postgres-architecture-diagram.png":::

> [!NOTE]
> For applications that require data separation at the database level, you can add more databases with postInitSQL commands and similar. It is not currently possible with the CNPG operator to add more databases in a declarative way.
[Learn more](https://github.com/cloudnative-pg/cloudnative-pg) about the CNPG operator. 

### Storage considerations

The type of storage you use can have large effects on PostgreSQL performance. Later in this guide, you will select the option that is best suited for your goals and performance needs.

| Storage type | Compatible driver | Description  |
|-|-|-|
| [Premium SSD][pv1] | Azure Disks CSI driver or Azure Container Storage | **Best data resiliency**. Azure Premium SSD delivers high-performance storage and seamlessly works with Azure Premium zone-redundant storage (ZRS). Premium SSD is provisioned based on specific sizes, which each offer certain IOPS and throughput levels. |
| [Premium SSD v2][pv2] | **Best price-performance**. Azure Disks CSI driver or Azure Container Storage | Azure Premium SSD v2 offers higher performance than Azure Premium SSDs while also generally being less costly. Unlike Premium SSDs, Premium SSD v2 doesn't have dedicated sizes. You can set a Premium SSD v2 to any supported size you prefer, and make granular adjustments to the performance without downtime. Azure Premium SSD v2 disks have certain limitations that you should be aware of. For a complete list, see [Premium SSD v2 limitations][pv2-limitations]. |
| [Local NVMe or temp SSD (Ephemeral Disks)][ephemeral-disks] | Azure Container Storage only | **Maximum performance**. Ephemeral Disks are the local NVMe and temp SSD storage resources available to select VM families. This provides the highest possible IOPS and throughput to your AKS cluster while providing the lowest sub-millsecond latency. However, ephemeral means that the disks are deployed on the local VMs hosting the AKS cluster and not saved to an Azure storage service. Data will be lost on these disks if you stop/deallocate your cluster. Using Ephemeral Disks is straightforward with Azure Container Storage, which exposes these storage devices to your AKS cluster. [Azure Container Storage](/azure/storage/container-storage/container-storage-introduction) is a managed Kubernetes storage solution that dynamically provisions persistent volumes for stateful applications like Kafka. Based on the OpenEBS open-source project, it provides enterprise-grade storage capabilities specifically optimized for containerized workloads. |

## Next steps

> [!div class="nextstepaction"]
> [Create the infrastructure to deploy a highly available PostgreSQL database on AKS using the CNPG operator][create-infrastructure]

## Contributors

*Microsoft maintains this article. The following contributors originally wrote it:*

* Ken Kilty | Principal TPM
* Russell de Pina | Principal TPM
* Adrian Joian | Senior Customer Engineer
* Jenny Hayes | Senior Content Developer
* Carol Smith | Senior Content Developer
* Erin Schaffer | Content Developer 2
* Adam Sharif | Customer Engineer 2

<!-- LINKS -->
[what-is-aks]: ./what-is-aks.md
[postgresql]: https://www.postgresql.org/
[core-kubernetes-concepts]: ./concepts-clusters-workloads.md
[azure-roles]: /azure/role-based-access-control/built-in-roles
[aks-preview]: ./draft.md#install-the-aks-preview-azure-cli-extension
[jq]: https://jqlang.github.io/jq/
[install-kubectl]: https://kubernetes.io/docs/tasks/tools/install-kubectl/
[install-helm]: https://helm.sh/docs/intro/install/
[install-openssl]: https://www.openssl.org/
[install-vscode]: https://code.visualstudio.com/Download
[install-krew]: https://krew.sigs.k8s.io/
[cnpg-plugin]: https://cloudnative-pg.io/documentation/current/kubectl-plugin/#using-krew
[create-infrastructure]: ./create-postgresql-ha.md
[pv1]: /azure/virtual-machines/disks-types#premium-ssds
[pv2]: /azure/virtual-machines/disks-types#premium-ssd-v2
[pv2-limitations]: /azure/virtual-machines/disks-types#premium-ssd-v2-limitations
[ephemeral-disks]: /azure/storage/container-storage/use-container-storage-with-local-disk#what-is-ephemeral-disk
