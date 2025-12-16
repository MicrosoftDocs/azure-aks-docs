---
title: Certificate Rotation in Azure Kubernetes Service (AKS)
description: Learn about certificate rotation in an Azure Kubernetes Service (AKS) cluster, including how to manually rotate certificates and enable autorotation for enhanced security.
author: davidsmatlak
ms.author: davidsmatlak
ms.topic: how-to
ms.subservice: aks-security
ms.service: azure-kubernetes-service
ms.custom: devx-track-azurecli
ms.date: 08/29/2024
# Customer intent: "As a Kubernetes administrator, I want to implement certificate rotation in my AKS cluster, so that I can ensure the security and compliance of my cluster by managing certificate expirations and maintaining secure communication between components."
---

# Certificate rotation in Azure Kubernetes Service (AKS)

Azure Kubernetes Service (AKS) uses certificates for authentication with many of its components. You need to periodically rotate those certificates for security or policy reasons. This article shows you how certificate rotation works in your AKS cluster.

## Prerequisites

- This article requires the Azure CLI version 2.0.77 or later. Check your version using the `az --version` command. If you need to install or upgrade, see [Install Azure CLI][azure-cli-install].
- Configure `kubectl` to connect to your AKS cluster using the [`az aks get-credentials`][az-aks-get-credentials] command:

    ```azurecli-interactive
    az aks get-credentials --resource-group <resource-group> --name <cluster-name>
    ```

## AKS certificates, Certificate Authorities, and Service Accounts

AKS generates and uses the following certificates, Certificate Authorities (CA), and Service Accounts (SA):

- The AKS API server creates a CA called the _Cluster CA_, which signs certificates for one-way communication from the API server to kubelet.
- Each kubelet creates a Certificate Signing Request (CSR), which the Cluster CA signs, for communication from the kubelet to the API server.
- The API aggregator uses the Cluster CA to issue certificates for communication with other APIs. The API aggregator can also have its own CA for issuing those certificates, but it currently uses the Cluster CA.
- Each agent node uses an SA token, which the Cluster CA signs.
- The `kubectl` client has a certificate for communicating with the AKS cluster.

Microsoft maintains all certificates mentioned in this section, except for the cluster certificate.

## Certificate expiration dates

> [!IMPORTANT]
> The expiration date for your certificates depends on when your AKS cluster was created:
>
> - **AKS clusters created _before_ May 2019** have certificates that expire after two years.
> - **AKS clusters created _after_ May 2019** have Cluster CA certificates that expire after 30 years.
>
> You can verify when your cluster was created using the `kubectl get nodes` command, which shows you the `Age` of your agent nodes.

## Check cluster certificate expiration date

- Check the expiration date of the cluster certificate using the `kubectl config view` command.

    ```bash
    kubectl config view --raw -o jsonpath="{.clusters[?(@.name == '')].cluster.certificate-authority-data}" | base64 -d | openssl x509 -text | grep -A2 Validity
    ```

## Check API server certificate expiration date

- Check the expiration date of the API server certificate using the following `curl` command:

    ```bash
    curl https://{apiserver-fqdn} -k -v 2>&1 | grep expire
    ```

## Check virtual machine (VM) agent node certificate expiration date

- Check the expiration date of the VM agent node certificate using the [`az vm run-command invoke`][az-vm-run-command-invoke] command.

    **Key parameters in this command**:
      - `--resource-group <node-resource-group>`: The resource group that contains the VM agent node.
      - `--name <vm-name>`: The name of the VM agent node.
      - `--scripts "openssl x509 -in /etc/kubernetes/certs/apiserver.crt -noout -enddate"`: The script that retrieves the expiration date of the API server certificate located at `/etc/kubernetes/certs/apiserver.crt`.

    ```azurecli-interactive
    az vm run-command invoke --resource-group <node-resource-group> --name <vm-name> --command-id RunShellScript --query 'value[0].message' -otsv --scripts "openssl x509 -in /etc/kubernetes/certs/apiserver.crt -noout -enddate"
    ```

## Check certificate expiration for the Azure Virtual Machine Scale Set agent node

