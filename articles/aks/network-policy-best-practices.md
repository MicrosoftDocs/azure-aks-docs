---
title: Network security best practices for Azure Kubernetes Service (AKS)
description: Learn how to plan network policies, service exposure, ingress security, and API server access for a production Azure Kubernetes Service (AKS) cluster.
author: schaffererin
ms.topic: best-practice
ms.date: 08/25/2026
ms.author: schaffererin
ms.service: azure-kubernetes-service
ms.custom: aeo-round-2
ms.subservice: aks-networking
# Customer intent: As a Kubernetes administrator, I want to plan network security for a production Azure Kubernetes Service (AKS) cluster, including network policies and service exposure, so that I can minimize unauthorized access and protect workloads and management endpoints.
---

# Network security best practices for Azure Kubernetes Service (AKS)

Kubernetes, by default, operates as a flat network where all pods can communicate freely with each other. This unrestricted connectivity can be convenient for developers but poses significant security risks as applications scale. Imagine an organization deploying multiple microservices, each handling sensitive data, customer transactions, or backend operations. Without any restrictions, any compromised pod could access unauthorized data or disrupt services.

Production network security requires controls for both workload communication and endpoint exposure. Use [Kubernetes network policies](https://kubernetes.io/docs/concepts/services-networking/network-policies/) to restrict traffic between workloads, choose the least-exposed Kubernetes Service type that meets each application's requirements, and limit access to the Kubernetes API server.

## Plan service and cluster exposure

Start with private access and add public exposure only when the workload requires it. Network policies complement, but don't replace, Kubernetes Services, ingress controls, web application firewalls (WAFs), or API server access controls.

Use the following guidance when you plan a production AKS cluster:

| Network surface | Recommended approach | Security considerations |
|-----------------|----------------------|-------------------------|
| Services used only inside the cluster | Use a [`ClusterIP` Service](concepts-network-services.md#clusterip), which is the default Service type. | Apply ingress and egress network policies so that only authorized pods and namespaces can reach the Service's backing pods. |
| Services used from a private network | Use an [internal `LoadBalancer` Service](internal-lb.md) or an internal ingress controller. | The private IP limits access to networks that have connectivity to the virtual network. Also restrict source networks with network security groups, firewalls, and network policies. |
| Public non-HTTP or non-HTTPS services | Use a public `LoadBalancer` Service only when direct external access is required. | Restrict allowed source IP ranges, expose only required ports, and avoid using `NodePort` as a direct production exposure mechanism. |
| Public HTTP or HTTPS applications | Place services behind an [ingress controller](concepts-network-ingress.md) or Gateway API implementation instead of assigning a public IP to every Service. | Centralize TLS termination, routing, authentication, and public IP management. Configure backend Services as `ClusterIP` when direct external access isn't required. |
| Internet-facing web applications and APIs | Put an [Azure WAF](/azure/web-application-firewall/overview) in front of the ingress layer, such as with [Azure Application Gateway for Containers](/azure/application-gateway/for-containers/overview). | Use managed and custom WAF rules to help protect against common web exploits. Restrict direct access to the ingress origin so clients can't bypass the WAF. |
| Kubernetes API server | Prefer a [private AKS cluster](private-clusters.md) when administrators and automation can connect through a private network. | A private cluster keeps API server traffic on a private endpoint. Plan DNS, VPN, ExpressRoute, peering, or a secured management host for administrative access. |
| Public Kubernetes API server | If a public endpoint is required, configure [API server authorized IP ranges](api-server-authorized-ip-ranges.md) and use Microsoft Entra ID with least-privilege RBAC. | Allow only known management and automation source ranges. Don't leave the API server open to all source IP addresses. Consider [API Server VNet Integration](api-server-vnet-integration.md) when the design requires private network connectivity or changing public access after cluster creation. |

Inventory every inbound path before deployment and document whether it must be cluster-internal, private to connected networks, or public. Avoid parallel public paths that bypass the approved ingress and WAF layer. Reserve public IP addresses for endpoints with a documented internet-access requirement, and periodically review public `LoadBalancer`, ingress, and API server endpoints for continued need.

## What is a Kubernetes network policy?

A Kubernetes network policy is a set of rules that controls how pods communicate with each other and with external services. It provides fine-grained control over network traffic, allowing administrators to enforce security and segmentation at the namespace level.
By implementing network policies, you gain:

- **Stronger security posture**: Prevent unauthorized lateral movement within the cluster.
- **Compliance and governance**: Enforce regulatory requirements by controlling communication pathways.
- **Reduced blast radius**: Limit the impact of a compromised workload by restricting its network access.

Network policies initially operated at Layer 3 (IP) and Layer 4 (TCP/UDP) of the OSI model, enabling basic control over pod-to-pod and external communications. Advanced network policy engines such as Cilium extend policy enforcement to Layer 7 (application layer), allowing deeper control over application traffic for modern cloud-native applications.

Network policies are namespace-scoped, which means each policy applies to workloads within a specific namespace. The main components of a network policy include:

- **Pod selector**: Defines which pods the policy applies to based on labels.
- **Ingress rules**: Specify the allowed incoming connections.
- **Egress rules**: Specify the allowed outgoing connections.
- **Policy types**: Define whether the policy applies to ingress (incoming), egress (outgoing), or both.

## Foundations of building effective network policies

Effective network policies require understanding your application architecture, traffic patterns, and security requirements before writing configurations.

### Understanding your workload connectivity

Before implementing network policies, you need visibility into how workloads communicate with each other and external services. This step ensures that policies don’t inadvertently block critical traffic while effectively limiting unnecessary exposure.

- **Use visibility tools**: In addition to the network requirements provided by the application team, use tools such as [Cilium Hubble](https://github.com/cilium/hubble) and [Retina](https://retina.sh/) to analyze pod-to-pod traffic, identify which services must communicate, and define their ingress and egress dependencies. For example, a frontend might need to reach a backend API, but it shouldn't communicate directly with a database.

- **Use labels in network policies**: Traditionally, network security policies rely on static IP addresses to define traffic rules. This approach is problematic in Kubernetes because pods are ephemeral - created and destroyed frequently, often with dynamically assigned IP addresses. Maintaining security rules based on constantly changing IPs requires continuous updates, making policy management inefficient and error-prone.

Labels solve this challenge by providing a stable way to group workloads. Instead of relying on fixed IPs, Kubernetes network policies use labels to define security rules that remain consistent even as pods restart or shift across nodes. For example, a policy can allow communication between pods labeled `app: frontend` and `app: backend`, ensuring traffic flows as intended regardless of pod IP changes. This label-based approach is critical for achieving scalable, intent-driven network security in cloud-native environments.

A well-defined labeling strategy simplifies policy management, reduces misconfigurations, and enhances security enforcement across clusters.

- **Define microsegmentation**: Organizing workloads into security zones, such as frontend, backend, and database zones, helps enforce the principle of least privilege. For example, isolate microservices that handle customer transactions from general-purpose applications.

### Layered security approach for Kubernetes

Relying solely on basic Kubernetes network policies might not be sufficient for all security needs. A layered approach ensures comprehensive protection across different levels of network communication.

- **L3/L4 policies**: Control traffic based on pod labels and namespaces at the IP, port, and protocol level.
- **FQDN-based policies**: Restrict egress traffic to specific external domains, ensuring workloads can only reach approved external services (for example: only allowing access to *microsoft.com* for API calls).
- **Layer 7 policies**: Filter requests based on HTTP methods, headers, and paths to secure APIs and enforce application-layer security policies.

### Manage network policies

The teams that manage network policies depend on the organization's structure and security requirements. A balanced approach allows security teams and application developers to collaborate effectively.

- **Centralized security administration**: Security or networking teams should define baseline policies to enforce global security requirements, such as default deny-all rules or compliance-driven restrictions.
- **Developer autonomy with guardrails**: Application teams should be able to define service-specific network policies within their namespaces, enabling security while maintaining agility.
- **Policy lifecycle management**: Regularly reviewing and updating policies ensures that security remains aligned with evolving application architectures. Observability tools can help detect policy misconfigurations and missing rules.

#### Example: Secure a multi-tier web application with network policies

**Step 1: Understand workload connectivity**

Use Cilium Hubble to observe how pods communicate.

:::image type="content" source="./media/advanced-container-networking-services/hubble-ui.png" alt-text="Screenshot of the Hubble UI showing how the application's microservices are communicating with each other.":::

Map the required connectivity:

|Source	 | Destination |	Protocol | Port |
|--------|-------------|----------|------|
|Frontend| Backend     |	TCP | 8080 |
|Backend | Database    |	TCP | 5432 |
|Backend | External Payment Gateway   |	TCP | 443 |

**Step 2: Apply labels for policy enforcement**

By labeling workloads correctly, policies can remain stable even if pod IPs change.

- `app: frontend` for UI pods.
- `app: backend` for API pods.
- `app: database` for DB pods.

**Step 3: Implement application-level network policies**

This example uses two layers of network policies: L3/L4 policies to control traffic between microservices and a fully qualified domain name (FQDN) policy to control egress traffic to an external payment gateway.

##### Allow frontend traffic to the backend

Apply egress and ingress policies so that frontend pods can reach backend pods only on TCP port 8080.

```yaml
apiVersion: networking.k8s.io/v1
kind: NetworkPolicy
metadata:
  name: frontend-egress
  namespace: default
spec:
  podSelector:
    matchLabels:
      app: frontend
  policyTypes:
    - Egress
  egress:
    - to:
        - podSelector:
            matchLabels:
              app: backend
      ports:
        - protocol: TCP
          port: 8080
---
apiVersion: networking.k8s.io/v1
kind: NetworkPolicy
metadata:
  name: backend-ingress
  namespace: default
spec:
  podSelector:
    matchLabels:
      app: backend
  policyTypes:
    - Ingress
  ingress:
    - from:
        - podSelector:
            matchLabels:
              app: frontend
      ports:
        - protocol: TCP
          port: 8080
```

##### Allow backend traffic to the database

Apply egress and ingress policies so that backend pods can reach database pods only on TCP port 5432.

```yaml
apiVersion: networking.k8s.io/v1
kind: NetworkPolicy
metadata:
  name: backend-egress
  namespace: default
spec:
  podSelector:
    matchLabels:
      app: backend
  policyTypes:
    - Egress
  egress:
    - to:
        - podSelector:
            matchLabels:
              app: database
      ports:
        - protocol: TCP
          port: 5432
---
apiVersion: networking.k8s.io/v1
kind: NetworkPolicy
metadata:
  name: database-ingress
  namespace: default
spec:
  podSelector:
    matchLabels:
      app: database
  policyTypes:
    - Ingress
  ingress:
    - from:
        - podSelector:
            matchLabels:
              app: backend
      ports:
        - protocol: TCP
          port: 5432
```

##### Allow backend traffic to an external payment API

Apply a Cilium network policy so that backend pods can resolve and connect to `payments.example.com` only on TCP port 443.

```yaml
apiVersion: cilium.io/v2
kind: CiliumNetworkPolicy
metadata:
  name: backend-payment-api
  namespace: default
spec:
  endpointSelector:
    matchLabels:
      app: backend
  egress:
    - toEndpoints:
        - matchLabels:
            "k8s:io.kubernetes.pod.namespace": kube-system
            "k8s:k8s-app": kube-dns
      toPorts:
        - ports:
            - port: "53"
              protocol: ANY
          rules:
            dns:
              - matchName: payments.example.com
    - toFQDNs:
        - matchName: payments.example.com
      toPorts:
        - ports:
            - port: "443"
              protocol: TCP
```

**Step 4: Manage and maintain policies**

The following table summarizes the policy layers that teams should enforce across clusters.

| Policy layer | Responsibility | Example control |
|--------------|----------------|-----------------|
| Baseline | Deny traffic that isn't explicitly allowed. | Default deny ingress and egress. |
| Platform | Allow access to required shared services. | Allow DNS and logging traffic. |
| Security | Block known threats and enforce organizational requirements. | Block known malicious IP addresses and domains. |

Ensure that application network policies comply with the baseline, platform, and security requirements while allowing the required workload communication.

## Azure CNI powered by Cilium

[Azure Container Network Interface (CNI) powered by Cilium](/azure/aks/azure-cni-powered-by-cilium) uses eBPF (extended Berkeley Packet Filter) to provide high-performance networking, observability, and security for Kubernetes workloads. Unlike traditional CNIs that rely on iptables-based packet filtering, Azure CNI powered by Cilium uses eBPF to operate at the kernel level, enabling efficient and scalable network policy enforcement. Cilium is the recommended network policy engine for Linux workloads on Azure Kubernetes Service (AKS). For more information about the other supported engines and their platform support, see [Network policy options in AKS](/azure/aks/use-network-policies#network-policy-options-in-aks).
Azure Kubernetes Service integrates Cilium as a managed component, simplifying network security enforcement. Administrators can define `CiliumNetworkPolicy` resources directly within their AKS clusters without requiring external controllers.

Cilium identities extend label-based policy enforcement. Large clusters with high pod churn might encounter scalability problems because nodes must constantly update IP filters. Cilium identities map to labels and allow connections to start as soon as the identity resolves, without waiting for filter updates on each node.

With Azure CNI powered by Cilium, you don't need to install a separate network policy engine such as Azure Network Policy Manager or Calico.

### Create an AKS cluster with Azure CNI powered by Cilium

The following example creates an AKS cluster with Azure CNI Overlay powered by Cilium. The `--network-plugin-mode overlay` option configures Azure CNI Overlay networking, `--pod-cidr 192.168.0.0/16` assigns the pod IP address range, and `--network-dataplane cilium` selects Cilium as the data plane. Cluster creation options and address values can differ for other AKS networking configurations. Use values appropriate for your networking configuration.

```bash
az aks create \
  --name <clusterName> \
  --resource-group <resourceGroupName> \
  --location <location> \
  --network-plugin azure \
  --network-plugin-mode overlay \
  --pod-cidr 192.168.0.0/16 \
  --network-dataplane cilium \
  --generate-ssh-keys
```

## Cilium network policy resources and components

With Azure CNI powered by Cilium, you can configure network policies natively in Kubernetes using two available formats:

- **The standard `NetworkPolicy` resource**, which supports L3 and L4 policies at ingress or egress of the pod.
- **The extended `CiliumNetworkPolicy` format**, which is available as a CustomResourceDefinition that supports specification of policies at Layers 3-7 for both ingress and egress.

Use these custom resource definitions (CRDs) to define security policies. Kubernetes automatically distributes the policies to all nodes in the cluster.

A network policy consists of several key components:

- **Pod selector**: Specifies which pods the policy applies to using labels.
- **Policy types**: Determines whether the policy applies to ingress (incoming traffic), egress (outgoing traffic), or both.
- **Ingress rules**: Defines allowed sources (pods, namespaces, or IP ranges) and ports.
- **Egress rules**: Defines allowed destinations and ports.

    ```yaml
    apiVersion: networking.k8s.io/v1
    kind: NetworkPolicy
    metadata:
      name: frontend-egress
      namespace: default
    spec:
      podSelector:
        matchLabels:
          app: frontend
      policyTypes:
        - Egress
      egress:
        - to:
            - podSelector:
                matchLabels:
                  app: backend
          ports:
            - protocol: TCP
              port: 8080
    ```

## Advanced network policies with ACNS

Azure Kubernetes Service offers [Advanced Container Networking Services (ACNS)](/azure/aks/advanced-container-networking-services-overview?tabs=cilium), a suite of services designed to enhance the networking capabilities of AKS clusters.

A key feature of ACNS is Container Network Security, which offers advanced security capabilities to safeguard containerized workloads. These capabilities include fully qualified domain name (FQDN) filtering and Layer 7 (L7) policies for granular control over egress traffic and application-layer communication.

Container Network Security is a paid offering for Linux node pools that requires Azure CNI powered by Cilium and Kubernetes version 1.29 or later. For pricing details, see [Advanced Container Networking Services pricing](https://azure.microsoft.com/pricing/details/advanced-container-networking-services/).

### Secure egress traffic with FQDN filtering
Traditionally, Kubernetes network policies are based on IP addresses. In dynamic environments where pod IPs frequently change, these policies can be difficult to manage. [FQDN filtering](/azure/aks/container-network-security-concepts#overview-of-fqdn-filtering) lets you define policies with domain names instead of IP addresses, which simplifies traffic control.

FQDN filtering requires an AKS cluster that uses Azure CNI powered by Cilium, runs Kubernetes version 1.29 or later, and has ACNS enabled. Configure a `CiliumNetworkPolicy` to define the domains that selected pods can access.

To enable Advanced Container Networking Services (ACNS) in Azure Kubernetes Service (AKS), use the `--enable-acns` flag.

#### Example: Enable Advanced Container Networking Services on an existing cluster

```azurecli-interactive
az aks update \
  --resource-group $RESOURCE_GROUP \
  --name $CLUSTER_NAME \
  --enable-acns
```

This command enables ACNS, including FQDN filtering, on an existing cluster that uses the Cilium data plane.

#### Example: Build a network policy that allows traffic to `bing.com` and its subdomains

The following policy allows selected pods to resolve and connect to `bing.com` and its subdomains. The `dns` rules permit name resolution, and the `toFQDNs` rules permit egress connections to the resolved addresses.

```yaml
apiVersion: "cilium.io/v2"
kind: CiliumNetworkPolicy
metadata:
  name: "allow-bing-fqdn"
spec:
  endpointSelector:
    matchLabels:
      app: demo-container
  egress:
    - toEndpoints:
        - matchLabels:
            "k8s:io.kubernetes.pod.namespace": kube-system
            "k8s:k8s-app": kube-dns
      toPorts:
        - ports:
            - port: "53"
              protocol: ANY
          rules:
            dns:
              - matchName: "bing.com"
              - matchPattern: "*.bing.com"
    - toFQDNs:
        - matchName: "bing.com"
        - matchPattern: "*.bing.com"
```

### Protection and security for APIs with L7 policies

Layer 7 (L7) policies in AKS use `CiliumNetworkPolicy` resources to filter application traffic by attributes such as HTTP methods and paths, gRPC paths, and Kafka topics. They require ACNS on an AKS cluster that uses Azure CNI powered by Cilium. Standard network policies control traffic at Layer 3 (IP) and Layer 4 (TCP/UDP) but don't inspect these application-level attributes.

Layer 7 (L7) policies provide the following benefits and features:

- **Granular API security**: Enforce policies based on HTTP, gRPC, or Kafka request data, rather than just IP addresses and ports.
- **Reduced attack surface**: Prevent unauthorized access and mitigate API-based attacks by filtering traffic at the application layer.
- **Compliance and auditing**: Ensure adherence to security standards by logging and controlling specific API interactions.
- **Simplified policy management**: Avoid the operational burden of additional sidecar proxies by leveraging built-in Cilium-powered L7 controls.

L7 policies support HTTP, HTTPS, gRPC, and Kafka protocols.

#### Example: Enable ACNS and L7 policies on an existing cluster

```azurecli-interactive
az aks update \
  --resource-group $RESOURCE_GROUP \
  --name $CLUSTER_NAME \
  --enable-acns \
  --acns-advanced-networkpolicies L7
```

This command enables ACNS and L7 policy enforcement on the existing cluster. Setting `--acns-advanced-networkpolicies` to `L7` also enables FQDN filtering.

#### Example: Allow only GET requests to /api from the frontend pod to the backend service on port 8080

The following policy permits selected frontend pods to send only `GET` requests to `/api` on TCP port 8080 of the selected backend endpoints.

```yaml
apiVersion: "cilium.io/v2"
kind: CiliumNetworkPolicy
metadata:
  name: frontend-l7-policy
  namespace: default
spec:
  endpointSelector:
    matchLabels:
      app: frontend
  egress:
    - toEndpoints:
        - matchLabels:
            app: backend
      toPorts:
        - ports:
            - port: "8080"
              protocol: TCP
          rules:
            http:
              - method: "GET"
                path: "/api"
```

## Network policy strategies for AKS workloads

The following strategies help enforce least-privilege traffic rules across AKS workloads.

### Adopt a Zero Trust model

By default, Kubernetes allows unrestricted communication between all pods in a cluster. A Zero Trust approach requires you to deny traffic by default and explicitly allow required communication paths. A default deny-all network policy ensures that only necessary traffic flows between workloads.

Example of a deny-all policy:

> [!IMPORTANT]
> A default-deny egress policy also blocks DNS traffic. Before you apply this policy, define an egress policy that allows access to the DNS service used by your cluster. The required destination depends on your cluster DNS configuration, including whether the cluster uses [LocalDNS](/azure/aks/localdns-custom).

```yaml
apiVersion: networking.k8s.io/v1
kind: NetworkPolicy
metadata:
  name: default-deny
  namespace: default
spec:
  podSelector: {}
  policyTypes:
    - Ingress
    - Egress
```
### Namespace and multi-tenancy segmentation

In multi-tenant environments, namespaces help isolate workloads. Different teams typically manage their applications within dedicated namespaces, ensuring logical isolation between workloads. This separation is critical when multiple applications run alongside each other. Applying network policies at the namespace scope is often the first step in securing workloads, as it prevents unrestricted lateral movement between applications managed by different teams.

For example, restrict all ingress traffic to a namespace, allowing only traffic from the same namespace:

```yaml
apiVersion: networking.k8s.io/v1
kind: NetworkPolicy
metadata:
  name: restrict-cross-namespace
  namespace: team-a
spec:
  podSelector: {}
  policyTypes:
    - Ingress
  ingress:
    - from:
        - namespaceSelector:
            matchLabels:
              kubernetes.io/metadata.name: team-a
```
### Microsegmentation for workload isolation

While namespace-based segmentation is an essential first step in securing multi-tenant Kubernetes clusters, application-level microsegmentation provides fine-grained control over how workloads interact within a namespace. Namespace isolation alone does not prevent unintended or unauthorized communication between different applications within the same namespace. This is where pod-level segmentation becomes critical.

For instance, if a frontend service should only talk to a backend service within the same namespace, a policy using pod labels can enforce this restriction:

```yaml
apiVersion: networking.k8s.io/v1
kind: NetworkPolicy
metadata:
  name: frontend-to-backend
  namespace: team-a
spec:
  podSelector:
    matchLabels:
      app: frontend
  policyTypes:
    - Egress
  egress:
    - to:
        - podSelector:
            matchLabels:
              app: backend
      ports:
        - protocol: TCP
          port: 8080
```
This prevents frontend pods from making unintended connections to other services, reducing the risk of unauthorized access or lateral movement inside the namespace.

By combining namespace-wide isolation with fine-grained application-level policies, teams can implement a multi-layered security model that prevents unauthorized traffic while allowing necessary communication for application functionality.

### Layered security approach

Network security should be implemented in layers, combining multiple levels of enforcement:

- **L3/L4 policies**: Restrict traffic at the IP and port level (for example: allow TCP traffic on port 443).
- **FQDN-based filtering**: Restrict external communication based on domain names rather than IP addresses.
- **L7 policies**: Control communication based on application-layer attributes (for example: allow only HTTP GET requests to specific API paths).

For example, a Cilium L7 policy can restrict frontend services to only issue GET requests to the backend API:

```yaml
apiVersion: "cilium.io/v2"
kind: CiliumNetworkPolicy
metadata:
  name: frontend-l7-policy
  namespace: default
spec:
  endpointSelector:
    matchLabels:
      app: frontend
  egress:
    - toEndpoints:
        - matchLabels:
            app: backend
      toPorts:
        - ports:
            - port: "8080"
              protocol: TCP
          rules:
            http:
              - method: "GET"
                path: "/api"
```
This prevents the frontend from making POST or DELETE requests, limiting the attack surface.

### Integrate RBAC with network policy management

Role-based access control (RBAC) plays a crucial role in ensuring that only authorized users or teams can create, modify, or delete network policies. Without proper access controls, a misconfigured policy could either expose workloads to unauthorized access or unintentionally block critical application traffic.

By leveraging Kubernetes RBAC in conjunction with network policies, organizations can enforce separation of duties between platform administrators, security teams, and application developers. A typical approach is:

- Define baseline security policies through platform or security teams to enforce compliance and restrict external access.
- Grant application teams limited permissions to create or update network policies only for their respective namespaces.

For example, the following RBAC policy allows developers to create and modify network policies but only within their assigned namespace:

```yaml
apiVersion: rbac.authorization.k8s.io/v1
kind: Role
metadata:
  name: network-policy-editor
  namespace: team-a
rules:
  - apiGroups: ["networking.k8s.io"]
    resources: ["networkpolicies"]
    verbs: ["get", "list", "create", "update", "delete"]
```

Bind this role to a specific team by using a `RoleBinding`:

```yaml
apiVersion: rbac.authorization.k8s.io/v1
kind: RoleBinding
metadata:
  name: team-a-network-policy-binding
  namespace: team-a
subjects:
  - kind: User
    name: developer@example.com
    apiGroup: rbac.authorization.k8s.io
roleRef:
  kind: Role
  name: network-policy-editor
  apiGroup: rbac.authorization.k8s.io
```
By restricting network policy modifications to designated teams and namespaces, organizations can prevent accidental misconfigurations or unauthorized changes while still allowing flexibility for developers to implement application-specific security policies.

This approach reinforces the principle of least privilege while ensuring that network segmentation strategies remain consistent, secure, and aligned with organizational policies.

## Legacy and third-party solutions

### Azure Network Policy Manager (NPM)
Azure Network Policy Manager (NPM) is a legacy solution for enforcing Kubernetes network policies on AKS.

> [!IMPORTANT]
> Support for NPM on Windows nodes ends on September 30, 2026. Support for NPM on Linux nodes ends on September 30, 2028. After these dates, NPM is no longer supported on the corresponding operating system. For more information, see [Network policy options in AKS](/azure/aks/use-network-policies#network-policy-options-in-aks).

For Linux nodes, Microsoft recommends transitioning from NPM to Cilium, which provides better performance, scalability, and enhanced security through eBPF-based enforcement. For migration guidance, see [Upgrade from Azure Network Policy Manager to Cilium](/azure/aks/migrate-from-npm-to-cilium-network-policy).

### `NetworkPolicy` support for Windows nodes
Azure CNI powered by Cilium supports Linux nodes only. For Windows workloads, AKS supports Calico, which is integrated into AKS to simplify deployment. You can enable it using the `--network-policy calico` flag when creating a cluster. NPM also supports Windows nodes until September 30, 2026, but new subscriptions can no longer register the feature flag required to enable it.

### Calico open source: third-party solution
Calico open source is a third-party solution for enforcing Kubernetes network policies on Linux and Windows nodes. Tigera maintains the Calico project and images. Microsoft support is limited to ensuring that Calico integrates with AKS and functions as expected within the platform. Direct upstream bugs, feature requests, and troubleshooting beyond AKS integration to the Calico open-source community or Tigera.

For Linux nodes, Microsoft recommends using Cilium for network policy enforcement. For Windows nodes, Microsoft recommends using Calico.


## Conclusion 

Network policies are a fundamental part of Kubernetes security, enabling organizations to control traffic flow, enforce workload isolation, and reduce the attack surface. As cloud-native environments evolve, relying solely on basic Layer 3/4 policies is no longer sufficient. Advanced solutions, such as Layer 7 filtering and FQDN-based policies, provide the granular security and flexibility needed to protect modern applications.

By following practices such as a Zero Trust model and microsegmentation, and by adopting Azure CNI powered by Cilium, teams can enhance security while maintaining operational efficiency. Modern, observability-driven approaches help secure workloads as Kubernetes networking evolves.