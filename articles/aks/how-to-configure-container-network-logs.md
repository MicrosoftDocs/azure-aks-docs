---
title: Set up container network logs
description: Learn how to configure container network logs in Advanced Container Networking Services for Azure Kubernetes Service (AKS), including stored logs and on-demand logs modes.
author: shaifaligargmsft
ms.author: shaifaligarg
ms.service: azure-kubernetes-service
ms.subservice: aks-networking
ms.topic: how-to
ms.date: 04/07/2026
ms.custom: template-how-to-pattern, devx-track-azurecli
---

# Set up container network logs

This guide walks you through configuring container network logs in [Advanced Container Networking Services](advanced-container-networking-services-overview.md) for Azure Kubernetes Service (AKS). You can set up **stored logs** for continuous collection with persistent storage, or **on-demand logs** for real-time troubleshooting.

For an overview of what container network logs capture and when to use each mode, see [What are container network logs?](container-network-observability-logs.md).

## Prerequisites

* An Azure account with an active subscription. If you don't have one, create a [free account](https://azure.microsoft.com/pricing/purchase-options/azure-account?cid=msft_learn) before you begin.

[!INCLUDE [azure-CLI-prepare-your-environment-no-header.md](~/reusable-content/azure-cli/azure-cli-prepare-your-environment-no-header.md)]

* Azure CLI version 2.75.0 or later. Run `az --version` to check. To install or upgrade, see [Install Azure CLI](/cli/azure/install-azure-cli).

* The `aks-preview` Azure CLI extension version `19.0.07` or later:

    ```azurecli
    # Install the aks-preview extension
    az extension add --name aks-preview
    # Update the extension to make sure you have the latest version installed
    az extension update --name aks-preview
    ```

* Stored logs mode requires the Cilium data plane.

* On-demand logs mode works with both Cilium and non-Cilium data planes.

* Your cluster must be running Kubernetes version 1.33 or later.

* Layer 7 flow data is captured only when Layer 7 policy support is enabled. For more information, see [Configure a Layer 7 policy](./how-to-apply-l7-policies.md).
* DNS flows and metrics are captured only when a Cilium FQDN network policy is applied. For more information, see [Configure an FQDN policy](./how-to-apply-fqdn-filtering-policies.md).


## Configure stored logs mode