- Check the expiration date of the Azure Virtual Machine Scale Set agent node certificate using the [`az vmss run-command invoke`][az-vmss-run-command-invoke] command.

    **Key parameters in this command**:
      - `--resource-group <node-resource-group>`: The resource group that contains the Azure Virtual Machine Scale Set agent node.
      - `--name <vmss-name>`: The name of the Azure Virtual Machine Scale Set.
      - `--instance-id 1`: The instance ID of the Azure Virtual Machine Scale Set agent node.
      - `--scripts "openssl x509 -in  /var/lib/kubelet/pki/kubelet-client-current.pem -noout -enddate"`: The script that retrieves the expiration date of the kubelet client certificate located at `/var/lib/kubelet/pki/kubelet-client-current.pem`.

    ```azurecli-interactive
    az vmss run-command invoke --resource-group <node-resource-group> --name <vmss-name> --command-id RunShellScript --instance-id 1 --scripts "openssl x509 -in  /var/lib/kubelet/pki/kubelet-client-current.pem -noout -enddate" --query "value[0].message"
    ```

## Manually rotate your cluster certificates

1. Rotate all certificates, CAs, and SAs on your cluster using the [`az aks rotate-certs`][az-aks-rotate-certs] command.

    ```azurecli-interactive
    az aks rotate-certs --resource-group <resource-group> --name <cluster-name>
    ```

    > [!IMPORTANT]
    > The [`az aks rotate-certs`][az-aks-rotate-certs] command recreates all of your agent nodes, Azure Virtual Machine Scale Sets, and disks. This command can also cause up to _30 minutes of downtime_ for your AKS cluster. If the command fails before completing, use the [`az aks show`][az-aks-show] command to verify the status of the cluster is `Certificate Rotating`. If the cluster is in a failed state, rerun the [`az aks rotate-certs`][az-aks-rotate-certs] command to rotate your certificates again.

1. Verify the old certificates are no longer valid using any `kubectl` command. The following example uses the `kubectl get nodes` command:

    ```bash
    kubectl get nodes
    ```

    If you didn't update the certificates used by `kubectl`, you see an error similar to the following example output:

    ```output
    Unable to connect to the server: x509: certificate signed by unknown authority (possibly because of "crypto/rsa: verification error" while trying to verify candidate authority certificate "ca")
    ```

1. Update the certificate used by `kubectl` using the [`az aks get-credentials`][az-aks-get-credentials] command with the `--overwrite-existing` flag.

    ```azurecli-interactive
    az aks get-credentials --resource-group <resource-group> --name <cluster-name> --overwrite-existing
    ```

1. Verify the certificates are updated using the [`kubectl get`][kubectl-get] command.

    ```bash
    kubectl get nodes
    ```

If you have any services that run on top of AKS, you might need to update their certificates as well.

## Rotate the kubelet serving certificate

When you rotate the kubelet serving certificate, AKS allows kubelet server Transport Layer Security (TLS) Bootstrapping for both bootstrapping and rotating serving certificates signed by the Cluster CA.

### Limitations for kubelet serving certificate rotation

- Supported on Kubernetes version 1.27 and above.
- Not supported when the node pool is using a node pool snapshot based on any node image older than `202501.12.0`.
- You can't manually enable this feature. Kubelet serving certificate rotation is enabled by default on existing node pools when they perform their first upgrade to any Kubernetes version 1.27 or higher. Kubelet serving certificate rotation is enabled by default on new node pools using Kubernetes version 1.27 or higher. To see if kubelet serving certificate rotation is enabled in your region, check the [AKS releases](https://github.com/Azure/AKS/releases).

## Verify kubelet serving certificate rotation is enabled

Each node with the feature enabled is automatically given the label `kubernetes.azure.com/kubelet-serving-ca=cluster`.

- Verify the labels are set using the `kubectl get nodes -L kubernetes.azure.com/kubelet-serving-ca` command.

    ```bash
    kubectl get nodes -L kubernetes.azure.com/kubelet-serving-ca
    ```

    The output should show the label `kubernetes.azure.com/kubelet-serving-ca` with the value `cluster` for each agent node.

## Verify kubelet TLS Bootstrapping is working

