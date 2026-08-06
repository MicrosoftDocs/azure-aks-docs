---
title: Deploy infrastructure for Ray and Kueue on Azure Kubernetes Service (AKS)
description: Learn how to deploy the AKS cluster, KubeRay operator, Kueue controller, and Azure Blob storage for running Ray AI workloads.
ms.topic: how-to
ms.service: azure-kubernetes-service
ms.date: 06/26/2026
author: feiskyer
ms.author: peni
ms.custom: 'stateful-workloads'
---

# Deploy infrastructure for Ray and Kueue on AKS

In this article, you deploy the infrastructure required to run Ray AI workloads with Kueue on Azure Kubernetes Service (AKS). The Terraform module provisions an AKS cluster with GPU node pools, installs the KubeRay operator and Kueue controller via Helm, creates Azure Blob Storage with pre-staged datasets, and configures workload identity for secure access.

[!INCLUDE [open source disclaimer](./includes/open-source-disclaimer.md)]

## Prerequisites

* An Azure subscription. If you don't have one, create a [free account](https://azure.microsoft.com/pricing/purchase-options/azure-account?cid=msft_learn).
* [Azure CLI](/cli/azure/install-azure-cli) version 2.70 or later, authenticated with `az login`. If you have multiple subscriptions, set the correct one with `az account set --subscription <subscription-id>`.
* [Terraform](https://developer.hashicorp.com/terraform/install) version 1.6 or later.
* [kubectl](https://kubernetes.io/docs/tasks/tools/) version 1.28 or later. Install with `az aks install-cli`.
* [Python](https://www.python.org/downloads/) version 3.10 or later (required for Aurora data generation).
* GPU quota in your target Azure region. The default configuration provisions a `Standard_ND96amsr_A100_v4` node (8×A100 80 GB GPUs).

## Clone the repository

Clone the Azure/AKS repository and navigate to the infrastructure module:

```bash
git clone https://github.com/Azure/AKS
cd AKS/examples/kueue-and-ray-on-aks/1-infrastructure
```

## Install Python dependencies

The Aurora data upload step requires Python packages. Install them before deploying:

```bash
pip install -r terraform/requirements-generator.txt
```

## Check GPU quota

Verify that your subscription has quota for the GPU SKU in your target region. Replace `eastus2` with your preferred region:

```bash
LOCATION=<your-azure-region>
az vm list-usage --location "$LOCATION" --output table | grep -i "NDAMSv4_A100"
```

> [!NOTE]
> If you don't have GPU quota or want to validate the infrastructure without GPUs, deploy with `gpu_enabled=false`:
> ```bash
> terraform apply -var="subscription_id=<your-subscription-id>" -var="gpu_enabled=false"
> ```
> The CPU-only path is useful for validating infrastructure and queue configuration. Workloads that request GPUs stay Pending.

## Deploy with Terraform

Initialize and apply the Terraform module:

```bash
cd terraform
terraform init
terraform apply -var="subscription_id=<your-subscription-id>"
```

The Terraform module creates:

* An AKS cluster with OIDC issuer and workload identity enabled
* A system node pool and a GPU node pool (when `gpu_enabled=true`)
* KubeRay operator and Kueue controller (Helm releases from MCR)
* GPU monitoring DaemonSet (when `gpu_enabled=true`)
* Azure Blob Storage account with `aurora` and `llm-pipeline` containers
* User-assigned managed identity with Storage Blob Data Contributor role
* Federated identity credential for the `ray-workload` ServiceAccount
* Pre-staged datasets (Aurora WeatherBench2 data and viggo NLG dataset)

For the full Terraform module configuration, see the [1-infrastructure directory](https://github.com/Azure/AKS/tree/master/examples/kueue-and-ray-on-aks/1-infrastructure/terraform) in the repository.

## Connect to the cluster

Retrieve the credentials for your new AKS cluster:

```bash
eval "$(terraform output -raw get_credentials_command)"
```

## Verify the deployment

Confirm that the operators are running and nodes are available:

1. Verify the KubeRay operator:

    ```bash
    kubectl -n kuberay-system get pods
    ```

    Expected output:

    ```output
    NAME                                READY   STATUS    RESTARTS   AGE
    kuberay-operator-xxxxxxxxxx-xxxxx   1/1     Running   0          5m
    ```

1. Verify the Kueue controller:

    ```bash
    kubectl -n kueue-system get pods
    ```

    Expected output:

    ```output
    NAME                                            READY   STATUS    RESTARTS   AGE
    kueue-controller-manager-xxxxxxxxxx-xxxxx       1/1     Running   0          5m
    ```

1. Verify the nodes:

    ```bash
    kubectl get nodes
    ```

    Expected output (with `gpu_enabled=true`):

    ```output
    NAME                              STATUS   ROLES    AGE   VERSION
    aks-gpupool-xxxxxxxx-vmssxxxxxx   Ready    <none>   5m    v1.35.x
    aks-system-xxxxxxxx-vmssxxxxxx    Ready    <none>   10m   v1.35.x
    aks-system-xxxxxxxx-vmssxxxxxx    Ready    <none>   10m   v1.35.x
    ```

1. Verify GPU monitoring (only when `gpu_enabled=true`):

    ```bash
    kubectl -n gpu-monitoring get daemonsets
    ```

    Expected output:

    ```output
    NAME                    DESIRED   CURRENT   READY   UP-TO-DATE   AVAILABLE   NODE SELECTOR   AGE
    gpu-monitoring-a100     1         1         1       1            1           <none>          5m
    ```

## Clean up resources

To delete all Azure resources that you created by using this module:

```bash
terraform destroy -var="subscription_id=<your-subscription-id>"
```

## Next step

> [!div class="nextstepaction"]
> [Configure Kueue queues for Ray workloads on AKS](./configure-ray-kueue-queues.md)
