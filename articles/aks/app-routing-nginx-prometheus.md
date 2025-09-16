---
title: Monitor the ingress-nginx controller metrics in the application routing add-on with Prometheus
description: Configure Prometheus to scrape the ingress-nginx controller metrics.
ms.service: azure-kubernetes-service
ms.subservice: aks-networking
ms.custom:
author: sabbour
ms.topic: how-to
ms.date: 09/15/2025
ms.author: asabbour
# Customer intent: As a Kubernetes operator, I want to configure Prometheus to scrape ingress-nginx controller metrics, so that I can monitor and analyze the performance and usage of my applications effectively.
---

# Monitor the ingress-nginx controller metrics in the application routing add-on with Prometheus and Grafana

The ingress-nginx controller in the application routing add-on exposes many metrics for requests, the nginx process, and the controller that can be helpful in analyzing the performance and usage of your application.

The application routing add-on exposes the Prometheus metrics endpoint at `/metrics` on port 10254 and a private Service `nginx-metrics`.

## Prerequisites

- An Azure Kubernetes Service (AKS) cluster with the [application routing add-on enabled][app-routing].
- A Prometheus instance, such as Azure Monitor managed service for Prometheus.

## Validating the metrics endpoint

To validate the metrics are being collected, you can set up a port forward from a local port to port 10254 on the `nginx-metrics` service.

```bash
kubectl port-forward -n app-routing-system service/nginx-metrics :10254
```

```bash 
Forwarding from 127.0.0.1:43307 -> 10254
Forwarding from [::1]:43307 -> 10254
```

Note the local port (`43307` in this case) and open http://localhost:43307/metrics in your browser. You should see the ingress-nginx controller metrics loading.

![Screenshot of the Prometheus metrics in the browser.](./media/app-routing/prometheus-metrics.png)

You can now terminate the `port-forward` process to close the forwarding.

## Configuring Azure Monitor managed service for Prometheus

Azure Monitor managed service for Prometheus is a fully managed Prometheus-compatible service that supports industry standard features such as PromQL, Grafana dashboards, and Prometheus alerts. This service requires configuring the metrics addon for the Azure Monitor agent, which sends data to Prometheus. If your cluster isn't configured with the add-on, you can follow this article to configure your Azure Kubernetes Service (AKS) cluster to send data to Azure Monitor managed service for Prometheus.

### Enable Service Monitor based scraping

Once your cluster is updated with the Azure Monitor agent, you need to configure the agent to enable scraping the metrics endpoint. You can [create a Pod or a Service Monitor](/azure/azure-monitor/containers/prometheus-metrics-scrape-crd) to accomplish this.

The following creates a Service Monitor scrape metrics from the ingress-nginx controller deployed by the application routing add-on.

```bash
kubectl apply -f - <<EOF
apiVersion: azmonitoring.coreos.com/v1
kind: ServiceMonitor
metadata:
  name: nginx-monitor
  namespace: app-routing-system
spec:
  labelLimit: 63
  labelNameLengthLimit: 511
  labelValueLengthLimit: 1023
  selector:
    matchLabels:
      app.kubernetes.io/component: ingress-controller
      app.kubernetes.io/managed-by: aks-app-routing-operator
      app.kubernetes.io/name: nginx
  endpoints:
  - port: prometheus
EOF
```

In a few minutes, the `ama-metrics` pods in the `kube-system` namespace should restart and pick up the new configuration.

## Review visualization of metrics in Azure Managed Grafana

Now that you have Azure Monitor managed service for Prometheus and Azure Managed Grafana configured, you should [access your Managed Grafana instance][access-grafana].

