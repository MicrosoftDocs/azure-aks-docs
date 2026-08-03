---
title: Manage and Rotate Certificates in Azure Kubernetes Service (AKS)
description: Learn how to manage and rotate certificates in Azure Kubernetes Service (AKS) clusters to maintain secure communication between components and ensure compliance.
author: schaffererin
ms.author: schaffererin
ms.topic: how-to
ms.subservice: aks-security
ms.service: azure-kubernetes-service
ms.custom: devx-track-azurecli
ms.date: 07/13/2026
# Customer intent: "As a Kubernetes administrator, I want to implement certificate rotation in my AKS cluster, so that I can ensure the security and compliance of my cluster by managing certificate expirations and maintaining secure communication between components."
---

# Manage and rotate certificates in Azure Kubernetes Service (AKS)

This article explains how to manage and rotate certificates in Azure Kubernetes Service (AKS) clusters to maintain secure communication between components and ensure compliance.

## Prerequisites

- Azure CLI version 2.0.77 or later. Check your version by using the `az --version` command. To install or upgrade, see [Install Azure CLI][azure-cli-install].

## Check cluster certificate authority (CA) certificate expiration date

Check the expiration date of the cluster CA certificate using the `kubectl config view` command.

```bash
kubectl config view --raw -o jsonpath="{.clusters[?(@.name == '')].cluster.certificate-authority-data}" | base64 -d | openssl x509 -text | grep -A2 Validity
```

## Check API server certificate expiration date

Check the expiration date of the API server certificate using the following `curl` command:

```bash
curl https://{apiserver-fqdn} -k -v 2>&1 | grep expire
```

## Check VMSS agent node certificate expiration date

