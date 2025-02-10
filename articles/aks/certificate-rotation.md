---
title: Certificate Rotation in Azure Kubernetes Service (AKS)
description: Learn about certificate rotation in an Azure Kubernetes Service (AKS) cluster.
author: tamram

ms.author: tamram
ms.topic: article
ms.subservice: aks-security
ms.custom: devx-track-azurecli
ms.date: 08/29/2024
---

# Certificate rotation in Azure Kubernetes Service (AKS)

Azure Kubernetes Service (AKS) uses certificates for authentication with many of its components. Clusters with Azure role-based access control (Azure RBAC) that were created after March 2022 are enabled with certificate auto rotation. You might need to periodically rotate those certificates for security or policy reasons. For example, you might have a policy to rotate all your certificates every 90 days.

> [!NOTE]
> Certificate auto rotation is enabled by default only for RBAC-enabled AKS clusters.

This article shows you how certificate rotation works in your AKS cluster.

## Before you begin

This article requires the Azure CLI version 2.0.77 or later. Run `az --version` to find the version. If you need to install or upgrade, see [Install Azure CLI][azure-cli-install].

## AKS certificates, Certificate Authorities, and Service Accounts

AKS generates and uses the following certificates, Certificate Authorities (CA), and Service Accounts (SA):

* The AKS API server creates a CA called the Cluster CA.
* The API server has a Cluster CA, which signs certificates for one-way communication from the API server to kubelets.
* Each kubelet creates a Certificate Signing Request (CSR), which the Cluster CA signs, for communication from the kubelet to the API server.
* The API aggregator uses the Cluster CA to issue certificates for communication with other APIs. The API aggregator can also have its own CA for issuing those certificates, but it currently uses the Cluster CA.
* Each node uses an SA token, which the Cluster CA signs.
* The `kubectl` client has a certificate for communicating with the AKS cluster.

Microsoft maintains all certificates mentioned in this section, except for the cluster certificate.

> [!NOTE]
>
> * **AKS clusters created *before* May 2019** have certificates that expire after two years.
> * **AKS clusters created *after* May 2019** have Cluster CA certificates that expire after 30 years.
>
> You can verify when your cluster was created using the `kubectl get nodes` command, which shows you the *Age* of your node pools.

## Check certificate expiration dates

### Check cluster certificate expiration date

* Check the expiration date of the cluster certificate using the `kubectl config view` command.

    ```console
   kubectl config view --raw -o jsonpath="{.clusters[?(@.name == '')].cluster.certificate-authority-data}" | base64 -d | openssl x509 -text | grep -A2 Validity
    ```

### Check API server certificate expiration date

* Check the expiration date of the API server certificate using the following `curl` command.

    ```console
    curl https://{apiserver-fqdn} -k -v 2>&1 | grep expire
    ```

### Check VMAS agent node certificate expiration date

* Check the expiration date of the VMAS agent node certificate using the `az vm run-command invoke` command.

    ```azurecli-interactive
    az vm run-command invoke --resource-group MC_rg_myAKSCluster_region --name vm-name --command-id RunShellScript --query 'value[0].message' -otsv --scripts "openssl x509 -in /etc/kubernetes/certs/apiserver.crt -noout -enddate"
    ```

### Check certificate expiration for the virtual machine scale set agent node

* Check the expiration date of the virtual machine scale set agent node certificate using the `az vmss run-command invoke` command.

    ```azurecli-interactive
    az vmss run-command invoke --resource-group "MC_rg_myAKSCluster_region" --name "vmss-name" --command-id RunShellScript --instance-id 1 --scripts "openssl x509 -in  /var/lib/kubelet/pki/kubelet-client-current.pem -noout -enddate" --query "value[0].message"
    ```

## Certificate auto rotation