- Verify the bootstrapping process is taking place using the [`kubectl get`][kubectl-get] command.

    ```bash
    kubectl get csr --field-selector=spec.signerName=kubernetes.io/kubelet-serving
    ```

    In the output, all serving CSRs should be in the `Approved,Issued` state, which indicates the CSR was approved and issued a signed certificate. Serving CSRs have a signer name of `kubernetes.io/kubelet-serving`. For example:

    ```output
    NAME        AGE    SIGNERNAME                                    REQUESTOR                    REQUESTEDDURATION   CONDITION
    csr-1ab2c   113s   kubernetes.io/kube-apiserver-client-kubelet   system:bootstrap:uoxr9r      none              Approved,Issued
    csr-defgh   111s   kubernetes.io/kubelet-serving                 system:node:akswinp7000000   none              Approved,Issued
    csr-ij3kl   46m    kubernetes.io/kubelet-serving                 system:node:akswinp6000000   none              Approved,Issued
    csr-mn4op   46m    kubernetes.io/kube-apiserver-client-kubelet   system:bootstrap:ho7zyu      none              Approved,Issued
    ```

## Verify kubelet is using a certificate obtained from server TLS Bootstrapping

- Confirm the kubelet is using a serving certificate signed by the Cluster CA using the [`kubectl debug`][kubectl-debug] command.

    ```bash
    kubectl debug node/<node> -ti --image=mcr.microsoft.com/azurelinux/base/core:3.0 -- ls -l /host/var/lib/kubelet/kubelet-server-current.pem
    ```

    If a `kubelet-server-current.pem` symlink exists, then the kubelet bootstrapped/rotated its own serving certificate, and the Cluster CA signed it.

## Disable kubelet serving certificate rotation

- Disable kubelet serving certificate rotation by updating the node pool using the [`az aks nodepool update`][az-aks-nodepool-update] command with the `aks-disable-kubelet-serving-certificate-rotation=true` tag.

    ```azurecli-interactive
    az aks nodepool update --cluster-name <cluster-name> --resource-group <resource-group> --name <node-pool-name> --tags aks-disable-kubelet-serving-certificate-rotation=true
    ```

1. Reimage your nodes using a [node image upgrade][node-image-upgrade] or by scaling the pool to _zero_ instances and then back up to the desired value.

## Certificate autorotation

Keep the following considerations in mind when using certificate autorotation:

- If you have an existing cluster, you have to upgrade that cluster to enable certificate autorotation.
- Don't disable TLS Bootstrap to keep certificate autorotation enabled.
- If the cluster is in a stopped state during certificate autorotation, only the control plane certificates are rotated. In this case, you should recreate the node pool after certificate rotation to initiate the node pool certificate rotation.
- For any AKS clusters created or upgraded after March 2022, AKS automatically rotates non-CA certificates on both the control plane and agent nodes within 80% of the client certificate valid time before they expire with no downtime for the cluster.

## Verify TLS Bootstrapping is enabled on current agent node pool

1. Verify your cluster has TLS Bootstrapping enabled by browsing to one to the following paths:

   - **On a Linux node**: `/var/lib/kubelet/bootstrap-kubeconfig` or `/host/var/lib/kubelet/bootstrap-kubeconfig`
   - **On a Windows node**: `C:\k\bootstrap-config`

    For more information, see [Connect to Azure Kubernetes Service (AKS) cluster nodes for maintenance or troubleshooting][aks-node-access].

    > [!NOTE]
    > The file path might change as Kubernetes versions evolve.

1. Once a region is configured, create a new cluster or upgrade an existing cluster to set certificate autorotation for the cluster certificate. You need to upgrade the control plane and node pool to enable this feature.

## Related content

- [Best practices for cluster security and upgrades in Azure Kubernetes Service (AKS)][aks-best-practices-security-upgrades].

<!-- LINKS - internal -->
[azure-cli-install]: /cli/azure/install-azure-cli
[az-aks-nodepool-update]: /cli/azure/aks#az-aks-update
[az-aks-get-credentials]: /cli/azure/aks#az-aks-get-credentials
[aks-best-practices-security-upgrades]: operator-best-practices-cluster-security.md
[aks-node-access]: ./node-access.md
[az-aks-rotate-certs]: /cli/azure/aks#az-aks-rotate-certs
[node-image-upgrade]: node-image-upgrade.md
[az-vm-run-command-invoke]: /cli/azure/vm/run-command#az-vm-run-command-invoke
[az-vmss-run-command-invoke]: /cli/azure/vmss/run-command#az-vmss-run-command-invoke

<!-- LINKS - external -->
[kubectl-get]: https://kubernetes.io/docs/reference/generated/kubectl/kubectl-commands#get
[kubectl-debug]: https://kubernetes.io/docs/reference/kubectl/generated/kubectl_debug/