Stored logs mode continuously collects network flow logs and stores them for long-term analysis. Similar flows are automatically grouped into summarized records through [flow log aggregation](container-network-observability-logs.md#flow-log-aggregation), which cuts data volume while preserving the patterns you need. You can set this up on a new cluster or enable it on an existing one.

### Deployment options

# [Azure CLI](#tab/cli)

Choose the path that matches your situation:

- **[New cluster](#new-cluster)**: Create and configure a cluster from scratch.
- **[Existing cluster](#existing-cluster)**: Enable stored logs on a cluster you already have.

# [ARM Template](#tab/arm)

For ARM template deployments, follow the steps in the [Azure Monitor ARM template guide](/azure/azure-monitor/containers/container-insights-network-monitoring?tabs=arm#onboarding-to-container-network-logs). The template includes `enableContainerNetworkLogs` configuration and deployment commands.

# [Bicep](#tab/bicep)

For Bicep deployments, see the [Azure Monitor Bicep deployment guide](/azure/azure-monitor/containers/container-insights-network-monitoring?tabs=bicep#onboarding-to-container-network-logs).

---

## New cluster

### Step 1: Create a cluster with ACNS enabled

```azurecli
# Replace placeholders with your own values
export CLUSTER_NAME="<aks-cluster-name>"
export RESOURCE_GROUP="<aks-resource-group>"
export LOCATION="<location>"

# Create the resource group if it doesn't already exist
az group create --name $RESOURCE_GROUP --location $LOCATION

# Create an AKS cluster with ACNS
az aks create \
  --resource-group $RESOURCE_GROUP \
  --name $CLUSTER_NAME \
  --location $LOCATION \
  --pod-cidr 192.168.0.0/16 \
  --network-plugin azure \
  --network-plugin-mode overlay \
  --network-dataplane cilium \
  --generate-ssh-keys \
  --enable-acns \
  --acns-advanced-networkpolicies L7

# Optional: add --node-vm-size Standard_D4ads_v5 if the default VM size is not available in your subscription
```

Get your cluster credentials so you can run `kubectl` commands:

```azurecli
az aks get-credentials --name $CLUSTER_NAME --resource-group $RESOURCE_GROUP
```

### Step 2: Define what to log with a ContainerNetworkLog custom resource

Stored logs mode doesn't collect anything until you define at least one `ContainerNetworkLog` custom resource. This resource specifies which traffic to capture: by namespace, pod, service, protocol, or verdict.

When a custom resource is applied, matching flows are written to `/var/log/acns/hubble/events.log` on each host node.

See the full [ContainerNetworkLog CRD template](#containernetworklog-crd-template) below for all available fields, or jump straight to applying one:

```azurecli
kubectl apply -f <crd.yaml>
```

> [!TIP]
> For a practical example, see the [sample CRD in the AKS Labs documentation](https://azure-samples.github.io/aks-labs/docs/networking/acns-lab/#enable-flow-logs-for-the-pets-namespace).

Logs on host nodes are temporary. Files auto-rotate at 50 MB, and older entries are overwritten. For persistent storage, configure Azure Monitor (next step). You can also integrate a partner logging service like an OpenTelemetry collector.

### Step 3: Configure Azure Monitor for persistent storage (recommended)

To send logs to a Log Analytics workspace for long-term retention and analysis:

```azurecli
az aks update --enable-acns \
  --enable-container-network-logs \
  -g $RESOURCE_GROUP \
  -n $CLUSTER_NAME
```

To send logs to a specific workspace, add the `--azure-monitor-workspace-resource-id` flag:

```azurecli
az aks update --enable-acns \
  --enable-container-network-logs \
  --azure-monitor-workspace-resource-id $AZURE_MONITOR_ID \
  -g $RESOURCE_GROUP \
  -n $CLUSTER_NAME
```

> [!NOTE]
> Flow logs are written to the host when the `ContainerNetworkLog` custom resource is applied. If you enable Log Analytics integration later, the Azure Monitor Agent begins collecting from that point forward. Logs older than two minutes aren't ingested.

### Alternative: Create a cluster with Log Analytics from the start

If you want logs sent to a Log Analytics workspace from the beginning, include `--enable-container-network-logs` in the create command:

```azurecli
az aks create \
  --resource-group $RESOURCE_GROUP \
  --name $CLUSTER_NAME \
  --location $LOCATION \
  --pod-cidr 192.168.0.0/16 \
  --network-plugin azure \
  --network-plugin-mode overlay \
  --network-dataplane cilium \
  --generate-ssh-keys \
  --enable-acns \
  --enable-container-network-logs \
  --acns-advanced-networkpolicies L7
```

To send logs to a specific workspace, add the `--azure-monitor-workspace-resource-id` flag:

```azurecli
az aks create \
  --resource-group $RESOURCE_GROUP \
  --name $CLUSTER_NAME \
  --location $LOCATION \
  --pod-cidr 192.168.0.0/16 \
  --network-plugin azure \
  --network-plugin-mode overlay \
  --network-dataplane cilium \
  --generate-ssh-keys \
  --enable-acns \
  --enable-container-network-logs \
  --azure-monitor-workspace-resource-id $AZURE_MONITOR_ID \
  --acns-advanced-networkpolicies L7
```

With this approach, you still need to apply a `ContainerNetworkLog` CRD (Step 2) to define which traffic to capture. Log Analytics integration is ready, so matched flows are collected and sent to your workspace automatically.

## Existing cluster

> [!NOTE]
> If your cluster already has ACNS enabled, you can start collecting flow logs on the host node right away by applying a `ContainerNetworkLog` CRD. To also send logs to a Log Analytics workspace, follow the steps below.

```azurecli
# Replace placeholders with your own values
export CLUSTER_NAME="<aks-cluster-name>"
export RESOURCE_GROUP="<aks-resource-group>"
```

### Step 1: Enable container network logs

```azurecli
az aks update --enable-acns \
  --enable-container-network-logs \
  -g $RESOURCE_GROUP \
  -n $CLUSTER_NAME
```

To send logs to a specific Log Analytics workspace, add the `--azure-monitor-workspace-resource-id` flag:

```azurecli
az aks update --enable-acns \
  --enable-container-network-logs \
  --azure-monitor-workspace-resource-id $AZURE_MONITOR_ID \
  -g $RESOURCE_GROUP \
  -n $CLUSTER_NAME
```

### Step 2: Apply a ContainerNetworkLog CRD to start log collection

See the [CRD template](#containernetworklog-crd-template) for the full spec.

```azurecli
kubectl apply -f <crd.yaml>
```

> [!TIP]
> For a practical example, see the [sample CRD in the AKS Labs documentation](https://azure-samples.github.io/aks-labs/docs/networking/acns-lab/#enable-flow-logs-for-the-pets-namespace).

## ContainerNetworkLog CRD template

The `ContainerNetworkLog` custom resource defines which network flows to capture. You can create multiple custom resources in a single cluster, and each can target different namespaces, pods, or protocols.

```yaml
apiVersion: acn.azure.com/v1alpha1
kind: ContainerNetworkLog
metadata:
  name: sample-containernetworklog # Cluster scoped
spec:
  includefilters: # At least one filter is required
    - name: sample-filter
      from:
        namespacedPod: # Format: namespace/pod
          - sample-namespace/sample-pod
        labelSelector:
          matchLabels:
            app: frontend
            k8s.io/namespace: sample-namespace
          matchExpressions:
            - key: environment
              operator: In
              values:
                - production
                - staging
        ip: # Single IP or CIDR
          - "192.168.1.10"
          - "10.0.0.1"
      to:
        namespacedPod:
          - sample-namespace2/sample-pod2
        labelSelector:
          matchLabels:
            app: backend
            k8s.io/namespace: sample-namespace2
          matchExpressions:
            - key: tier
              operator: NotIn
              values:
                - dev
        ip:
          - "192.168.1.20"
          - "10.0.1.1"
      protocol: # tcp, udp, dns
        - tcp
        - udp
        - dns
      verdict: # forwarded, dropped
        - forwarded
        - dropped
```

### CRD field reference

| Field | Type | Description | Required |
|-------|------|-------------|----------|
| `includefilters` | []filter | Filters that define which network flows to capture. Must contain at least one filter. | Yes |
| `filters.name` | String | Name of the filter. | No |
| `filters.protocol` | []string | Protocols to match: `tcp`, `udp`, `dns`. If omitted, all protocols are included. | No |
| `filters.verdict` | []string | Flow verdict to match: `forwarded`, `dropped`. If omitted, all verdicts are included. | No |
| `filters.from` | Endpoint | Source of the network flow. Can include IPs, label selectors, and namespace/pod pairs. | No |
| `filters.to` | Endpoint | Destination of the network flow. Same options as `from`. | No |
| `Endpoint.ip` | []string | Single IP address or CIDR range. | No |
| `Endpoint.labelSelector` | Object | Standard Kubernetes label selector with `matchLabels` and `matchExpressions`. Conditions are combined with AND. If empty, matches all resources. | No |
| `Endpoint.namespacedPod` | []string | Namespace/pod pairs in `namespace/pod` format. | No |

### Capture Layer 7 flows and DNS errors

To see Layer 7 flow data and DNS errors in your logs, you need Cilium network policies with FQDN filtering and L7 policy support enabled. Without these policies, L7 and DNS-related flow information won't appear.

Example Cilium network policy with FQDN filtering and L7 support:

```yaml
apiVersion: cilium.io/v2
kind: CiliumNetworkPolicy
metadata:
  name: l7-dns-policy
  namespace: default
spec:
  endpointSelector:
    matchLabels:
      app: myapp
  egress:
    - toEndpoints:
        - matchLabels:
            "k8s:io.kubernetes.pod.namespace": kube-system
            "k8s:k8s-app": kube-dns
      toPorts:
        - ports:
            - port: "53"
              protocol: UDP
          rules:
            dns:
              - matchPattern: "*.example.com"
    - toFQDNs:
        - matchPattern: "*.example.com"
      toPorts:
        - ports:
            - port: "443"
              protocol: TCP
          rules:
            http:
              - method: "GET"
                path: "/1"
```

```bash
kubectl apply -f l7-dns-policy.yaml
```

For more information, see [Configure a Layer 7 policy](./how-to-apply-l7-policies.md) and [Configure an FQDN policy](./how-to-apply-fqdn-filtering-policies.md).

## Verify the setup

These steps apply to both new and existing cluster setups.

### Get cluster credentials

```azurecli
az aks get-credentials --name $CLUSTER_NAME --resource-group $RESOURCE_GROUP
```

### Confirm that container network logs are enabled

```azurecli
az aks show -g $RESOURCE_GROUP -n $CLUSTER_NAME
```

Look for these sections in the output:

```json
"networkProfile": {
  "advancedNetworking": {
    "enabled": true,
    "observability": {
      "enabled": true
    }
  }
}
```

```json
"osmagent": {
  "config": {
    "enableContainerNetworkLogs": "True"
  }
}
```

### Check custom resource status

List all `ContainerNetworkLog` resources in the cluster:

```azurecli
kubectl get containernetworklog
```
It will give you the name of the containernetworklog resource you just created. Use that name in the command below to check its status:

Check the status of a specific resource:

```azurecli
kubectl describe containernetworklog <cr-name>
```

The `Status` > `State` field should show `CONFIGURED`. If it shows `FAILED`, check that your filter spec is valid.

```output
Spec:
  Includefilters:
    From:
      Namespaced Pod:
        namespace/pod-
    Name:  sample-filter
    Protocol:
      tcp
    To:
      Namespaced Pod:
        namespace/pod-
    Verdict:
      dropped
Status:
  State:      CONFIGURED
  Timestamp:  2025-05-01T11:24:48Z
```

You can apply multiple `ContainerNetworkLog` custom resources. Each one has its own status.

## Query logs in Log Analytics

When Log Analytics is configured, you can query historical flow logs using the `ContainerNetworkLogs` table in your Log Analytics workspace. Use Kusto Query Language (KQL) to analyze network patterns, identify security incidents, troubleshoot connectivity, and perform root cause analysis.

For sample queries, see [Progressive diagnosis using flow logs](https://azure-samples.github.io/aks-labs/docs/networking/acns-lab/#progressive-diagnosis-using-flow-logs) in the AKS Labs documentation.

## Visualize with Grafana dashboards

You can access prebuilt Grafana dashboards through the Azure portal. Before you start, make sure the Azure Monitor log pods are running:

```azurecli
kubectl get pods -o wide -n kube-system | grep ama-logs
```

Expected output:

```output
ama-logs-9bxc6                                   3/3     Running   1 (39m ago)   44m
ama-logs-fd568                                   3/3     Running   1 (40m ago)   44m
ama-logs-rs-65bdd98f75-hqnd2                     2/2     Running   1 (43m ago)   22h
```

### Grant Grafana access to monitoring data

Your Managed Grafana workspace needs the **Monitoring Reader** role on the subscription that contains your Log Analytics workspace.

If you're a subscription Owner or User Access Administrator, the Managed Grafana workspace gets this role automatically when it's created.

If not (or if your Log Analytics and Grafana workspaces are in different subscriptions), grant the role manually:

1. In your Managed Grafana workspace, go to **Settings** > **Identity**.

    :::image type="content" source="./media/advanced-container-networking-services/grafana-identity.png" alt-text="Screenshot of the identity option in a Managed Grafana instance." lightbox="./media/advanced-container-networking-services/grafana-identity.png":::

1. Select **Azure role assignments** > **Add role assignments**.

    :::image type="content" source="./media/advanced-container-networking-services/azure-role-assignments.png" alt-text="Screenshot of choosing Azure role assignments in a Grafana instance." lightbox="./media/advanced-container-networking-services/azure-role-assignments.png":::

1. Set **Scope** to **Subscription**, select your subscription, set **Role** to **Monitoring Reader**, and select **Save**.

    :::image type="content" source="./media/advanced-container-networking-services/grafana-subscription-selection.png" alt-text="Screenshot of entering subscription details in a Managed Grafana instance." lightbox="./media/advanced-container-networking-services/grafana-subscription-selection.png":::

1. Verify the data source in the **Data source** tab of your Managed Grafana instance:

    :::image type="content" source="./media/advanced-container-networking-services/check-datasource-grafana.png" alt-text="Screenshot of checking the data source in a Managed Grafana instance." lightbox="./media/advanced-container-networking-services/check-datasource-grafana.png":::

### Access the dashboards

To open the dashboards from the Azure portal:

1. Go to your AKS cluster in the Azure portal.
1. Select **Dashboards with Grafana (Preview)**.
1. Browse the available dashboards under Azure Monitor or Azure Managed Prometheus.

Look for the dashboards under **Azure Monitor** > **Insights** > **Containers** > **Networking**. There are two options depending on the tier you chose for your `ContainerNetworkLogs` table in Log Analytics:

| Dashboard | Path | Table tier | Grafana ID |
| --- | --- | --- | --- |
| **Flow Logs - Basic Tier** | **Azure** > **Insights** > **Containers** > **Networking** > **Flow Logs - Basic Tier** | Basic | 23155 |
| **Flow Logs - Analytics Tier** | **Azure** > **Insights** > **Containers** > **Networking** > **Flow Logs - Analytics Tier** | Analytics (default) | 23156 |

Both dashboards show which AKS workloads communicate with each other, including requests, responses, drops, and errors. Use the one that matches the tier configured for your `ContainerNetworkLogs` table.

:::image type="content" source="./media/advanced-container-networking-services/grafana-dashboard-in-monitor-resource.png" alt-text="Screenshot of Grafana dashboards in Azure Monitor." lightbox="./media/advanced-container-networking-services/grafana-dashboard-in-monitor-resource.png":::

For more about the dashboard components, see the [container network logs overview](container-network-observability-logs.md#visualize-logs-in-the-azure-portal).

> [!TIP]
> The `ContainerNetworkLogs` table defaults to the **Analytics** tier. If you want to reduce ingestion and retention costs, you can switch to the **Basic** tier and use the corresponding dashboard. For more information, see [Log Analytics table plans](/azure/azure-monitor/logs/data-platform-logs#table-plans).


## Configure on-demand logs mode

On-demand logs let you capture flow data in real time without persistent storage. This mode works with both Cilium and non-Cilium data planes.

Your cluster needs [Advanced Container Networking Services](./advanced-container-networking-services-overview.md) enabled. If you don't have an ACNS-enabled cluster yet, create one:

#### [Cilium](#tab/cilium)

```azurecli
export CLUSTER_NAME="<aks-cluster-name>"
export RESOURCE_GROUP="<aks-resource-group>"

az aks create \
    --name $CLUSTER_NAME \
    --resource-group $RESOURCE_GROUP \
    --generate-ssh-keys \
    --location eastus \
    --max-pods 250 \
    --network-plugin azure \
    --network-plugin-mode overlay \
    --network-dataplane cilium \
    --node-count 2 \
    --pod-cidr 192.168.0.0/16 \
    --kubernetes-version 1.33 \
    --enable-acns
```

#### [Non-Cilium](#tab/non-cilium)

> [!NOTE]
> [Container Network Security](./advanced-container-networking-services-overview.md#container-network-security) isn't available for non-Cilium clusters.

```azurecli
export CLUSTER_NAME="<aks-cluster-name>"
export RESOURCE_GROUP="<aks-resource-group>"

az aks create \
    --name $CLUSTER_NAME \
    --resource-group $RESOURCE_GROUP \
    --generate-ssh-keys \
    --network-plugin azure \
    --network-plugin-mode overlay \
    --pod-cidr 192.168.0.0/16 \
    --enable-acns
```

---

### Enable ACNS on an existing cluster

To enable ACNS on a cluster you already have:

```azurecli
az aks update \
    --resource-group $RESOURCE_GROUP \
    --name $CLUSTER_NAME \
    --enable-acns
```

> [!NOTE]
> Container Network Security features require the Cilium data plane.

Get your cluster credentials:

```azurecli
az aks get-credentials --name $CLUSTER_NAME --resource-group $RESOURCE_GROUP
```

### Install the Hubble CLI

```azurecli
export HUBBLE_VERSION=v1.16.3
export HUBBLE_ARCH=amd64

if [ "$(uname -m)" = "aarch64" ]; then HUBBLE_ARCH=arm64; fi
curl -L --fail --remote-name-all https://github.com/cilium/hubble/releases/download/$HUBBLE_VERSION/hubble-linux-${HUBBLE_ARCH}.tar.gz{,.sha256sum}
sha256sum --check hubble-linux-${HUBBLE_ARCH}.tar.gz.sha256sum
sudo tar xzvfC hubble-linux-${HUBBLE_ARCH}.tar.gz /usr/local/bin
rm hubble-linux-${HUBBLE_ARCH}.tar.gz{,.sha256sum}
```

### Use the Hubble CLI

1. Confirm the Hubble Relay pod is running:

    ```azurecli
    kubectl get pods -o wide -n kube-system -l k8s-app=hubble-relay
    ```

    Expected output:

    ```output
    hubble-relay-7ddd887cdb-h6khj     1/1  Running     0       23h
    ```

1. Port-forward the Hubble Relay:

    ```bash
    kubectl port-forward -n kube-system svc/hubble-relay --address 127.0.0.1 4245:443
    ```

1. Configure mTLS certificates for the Hubble client:

    ```bash
    #!/usr/bin/env bash
    set -euo pipefail
    set -x

    CERT_DIR="$(pwd)/.certs"
    mkdir -p "$CERT_DIR"

    declare -A CERT_FILES=(
      ["tls.crt"]="tls-client-cert-file"
      ["tls.key"]="tls-client-key-file"
      ["ca.crt"]="tls-ca-cert-files"
    )

    for FILE in "${!CERT_FILES[@]}"; do
      KEY="${CERT_FILES[$FILE]}"
      JSONPATH="{.data['${FILE//./\\.}']}"

      kubectl get secret hubble-relay-client-certs -n kube-system \
        -o jsonpath="${JSONPATH}" | \
        base64 -d > "$CERT_DIR/$FILE"

      hubble config set "$KEY" "$CERT_DIR/$FILE"
    done

    hubble config set tls true
    hubble config set tls-server-name instance.hubble-relay.cilium.io
    ```

1. Verify the secrets exist:

    ```azurecli
    kubectl get secrets -n kube-system | grep hubble-
    ```

    Expected output:

    ```output
    kube-system     hubble-relay-client-certs     kubernetes.io/tls     3     9d
    kube-system     hubble-relay-server-certs     kubernetes.io/tls     3     9d
    kube-system     hubble-server-certs           kubernetes.io/tls     3     9d
    ```

1. Observe flows from a specific pod:

    ```azurecli
    hubble observe --pod hubble-relay-7ddd887cdb-h6khj
    ```

### Set up the Hubble UI

1. Save the following manifest as `hubble-ui.yaml`:

    ```yml
    apiVersion: v1
    kind: ServiceAccount
    metadata:
      name: hubble-ui
      namespace: kube-system
    ---
    kind: ClusterRole
    apiVersion: rbac.authorization.k8s.io/v1
    metadata:
      name: hubble-ui
      labels:
        app.kubernetes.io/part-of: retina
    rules:
      - apiGroups:
          - networking.k8s.io
        resources:
          - networkpolicies
        verbs:
          - get
          - list
          - watch
      - apiGroups:
          - ""
        resources:
          - componentstatuses
          - endpoints
          - namespaces
          - nodes
          - pods
          - services
        verbs:
          - get
          - list
          - watch
      - apiGroups:
          - apiextensions.k8s.io
        resources:
          - customresourcedefinitions
        verbs:
          - get
          - list
          - watch
      - apiGroups:
          - cilium.io
        resources:
          - "*"
        verbs:
          - get
          - list
          - watch
    ---
    apiVersion: rbac.authorization.k8s.io/v1
    kind: ClusterRoleBinding
    metadata:
      name: hubble-ui
      labels:
        app.kubernetes.io/part-of: retina
    roleRef:
      apiGroup: rbac.authorization.k8s.io
      kind: ClusterRole
      name: hubble-ui
    subjects:
      - kind: ServiceAccount
        name: hubble-ui
        namespace: kube-system
    ---
    apiVersion: v1
    kind: ConfigMap
    metadata:
      name: hubble-ui-nginx
      namespace: kube-system
    data:
      nginx.conf: |
        server {
            listen       8081;
            server_name  localhost;
            root /app;
            index index.html;
            client_max_body_size 1G;
            location / {
                proxy_set_header Host $host;
                proxy_set_header X-Real-IP $remote_addr;
                # CORS
                add_header Access-Control-Allow-Methods "GET, POST, PUT, HEAD, DELETE, OPTIONS";
                add_header Access-Control-Allow-Origin *;
                add_header Access-Control-Max-Age 1728000;
                add_header Access-Control-Expose-Headers content-length,grpc-status,grpc-message;
                add_header Access-Control-Allow-Headers range,keep-alive,user-agent,cache-control,content-type,content-transfer-encoding,x-accept-content-transfer-encoding,x-accept-response-streaming,x-user-agent,x-grpc-web,grpc-timeout;
                if ($request_method = OPTIONS) {
                    return 204;
                }
                # /CORS
                location /api {
                    proxy_http_version 1.1;
                    proxy_pass_request_headers on;
                    proxy_hide_header Access-Control-Allow-Origin;
                    proxy_pass http://127.0.0.1:8090;
                }
                location / {
                    try_files $uri $uri/ /index.html /index.html;
                }
                # Liveness probe
                location /healthz {
                    access_log off;
                    add_header Content-Type text/plain;
                    return 200 'ok';
                }
            }
        }
    ---
    kind: Deployment
    apiVersion: apps/v1
    metadata:
      name: hubble-ui
      namespace: kube-system
      labels:
        k8s-app: hubble-ui
        app.kubernetes.io/name: hubble-ui
        app.kubernetes.io/part-of: retina
    spec:
      replicas: 1
      selector:
        matchLabels:
          k8s-app: hubble-ui
      template:
        metadata:
          labels:
            k8s-app: hubble-ui
            app.kubernetes.io/name: hubble-ui
            app.kubernetes.io/part-of: retina
        spec:
          serviceAccountName: hubble-ui
          automountServiceAccountToken: true
          containers:
          - name: frontend
            image: mcr.microsoft.com/oss/cilium/hubble-ui:v0.12.2
            imagePullPolicy: Always
            ports:
            - name: http
              containerPort: 8081
            livenessProbe:
              httpGet:
                path: /healthz
                port: 8081
            readinessProbe:
              httpGet:
                path: /
                port: 8081
            resources: {}
            volumeMounts:
            - name: hubble-ui-nginx-conf
              mountPath: /etc/nginx/conf.d/default.conf
              subPath: nginx.conf
            - name: tmp-dir
              mountPath: /tmp
            terminationMessagePolicy: FallbackToLogsOnError
            securityContext: {}
          - name: backend
            image: mcr.microsoft.com/oss/cilium/hubble-ui-backend:v0.12.2
            imagePullPolicy: Always
            env:
            - name: EVENTS_SERVER_PORT
              value: "8090"
            - name: FLOWS_API_ADDR
              value: "hubble-relay:443"
            - name: TLS_TO_RELAY_ENABLED
              value: "true"
            - name: TLS_RELAY_SERVER_NAME
              value: ui.hubble-relay.cilium.io
            - name: TLS_RELAY_CA_CERT_FILES
              value: /var/lib/hubble-ui/certs/hubble-relay-ca.crt
            - name: TLS_RELAY_CLIENT_CERT_FILE
              value: /var/lib/hubble-ui/certs/client.crt
            - name: TLS_RELAY_CLIENT_KEY_FILE
              value: /var/lib/hubble-ui/certs/client.key
            livenessProbe:
              httpGet:
                path: /healthz
                port: 8090
            readinessProbe:
              httpGet:
                path: /healthz
                port: 8090
            ports:
            - name: grpc
              containerPort: 8090
            resources: {}
            volumeMounts:
            - name: hubble-ui-client-certs
              mountPath: /var/lib/hubble-ui/certs
              readOnly: true
            terminationMessagePolicy: FallbackToLogsOnError
            securityContext: {}
          nodeSelector:
            kubernetes.io/os: linux
          volumes:
          - configMap:
              defaultMode: 420
              name: hubble-ui-nginx
            name: hubble-ui-nginx-conf
          - emptyDir: {}
            name: tmp-dir
          - name: hubble-ui-client-certs
            projected:
              defaultMode: 0400
              sources:
              - secret:
                  name: hubble-relay-client-certs
                  items:
                    - key: tls.crt
                      path: client.crt
                    - key: tls.key
                      path: client.key
                    - key: ca.crt
                      path: hubble-relay-ca.crt
    ---
    kind: Service
    apiVersion: v1
    metadata:
      name: hubble-ui
      namespace: kube-system
      labels:
        k8s-app: hubble-ui
        app.kubernetes.io/name: hubble-ui
        app.kubernetes.io/part-of: retina
    spec:
      type: ClusterIP
      selector:
        k8s-app: hubble-ui
      ports:
        - name: http
          port: 80
          targetPort: 8081
    ```

1. Apply the manifest:

    ```azurecli
    kubectl apply -f hubble-ui.yaml
    ```

1. Set up port forwarding:

    ```azurecli
    kubectl -n kube-system port-forward svc/hubble-ui 12000:80
    ```

1. Open `http://localhost:12000/` in your browser to access the Hubble UI.

## Troubleshooting

* **ACNS not enabled.** Running `--enable-container-network-logs` without ACNS produces:

    `Flow logs requires '--enable-acns', advanced networking to be enabled. 

* **Kubernetes version too old.** Running `--enable-container-network-logs` on a cluster older than 1.33.0 produces:

    `The specified orchestrator version %s is not valid. Advanced Networking Flow Logs is only supported on Kubernetes version 1.33.0 or later.`

* **CRD not recognized.** Applying a `ContainerNetworkLog` on a cluster without ACNS produces:

    `error: resource mapping not found for <....>": no matches for kind "ContainerNetworkLog" in version "acn.azure.com/v1alpha1"`

    Make sure ACNS is enabled on the cluster.

## Disable stored logs mode

Deleting all `ContainerNetworkLog` custom resources stops flow log collection since no filters are defined.

To also disable the Azure Monitor Agent log collection:

```azurecli
az aks update -n $CLUSTER_NAME -g $RESOURCE_GROUP --disable-container-network-logs
```

## Clean up resources

If you no longer need the resources, delete the resource group:

```azurecli
az group delete --name $RESOURCE_GROUP
```

## Limitations
* Stored logs mode is only available for clusters with the Cilium data plane.
* Flow logs are written to host nodes and collected by the Azure Monitor Agent. If you enable Log Analytics integration after applying a `ContainerNetworkLog` CRD, only new logs from that point forward are ingested. Historical logs on the host aren't collected.
* When Log Analytics isn't configured for log storage, container network logs are limited to a maximum of 50 MB of storage. When this limit is reached, new entries overwrite older logs on the host node. For long-term retention and analysis, it's recommended to configure Azure Monitor or an external logging solution.
* Switching the Log Analytics workspace after enabling Container Network Logs may cause logs to stop flowing to the new workspace. This happens because the existing Azure Monitor data collection configuration is not automatically updated. To prevent this issue, configure the desired workspace when first enabling Container Network Logs, or manually update the associated data collection rule when changing workspaces, see [Configure data collection in Container insights](/azure/azure-monitor/containers/kubernetes-data-collection-configure#send-to-multiple-workspaces-and-tables).

* Flow log aggregation doesn't preserve individual flow timestamps, per-pod IP addresses, or high-cardinality fields like HTTP URLs and DNS query names. Use on-demand logs for per-flow investigation.

## Related content

* [What are container network logs?](container-network-observability-logs.md)
* [Advanced Container Networking Services for AKS](advanced-container-networking-services-overview.md)
* [Container Network Observability](./advanced-container-networking-services-overview.md#container-network-observability) in Advanced Container Networking Services