For AKS to automatically rotate non-CA certificates, the cluster must have [TLS Bootstrapping](https://kubernetes.io/docs/reference/access-authn-authz/kubelet-tls-bootstrapping/), which is enabled by default in all Azure regions.

> [!NOTE]
>
> * If you have an existing cluster, you have to upgrade that cluster to enable Certificate Auto Rotation.
> * Don't disable Bootstrap to keep auto rotation enabled.
> * If the cluster is in a stopped state during the auto certificate rotation, only the control plane certificates are rotated. In this case, you should recreate the node pool after certificate rotation to initiate the node pool certificate rotation.

For any AKS clusters created or upgraded after March 2022, Azure Kubernetes Service automatically rotates non-CA certificates on both the control plane and agent nodes within 80% of the client certificate valid time before they expire with no downtime for the cluster.

### How to check whether current agent node pool is TLS Bootstrapping enabled?

1. Verify if your cluster has TLS Bootstrapping enabled by browsing to one to the following paths:

   * On a Linux node: */var/lib/kubelet/bootstrap-kubeconfig* or */host/var/lib/kubelet/bootstrap-kubeconfig*
   * On a Windows node: *C:\k\bootstrap-config*

    For more information, see [Connect to Azure Kubernetes Service cluster nodes for maintenance or troubleshooting][aks-node-access].

    > [!NOTE]
    > The file path might change as Kubernetes versions evolve.

2. Once a region is configured, create a new cluster or upgrade an existing cluster to set auto rotation for the cluster certificate. You need to upgrade the control plane and node pool to enable this feature.

## Manually rotate your cluster certificates

> [!WARNING]
> Rotating your certificates using `az aks rotate-certs` recreates all of your nodes, virtual machine scale sets, and disks and can cause up to *30 minutes of downtime* for your AKS cluster.

1. Connect to your cluster using the [`az aks get-credentials`][az-aks-get-credentials] command.

    ```azurecli-interactive
    az aks get-credentials --resource-group $RESOURCE_GROUP_NAME --name $CLUSTER_NAME
    ```

2. Rotate all certificates, CAs, and SAs on your cluster using the [`az aks rotate-certs`][az-aks-rotate-certs] command.

    ```azurecli-interactive
    az aks rotate-certs --resource-group $RESOURCE_GROUP_NAME --name $CLUSTER_NAME
    ```

    > [!IMPORTANT]
    > It might take up to 30 minutes for `az aks rotate-certs` to complete. If the command fails before completing, use `az aks show` to verify the status of the cluster is *Certificate Rotating*. If the cluster is in a failed state, rerun `az aks rotate-certs` to rotate your certificates again.

3. Verify the old certificates are no longer valid using any `kubectl` command, such as `kubectl get nodes`.

    ```azurecli-interactive
    kubectl get nodes
    ```

    If you haven't updated the certificates used by `kubectl`, you see an error similar to the following example output:

    ```output
    Unable to connect to the server: x509: certificate signed by unknown authority (possibly because of "crypto/rsa: verification error" while trying to verify candidate authority certificate "ca")
    ```

4. Update the certificate used by `kubectl` using the [`az aks get-credentials`][az-aks-get-credentials] command with the `--overwrite-existing` flag.

    ```azurecli-interactive
    az aks get-credentials --resource-group $RESOURCE_GROUP_NAME --name $CLUSTER_NAME --overwrite-existing
    ```

5. Verify the certificates have been updated using the [`kubectl get`][kubectl-get] command.

    ```azurecli-interactive
    kubectl get nodes
    ```

    > [!NOTE]
    > If you have any services that run on top of AKS, you might need to update their certificates.

## Kubelet serving certificate rotation
Kubelet serving certificate rotation allows AKS to utilize kubelet server TLS bootstrapping for both bootstrapping and rotating serving certificates signed by the Cluster CA.

### Limitations
- Supported on Kubernetes version 1.27 and above.
- Not supported when the node pool is provisioned based on a snapshot.
- Existing node pools will have kubelet serving certificate rotation enabled by default when they perform their first upgrade to any kubernetes version 1.27 or greater. New node pools on kubernetes version 1.27 or greater will have kubelet serving certificate rotation enabled by default. To see if kubelet serving certificate rotation has been enabled in your region, see [AKS Releases](https://github.com/Azure/AKS/releases).

### Verify kubelet serving certificate rotation has been enabled 
Each node with the feature enabled is automatically given the label `kubernetes.azure.com/kubelet-serving-ca=cluster`. Verify the labels were set using the `kubectl get nodes -L kubernetes.azure.com/kubelet-serving-ca` command.

 ```bash
kubectl get nodes -L kubernetes.azure.com/kubelet-serving-ca
 ```

### Verify kubelet goes through TLS bootstrapping process

With this feature enabled, each kubelet running your nodes should go through the serving [TLS bootstrapping process](https://kubernetes.io/docs/reference/access-authn-authz/kubelet-tls-bootstrapping/#certificate-rotation).

Verify the bootstrapping process is taking place by using the [`kubectl get`][kubectl-get] command to get the current CSR objects within your cluster.

```azurecli-interactive
kubectl get csr --field-selector=spec.signerName=kubernetes.io/kubelet-serving
```

All serving CSRs should be in the `Approved,Issued` state, which indicates the CSR was approved and issued a signed certificate. Serving CSRs have a signer name of `kubernetes.io/kubelet-serving`. 

```output
   NAME        AGE    SIGNERNAME                                    REQUESTOR                    REQUESTEDDURATION   CONDITION
csr-8mx4w   113s   kubernetes.io/kube-apiserver-client-kubelet   system:bootstrap:uoxr9r      none              Approved,Issued
csr-bchlj   111s   kubernetes.io/kubelet-serving                 system:node:akswinp7000000   none              Approved,Issued
csr-sb4wz   46m    kubernetes.io/kubelet-serving                 system:node:akswinp6000000   none              Approved,Issued
csr-zc4wt   46m    kubernetes.io/kube-apiserver-client-kubelet   system:bootstrap:ho7zyu      none              Approved,Issued
```

### Verify kubelet is using a certificate obtained from server TLS bootstrapping
To confirm whether the node's kubelet is using a serving certificate signed by the cluster CA, use  [`kubectl debug`][kubectl-debug] to examine the contents of the kubelet's PKI directory.

```azurecli-interactive
kubectl debug
```

If a `kubelet-server-current.pem` symlink exists, then the kubelet has bootstrapped/rotated its own serving certificate via the TLS bootstrapping process, and is signed by the cluster CA.

### Disable kubelet serving certificate rotation
You can disable kubelet serving certificate rotation by updating the node pool using the [az aks nodepool update][az-aks-nodepool-update] command to specify the tag `aks-disable-kubelet-serving-certificate-rotation=true` and reimaging your nodes. A node reimage can be done via a node image upgrade or by scaling the pool to 0 instances and back up to the desired value.

```azurecli-interactive
az aks nodepool update --cluster-name myCluster --resource-group myResourceGroup --name mynodepool --tags aks-disable-kubelet-serving-certificate-rotation=true
```

## Next steps

This article showed you how to manually and automatically rotate your cluster certificates, CAs, and SAs. For more information, see [Best practices for cluster security and upgrades in Azure Kubernetes Service (AKS)][aks-best-practices-security-upgrades].

<!-- LINKS - internal -->
[azure-cli-install]: /cli/azure/install-azure-cli
[az-aks-get-credentials]: /cli/azure/aks#az_aks_get_credentials
[aks-best-practices-security-upgrades]: operator-best-practices-cluster-security.md
[aks-node-access]: ./node-access.md
[az-aks-rotate-certs]: /cli/azure/aks#az_aks_rotate_certs

<!-- LINKS - external -->
[kubectl-get]: https://kubernetes.io/docs/reference/generated/kubectl/kubectl-commands#get
