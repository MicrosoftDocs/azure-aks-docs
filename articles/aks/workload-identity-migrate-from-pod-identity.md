---
title: Migrate Azure Kubernetes Service (AKS) Pods to Microsoft Entra Workload ID
description: Migrate AKS pods from pod-managed identities to Microsoft Entra Workload ID using Azure Identity SDK versions or migration sidecar approaches.
ms.topic: how-to
ms.subservice: aks-security
ms.service: azure-kubernetes-service
ms.custom: devx-track-azurecli, innovation-engine
ms.date: 07/31/2023
author: davidsmatlak
ms.author: davidsmatlak
# Customer intent: "As a Kubernetes administrator, I want to migrate my AKS pods from pod-managed identities to workload identity, so that I can enhance security and streamline authentication for my containerized applications."
---

# Migrate Azure Kubernetes Service (AKS) pods from pod-managed identity to Microsoft Entra Workload ID

[![Deploy to Azure](https://aka.ms/deploytoazurebutton)](https://go.microsoft.com/fwlink/?linkid=2303216)

Migrate AKS pods from pod-managed identities to [Microsoft Entra Workload ID][workload-identity-overview] (workload identity) using one of three approaches based on your current [Azure Identity SDK][azure-identity-libraries] version: latest SDK parallel deployment, migration sidecar proxy (Linux only), or SDK rewrite.

## Prerequisites

- Azure CLI version 2.47.0 or later. Run the `az --version` command to find the version. If you need to install or upgrade, see [Install Azure CLI][install-azure-cli].

## Set environment variables

The following table lists the environment variables used in the commands throughout this article. Make sure to replace the placeholder values with your own values.

| Environment variable | Description | Example value |
| -------------------- | ----------- | ------------- |
| `SUBSCRIPTION_ID` | The ID of the Azure subscription where the AKS cluster and managed identity are created. | `00000000-0000-0000-0000-000000000000` |
| `RESOURCE_GROUP` | The name of the resource group where the AKS cluster and managed identity are created. | `myResourceGroup` |
| `LOCATION` | The Azure region where the AKS cluster and managed identity are created. | `eastus` |
| `CLUSTER_NAME` | The name of the AKS cluster. | `myAKSCluster` |
| `MANAGED_IDENTITY_NAME` | The name of the user-assigned managed identity. | `myManagedIdentity` |
| `SERVICE_ACCOUNT_NAME` | The name of the Kubernetes service account to create or associate with the managed identity. | `workload-identity-sa` |
| `SERVICE_ACCOUNT_NAMESPACE` | The namespace of the Kubernetes service account. | `default` |
| `FEDERATED_IDENTITY_NAME` | The name of the federated identity credential to create. | `myFederatedIdentity` |

## Choose a migration path

Select the appropriate migration approach based on your current Azure Identity SDK version:

- **Latest Azure Identity SDK**: If your application already uses the latest version of Azure Identity SDK, you can migrate by deploying Microsoft Entra Workload ID in parallel with existing pod-managed identity.
- **Older SDK with migration sidecar** - If your application uses an older SDK version and runs on Linux containers, you can use a temporary migration sidecar to proxy Instance Metadata Service (IMDS) transactions while planning your SDK upgrade.
- **Older SDK rewrite approach**: If your application uses an older SDK version, you can update your application code to use the latest Azure Identity SDK, then migrate to workload identity.

## Prepare for migration

For all migration paths, you need to have the federated trust set up before you update your application to use Microsoft Entra Workload ID. The following are the minimum steps required:

- [Create a managed identity](#create-a-managed-identity) credential.
- Associate the user-assigned managed identity with the Kubernetes service account already used for the pod-managed identity or [create a new Kubernetes service account](#create-kubernetes-service-account) and then associate it with the managed identity.
- [Establish a federated trust relationship](#establish-federated-identity-credential-trust) between the managed identity and Microsoft Entra ID using the [OpenID Connect (OIDC)][openid-connect-overview] issuer URL and the service account.

## Migrate from latest version of Azure Identity SDK

**This migration path applies when** your application already uses the latest version of the Azure Identity SDK and you want to migrate with minimal code changes.

**Migration approach**: Deploy Microsoft Entra Workload ID in parallel with pod-managed identity, verify functionality, then remove pod-managed identity.

**Steps**:

1. Deploy Microsoft Entra Workload ID in parallel with existing pod-managed identity.
1. Restart your application deployment to begin using Microsoft Entra Workload ID (OIDC annotations are injected automatically).
1. Verify the application can authenticate successfully using workload identity.
1. [Remove the pod-managed identity](#remove-pod-managed-identity) annotations from your application.
1. Remove the pod-managed identity add-on from your cluster.

## Use a migration sidecar (Linux containers only)

**This migration path applies when** your application uses an older version of the Azure Identity SDK, runs on Linux containers, and you need a temporary solution while planning SDK updates.

**Migration approach**: Deploy a migration sidecar that proxies IMDS transactions to OIDC, allowing your existing application code to work without immediate changes.

**Important limitations*"*:

- **Linux containers only**. Windows containers aren't supported.
- **Temporary solution** that's not intended for long-term production use.
- **Planning required** to schedule SDK updates for long-term support.

**Steps**:

1. [Deploy the workload with migration sidecar](#deploy-the-workload-with-migration-sidecar) to proxy IMDS transactions.
1. Verify authentication transactions complete successfully.
1. Schedule application SDK updates to supported Azure Identity versions.
1. Once SDKs are updated, remove the proxy sidecar and redeploy applications.

## Rewrite application for latest Azure Identity SDK

**This migration path applies when** your application uses an older version of the Azure Identity SDK and you want to update to the latest supported SDK before migrating.

**Migration approach**: Update your application code to use the latest Azure Identity SDK, then migrate to Microsoft Entra Workload ID with the updated code.

**Technical outcomes**:

- Uses current Azure Identity SDK versions (no deprecation timeline).
- Supports both Linux and Windows containers (unlike sidecar approach).
- Eliminates proxy components and IMDS translation overhead.

**Steps**:

1. Update your application code to use the latest [Azure Identity SDK][azure-identity-supported-versions].
2. Test the updated application with pod-managed identity.
3. Restart your application deployment to begin authenticating using Microsoft Entra Workload ID (OIDC annotations are injected automatically).
4. Verify authentication transactions complete successfully.
5. [Remove the pod-managed identity](#remove-pod-managed-identity) annotations and add-on.

## Set an active Azure subscription

- Set a specific Azure subscription as the current active subscription using the [`az account set`][az-account-set] command.

    ```azurecli-interactive
    az account set --subscription $SUBSCRIPTION_ID
    ```

## Create a managed identity

- Create a managed identity using the [`az identity create`][az-identity-create] command.

    ```azurecli-interactive
    az identity create --name $MANAGED_IDENTITY_NAME --resource-group $RESOURCE_GROUP --location $LOCATION --subscription $SUBSCRIPTION_ID
    ```

## Get managed identity client ID

- Get the client ID of the managed identity and save it to an environmental variable using the [`az identity show`][az-identity-show] command.

    ```azurecli-interactive
    export USER_ASSIGNED_CLIENT_ID="$(az identity show --resource-group $RESOURCE_GROUP --name $MANAGED_IDENTITY_NAME --query 'clientId' -otsv)"
    ```

## Grant managed identity access to Azure resources

- Grant the managed identity the permissions needed to access the required Azure resources. Follow the steps in [Assign a managed identity access to a resource][assign-rbac-managed-identity] to assign the appropriate role to the managed identity.

## Get OIDC issuer URL

- Get the OIDC issuer URL and save it to an environmental variable using the [`az aks show`][az-aks-show] command.

    ```azurecli-interactive
    export AKS_OIDC_ISSUER="$(az aks show --name $CLUSTER_NAME --resource-group $RESOURCE_GROUP --query "oidcIssuerProfile.issuerUrl" -o tsv)"
    ```

    The variable should contain an issuer URL similar to the following example:

    ```output
    https://eastus.oic.prod-aks.azure.com/00000000-0000-0000-0000-000000000000/00000000-0000-0000-0000-000000000000/
    ```

    By default, the issuer uses the base URL `https://{region}.oic.prod-aks.azure.com/{uuid}`, where the value for `{region}` matches the location the AKS cluster is deployed in. The value `{uuid}` represents the OIDC key.

## Get AKS cluster credentials

- Get the AKS cluster credentials using the [`az aks get-credentials`][az-aks-get-credentials] command.

    ```azurecli-interactive
    az aks get-credentials --name $CLUSTER_NAME --resource-group $RESOURCE_GROUP
    ```

## Create Kubernetes service account

- Create a Kubernetes service account and annotate it with the managed identity client ID using the `kubectl apply` command. Make sure to replace the placeholder values with your own values.

    ```bash
    cat <<EOF | kubectl apply -f -
    apiVersion: v1
    kind: ServiceAccount
    metadata:
      annotations:
        azure.workload.identity/client-id: ${USER_ASSIGNED_CLIENT_ID}
      name: ${SERVICE_ACCOUNT_NAME}
      namespace: ${SERVICE_ACCOUNT_NAMESPACE}
    EOF
    ```

    The following output resembles successful creation of the identity:

    ```output
    Serviceaccount/workload-identity-sa created
    ```

## Establish federated identity credential trust

- Create the federated identity credential between the managed identity, service account issuer, and subject using the [`az identity federated-credential create`][az-identity-federated-credential-create] command.

    ```azurecli-interactive
    az identity federated-credential create --name $FEDERATED_IDENTITY_NAME --identity-name $MANAGED_IDENTITY_NAME --resource-group $RESOURCE_GROUP --issuer ${AKS_OIDC_ISSUER} --subject system:serviceaccount:${SERVICE_ACCOUNT_NAMESPACE}:${SERVICE_ACCOUNT_NAME} --audience api://AzureADTokenExchange
    ```

    The federated identity credential takes a few minutes to propagate after being added. If a token request is made immediately after adding the federated identity credential, the token request might fail because the Azure AD directory cache contains outdated information.

## Deploy the workload with migration sidecar

If your application uses user-assigned managed identity and still relies on IMDS to get an access token you can use the migration sidecar to start migrating to Microsoft Entra Workload ID. In long-term applications, you should modify the code to use the latest Azure Identity SDKs that support client assertion.

To update or deploy the workload, add the following [pod annotations][pod-annotations] to your pod specification (only if you want to use the migration sidecar):

| Pod annotation | Description | Value |
| -------------- | ----------- | ----- |
| `azure.workload.identity/inject-proxy-sidecar` | Indicates whether to inject the proxy sidecar into the pod. | `true` or `false` |
| `azure.workload.identity/proxy-sidecar-port` | Desired port for the proxy sidecar. | Default value: `8000` |

When you create a pod with these annotations, the Microsoft Entra Workload ID mutating webhook automatically injects the `init-container` and proxy sidecar to the pod spec. The following YAML shows an example of what the mutating webhook adds to the pod deployment:

```yml
apiVersion: v1
kind: Pod
metadata:
  name: httpbin-pod
  labels:
    app: httpbin
    azure.workload.identity/use: "true"
  annotations:
    azure.workload.identity/inject-proxy-sidecar: "true"
spec:
  serviceAccountName: workload-identity-sa
  initContainers:
  - name: init-networking
    image: mcr.microsoft.com/oss/azure/workload-identity/proxy-init:v1.1.0
    securityContext:
      capabilities:
        add:
        - NET_ADMIN
        drop:
        - ALL
      privileged: true
      runAsUser: 0
    env:
    - name: PROXY_PORT
      value: "8000"
  containers:
  - name: nginx
    image: nginx:alpine
    ports:
    - containerPort: 80
  - name: proxy
    image: mcr.microsoft.com/oss/azure/workload-identity/proxy:v1.1.0
    ports:
    - containerPort: 8000
```

## Verify the workload with migration sidecar

1. Verify the pod is in a running state using the [`kubectl describe pod`][kubectl-describe] command. Replace `<pod-name>` with the name of your pod.

    ```bash
    kubectl describe pods <pod-name>
    ```

1. Verify the pod is passing IMDS transactions using the [`kubectl logs`][kubelet-logs] command. Replace `<pod-name>` with the name of your pod.

    ```bash
    kubectl logs <pod-name>
    ```

    The following example log output resembles successful communication through the proxy sidecar. Verify the logs show a token is successfully acquired and the `GET` operation is successful.

    ```output
    I0926 00:29:29.968723       1 proxy.go:97] proxy "msg"="starting the proxy server" "port"=8080 "userAgent"="azure-workload-identity/proxy/v0.13.0-12-gc8527f3 (linux/amd64) c8527f3/2022-09-26-00:19"
    I0926 00:29:29.972496       1 proxy.go:173] proxy "msg"="received readyz request" "method"="GET" "uri"="/readyz"
    I0926 00:29:30.936769       1 proxy.go:107] proxy "msg"="received token request" "method"="GET" "uri"="/metadata/identity/oauth2/token?resource=https://management.core.windows.net/api-version=2018-02-01&client_id=<client_id>"
    I0926 00:29:31.101998       1 proxy.go:129] proxy "msg"="successfully acquired token" "method"="GET" "uri"="/metadata/identity/oauth2/token?resource=https://management.core.windows.net/api-version=2018-02-01&client_id=<client_id>"
    ```

## Remove pod-managed identity

After you complete your testing and the application can successfully get a token using the proxy sidecar, you can remove the identity and pod-managed identity mapping from your AKS cluster

- Remove the pod-managed identity binding from your pod using the [`az aks pod-identity delete`][az-aks-pod-identity-delete] command. Replace `<pod-identity-name>` and `<pod-identity-namespace>` with the name and namespace of your pod identity.

    ```azurecli-interactive
    az aks pod-identity delete --name <pod-identity-name> --namespace <pod-identity-namespace> --resource-group $RESOURCE_GROUP --cluster-name $CLUSTER_NAME
    ```

## Related content

For more information about Microsoft Entra Workload ID, see the [Overview][workload-identity-overview] article.

<!-- INTERNAL LINKS -->
[pod-annotations]: workload-identity-overview.md#pod-annotations
[az-identity-create]: /cli/azure/identity#az-identity-create
[az-account-set]: /cli/azure/account#az-account-set
[az-aks-get-credentials]: /cli/azure/aks#az-aks-get-credentials
[workload-identity-overview]: workload-identity-overview.md
[az-identity-federated-credential-create]: /cli/azure/identity/federated-credential#az-identity-federated-credential-create
[az-aks-pod-identity-delete]: /cli/azure/aks/pod-identity#az-aks-pod-identity-delete
[azure-identity-supported-versions]: workload-identity-overview.md#prerequisites
[azure-identity-libraries]: ../active-directory/develop/reference-v2-libraries.md
[openid-connect-overview]: /azure/active-directory/develop/v2-protocols-oidc
[install-azure-cli]: /cli/azure/install-azure-cli
[assign-rbac-managed-identity]: /azure/role-based-access-control/role-assignments-portal-managed-identity
[az-identity-show]: /cli/azure/identity#az-identity-show
[az-aks-show]: /cli/azure/aks#az-aks-show

<!-- EXTERNAL LINKS -->
[kubectl-describe]: https://kubernetes.io/docs/reference/generated/kubectl/kubectl-commands#describe
[kubelet-logs]: https://kubernetes.io/docs/reference/generated/kubectl/kubectl-commands#logs
