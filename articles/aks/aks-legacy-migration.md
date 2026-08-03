---
title: Migrate Legacy Applications to Azure Kubernetes Service (AKS)
description: This guide provides a four-phase framework for assessing and migrating legacy applications to Azure Kubernetes Service (AKS), including practical migration pathways, Windows and .NET Framework specifics, operational checks, and a FAQ.
ms.topic: how-to
ms.date: 07/15/2026
ms.author: schaffererin
author: schaffererin
ms.service: azure-kubernetes-service
ai-usage: ai-assisted
# Customer intent: "As a customer, I want to migrate my legacy applications to Azure Kubernetes Service (AKS) so that I can modernize my workloads and take advantage of cloud-native features."
---

# Migrate legacy applications to AKS

This page is a focused guide for assessing and migrating legacy applications to Azure Kubernetes Service (AKS). It covers a four‑phase readiness framework, pragmatic migration pathways (refactor, replatform, lift‑and‑shift), Windows and .NET Framework specifics, operational checks, and a compact FAQ that answers the common stumbling blocks you’ll hit when bringing legacy workloads into AKS.

Note: this article owns the legacy migration narrative for AKS. It does not reproduce the step‑by‑step cluster provisioning, CI/CD, or detailed Azure Migrate tutorials already available elsewhere — see the AKS migration overview (aks-migration) and Azure Migrate App Containerization tutorials for hands‑on steps and tooling. Add a prominent cross‑link from those pages to this legacy migration guide so teams with legacy .NET or IIS workloads find the single, focused surface they need.

## 1. Legacy application assessment — a four‑phase framework

Before you move any workload, run a disciplined assessment. Use a four‑phase framework to convert ad‑hoc decisions into a repeatable plan.

### Phase 1 — Dependency mapping and readiness scoring

Goal: discover what the application requires at runtime and produce a containerization readiness score.

- Run automated discovery tools (for example, Azure Migrate App Containerization) to generate a baseline readiness report and suggested Dockerfile/manifests where possible.
- Map service‑to‑service and external dependencies:
  - Downstream databases, message buses, legacy file shares, SMTP, AD/LDAP, on‑prem APIs, hardware devices.
  - Network requirements (static IPs, VIPs, reserved ports).
  - OS and kernel dependencies (Windows API, native drivers, kernel modules).
- Create a simple readiness score per service (0–10) using criteria:
  - Statelessness (stateless = higher readiness).
  - External dependency complexity (high complexity = lower readiness).
  - Secrets handling (uses in‑process secrets vs. external secret store).
  - Windows or native dependencies (reduces readiness for Linux containers).
- Capture any blocking items that must be resolved prior to containerization: e.g., COM+ components, hardware dongles, required desktop UI.

Deliverable: dependency map + readiness scorecard for each service and an ordered migration backlog.

### Phase 2 — Workload classification: refactor, replatform, or lift‑and‑shift

Goal: pick the right migration pathway for each service.

Decision guide:

- Refactor (containerize and modernize):
  - Best for stateless services with clean APIs, small code changes, no Windows‑only dependencies.
  - Candidate when you can move to .NET (Core/.NET 6/7/8) or modern Java runtimes.
  - Recommended target: Linux node pools on AKS; consider AKS Automatic for managed operations.
- Replatform (containerize with some architectural changes or 3rd‑party replacement):
  - Candidate when services have manageable external dependencies (e.g., can be moved to managed DBs, replaced with a cloud service, or run behind sidecar adapters).
  - Use Azure Migrate App Containerization to produce container artifacts and then validate.
- Lift‑and‑shift (minimal code change, run on Windows in AKS):
  - Best for IIS, .NET Framework (3.5/4.x), COM interop, and Windows Authentication workloads that are costly to rework.
  - Use AKS Windows node pools to run Windows containers with minimal changes.

Classify each service and add an expected migration effort estimate (days/weeks) and rollback strategy.

### Phase 3 — Windows‑specific readiness checks

If the service targets Windows, validate these specifics:

- IIS and app pool identity:
  - Does the app depend on a certain AppPool identity or impersonation? Plan for gMSA or managed identities.
- .NET Framework compatibility:
  - .NET Framework 3.5 and 4.x run on Windows Server images in Windows containers. If you can move to .NET 6/7/8, prefer Linux containers, but Windows containers are supported for legacy Framework apps.
- COM / COM+ / native interop:
  - Many COM and COM+ components cannot be containerized cleanly. Options: re‑implement, wrap as a Windows service in a VM and expose a network API, or containerize when the component works in the Windows ServerCore image (validate carefully).
- Windows Authentication (Kerberos/NTLM):
  - Plan for gMSA (group Managed Service Account) or Active Directory integration for Kerberos constrained delegation scenarios. Some workloads require VM/AD footprints to preserve legacy behavior.
- File system and profile expectations:
  - Apps that depend on per‑machine registry keys, local services, or desktop‑session artifacts may need refactoring.

