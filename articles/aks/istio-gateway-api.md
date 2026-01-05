---
title: Kubernetes Gateway API Ingress for Istio Service Mesh Add-on for Azure Kubernetes Service (AKS) (preview)
description: Configure ingresses for the Istio service mesh add-on for AKS using the Kubernetes Gateway API.
ms.topic: how-to
ms.service: azure-kubernetes-service
author: nshankar
ms.date: 08/21/2025
ms.author: nshankar
ms.reviewer: schaffererin
# Customer intent: "As a Kubernetes administrator, I want to deploy Kubernetes Gateway API-based ingress gateways for the Istio service mesh on my cluster, so that I can efficiently manage ingress application traffic routing."
---

# Configure Istio ingress with the Kubernetes Gateway API for Azure Kubernetes Service (AKS) (preview)

[!INCLUDE [preview features callout](~/reusable-content/ce-skilling/azure/includes/aks/includes/preview/preview-callout.md)]

The Istio service mesh add-on supports both [Istio's own ingress traffic management API][istio-deploy-ingress] and the Kubernetes Gateway API for ingress traffic management. You can use the Istio Gateway API [automated deployment model][istio-gateway-auto-deployment] or the [manual deployment model][istio-gateway-manual-deployment]. This article describes how to configure ingress traffic management for the Istio service mesh add-on using the Kubernetes Gateway API with the [automated deployment model][istio-gateway-auto-deployment].

## Limitations and considerations

- Using the Kubernetes Gateway API for [egress traffic management][istio-deploy-egress] with the Istio service mesh add-on is only supported for the [manual deployment model][istio-gateway-manual-deployment].
- ConfigMap customizations for `Gateway` resources must fall within the Resource customization allowlist. Fields not on the allowlist are disallowed and blocked via add-on managed webhooks. For more information, see the [Istio service mesh add-on add-on support policy][istio-support-policy].

## Prerequisites

- Enable the [Managed Gateway API][managed-gateway-addon] on your AKS cluster.
- Install the Istio service mesh add-on revision `asm-1-26` or higher. Follow the [installation guide][istio-deploy-addon] if you don't have the Istio service mesh add-on installed yet, or the [upgrade guide][istio-upgrade] if you're on a lower minor revision.

## Set environment variables

Set the following environment variables to use throughout this article:

| Variable | Description |
|----------|-------------|
| `RESOURCE_GROUP` | The name of the resource group containing your AKS cluster. |
| `CLUSTER_NAME` | The name of your AKS cluster. |
| `LOCATION` | The Azure region where your AKS cluster is deployed. |
| `KEY_VAULT_NAME` | The name of the Azure Key Vault resource to be created for storing TLS secrets. If you have an existing resource, use that name. |

## Deploy sample application

- Deploy the sample `httpbin` application in the `default` namespace using the [`kubectl apply`][kubectl-apply] command.

    ```bash
    kubectl apply -f https://raw.githubusercontent.com/istio/istio/release-1.26/samples/httpbin/httpbin.yaml
    ```

## Create Kubernetes Gateway and HTTPRoute

The example manifest creates an external ingress load balancer service that's accessible from outside the cluster. You can add [annotations][annotation-customizations] to create an internal load balancer and customize other load balancer settings.

- Deploy a Gateway API configuration in the `default` namespace with the `gatewayClassName` set to `istio` and an `HTTPRoute` that routes traffic to the `httpbin` service using the following manifest:

    ```bash
    kubectl apply -f - <<EOF
    apiVersion: gateway.networking.k8s.io/v1
    kind: Gateway
    metadata:
      name: httpbin-gateway
    spec:
      gatewayClassName: istio
      listeners:
      - name: http
        port: 80
        protocol: HTTP
        allowedRoutes:
          namespaces:
            from: Same
    ---
    apiVersion: gateway.networking.k8s.io/v1
    kind: HTTPRoute
    metadata:
      name: http
      namespace: default
    spec:
      parentRefs:
      - name: httpbin-gateway
      hostnames: ["httpbin.example.com"]
      rules:
      - matches:
        - path:
            type: PathPrefix
            value: /get
        backendRefs:
        - name: httpbin
          port: 8000
    EOF
    ```

    > [!NOTE]
    > If you're performing a [minor revision upgrade][istio-upgrade] and have two Istio service mesh add-on revisions installed on your cluster simultaneously, the control plane for the higher minor revision takes ownership of the `Gateways` by default. You can add the `istio.io/rev` label to the `Gateway` to control which control plane revision owns it. If you add the revision label, make sure that you update it accordingly to the appropriate control plane revision before rolling back or completing the upgrade operation.

## Verify resource creation

- Verify the `Deployment`, `Service`, `HorizontalPodAutoscaler`, and `PodDisruptionBudget` resources were created using the following `kubectl get` commands:

    ```bash
    kubectl get deployment httpbin-gateway-istio
    kubectl get service httpbin-gateway-istio
    kubectl get hpa httpbin-gateway-istio
    kubectl get pdb httpbin-gateway-istio
    ```

    Example output:

    ```output
    # Deployment resource
    NAME                    READY   UP-TO-DATE   AVAILABLE   AGE
    httpbin-gateway-istio   2/2     2            2           31m

    # Service resource
    NAME                    TYPE           CLUSTER-IP   EXTERNAL-IP      PORT(S)                        AGE
    httpbin-gateway-istio   LoadBalancer   10.0.65.45   <external-ip>    15021:32053/TCP,80:31587/TCP   33m

    # HPA resource
    NAME                    REFERENCE                          TARGETS       MINPODS   MAXPODS   REPLICAS   AGE
    httpbin-gateway-istio   Deployment/httpbin-gateway-istio   cpu: 3%/80%   2         5         3          34m

    # PDB resource
    NAME                    MIN AVAILABLE   MAX UNAVAILABLE   ALLOWED DISRUPTIONS   AGE
    httpbin-gateway-istio   1               N/A               2                     36m
    ```

## Send request to sample application

1. Try sending a `curl` request to the `httpbin` application. First, set the `INGRESS_HOST` environment variable:

    ```bash
    kubectl wait --for=condition=programmed gateways.gateway.networking.k8s.io httpbin-gateway
    export INGRESS_HOST=$(kubectl get gateways.gateway.networking.k8s.io httpbin-gateway -ojsonpath='{.status.addresses[0].value}')
    ```

1. Try sending an HTTP request to `httpbin`.

    ```bash
    curl -s -I -HHost:httpbin.example.com "http://$INGRESS_HOST/get"
    ```

    In the output, you should see an `HTTP 200` response.

## Secure Istio ingress traffic with the Kubernetes Gateway API

The Istio service mesh add-on supports syncing secrets from Azure Key Vault for securing Gateway API-based ingress traffic with [Transport Layer Security (TLS) termination][istio-tls-termination] or [Server Name Indication (SNI) passthrough][istio-sni-passthrough]. In the following sections, you sync secrets from Azure Key Vault onto your AKS cluster using the [Azure Key Vault provider for Secrets Store Container Storage Interface (CSI) Driver add-on][aks-csi-driver] and terminate TLS at the ingress gateway.

## Create client/server certificates and keys

1. Create a root certificate and private key for signing the certificates for sample services:

    ```bash
    mkdir httpbin_certs
    openssl req -x509 -sha256 -nodes -days 365 -newkey rsa:2048 -subj '/O=example Inc./CN=example.com' -keyout httpbin_certs/example.com.key -out httpbin_certs/example.com.crt
    ```

1. Generate a certificate and a private key for `httpbin.example.com`:

    ```bash
    openssl req -out httpbin_certs/httpbin.example.com.csr -newkey rsa:2048 -nodes -keyout httpbin_certs/httpbin.example.com.key -subj "/CN=httpbin.example.com/O=httpbin organization"
    openssl x509 -req -sha256 -days 365 -CA httpbin_certs/example.com.crt -CAkey httpbin_certs/example.com.key -set_serial 0 -in httpbin_certs/httpbin.example.com.csr -out httpbin_certs/httpbin.example.com.crt
    ```

## Set up Azure Key Vault and create secrets

1. Create an Azure Key Vault instance to supply the certificate and key inputs to the Istio service mesh add-on using the [`az keyvault create`][akv-create] command. If you already have an Azure Key Vault instance, you can skip this step.

    ```azurecli-interactive
    az keyvault create --name $KEY_VAULT_NAME --resource-group $RESOURCE_GROUP --location $LOCATION
    ```

1. Enable the [Azure Key Vault provider for Secrets Store (CSI) Driver add-on][akv-addon] on your cluster using the [`az aks enable-addons`][az-aks-enable-addons] command.

    ```azurecli-interactive
    az aks enable-addons --addons azure-keyvault-secrets-provider --resource-group $RESOURCE_GROUP --name $CLUSTER_NAME
    ```

1. If your key vault uses Azure role-based access control (RBAC) for the permissions model, follow the instructions in [Provide access to Azure Key Vault keys, certificates, and secrets with Azure role-based access control][akv-rbac-guide] to assign an Azure role of _Key Vault Secrets User_ for the add-on's user-assigned managed identity. Alternatively, if your key vault uses the vault access policy permissions model, authorize the user-assigned managed identity of the add-on to access Azure Key Vault resource using access policy using the [`az keyvault set-policy`][akv-set-policy] command.

    ```azurecli-interactive
    OBJECT_ID=$(az aks show --resource-group $RESOURCE_GROUP --name $CLUSTER_NAME --query 'addonProfiles.azureKeyvaultSecretsProvider.identity.objectId' -o tsv | tr -d '\r')
    CLIENT_ID=$(az aks show --resource-group $RESOURCE_GROUP --name $CLUSTER_NAME --query 'addonProfiles.azureKeyvaultSecretsProvider.identity.clientId')
    TENANT_ID=$(az keyvault show --resource-group $RESOURCE_GROUP --name $KEY_VAULT_NAME --query 'properties.tenantId')
    
    az keyvault set-policy --name $KEY_VAULT_NAME --object-id $OBJECT_ID --secret-permissions get list
    ```

1. Create secrets in Azure Key Vault using the certificates and keys using the following [`az keyvault secret set`][akv-csi-driver-set-secret] commands:

    ```azurecli-interactive
    az keyvault secret set --vault-name $KEY_VAULT_NAME --name test-httpbin-key --file httpbin_certs/httpbin.example.com.key
    az keyvault secret set --vault-name $KEY_VAULT_NAME --name test-httpbin-crt --file httpbin_certs/httpbin.example.com.crt
    ```

## Deploy SecretProviderClass and sample pod

1. Deploy the SecretProviderClass to provide Azure Key Vault specific parameters to the CSI driver using the following manifest. In this example, `test-httpbin-key` and `test-httpbin-crt` are the names of the secret objects in Azure Key Vault.

    ```bash
    cat <<EOF | kubectl apply -f -
    apiVersion: secrets-store.csi.x-k8s.io/v1
    kind: SecretProviderClass
    metadata:
      name: httpbin-credential-spc
    spec:
      provider: azure
      secretObjects:
      - secretName: httpbin-credential
        type: kubernetes.io/tls
        data:
        - objectName: test-httpbin-key
          key: tls.key
        - objectName: test-httpbin-crt
          key: tls.crt
      parameters:
        useVMManagedIdentity: "true"
        userAssignedIdentityID: $CLIENT_ID 
        keyvaultName: $KEY_VAULT_NAME
        cloudName: ""
        objects:  |
          array:
            - |
              objectName: test-httpbin-key
              objectType: secret
              objectAlias: "test-httpbin-key"
            - |
              objectName: test-httpbin-crt
              objectType: secret
              objectAlias: "test-httpbin-crt"
        tenantId: $TENANT_ID
    EOF
    ```

    > [!NOTE]
    > Alternatively, to reference a certificate object type directly from Azure Key Vault, use the following manifest to deploy SecretProviderClass. In this example, `test-httpbin-cert-pxf` is the name of the certificate object in Azure Key Vault.
    >
    > ```bash
    > cat <<EOF | kubectl apply -f -
    > apiVersion: secrets-store.csi.x-k8s.io/v1
    > kind: SecretProviderClass
    > metadata:
    >   name: httpbin-credential-spc
    > spec:
    >   provider: azure
    >   secretObjects:
    >   - secretName: httpbin-credential
    >     type: kubernetes.io/tls
    >     data:
    >     - objectName: test-httpbin-key
    >       key: tls.key
    >     - objectName: test-httpbin-crt
    >       key: tls.crt
    >   parameters:
    >     useVMManagedIdentity: "true"
    >     userAssignedIdentityID: $CLIENT_ID 
    >     keyvaultName: $KEY_VAULT_NAME
    >     cloudName: ""
    >     objects:  |
    >       array:
    >         - |
    >           objectName: test-httpbin-cert-pfx  #certificate object name from keyvault
    >           objectType: secret
    >           objectAlias: "test-httpbin-key"
    >         - |
    >           objectName: test-httpbin-cert-pfx #certificate object name from keyvault
    >           objectType: cert
    >           objectAlias: "test-httpbin-crt"
    >     tenantId: $TENANT_ID
    > EOF
    > ```

1. Deploy a sample pod using the following manifest. The Azure Key Vault provider for Secrets Store (CSI) Driver add-on requires a pod to reference the SecretProviderClass resource to ensure secrets sync from Azure Key Vault to the cluster.

    ```bash
    cat <<EOF | kubectl apply -f -
    apiVersion: v1
    kind: Pod
    metadata:
      name: secrets-store-sync-httpbin
    spec:
      containers:
        - name: busybox
          image: mcr.microsoft.com/oss/busybox/busybox:1.33.1
          command:
            - "/bin/sleep"
            - "10"
          volumeMounts:
          - name: secrets-store01-inline
            mountPath: "/mnt/secrets-store"
            readOnly: true
      volumes:
        - name: secrets-store01-inline
          csi:
            driver: secrets-store.csi.k8s.io
            readOnly: true
            volumeAttributes:
              secretProviderClass: "httpbin-credential-spc"
    EOF
    ```

## Verify TLS secret creation

- Verify the `httpbin-credential` secret was created in the `default` namespace as defined in the SecretProviderClass resource using the `kubectl describe secret` command.

    ```bash
    kubectl describe secret/httpbin-credential
    ```

    Example output:

    ```output
    Name:         httpbin-credential
    Namespace:    default
    Labels:       secrets-store.csi.k8s.io/managed=true
    Annotations:  <none>

    Type:  kubernetes.io/tls

    Data
    ====
    tls.crt:  1180 bytes
    tls.key:  1675 bytes
    ```

## Deploy TLS Gateway

1. Create a Kubernetes Gateway that references the `httpbin-credential` secret under the TLS configuration using the following manifest:

    ```bash
    cat <<EOF | kubectl apply -f -
    apiVersion: gateway.networking.k8s.io/v1
    kind: Gateway
    metadata:
      name: httpbin-gateway
    spec:
      gatewayClassName: istio
      listeners:
      - name: https
        hostname: "httpbin.example.com"
        port: 443
        protocol: HTTPS
        tls:
          mode: Terminate
          certificateRefs:
          - name: httpbin-credential
        allowedRoutes:
          namespaces:
            from: Selector
            selector:
              matchLabels:
                kubernetes.io/metadata.name: default
    EOF
    ```

    > [!NOTE]
    > In the gateway definition, `tls.certificateRefs.name` must match the `secretName` in SecretProviderClass resource.

1. Create a corresponding `HTTPRoute` to configure ingress traffic routing to the `httpbin` service over HTTPS using the following manifest:

    ```bash
    cat <<EOF | kubectl apply -f -
    apiVersion: gateway.networking.k8s.io/v1
    kind: HTTPRoute
    metadata:
      name: httpbin
    spec:
      parentRefs:
      - name: httpbin-gateway
      hostnames: ["httpbin.example.com"]
      rules:
      - matches:
        - path:
            type: PathPrefix
            value: /status
        - path:
            type: PathPrefix
            value: /delay
        backendRefs:
        - name: httpbin
          port: 8000
    EOF
    ```

1. Get the ingress gateway's external IP address and secure port using the following commands:

    ```bash
    kubectl wait --for=condition=programmed gateways.gateway.networking.k8s.io httpbin-gateway
    export INGRESS_HOST=$(kubectl get gateways.gateway.networking.k8s.io httpbin-gateway -o jsonpath='{.status.addresses[0].value}')
    export SECURE_INGRESS_PORT=$(kubectl get gateways.gateway.networking.k8s.io httpbin-gateway -o jsonpath='{.spec.listeners[?(@.name=="https")].port}')
    ```

1. Send an HTTPS request to access the `httpbin` service:

    ```bash
    curl -v -HHost:httpbin.example.com --resolve "httpbin.example.com:$SECURE_INGRESS_PORT:$INGRESS_HOST" \
    --cacert httpbin_certs/example.com.crt "https://httpbin.example.com:$SECURE_INGRESS_PORT/status/418"
    ```

    The output should show the `httpbin` service return the _418 I’m a Teapot_ code.

    > [!NOTE]
    > To configure HTTPS ingress access to an HTTPS service, update the TLS mode in the gateway definition to `Passthrough`. This configuration instructs the gateway to pass the ingress traffic _as is_, without terminating TLS.

## Annotation customizations

You can add annotations under `spec.infrastructure.annotations` to [configure load balancer settings][azure-aks-load-balancer-annotations] for the `Gateway`. For instance, to create an internal load balancer attached to a specific subnet, you can create a `Gateway` with the following annotations:

```yaml
spec:
  # ... existing spec content ...
  infrastructure:
    annotations: 
      service.beta.kubernetes.io/azure-load-balancer-internal: "true"
      service.beta.kubernetes.io/azure-load-balancer-internal-subnet: "my-subnet"
```

## ConfigMap customizations

The Istio service mesh add-on supports [customizations of the resources][istio-gateway-auto-deployment] generated for the `Gateways`, including:

- Service
- Deployment
- Horizontal Pod Autoscaler (HPA)
- Pod Disruption Budget (PDB)

The [default settings for these resources][istio-gateway-class-cm] are set in the `istio-gateway-class-defaults` ConfigMap in the `aks-istio-system` namespace. This ConfigMap must have the `gateway.istio.io/defaults-for-class` label set to `istio` for the customizations to take effect for all `Gateways` with `spec.gatewayClassName: istio`. The `GatewayClass`-level ConfigMap is installed by default in the `aks-istio-system` namespace when the [Managed Gateway API installation][managed-gateway-addon] is enabled. It could take up to five minutes for the `istio-gateway-class-defaults` ConfigMap to get deployed after installing the Managed Gateway API CRDs.

```bash
kubectl get configmap istio-gateway-class-defaults -n aks-istio-system -o yaml
```

```yaml
...
data:
  horizontalPodAutoscaler: |
    spec:
      minReplicas: 2
      maxReplicas: 5
  podDisruptionBudget: |
    spec:
      minAvailable: 1
...
```

You can modify these settings for all Istio `Gateways` at a `GatewayClass` level by updating the `istio-gateway-class-defaults` ConfigMap, or you can set them for individual `Gateway` resources. For both the `GatewayClass`-level and `Gateway`-level `ConfigMaps`, you must add fields to the allowlist for the given resource. If there are customizations both for the `GatewayClass` and an individual `Gateway`, the `Gateway`-level configuration takes precedence.

## Deployment customization allowlist fields

| Field path | Description |
|------------|----------|
| `metadata.labels` | Deployment labels |
| `metadata.annotations` | Deployment annotations |
| `spec.replicas` | Deployment replica count |
| `spec.template.metadata.labels` | Pod labels |
| `spec.template.metadata.annotations` | Pod annotations |
| `spec.template.spec.affinity.nodeAffinity.requiredDuringSchedulingIgnoredDuringExecution.nodeSelectorTerms` | Node affinity |
| `spec.template.spec.affinity.nodeAffinity.preferredDuringSchedulingIgnoredDuringExecution` | Node affinity |
| `spec.template.spec.affinity.podAffinity.requiredDuringSchedulingIgnoredDuringExecution` | Pod affinity|
| `spec.template.spec.affinity.podAffinity.preferredDuringSchedulingIgnoredDuringExecution` | Pod affinity |
| `spec.template.spec.affinity.podAntiAffinity.requiredDuringSchedulingIgnoredDuringExecution` | Pod anti-affinity |
| `spec.template.spec.affinity.podAntiAffinity.preferredDuringSchedulingIgnoredDuringExecution` | Pod anti-affinity |
| `spec.template.spec.containers.resizePolicy` | Container resource utilization |
| `spec.template.spec.containers.resources.limits` | Container resource utilization |
| `spec.template.spec.containers.resources.requests` | Container resource utilization |
| `spec.template.spec.containers.stdin` | Container debugging |
| `spec.template.spec.containers.stdinOnce` | Container debugging |
| `spec.template.spec.nodeSelector` | Pod scheduling |
| `spec.template.spec.nodeName` | Pod scheduling |
| `spec.template.spec.tolerations` | Pod scheduling |
| `spec.template.spec.topologySpreadConstraints` | Pod scheduling |

## Service customization allowlist fields

| Field path | Description |
|------------|----------|
| `metadata.labels` | Service labels |
| `metadata.annotations` | Service annotations |
| `spec.type` | Service type |
| `spec.loadBalancerSourceRanges` | Service load balancer settings |
| `spec.loadBalancerClass` | Service load balancer settings |
| `spec.externalTrafficPolicy` | Service traffic policy |
| `spec.internalTrafficPolicy` | Service traffic policy |

## HorizontalPodAutoscaler (HPA) customization allowlist fields

| Field path | Description |
|------------|----------|
| `metadata.labels` | HPA labels |
| `metadata.annotations` | HPA annotations |
| `spec.behavior.scaleUp.stabilizationWindowSeconds` | HPA scale-up behavior |
| `spec.behavior.scaleUp.selectPolicy` | HPA scale-up behavior |
| `spec.behavior.scaleUp.policies` | HPA scale-up behavior |
| `spec.behavior.scaleDown.stabilizationWindowSeconds` | HPA scale-down behavior |
| `spec.behavior.scaleDown.selectPolicy` | HPA scale-down behavior |
| `spec.behavior.scaleDown.policies` | HPA scale-down behavior |
| `spec.metrics` | HPA scaling resource metrics |
| `spec.minReplicas` | HPA minimum replica count. Must not be below 2. |
| `spec.maxReplicas` | HPA maximum replica count |

## PodDisruptionBudget (PDB) customization allowlist fields

| Field path | Description |
|------------|----------|
| `metadata.labels` | PDB labels|
| `metadata.annotations` | PDB annotations |
| `spec.minAvailable` | PDB minimum availability |
| `spec.unhealthyPodEvictionPolicy` | PDB eviction policy |

> [!NOTE]
> Modifying the `PDB` minimum availability and eviction policy can lead to potential errors during cluster/node upgrade and deletion operations. Follow the [PDB troubleshooting guide][pdb-troubleshooting] to address _UpgradeFailed_ errors due to `PDB` eviction failures.

## Configure GatewayClass-level settings

1. Update the `GatewayClass`-level ConfigMap in the `aks-istio-system` namespace using the `kubectl edit configmap` command:

    ```bash
    kubectl edit cm istio-gateway-class-defaults -n aks-istio-system
    ```

1. Edit the resource settings in the `data` section as needed. For example, to update the HPA min/max replicas and add a label to the `Deployment`, modify the ConfigMap as follows:

    ```yaml
    ...
    data:
      deployment: |
        metadata:
          labels:
            test.azureservicemesh.io/deployment-config: "updated"
      horizontalPodAutoscaler: |
        spec:
          minReplicas: 3
          maxReplicas: 6
      podDisruptionBudget: |
        spec:
          minAvailable: 1
    ...
    ```

    > [!NOTE]
    > Only one ConfigMap per `GatewayClass` is allowed.

1. Now, you should see the `HPA` for `httpbin-gateway` that you created earlier get updated with the new min/max values. Verify the `HPA` settings using the `kubectl get hpa` command.

    ```bash
    kubectl get hpa httpbin-gateway-istio
    ```

    Example output:

    ```output
    NAME                    REFERENCE                          TARGETS       MINPODS   MAXPODS   REPLICAS   AGE
    httpbin-gateway-istio   Deployment/httpbin-gateway-istio   cpu: 3%/80%   3         6         3          36m
    ```

1. Verify the `Deployment` is updated with the new label using the `kubectl get deployment` command.

    ```bash
    kubectl get deployment httpbin-gateway-istio -ojsonpath='{.metadata.labels.test\.azureservicemesh\.io\/deployment-config}'
    ```

    Example output:

    ```output
    updated
    ```

## Configure settings for a specific gateway

1. Create a ConfigMap with resource customizations for the `httpbin` Gateway using the following manifest:

    ```bash
    kubectl apply -f - <<EOF
    apiVersion: v1
    kind: ConfigMap
    metadata:
      name: gw-options
    data:
      horizontalPodAutoscaler: |
        spec:
          minReplicas: 2
          maxReplicas: 4
      deployment: |
        metadata:
          labels:
            test.azureservicemesh.io/deployment-config: "updated-per-gateway"
    EOF
    ```

1. Update the `httpbin` `Gateway` to reference the ConfigMap:

    ```yaml
    spec:
      # ... existing spec content ...
      infrastructure:
        parametersRef:
          group: ""
          kind: ConfigMap
          name: gw-options
    ```

1. Apply the update using the `kubectl apply` command.

    ```bash
    kubectl apply -f httpbin-gateway-updated.yaml
    ```

1. Verify the `HPA` is updated with the new min/max values using the `kubectl get hpa` command. If you also configured the `GatewayClass`-level ConfigMap, the `Gateway`-level settings should take precedence.

    ```bash
    kubectl get hpa httpbin-gateway-istio
    ```

    Example output:

    ```output
    NAME                    REFERENCE                          TARGETS       MINPODS   MAXPODS   REPLICAS   AGE
    httpbin-gateway-istio   Deployment/httpbin-gateway-istio   cpu: 3%/80%   2         4         2          4h14m
    ```

3. Inspect the `Deployment` labels to ensure that the `test.azureservicemesh.io/deployment-config` is updated to the new value using the `kubectl get deployment` command.

    ```bash
    kubectl get deployment httpbin-gateway-istio -ojsonpath='{.metadata.labels.test\.azureservicemesh\.io\/deployment-config}'
    ```

    Example output:

    ```output
    updated-per-gateway
    ```

## Clean up resources

If you no longer need the resources created in this article, you can delete them to avoid incurring any charges.

1. Delete the Gateway and HTTPRoute resources using the following `kubectl delete` commands:

    ```bash
    kubectl delete gateways.gateway.networking.k8s.io httpbin-gateway
    kubectl delete httproute httpbin
    ```

1. If you created a ConfigMap to customize your Gateway resources, delete it using the `kubectl delete configmap` command.

    ```bash
    kubectl delete configmap gw-options
    ```

1. If you created a SecretProviderClass and secret to use for TLS termination delete the resources using the following `kubectl delete` commands:

    ```bash
    kubectl delete secret httpbin-credential
    kubectl delete pod secrets-store-sync-httpbin
    kubectl delete secretproviderclass httpbin-credential-spc
    ```

## Related content

- [Deploy egress gateways for the Istio service mesh add-on][istio-deploy-egress]

<!---LINKS--->
[aks-csi-driver]: ./csi-secrets-store-driver.md
[istio-deploy-addon]: istio-deploy-addon.md
[istio-deploy-egress]: istio-deploy-egress.md
[istio-deploy-ingress]: istio-deploy-ingress.md
[istio-support-policy]: istio-support-policy.md#allowed-supported-and-blocked-customizations
[istio-upgrade]: istio-upgrade.md
[managed-gateway-addon]: managed-gateway-api.md
[annotation-customizations]: #annotation-customizations
[azure-aks-load-balancer-annotations]: configure-load-balancer-standard.md#customizations-via-kubernetes-annotations
[akv-rbac-guide]: /azure/key-vault/general/rbac-guide
[istio-gateway-auto-deployment]: https://istio.io/latest/docs/tasks/traffic-management/ingress/gateway-api/#automated-deployment
[istio-gateway-manual-deployment]: https://istio.io/latest/docs/tasks/traffic-management/ingress/gateway-api/#manual-deployment
[istio-gateway-class-cm]: https://istio.io/latest/docs/tasks/traffic-management/ingress/gateway-api/#gatewayclass-defaults
[istio-tls-termination]: https://istio.io/latest/docs/tasks/traffic-management/ingress/secure-ingress/
[istio-sni-passthrough]: https://istio.io/latest/docs/tasks/traffic-management/ingress/ingress-sni-passthrough/
[pdb-troubleshooting]: /troubleshoot/azure/azure-kubernetes/create-upgrade-delete/error-code-poddrainfailure
[akv-addon]: ./csi-secrets-store-driver.md
[akv-create]: /cli/azure/keyvault#az-keyvault-create
[az-aks-enable-addons]: /cli/azure/aks#az-aks-enable-addons
[akv-set-policy]: /cli/azure/keyvault#az-keyvault-set-policy
[akv-csi-driver-set-secret]: ./csi-secrets-store-driver.md
[kubectl-apply]: https://kubernetes.io/docs/reference/kubectl/generated/kubectl_apply/