There are two [official ingress-nginx dashboards](https://github.com/kubernetes/ingress-nginx/tree/main/deploy/grafana/dashboards) dashboards that you can download and import into your Grafana instance:

- Ingress-nginx controller dashboard
- Request handling performance dashboard

### Ingress-nginx controller dashboard

This dashboard gives you visibility of request volume, connections, success rates, config reloads and configs out of sync. You can also use it to view the network IO pressure, memory and CPU use of the ingress controller. Finally, it also shows the P50, P95, and P99 percentile response times of your ingresses and their throughput.

You can download this dashboard from [GitHub][grafana-nginx-dashboard].

![Screenshot of a browser showing the ingress-nginx dashboard on Grafana.](media/app-routing/grafana-dashboard.png)

### Request handling performance dashboard

This dashboard gives you visibility into the request handling performance of the different ingress upstream destinations, which are your applications' endpoints that the ingress controller is forwarding traffic to. It shows the P50, P95 and P99 percentile of total request and upstream response times. You can also view aggregates of request errors and latency. Use this dashboard to review and improve the performance and scalability of your applications.

You can download this dashboard from [GitHub][grafana-nginx-request-performance-dashboard].

![Screenshot of a browser showing the ingress-nginx request handling performance dashboard on Grafana.](media/app-routing/grafana-dashboard-2.png)

### Importing a dashboard

To import a Grafana dashboard, expand the left menu and click on **Import** under Dashboards.

![Screenshot of a browser showing the Grafana instance with Import dashboard highlighted.](media/app-routing/grafana-import.png)

Then upload the desired dashboard file and click on **Load**.

![Screenshot of a browser showing the Grafana instance import dashboard dialog.](media/app-routing/grafana-import-json.png)
## Next steps

- You can configure scaling your workloads using ingress metrics scraped with Prometheus using [Kubernetes Event Driven Autoscaler (KEDA)][KEDA]. Learn more about [integrating KEDA with AKS][keda-prometheus].
- Create and run a load test with [Azure Load Testing][azure-load-testing] to test workload performance and optimize the scalability of your applications.

<!-- LINKS - internal -->
[az-aks-create]: /cli/azure/aks#az-aks-create
[app-routing]: /azure/aks/app-routing
[managed-prometheus]: /azure/azure-monitor/essentials/prometheus-metrics-overview
[managed-prometheus-configure]: /azure/azure-monitor/essentials/prometheus-metrics-enable?tabs=cli
[managed-prometheus-custom-annotations]: /azure/azure-monitor/essentials/prometheus-metrics-scrape-configuration#pod-annotation-based-scraping
[managed-grafana]: /azure/managed-grafana/overview
[create-grafana]: /azure/managed-grafana/quickstart-managed-grafana-portal
[access-grafana]: /azure/managed-grafana/quickstart-managed-grafana-portal#access-your-managed-grafana-instance
[keda]: /azure/aks/keda-about
[keda-prometheus]: /azure/azure-monitor/essentials/integrate-keda#scalers
[azure-load-testing]: /azure/load-testing/quickstart-create-and-run-load-test
[az-aks-show]: /cli/azure/aks#az-aks-show
[az-aks-enable-addons]: /cli/azure/aks#az-aks-enable-addons
[az-aks-disable-addons]: /cli/azure/aks#az-aks-disable-addons
[az-aks-install-cli]: /cli/azure/aks#az-aks-install-cli
[az-aks-get-credentials]: /cli/azure/aks#az-aks-get-credentials
[az-extension-add]: /cli/azure/extension#az-extension-add
[az-extension-update]: /cli/azure/extension#az-extension-update
[install-azure-cli]: /cli/azure/install-azure-cli
[az-keyvault-create]: /cli/azure/keyvault#az_keyvault_create
[az-keyvault-certificate-import]: /cli/azure/keyvault/certificate#az_keyvault_certificate_import
[az-keyvault-certificate-show]: /cli/azure/keyvault/certificate#az_keyvault_certificate_show
[az-network-dns-zone-create]: /cli/azure/network/dns/zone#az_network_dns_zone_create
[az-network-dns-zone-show]: /cli/azure/network/dns/zone#az_network_dns_zone_show
[az-role-assignment-create]: /cli/azure/role/assignment#az_role_assignment_create
[az-aks-addon-update]: /cli/azure/aks/addon#az_aks_addon_update
[az-keyvault-set-policy]: /cli/azure/keyvault#az_keyvault_set_policy

<!-- LINKS - external -->
[osm-release]: https://github.com/openservicemesh/osm/releases/
[nginx]: https://kubernetes.github.io/ingress-nginx/
[external-dns]: https://github.com/kubernetes-incubator/external-dns
[kubectl]: https://kubernetes.io/docs/reference/kubectl/
[kubectl-apply]: https://kubernetes.io/docs/reference/generated/kubectl/kubectl-commands#apply
[grafana-nginx-dashboard]: https://raw.githubusercontent.com/kubernetes/ingress-nginx/main/deploy/grafana/dashboards/nginx.json
[grafana-nginx-request-performance-dashboard]: https://raw.githubusercontent.com/kubernetes/ingress-nginx/main/deploy/grafana/dashboards/request-handling-performance.json