Deliverable: Windows compatibility checklist per workload and a decision to refactor or run on Windows node pools.

### Phase 4 — Compliance and security baseline

Before running production traffic on AKS, define and enforce a security baseline.

- Image provenance:
  - Enforce signed images and image scanning. Establish an ACR (Azure Container Registry) policy for allowed registries and image tags.
- Azure Policy for AKS baseline:
  - Use Azure Policy guest and Kubernetes policies to enforce namespaces, resource limits, allowed container registries, and disallowed privilege escalation.
- Secrets management:
  - Replace file or config‑based secrets with Azure Key Vault or sealed secrets. Ensure RBAC and network controls protect secret stores.
- Registry distribution and availability:
  - Use ACR geo‑replication for multi‑region distribution and redundancy if you deploy across regions.
- Attestation & supply chain:
  - Adopt image signing and attestation flows (e.g., Notation/Sigstore patterns) where required by compliance.

Deliverable: an enforceable policy set and CI gating criteria (image scan pass, signature present, manifest validated).

## 2. Legacy migration pathways — practical patterns

Choose a pathway per service based on your classification. Often you’ll use more than one pattern in the same application (“strangler fig” + some Windows lift‑and‑shift pieces).

### Pathway 1 — Strangler fig with Application Gateway for Containers

Use when you want incremental migration without wholesale cutovers.

- Approach:
  - Deploy new containerized services into AKS.
  - Use Application Gateway (or Application Gateway for Containers / ingress controller) as a routing facade in front of both legacy hosts and AKS.
  - Move traffic incrementally by URL path, host header, or feature flag header.
  - When traffic fully flows to AKS for a given path, decommission the legacy host.
- Benefits:
  - Minimal blast radius; easy rollback by routing back to legacy host.
  - Good for bounded contexts where you can move one route or API at a time.
- Considerations:
  - Session affinity and sticky sessions — use redis session store or convert to stateless sessions before migration.
  - TLS termination and certificate management across both sides.

Recommended when you have a monolith with clear module boundaries or a web tier that can be routed by path.

### Pathway 2 — Lift‑and‑shift with Windows node pools

Use when refactoring cost is prohibitive and the app requires Windows.

- How it works:
  - Add a Windows node pool to your AKS cluster:

    ```azurecli-interactive
    az aks nodepool add \
      --resource-group $RESOURCE_GROUP \
      --cluster-name $CLUSTER_NAME \
      --name winnp \
      --os-type Windows \
      --node-count 2 \
      --node-vm-size Standard_D4s_v3
    ```

    - Deploy Windows containers with a node selector:

    ```yaml
    spec:
      nodeSelector:
        "kubernetes.io/os": windows
    ```

  - Use official base images such as:
    - mcr.microsoft.com/dotnet/framework/aspnet (ASP.NET on .NET Framework)
    - mcr.microsoft.com/windows/servercore/iis (IIS server)
  - Azure CNI is required for Windows node pools in AKS (plan subnet sizing accordingly).
- When to choose:
  - IIS‑hosted apps, .NET Framework with heavy Windows API usage, or apps relying on Windows Authentication and COM interop.
- Limitations:
  - Windows containers have different resource characteristics and image sizes (larger).
  - Some Kubernetes features and add‑ons may have Windows differences; validate your observability and system tooling.
- Supportability:
  - Windows Server 2019/2022 images support .NET Framework 3.5 and 4.x on AKS node images. Validate the specific patch and image versions for your runtime.

### Pathway 3 — Phased refactoring with AKS Automatic

When you can modernize but want to reduce operational burden.

- AKS Automatic (managed node provisioning and scaling) can simplify cluster lifecycle tasks so your team focuses on the app.
- Approach:
  - Extract bounded contexts into containers one service at a time.
  - Use the strangler fig routing layer to manage traffic.
  - Let AKS Automatic handle node provisioning, autoscaling, OS patching, and upgrades where appropriate.
- Benefits:
  - Reduced cluster ops workload; ideal when adopting cloud‑native best practices alongside modernization.
- Considerations:
  - Requires investment in CI/CD and image promotion to prevent operational drift.

## 3. Windows and .NET Framework workload migration — practical checklist

This section consolidates the Azure‑specific commands and practical checks for Windows workloads in AKS.

### Add a Windows node pool (example)

Use the Azure CLI snippet (customize resource names):

```azurecli-interactive
az aks nodepool add \
  --resource-group $RESOURCE_GROUP \
  --cluster-name $CLUSTER_NAME \
  --name winnp \
  --os-type Windows \
  --node-count 2 \
  --node-vm-size Standard_D4s_v3
```

Notes:

- Windows node pools require Azure CNI networking. Plan the subnet IP capacity before adding pools.
- You can create mixed OS clusters (Linux + Windows pools) and gate Windows pods using nodeSelector or nodeAffinity.