Check the expiration date of the virtual machine scale set agent node certificate using the [`az vmss run-command invoke`](/cli/azure/vmss#az-vmss-run-command-invoke) command.

```azurecli-interactive
az vmss run-command invoke \
    --resource-group <node-resource-group> \
    --name <vmss-name> \
    --command-id RunShellScript \
    --instance-id 1 \
    --scripts "openssl x509 -in  /var/lib/kubelet/pki/kubelet-client-current.pem -noout -enddate" \
    --query "value[0].message"
```

## Check standalone VM certificate expiration date

Check the expiration date of a standalone VM using the [`az vm run-command invoke`](/cli/azure/vm#az-vm-run-command-invoke) command.

```azurecli-interactive
az vm run-command invoke \
    --resource-group <resource-group> \
    --name <vm-name> \
    --command-id RunShellScript \
    --scripts "openssl x509 -in /var/lib/kubelet/pki/kubelet-client-current.pem -noout -enddate" \
    --query "value[0].message"
```

## Manually rotate cluster CA certificates

When you rotate the cluster CA certificate, the following child certificates are also refreshed:

- Service account (SA) tokens
- API server certificates
- Kubelet client certificates
- Kubelet server certificates (if kubelet serving certificate rotation is enabled on the cluster)

> [!WARNING]
> Rotating your certificates using [`az aks rotate-certs`](/cli/azure/aks#az-aks-rotate-certs) recreates all of your nodes, virtual machine scale sets, and disks. This process can cause _up to 30 minutes of downtime_ for your AKS cluster. If the command fails before completing, use the [`az aks show`](/cli/azure/aks#az-aks-show) command to verify the status of the cluster shows _Certificate Rotating_. If the cluster is in a failed state, rerun [`az aks rotate-certs`](/cli/azure/aks#az-aks-rotate-certs) to rotate your certificates again.

1. Connect to your cluster using the [`az aks get-credentials`][az-aks-get-credentials] command.

    ```azurecli-interactive
    az aks get-credentials --resource-group <resource-group> --name <cluster-name>
    ```

1. Rotate all certificates, CAs, and SAs on your cluster using the [`az aks rotate-certs`][az-aks-rotate-certs] command.

    ```azurecli-interactive
    az aks rotate-certs --resource-group <resource-group> --name <cluster-name>
    ```

1. Verify the old certificates are no longer valid using any `kubectl` command, such as `kubectl get nodes`.

    ```bash
    kubectl get nodes
    ```

    If you didn't update the certificates used by `kubectl`, you see an error similar to the following example output:

    ```output
    Unable to connect to the server: x509: certificate signed by unknown authority (possibly because of "crypto/rsa: verification error" while trying to verify candidate authority certificate "ca")
    ```

## Update `kubectl` client certificates

1. Update the `kubectl` client certificate using the [`az aks get-credentials`][az-aks-get-credentials] command with the `--overwrite-existing` flag.

    ```azurecli-interactive
    az aks get-credentials --resource-group <resource-group> --name <cluster-name> --overwrite-existing
    ```

1. Verify the certificates are updated using the [`kubectl get`][kubectl-get] command.

    ```bash
    kubectl get nodes
    ```

    > [!NOTE]
    > If you have any services that run on top of AKS, you might need to update their certificates.

## Verify kubelet serving certificate rotation is enabled

Each node with the feature enabled is automatically given the label `kubernetes.azure.com/kubelet-serving-ca=cluster`. Verify the labels are set by using the `kubectl get nodes -L kubernetes.azure.com/kubelet-serving-ca` command.

```bash
kubectl get nodes -L kubernetes.azure.com/kubelet-serving-ca
```

### Verify kubelet goes through TLS bootstrapping process

When you enable this feature, each kubelet running your nodes goes through the serving [TLS bootstrapping process](https://kubernetes.io/docs/reference/access-authn-authz/kubelet-tls-bootstrapping/#certificate-rotation).

Verify the bootstrapping process is taking place using the [`kubectl get`][kubectl-get] command to get the current CSR objects within your cluster.

```bash
kubectl get csr --field-selector=spec.signerName=kubernetes.io/kubelet-serving
```

All serving CSRs are in the `Approved,Issued` state, which indicates the CSR was approved and issued a signed certificate. Serving CSRs have a signer name of `kubernetes.io/kubelet-serving`. For example:

```output
NAME        AGE    SIGNERNAME                                    REQUESTOR                    REQUESTEDDURATION   CONDITION
csr-1ab2c   113s   kubernetes.io/kube-apiserver-client-kubelet   system:bootstrap:abcd1e      none              Approved,Issued
csr-defgh   111s   kubernetes.io/kubelet-serving                 system:node:akswinp1000000   none              Approved,Issued
csr-ij3kl   46m    kubernetes.io/kubelet-serving                 system:node:akswinp2000000   none              Approved,Issued
csr-mn4op   46m    kubernetes.io/kube-apiserver-client-kubelet   system:bootstrap:ab1cde      none              Approved,Issued
```

## Verify kubelet is using a certificate obtained from server TLS bootstrapping

Confirm whether the node's kubelet is using a serving certificate signed by the cluster CA using the [`kubectl debug`][kubectl-debug] command to examine the contents of the kubelet's PKI directory.

```bash
kubectl debug node/<node> -ti --image=mcr.microsoft.com/azurelinux/base/core:3.0 -- ls -l /host/var/lib/kubelet/kubelet-server-current.pem
```

If a `kubelet-server-current.pem` symlink exists, the kubelet bootstraps and rotates its own serving certificate through the TLS bootstrapping process and is signed by the cluster CA.

## Disable kubelet serving certificate rotation

1. Disable kubelet serving certificate rotation by updating the node pool using the [`az aks nodepool update`][az-aks-nodepool-update] command and specify the tag `aks-disable-kubelet-serving-certificate-rotation=true`.

    ```azurecli-interactive
    az aks nodepool update \
        --cluster-name <cluster-name> \
        --resource-group <resource-group> \
        --name <node-pool-name> \
        --tags aks-disable-kubelet-serving-certificate-rotation=true
    ```

1. Reimage your nodes using a [node image upgrade][node-image-upgrade] or by scaling the pool to _zero_ instances and then back up to the desired value.

## Related content

For more information on AKS security, see the following articles:

- [Best practices for cluster security and upgrades in Azure Kubernetes Service (AKS)](./operator-best-practices-cluster-security.md)
- [Security concepts for applications and clusters in Azure Kubernetes Service (AKS)](./concepts-security.md)

<!-- LINKS - internal -->
[azure-cli-install]: /cli/azure/install-azure-cli
[az-aks-nodepool-update]: /cli/azure/aks#az-aks-update
[az-aks-get-credentials]: /cli/azure/aks#az_aks_get_credentials
[az-aks-rotate-certs]: /cli/azure/aks#az_aks_rotate_certs
[node-image-upgrade]: node-image-upgrade.md

<!-- LINKS - external -->
[kubectl-get]: https://kubernetes.io/docs/reference/generated/kubectl/kubectl-commands#get
