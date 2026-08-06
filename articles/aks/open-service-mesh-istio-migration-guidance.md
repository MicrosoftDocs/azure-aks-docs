---
title: Migration guidance from the Open Service Mesh (OSM) add-on to the Istio add-on
description: Learn how to migrate from the Open Service Mesh (OSM) add-on to the Istio add-on for Azure Kubernetes Service (AKS).
ms.service: azure-kubernetes-service
ms.custom: aks-migration
ms.topic: how-to
ms.date: 05/29/2026
ms.author: davidsmatlak
author: davidsmatlak
ai-usage: ai-assisted
# Customer intent: "As a cloud engineer migrating microservices from the OSM add-on to the Istio add-on, I want guidance for translating OSM add-on configurations to Istio add-on equivalents, so that I can plan the changes needed for my workloads."
---

# Migration guidance from the Open Service Mesh (OSM) add-on to the Istio add-on

> [!IMPORTANT]
> This article introduces how to identify OSM add-on configurations and translate them to equivalent Istio add-on configurations. It is not an exhaustive production migration runbook.

This article maps OSM add-on policies to equivalent Istio add-on policies. The source and target in this article are both managed Azure Kubernetes Service (AKS) add-ons. It doesn't cover migration from upstream Open Service Mesh to a self-managed or open source Istio installation. It uses the OSM [Bookstore sample application](https://docs.openservicemesh.io/docs/getting_started/install_apps/) as the reference for current OSM add-on users. The article has two independent sections:

- [Migrate the OSM Bookstore sample to the Istio add-on](#migrate-the-osm-bookstore-sample-to-the-istio-add-on): In-place migration procedure for an existing cluster running the OSM add-on.
- [Bookstore policy translation reference](#bookstore-policy-translation-reference): Clean-sample walkthrough that demonstrates how to translate OSM SMI policies to Istio equivalents on a fresh cluster.

If you aren't using OSM and are new to the managed Istio add-on, start with [Install the Istio add-on](istio-deploy-addon.md). If you currently use OSM, review the OSM [Bookstore sample application](https://docs.openservicemesh.io/docs/getting_started/install_apps/) walk-through before you continue. The following walk-through doesn't duplicate the OSM documentation and references specific topics when relevant. Make sure you understand the Bookstore application architecture before proceeding.

## Prerequisites

- An Azure subscription with an existing AKS cluster running the OSM add-on.
- [Azure CLI installed](/cli/azure/install-azure-cli).
- Access to the AKS cluster where you can enable or disable managed add-ons.
- `kubectl` access to the cluster.
- The OSM Bookstore sample already deployed in the `bookbuyer`, `bookthief`, `bookstore`, and `bookwarehouse` namespaces.
- Select an Istio revision to install. Set `LOCATION` to the Azure region for your AKS cluster, then look up supported Istio revisions using the `az aks mesh get-revisions` command:

    ```azurecli-interactive
    export LOCATION=<location>
    ```

    ```azurecli-interactive
    az aks mesh get-revisions --location ${LOCATION} -o table
    ```

- Set variables used throughout this article. Set `REVISION` to a revision returned by the `az aks mesh get-revisions` command:

    ```azurecli-interactive
    export RESOURCE_GROUP=<resource-group-name>
    export CLUSTER=<cluster-name>
    export REVISION=<revision>
    export BOOKSTORE_NAMESPACES="bookbuyer bookthief bookstore bookwarehouse"
    ```

## Migrate the OSM Bookstore sample to the Istio add-on

The OSM add-on and the Istio add-on can't run simultaneously on the same AKS cluster. This procedure migrates the OSM Bookstore sample without deleting the cluster, namespaces, services, or workload controllers. Running pods aren't changed in place. Existing pods keep their OSM sidecars until their controllers create replacement pods after the namespaces are labeled for the managed Istio revision.

> [!WARNING]
> This migration causes service disruption. Disabling the OSM add-on immediately removes SMI traffic policy enforcement: mTLS and access control stop being applied even though existing pods are still running. The window between disabling OSM and completing the Istio rollout leaves workloads without mesh-level security or routing policy. Any pod replacement during this window (rollout restarts, scaling events, node evictions, or crash loops) creates pods that have neither an OSM sidecar nor an Istio sidecar until the namespace is labeled and the pod is recreated again. Plan an application downtime or reduced-availability window for production workloads, and validate the full procedure in a non-production cluster first. AKS planned maintenance settings don't schedule or control this manual migration.

The migration below uses the following cleanup sequence:

1. Save the SMI resources before disabling the OSM add-on.
1. Disable the OSM add-on before enabling the managed Istio add-on.
1. Remove stale OSM admission webhooks before relabeling namespaces or restarting workloads.
1. Leave OSM and SMI CRDs in place through managed Istio enablement and workload rollout unless your own validation shows that they block enablement, admission, or rollout.
1. Remove stale `openservicemesh.io/*` namespace markers during the label swap.
1. Label workload namespaces with `istio.io/rev=<revision>`.
1. Apply and verify the translated Istio resources that are safe for your existing workload names and selectors.
1. Roll the existing workload controllers so replacement pods are created with Istio sidecars.
1. Delete residual OSM and SMI CRDs only after the migrated pods are ready.

### Verify the OSM Bookstore state

Verify that the OSM add-on is enabled and the managed Istio add-on is not enabled:

```azurecli-interactive
az aks show \
  --resource-group ${RESOURCE_GROUP} \
  --name ${CLUSTER} \
  --query "{openServiceMesh:addonProfiles.openServiceMesh.enabled, serviceMeshProfile:serviceMeshProfile}"
```

The `openServiceMesh.enabled` value should be `true`. The `serviceMeshProfile` value should be `null` or show `mode: disabled` before the migration starts.

Verify that the OSM control plane is ready:

```bash
kubectl wait -n kube-system --for=condition=Ready pod -l app=osm-controller --timeout=10m
kubectl wait -n kube-system --for=condition=Ready pod -l app=osm-injector --timeout=10m
kubectl wait -n kube-system --for=condition=Ready pod -l app=osm-bootstrap --timeout=10m
```

Verify that the Bookstore pods are running and have multiple ready containers. OSM-injected pods include the `osm-init` init container and the `envoy` sidecar container.

```bash
kubectl get pods -A -o wide | grep -E '^(bookbuyer|bookstore|bookthief|bookwarehouse)'
```

The following condensed example shows Bookstore pods with multiple containers ready:

```output
bookbuyer       bookbuyer-58c7699cb7-fxzvz       2/2   Running   0   51s   10.224.0.20   aks-nodepool1-32739176-vmss000002   <none>   <none>
bookstore       bookstore-7696584686-6zdkn       2/2   Running   0   50s   10.224.0.71   aks-nodepool1-32739176-vmss000001   <none>   <none>
bookthief       bookthief-77bf8c9b76-vswxz       2/2   Running   0   50s   10.224.0.15   aks-nodepool1-32739176-vmss000002   <none>   <none>
bookwarehouse   bookwarehouse-6b94d668f7-vksf4   2/2   Running   0   49s   10.224.0.82   aks-nodepool1-32739176-vmss000001   <none>   <none>
bookwarehouse   mysql-0                          3/3   Running   0   48s   10.224.0.17   aks-nodepool1-32739176-vmss000002   <none>   <none>
```

Confirm that the injected pods include OSM containers:

```bash
for NAMESPACE in ${BOOKSTORE_NAMESPACES}; do
  kubectl get pods -n ${NAMESPACE} \
    -o jsonpath='{range .items[*]}{.metadata.namespace}{"/"}{.metadata.name}{"\tinit="}{range .spec.initContainers[*]}{.name}{","}{end}{"\tcontainers="}{range .spec.containers[*]}{.name}{","}{end}{"\n"}{end}'
done
```

Verify the SMI resources used by the sample:

```bash
kubectl get traffictargets.access.smi-spec.io,httproutegroups.specs.smi-spec.io,tcproutes.specs.smi-spec.io,trafficsplits.split.smi-spec.io -A
```

Check the Bookbuyer logs before changing the mesh:

```bash
kubectl logs -n bookbuyer deploy/bookbuyer -c bookbuyer --tail=20
```

Optionally start a continuous Bookbuyer log stream to monitor application availability. Keep the stream running through namespace relabeling and workload rollout if you want the log to cover the full migration window.

```bash
BOOKBUYER_LOG=bookbuyer-migration.log
kubectl logs -n bookbuyer deploy/bookbuyer -c bookbuyer --timestamps --since=10s -f > ${BOOKBUYER_LOG} 2>&1 &
BOOKBUYER_LOG_PID=$!
```

### Save the SMI policy configuration

Save the SMI resources before final OSM and SMI API cleanup. Use these files to plan translation and rollback.

```bash
mkdir -p osm-smi-backup

kubectl get traffictargets.access.smi-spec.io -A -o yaml > osm-smi-backup/traffic-targets.yaml
kubectl get httproutegroups.specs.smi-spec.io -A -o yaml > osm-smi-backup/http-route-groups.yaml
kubectl get tcproutes.specs.smi-spec.io -A -o yaml > osm-smi-backup/tcp-routes.yaml
kubectl get trafficsplits.split.smi-spec.io -A -o yaml > osm-smi-backup/traffic-splits.yaml
```

Don't rely on residual OSM webhooks, CRDs, labels, or annotations as rollback state after the add-on is disabled.

Translate the saved SMI resources to Istio resources using the policy examples later in the article:

| OSM resource or behavior | Istio equivalent |
| --- | --- |
| OSM namespace onboarding | `istio.io/rev=<revision>` namespace label |
| OSM sidecar injection | Istio sidecar injection for the selected revision |
| `TrafficTarget`, `HTTPRouteGroup`, and `TCPRoute` | `AuthorizationPolicy` |
| `TrafficSplit` | `VirtualService` and `DestinationRule` |
| OSM permissive traffic policy and mTLS settings | `PeerAuthentication` and `AuthorizationPolicy` |

Apply and verify translated Istio resources for your workloads before you treat the migration as complete. The in-place Bookstore steps in this section verify the control plane change and sidecar rollout. They don't automatically apply the policy examples in the reference section, and the clean-sample manifests later in this article must be adapted before you apply them to existing namespaces.

### Disable the OSM add-on

Disable the OSM add-on:

```azurecli-interactive
az aks disable-addons \
  --resource-group ${RESOURCE_GROUP} \
  --name ${CLUSTER} \
  --addons open-service-mesh
```

Verify that the OSM add-on is disabled:

```azurecli-interactive
az aks show \
  --resource-group ${RESOURCE_GROUP} \
  --name ${CLUSTER} \
  --query "{openServiceMesh:addonProfiles.openServiceMesh.enabled, serviceMeshProfile:serviceMeshProfile}"
```

The `openServiceMesh.enabled` value should be `false` or `null`. The `serviceMeshProfile` value should remain unchanged until managed Istio is enabled.

Verify that the existing Bookstore pods are still running:

```bash
kubectl get pods -n bookbuyer
kubectl get pods -n bookthief
kubectl get pods -n bookstore
kubectl get pods -n bookwarehouse
```

Existing pods might still include OSM sidecars after OSM is disabled. This is expected. They are replaced when their controllers are rolled later in the procedure.

### Remove residual OSM admission blockers

Check whether residual OSM admission still affects a workload namespace:

```bash
kubectl run osm-admission-probe \
  --namespace bookbuyer \
  --image mcr.microsoft.com/oss/nginx/nginx:1.25.5 \
  --restart Never \
  --dry-run=server \
  -o yaml
```

Remove the AKS OSM add-on webhook configurations. If the dry run failed because Kubernetes can't call the `osm-injector` service, this cleanup clears the admission blocker.

```bash
kubectl delete mutatingwebhookconfiguration aks-osm-webhook-osm --ignore-not-found
kubectl delete validatingwebhookconfiguration aks-osm-validator-mesh-osm --ignore-not-found
```

Remove these webhook configurations before relabeling namespaces or restarting workloads. A broken residual OSM webhook can block pod creation for verification, workload rollout, or rollback testing.

Confirm that server-side pod admission succeeds after webhook cleanup:

```bash
kubectl run osm-admission-probe \
  --namespace bookbuyer \
  --image mcr.microsoft.com/oss/nginx/nginx:1.25.5 \
  --restart Never \
  --dry-run=server \
  -o yaml
```

Verify that no OSM admission webhooks remain:

```bash
kubectl get mutatingwebhookconfiguration,validatingwebhookconfiguration | grep -i osm || true
```

Inventory any remaining OSM and SMI CRDs before enabling managed Istio. Leave these CRDs in place unless validation shows they block enablement, admission, or rollout.

```bash
kubectl get crd | grep -E 'openservicemesh.io|smi-spec.io' || true
```

### Enable the Istio add-on and move workloads

Enable the managed Istio add-on:

```azurecli-interactive
az aks mesh enable \
  --resource-group ${RESOURCE_GROUP} \
  --name ${CLUSTER} \
  --revision ${REVISION}
```

Verify the managed Istio add-on state:

```azurecli-interactive
az aks show \
  --resource-group ${RESOURCE_GROUP} \
  --name ${CLUSTER} \
  --query "{mode:serviceMeshProfile.mode, revisions:serviceMeshProfile.istio.revisions}"
```

The `mode` value should be `Istio`, and the revision list should include the selected revision.

Wait for the Istio control plane and injector webhook:

```bash
kubectl wait -n aks-istio-system --for=condition=Ready pod -l app=istiod --timeout=10m
kubectl get mutatingwebhookconfiguration | grep istio-sidecar-injector
```

Remove stale OSM namespace markers and label the Bookstore namespaces with the managed Istio revision. Don't use `istio-injection=enabled` with the AKS managed Istio add-on.

```bash
for NAMESPACE in ${BOOKSTORE_NAMESPACES}; do
  kubectl label namespace ${NAMESPACE} openservicemesh.io/monitored-by- --overwrite
  kubectl annotate namespace ${NAMESPACE} openservicemesh.io/sidecar-injection- --overwrite
  kubectl label namespace ${NAMESPACE} istio.io/rev=${REVISION} --overwrite
done
```

Apply and verify the translated Istio resources that are safe for your existing workload names and selectors before rolling controllers. The exact files depend on the SMI resources you saved and translated.

```bash
kubectl apply -f translated-istio-resources.yaml
kubectl get peerauthentication,authorizationpolicy,destinationrule,virtualservice -A
```

Don't delete OSM or SMI APIs until equivalent Istio policy and routing behavior is verified for your workloads.

Roll the existing controllers so Kubernetes creates replacement pods with Istio sidecars. The following order matches the sample validation flow:

```bash
kubectl rollout restart -n bookwarehouse deployment/bookwarehouse
kubectl rollout status -n bookwarehouse deployment/bookwarehouse --timeout=10m

kubectl rollout restart -n bookwarehouse statefulset/mysql
kubectl rollout status -n bookwarehouse statefulset/mysql --timeout=10m

kubectl rollout restart -n bookstore deployment/bookstore
kubectl rollout status -n bookstore deployment/bookstore --timeout=10m

kubectl rollout restart -n bookthief deployment/bookthief
kubectl rollout status -n bookthief deployment/bookthief --timeout=10m

kubectl rollout restart -n bookbuyer deployment/bookbuyer
kubectl rollout status -n bookbuyer deployment/bookbuyer --timeout=10m
```

Verify that the replacement pods include `istio-proxy`:

```bash
for NAMESPACE in ${BOOKSTORE_NAMESPACES}; do
  kubectl get pods -n ${NAMESPACE} \
    -o jsonpath='{range .items[*]}{.metadata.namespace}{"/"}{.metadata.name}{"\tinit="}{range .spec.initContainers[*]}{.name}{","}{end}{"\tcontainers="}{range .spec.containers[*]}{.name}{","}{end}{"\n"}{end}'
done
```

Check Bookbuyer after the rollout:

```bash
kubectl logs -n bookbuyer deploy/bookbuyer -c bookbuyer --tail=20
```

If a Bookbuyer log stream was started, stop it and inspect the collected samples. Confirm the timestamps cover the relabeling and rollout window before using the log as availability evidence.

```bash
kill ${BOOKBUYER_LOG_PID}
wait ${BOOKBUYER_LOG_PID} 2>/dev/null || true

grep "MAESTRO! THIS TEST FAILED!" ${BOOKBUYER_LOG} || true
grep "MAESTRO! THIS TEST SUCCEEDED!" ${BOOKBUYER_LOG} | tail
```

After the migrated pods are ready, review the CRD inventory and delete residual OSM and SMI CRDs as final cleanup. Deleting a CRD removes all custom resources for that CRD across the cluster, not only the Bookstore sample. Don't run this cleanup until you confirm no remaining workloads depend on OSM or SMI resources.

```bash
kubectl delete crd \
  egresses.policy.openservicemesh.io \
  httproutegroups.specs.smi-spec.io \
  ingressbackends.policy.openservicemesh.io \
  meshconfigs.config.openservicemesh.io \
  meshrootcertificates.config.openservicemesh.io \
  retries.policy.openservicemesh.io \
  tcproutes.specs.smi-spec.io \
  trafficsplits.split.smi-spec.io \
  traffictargets.access.smi-spec.io \
  upstreamtrafficsettings.policy.openservicemesh.io \
  --ignore-not-found
```

Verify the final add-on and residual OSM state:

```azurecli-interactive
az aks show \
  --resource-group ${RESOURCE_GROUP} \
  --name ${CLUSTER} \
  --query "{openServiceMesh:addonProfiles.openServiceMesh.enabled, serviceMeshProfile:serviceMeshProfile}"
```

```bash
kubectl get mutatingwebhookconfiguration,validatingwebhookconfiguration | grep -i osm || true
kubectl get crd | grep -E 'openservicemesh.io|smi-spec.io' || true
```

The final AKS state should show OSM disabled and managed Istio enabled. If you removed the residual OSM and SMI CRDs, the residual OSM resource checks should return no resources.

## Bookstore policy translation reference

The rest of this article uses a clean Bookstore sample deployment to demonstrate how to translate OSM SMI resources and workload manifests to Istio resources. In a migration, apply the same kinds of changes to your existing manifests and roll your existing workload controllers in place instead of deleting and recreating the application.

> [!NOTE]
> Run the policy translation reference in a separate cluster or delete the existing Bookstore namespaces before running the sample deployment commands. The `kubectl create namespace` commands fail if the namespaces already exist. The target cluster must already have the managed Istio add-on enabled.

To allow Istio to manage the OSM Bookstore application, update the existing Bookstore and MySQL service manifests.

### Bookstore modifications

Before you translate OSM traffic policy, review how Istio handles [traffic management](https://istio.io/latest/docs/tasks/traffic-management/).

Istio uses a combination of a [VirtualService](https://istio.io/latest/docs/reference/config/networking/virtual-service/) and a [DestinationRule](https://istio.io/latest/docs/reference/config/networking/destination-rule/) for traffic routing. Review the concepts of a virtual service and destination rule before you continue.

The Istio virtual service defines routing rules for clients that request the host, which is the service name. The destination rule defines traffic policy for that service.

The Istio Bookstore service and deployment changes keep the Bookstore application behind the `bookstore` service. The Istio version of the OSM [traffic-access-v1.yaml](https://raw.githubusercontent.com/openservicemesh/osm-docs/release-v1.2/manifests/access/traffic-access-v1.yaml) manifest appears in [Create pods, services, and service accounts](#create-pods-services-and-service-accounts).

### MySQL modifications

Changes to the MySQL StatefulSet are only needed in the service configuration. Under the service specification, OSM needed the `targetPort` and `appProtocol` attributes. These attributes aren't needed for Istio. Keep the service name as `mysql` because the Bookstore sample and the MySQL StatefulSet use that name. The following updated service looks like this example:

```yml
apiVersion: v1
kind: Service
metadata:
  name: mysql
  namespace: bookwarehouse
  labels:
    app: mysql
    service: mysql
spec:
  ports:
    - port: 3306
      name: tcp
  selector:
    app: mysql
  clusterIP: None
```

## Deploy the modified Bookstore application

Similar to the OSM Bookstore walk-through, the sample starts with a new installation of the bookstore application. This sample deployment demonstrates the policy translation flow. For existing workloads, use the in-place migration pattern earlier in this article.

### Create the namespaces

```bash
kubectl create namespace bookstore
kubectl create namespace bookbuyer
kubectl create namespace bookthief
kubectl create namespace bookwarehouse
```

### Add a namespace label for Istio sidecar injection

For OSM, using the command `osm namespace add <namespace>` created the necessary annotations to the namespace for the OSM controller to add automatic sidecar injection. With the managed Istio add-on, label the namespace with the installed Istio revision to allow the Istio controller to inject the Envoy sidecar proxies. The default `istio-injection=enabled` label doesn't enable sidecar injection for the Istio add-on.

```bash
for NAMESPACE in ${BOOKSTORE_NAMESPACES}; do
  kubectl label namespace ${NAMESPACE} istio.io/rev=${REVISION}
done
```

### Deploy the Istio virtual service for Bookstore

Deploy the virtual service for the `bookstore` service.

```bash
kubectl apply -f - <<EOF
# Create bookstore virtual service
apiVersion: networking.istio.io/v1alpha3
kind: VirtualService
metadata:
  name: bookstore-virtualservice
  namespace: bookstore
spec:
  hosts:
  - bookstore
  http:
  - route:
    - destination:
        host: bookstore
EOF
```

### Create pods, services, and service accounts

Use a single manifest file that contains the modifications discussed earlier in the walk-through to deploy the `bookbuyer`, `bookthief`, `bookstore`, `bookwarehouse`, and `mysql` applications.

```bash
kubectl apply -f - <<EOF
##################################################################################################
# bookbuyer service
##################################################################################################
---
# Create bookbuyer Service Account
apiVersion: v1
kind: ServiceAccount
metadata:
  name: bookbuyer
  namespace: bookbuyer
---
# Create bookbuyer Deployment
apiVersion: apps/v1
kind: Deployment
metadata:
  name: bookbuyer
  namespace: bookbuyer
spec:
  replicas: 1
  selector:
    matchLabels:
      app: bookbuyer
      version: v1
  template:
    metadata:
      labels:
        app: bookbuyer
        version: v1
    spec:
      serviceAccountName: bookbuyer
      nodeSelector:
        kubernetes.io/arch: amd64
        kubernetes.io/os: linux
      containers:
        - name: bookbuyer
          image: openservicemesh/bookbuyer:latest-main
          imagePullPolicy: Always
          command: ["/bookbuyer"]
          env:
            - name: "BOOKSTORE_NAMESPACE"
              value: bookstore
            - name: "BOOKSTORE_SVC"
              value: bookstore
---
##################################################################################################
# bookthief service
##################################################################################################
---
# Create bookthief ServiceAccount
apiVersion: v1
kind: ServiceAccount
metadata:
  name: bookthief
  namespace: bookthief
---
# Create bookthief Deployment
apiVersion: apps/v1
kind: Deployment
metadata:
  name: bookthief
  namespace: bookthief
spec:
  replicas: 1
  selector:
    matchLabels:
      app: bookthief
  template:
    metadata:
      labels:
        app: bookthief
        version: v1
    spec:
      serviceAccountName: bookthief
      nodeSelector:
        kubernetes.io/arch: amd64
        kubernetes.io/os: linux
      containers:
        - name: bookthief
          image: openservicemesh/bookthief:latest-main
          imagePullPolicy: Always
          command: ["/bookthief"]
          env:
            - name: "BOOKSTORE_NAMESPACE"
              value: bookstore
            - name: "BOOKSTORE_SVC"
              value: bookstore
            - name: "BOOKTHIEF_EXPECTED_RESPONSE_CODE"
              value: "503"
---
##################################################################################################
# bookstore service version 1 & 2
##################################################################################################
---
# Create bookstore Service
apiVersion: v1
kind: Service
metadata:
  name: bookstore
  namespace: bookstore
  labels:
    app: bookstore
spec:
  ports:
    - port: 14001
      name: bookstore-port
  selector:
    app: bookstore

---
# Create bookstore Service Account
apiVersion: v1
kind: ServiceAccount
metadata:
  name: bookstore
  namespace: bookstore

---
# Create bookstore-v1 Deployment
apiVersion: apps/v1
kind: Deployment
metadata:
  name: bookstore-v1
  namespace: bookstore
spec:
  replicas: 1
  selector:
    matchLabels:
      app: bookstore
      version: v1
  template:
    metadata:
      labels:
        app: bookstore
        version: v1
    spec:
      serviceAccountName: bookstore
      nodeSelector:
        kubernetes.io/arch: amd64
        kubernetes.io/os: linux
      containers:
        - name: bookstore
          image: openservicemesh/bookstore:latest-main
          imagePullPolicy: Always
          ports:
            - containerPort: 14001
              name: web
          command: ["/bookstore"]
          args: ["--port", "14001"]
          env:
            - name: BOOKWAREHOUSE_NAMESPACE
              value: bookwarehouse
            - name: IDENTITY
              value: bookstore-v1

##################################################################################################
# bookwarehouse service
##################################################################################################
---
# Create bookwarehouse Service Account
apiVersion: v1
kind: ServiceAccount
metadata:
  name: bookwarehouse
  namespace: bookwarehouse
---
# Create bookwarehouse Service
apiVersion: v1
kind: Service
metadata:
  name: bookwarehouse
  namespace: bookwarehouse
  labels:
    app: bookwarehouse
spec:
  ports:
  - port: 14001
    name: bookwarehouse-port
  selector:
    app: bookwarehouse
---
# Create bookwarehouse Deployment
apiVersion: apps/v1
kind: Deployment
metadata:
  name: bookwarehouse
  namespace: bookwarehouse
spec:
  replicas: 1
  selector:
    matchLabels:
      app: bookwarehouse
  template:
    metadata:
      labels:
        app: bookwarehouse
        version: v1
    spec:
      serviceAccountName: bookwarehouse
      nodeSelector:
        kubernetes.io/arch: amd64
        kubernetes.io/os: linux
      containers:
        - name: bookwarehouse
          image: openservicemesh/bookwarehouse:latest-main
          imagePullPolicy: Always
          command: ["/bookwarehouse"]
##################################################################################################
# mysql service
##################################################################################################
---
apiVersion: v1
kind: ServiceAccount
metadata:
  name: mysql
  namespace: bookwarehouse
---
apiVersion: v1
kind: Service
metadata:
  name: mysql
  namespace: bookwarehouse
  labels:
    app: mysql
    service: mysql
spec:
  ports:
    - port: 3306
      name: tcp
  selector:
    app: mysql
  clusterIP: None
---
apiVersion: apps/v1
kind: StatefulSet
metadata:
  name: mysql
  namespace: bookwarehouse
spec:
  serviceName: mysql
  replicas: 1
  selector:
    matchLabels:
      app: mysql
  template:
    metadata:
      labels:
        app: mysql
    spec:
      serviceAccountName: mysql
      nodeSelector:
        kubernetes.io/os: linux
      containers:
      - image: mysql:5.6
        name: mysql
        env:
        - name: MYSQL_ROOT_PASSWORD
          value: mypassword
        - name: MYSQL_DATABASE
          value: booksdemo
        ports:
        - containerPort: 3306
          name: mysql
        volumeMounts:
        - mountPath: /mysql-data
          name: data
        readinessProbe:
          tcpSocket:
            port: 3306
          initialDelaySeconds: 15
          periodSeconds: 10
      volumes:
        - name: data
          emptyDir: {}
  volumeClaimTemplates:
  - metadata:
      name: data
    spec:
      accessModes: [ "ReadWriteOnce" ]
      resources:
        requests:
          storage: 250M
EOF
```

To view these resources on your cluster, run the following commands:

```bash
kubectl get pods,deployments,serviceaccounts -n bookbuyer
kubectl get pods,deployments,serviceaccounts -n bookthief

kubectl get pods,deployments,serviceaccounts,services,endpoints -n bookstore
kubectl get pods,deployments,serviceaccounts,services,endpoints -n bookwarehouse
```

### View the application UIs

Similar to the original OSM walk-through, if you have the OSM repository cloned, you can use the port forwarding scripts to view the application UIs. For more information, see [View the application UIs](https://release-v1-2.docs.openservicemesh.io/docs/getting_started/install_apps/#view-the-application-uis). For now, view only the `bookbuyer` and `bookthief` UIs.

```bash
cp .env.example .env
bash <<EOF
./scripts/port-forward-bookbuyer-ui.sh &
./scripts/port-forward-bookthief-ui.sh &
wait
EOF
```

In a browser, open the following URLs:

<http://localhost:8080> - bookbuyer

<http://localhost:8083> - bookthief

## Configure Istio's traffic policies

To keep the Istio translation aligned with the original OSM Bookstore walk-through, start with [OSM's permissive traffic policy mode](https://release-v1-2.docs.openservicemesh.io/docs/getting_started/traffic_policies/#permissive-traffic-policy-mode). OSM's permissive traffic policy mode allowed or denied traffic in the mesh when no specific [SMI Traffic Access Control rule](https://github.com/servicemeshinterface/smi-spec/blob/main/apis/traffic-access/v1alpha3/traffic-access.md) was deployed. This mode let users onboard applications into the mesh and get mTLS encryption before they defined explicit allow rules. You could set this value to `true` or `false` through OSM's MeshConfig.

Istio handles mTLS enforcement differently. Unlike OSM, Istio's permissive mode automatically configures sidecar proxies to use mTLS and allows services to accept both plaintext and mTLS traffic. Use Istio `PeerAuthentication` settings as the equivalent to OSM's permissive mode configuration. You can configure `PeerAuthentication` for a namespace or for the entire mesh. For more information, read the [Istio Mutual TLS Migration article](https://istio.io/latest/docs/tasks/security/authentication/mtls-migration/).

### Enforce Istio strict mode on Bookstore namespaces

Remember that, like OSM's permissive mode, Istio's `PeerAuthentication` configuration only applies to mTLS enforcement. Istio handles layer-7 policies, like those used in OSM's HTTPRouteGroups, with `AuthorizationPolicy` configurations.

Put the `bookbuyer`, `bookthief`, `bookstore`, and `bookwarehouse` namespaces in Istio's mTLS strict mode.

```bash
kubectl apply -f - <<EOF
apiVersion: security.istio.io/v1beta1
kind: PeerAuthentication
metadata:
  name: bookbuyer
  namespace: bookbuyer
spec:
  mtls:
    mode: STRICT
---
apiVersion: security.istio.io/v1beta1
kind: PeerAuthentication
metadata:
  name: bookthief
  namespace: bookthief
spec:
  mtls:
    mode: STRICT
---
apiVersion: security.istio.io/v1beta1
kind: PeerAuthentication
metadata:
  name: bookstore
  namespace: bookstore
spec:
  mtls:
    mode: STRICT
---
apiVersion: security.istio.io/v1beta1
kind: PeerAuthentication
metadata:
  name: bookwarehouse
  namespace: bookwarehouse
spec:
  mtls:
    mode: STRICT
EOF
```

### Deploy Istio access control policies

OSM uses [SMI Traffic Target](https://github.com/servicemeshinterface/smi-spec/blob/v0.6.0/apis/traffic-access/v1alpha2/traffic-access.md) and [SMI Traffic Specs](https://github.com/servicemeshinterface/smi-spec/blob/v0.6.0/apis/traffic-specs/v1alpha4/traffic-specs.md) resources to define access control and routing policies for application communication. Istio provides similar fine-grained controls with `AuthorizationPolicy` configurations.

The following example translates the bookstore TrafficTarget policy, which allows `bookbuyer` to communicate with bookstore by using specific layer-7 paths, headers, and methods. This content is a portion of the [traffic-access-v1.yaml](https://raw.githubusercontent.com/openservicemesh/osm-docs/release-v1.2/manifests/access/traffic-access-v1.yaml) manifest.

```yml
kind: TrafficTarget
apiVersion: access.smi-spec.io/v1alpha3
metadata:
  name: bookstore
  namespace: bookstore
spec:
  destination:
    kind: ServiceAccount
    name: bookstore
    namespace: bookstore
  rules:
    - kind: HTTPRouteGroup
      name: bookstore-service-routes
      matches:
        - buy-a-book
        - books-bought
  sources:
    - kind: ServiceAccount
      name: bookbuyer
      namespace: bookbuyer
---
apiVersion: specs.smi-spec.io/v1alpha4
kind: HTTPRouteGroup
metadata:
  name: bookstore-service-routes
  namespace: bookstore
spec:
  matches:
    - name: books-bought
      pathRegex: /books-bought
      methods:
        - GET
      headers:
        - "user-agent": ".*-http-client/*.*"
        - "client-app": "bookbuyer"
    - name: buy-a-book
      pathRegex: ".*a-book.*new"
      methods:
        - GET
```

In the TrafficTarget policy, `spec.destination` defines the destination service and `spec.sources` defines the authorized source service. In this example, `bookbuyer` can communicate with bookstore. The equivalent Istio `AuthorizationPolicy` looks like this example:

```yml
apiVersion: security.istio.io/v1beta1
kind: AuthorizationPolicy
metadata:
  name: bookstore
  namespace: bookstore
spec:
  selector:
    matchLabels:
      app: bookstore
  action: ALLOW
  rules:
    - from:
        - source:
            serviceAccounts: ["bookbuyer/bookbuyer"]
```

In the Istio `AuthorizationPolicy`, the OSM TrafficTarget destination service maps to the policy namespace and selector label match. The source service maps to the `source.serviceAccounts` attribute under `rules.from`.

In addition to the source and destination configuration in the OSM TrafficTarget, OSM binds an HTTPRouteGroup to define the layer-7 authorization for the source. The following HTTPRouteGroup includes two `matches` for the allowed source service.

```yml
apiVersion: specs.smi-spec.io/v1alpha4
kind: HTTPRouteGroup
metadata:
  name: bookstore-service-routes
  namespace: bookstore
spec:
  matches:
    - name: books-bought
      pathRegex: /books-bought
      methods:
        - GET
      headers:
        - "user-agent": ".*-http-client/*.*"
        - "client-app": "bookbuyer"
    - name: buy-a-book
      pathRegex: ".*a-book.*new"
      methods:
        - GET
```

The `books-bought` match allows the source to access the `/books-bought` path by using the `GET` method with user-agent and client-app header information. The `buy-a-book` match uses a regular expression for a path containing `.*a-book.*new` with the `GET` method.

Define these OSM HTTPRouteGroup configurations in the rules section of the Istio `AuthorizationPolicy`. Keep source, operation, and header conditions in the same rule so they don't allow separate requests on their own. Istio `AuthorizationPolicy` string fields support exact, prefix, suffix, and presence matches, not arbitrary SMI regular expressions. The following sample uses exact paths and a Go HTTP client user-agent prefix that matches the Bookstore sample. For your workloads, translate each SMI `pathRegex` and header regex to an explicit Istio match that preserves your intended access.

```yml
apiVersion: "security.istio.io/v1beta1"
kind: "AuthorizationPolicy"
metadata:
  name: "bookstore"
  namespace: bookstore
spec:
  selector:
    matchLabels:
      app: bookstore
  action: ALLOW
  rules:
    - from:
        - source:
            serviceAccounts: ["bookbuyer/bookbuyer"]
      to:
        - operation:
            methods: ["GET"]
            paths: ["/books-bought"]
      when:
        - key: request.headers[user-agent]
          values: ["Go-http-client/*"]
        - key: request.headers[client-app]
          values: ["bookbuyer"]
    - from:
        - source:
            serviceAccounts: ["bookbuyer/bookbuyer"]
      to:
        - operation:
            methods: ["GET"]
            paths: ["/buy-a-book/new"]
```

Deploy the OSM migrated traffic-access-v1.yaml manifest as an Istio `AuthorizationPolicy`. There isn't an `AuthorizationPolicy` for bookthief, so the bookthief UI should stop incrementing books from bookstore v1:

```bash
kubectl apply -f - <<EOF
##################################################################################################
# bookstore policy
##################################################################################################
apiVersion: "security.istio.io/v1beta1"
kind: "AuthorizationPolicy"
metadata:
  name: "bookstore"
  namespace: bookstore
spec:
  selector:
    matchLabels:
      app: bookstore
  action: ALLOW
  rules:
    - from:
        - source:
            serviceAccounts: ["bookbuyer/bookbuyer"]
      to:
        - operation:
            methods: ["GET"]
            paths: ["/books-bought"]
      when:
        - key: request.headers[user-agent]
          values: ["Go-http-client/*"]
        - key: request.headers[client-app]
          values: ["bookbuyer"]
    - from:
        - source:
            serviceAccounts: ["bookbuyer/bookbuyer"]
      to:
        - operation:
            methods: ["GET"]
            paths: ["/buy-a-book/new"]
---
##################################################################################################
# bookwarehouse policy
##################################################################################################
apiVersion: security.istio.io/v1beta1
kind: AuthorizationPolicy
metadata:
  name: "bookwarehouse"
  namespace: bookwarehouse
spec:
  selector:
    matchLabels:
      app: bookwarehouse
  action: ALLOW
  rules:
    - from:
        - source:
            serviceAccounts: ["bookstore/bookstore"]
      to:
        - operation:
            methods: ["POST"]
---
##################################################################################################
# mysql policy
##################################################################################################
apiVersion: security.istio.io/v1beta1
kind: AuthorizationPolicy
metadata:
  name: "mysql"
  namespace: bookwarehouse
spec:
  selector:
    matchLabels:
      app: mysql
  action: ALLOW
  rules:
    - from:
        - source:
            serviceAccounts: ["bookwarehouse/bookwarehouse"]
      to:
         - operation:
            ports: ["3306"]
EOF
```

### Allow the Bookthief application to access Bookstore

No `AuthorizationPolicy` currently allows bookthief to communicate with bookstore. Deploy the following `AuthorizationPolicy` to allow bookthief to communicate with bookstore. Notice the added rule in the bookstore policy that allows bookthief access.

```bash
kubectl apply -f - <<EOF
##################################################################################################
# bookstore policy
##################################################################################################
apiVersion: "security.istio.io/v1beta1"
kind: "AuthorizationPolicy"
metadata:
  name: "bookstore"
  namespace: bookstore
spec:
  selector:
    matchLabels:
      app: bookstore
  action: ALLOW
  rules:
    - from:
        - source:
            serviceAccounts: ["bookbuyer/bookbuyer", "bookthief/bookthief"]
      to:
        - operation:
            methods: ["GET"]
            paths: ["/books-bought"]
      when:
        - key: request.headers[user-agent]
          values: ["Go-http-client/*"]
        - key: request.headers[client-app]
          values: ["bookbuyer"]
    - from:
        - source:
            serviceAccounts: ["bookbuyer/bookbuyer", "bookthief/bookthief"]
      to:
        - operation:
            methods: ["GET"]
            paths: ["/buy-a-book/new"]
---
##################################################################################################
# bookwarehouse policy
##################################################################################################
apiVersion: security.istio.io/v1beta1
kind: AuthorizationPolicy
metadata:
  name: "bookwarehouse"
  namespace: bookwarehouse
spec:
  selector:
    matchLabels:
      app: bookwarehouse
  action: ALLOW
  rules:
    - from:
        - source:
            serviceAccounts: ["bookstore/bookstore"]
      to:
        - operation:
            methods: ["POST"]
---
##################################################################################################
# mysql policy
##################################################################################################
apiVersion: security.istio.io/v1beta1
kind: AuthorizationPolicy
metadata:
  name: "mysql"
  namespace: bookwarehouse
spec:
  selector:
    matchLabels:
      app: mysql
  action: ALLOW
  rules:
    - from:
        - source:
            serviceAccounts: ["bookwarehouse/bookwarehouse"]
      to:
         - operation:
            ports: ["3306"]
EOF
```

The bookthief UI should now increment books from bookstore.

## Summary

This walk-through shows how to migrate OSM policies to Istio policies. To learn how to deploy and operate the managed Istio add-on on AKS, see [Install the Istio add-on](istio-deploy-addon.md). Review the upstream [Istio concepts](https://istio.io/latest/docs/concepts/) when you need background on Istio APIs and traffic management behavior.