### Deploy Windows containers

Example pod selector (YAML fragment):

```yml
spec:
  nodeSelector:
    "kubernetes.io/os": windows
  containers:
  - name: legacy-iis
    image: mcr.microsoft.com/windows/servercore/iis:windowsservercore-ltsc2022
    ports:
    - containerPort: 80
```

- Base images:
  - mcr.microsoft.com/dotnet/framework/aspnet for ASP.NET apps on .NET Framework
  - mcr.microsoft.com/windows/servercore/iis for generic IIS workloads
- Networking:
  - Use Azure CNI; ensure subnet sizing is adequate and that network policies are validated.

### Windows Authentication and gMSA

To enable gMSA on your AKS cluster:

```azurecli-interactive
az aks update \
  --resource-group $RESOURCE_GROUP \
  --name $CLUSTER_NAME \
  --enable-windows-gmsa
```

High level steps:

- Prepare a gMSA credential in Active Directory.
- Create Kubernetes resources (CredentialSpec) that reference the gMSA account.
- Reference the credential spec in the pod spec.

If the app relies on Kerberos constrained delegation or NTLM, validate end‑to‑end with a test account and AD integration before migrating production traffic.

### .NET modernization path

- If the app can be upgraded to .NET (Core/.NET 6/7/8), prefer Linux containers for smaller images and better ecosystem support.
- Use the ASP.NET containerization tutorial to plan porting from .NET Framework to .NET Core/.NET 6+.
- For apps that cannot be modernized quickly, use the Windows lift‑and‑shift path and plan a parallel modernization backlog.

## 4. Legacy migration FAQ (quick answers)

Q: Can I run IIS in containers on AKS? A: Yes. Use Windows node pools and the IIS base image. Azure Migrate App Containerization can generate a Dockerfile and Kubernetes manifests for many IIS apps, reducing manual steps. For Windows Authentication scenarios, configure gMSA.

Q: Can I containerize COM+ or COM interop components? A: Typically no — COM+ and deep native interop are often incompatible with container patterns. Options:

- Reimplement or wrap as a networked service (REST/gRPC) hosted in a VM or refactored as a .NET service.
- If the COM component functions inside the ServerCore image and has no kernel/hardware dependencies, you may be able to test a Windows container, but expect compatibility risk.

Q: How do I enable Kerberos/NTLM (Windows Authentication) for pods? A: Enable gMSA on the cluster (see az aks update --enable-windows-gmsa), create gMSA credential specs in AD, and reference them in pod specs. Validate ticket forwarding and SPNs end‑to‑end.

Q: ImagePullBackOff from ACR — common causes and fixes

- Ensure the cluster identity (managed identity or service principal) has the AcrPull role assignment on the target ACR.
- Confirm ACR URI and image tag are correct and that ACR and cluster have network connectivity (VNet rules, private endpoints).
- If using private endpoints, make sure DNS resolution for the registry from the cluster resolves correctly.

Q: Azure CNI IP exhaustion after adding Windows node pools

- Windows nodes require more reserved IPs per node; plan subnet size accordingly.
- Mitigations:
  - Pre‑size the subnet with enough IPs before adding Windows node pools.
  - Use a lower --max-pods setting when creating node pools to reduce pod IPs per node:

    ```azurecli-interactive
    az aks nodepool add ... --max-pods 20
    ```

  - Evaluate Azure CNI overlay or alternative networking only where supported.

Q: How should I handle secrets in migrated apps?

- Replace file‑based secrets and in‑image config with Azure Key Vault or Kubernetes Secret backed by a Key Vault provider.
- Enforce secrets access with Azure RBAC and Kubernetes RBAC; use least privilege.

Q: What about ACR geo‑replication and content trust?

- Use ACR geo‑replication to push images closer to regional clusters and reduce cold pulls.
- Adopt image signing and supply‑chain attestation (e.g., Sigstore/Notation or other solutions) and enforce provenance with Azure Policy where compliance requires it.

## Migration checklist (practical next steps)

1. Run automated discovery (Azure Migrate App Containerization) and generate readiness reports.
1. Build a dependency map and score each service for containerization readiness.
1. Classify each service (refactor, replatform, lift‑and‑shift) and prioritize the backlog.
1. For Windows workloads:
   - Run Windows compatibility checklist (IIS, .NET Framework version, COM, gMSA).
   - Plan Azure CNI subnet sizing.
   - Add a Windows node pool in a test cluster and validate end‑to‑end behavior.
1. Define security baseline:
   - ACR policies, image scanning, image signing, Azure Policy for AKS.
   - Secrets migration plan (Key Vault).
1. Choose a migration pathway and run a pilot with low‑risk traffic:
   - Strangler fig with Application Gateway for Containers for progressive cutover.
   - Validate performance, logging, and observability (App Insights, Prometheus, Fluentd).
1. Iterate: move the next bounded context, decommission legacy components, and keep a rollback plan.
