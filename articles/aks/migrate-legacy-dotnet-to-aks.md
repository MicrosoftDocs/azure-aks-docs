---
title: Migrating Legacy .NET / Windows Applications to AKS - A Step-by-Step Guide
description: A step-by-step guide for migrating legacy .NET Framework and Windows IIS applications to Azure Kubernetes Service (AKS), covering assessment, planning, and execution.
ms.topic: how-to
ms.service: azure-kubernetes-service
ms.date: 07/23/2026
author: schaffererin
ms.author: schaffererin
ms.custom: aks-migration
ms.collection: 
 - migration
# Customer intent: As a customer, I want to migrate my legacy .NET Framework / Windows IIS applications to AKS, so I can modernize my infrastructure and leverage Kubernetes for scalability and management.
---

# Migrating legacy .NET and Windows applications to Azure Kubernetes Service (AKS) – a step‑by‑step guide

This guide shows how to assess, plan, and execute a migration of legacy .NET Framework and Windows Internet Information Services (IIS) applications into Azure Kubernetes Service (AKS). It's focused on the two practical pathways available for most Microsoft shops:

- Containerize your existing .NET Framework (IIS) app and run it on Windows node pools in AKS.
- Refactor (or port) the app to .NET 8 and Linux containers to take advantage of smaller images, broader OSS tooling, and cheaper node types.

Along the way, you find a readiness checklist, Windows node pool configuration guidance, a worked example (VM → Windows container on AKS), and an Azure DevOps CI/CD pipeline template.

## Readiness assessment — .NET Framework and Windows application checklist

Before you begin, perform a focused readiness assessment. The goal is to identify blockers that affect whether you can containerize the app as-is on Windows or refactor it to Linux/.NET 8.

- IIS dependencies
  - Does the app require full IIS, including modules, ASP.NET integration, URL Rewrite rules, or ISAPI filters?
  - Does the app use custom IIS modules or native ISAPI extensions?
  - Can you move the configuration into `web.config` or embed it in the container image?

- Windows authentication and identity
  - Does the app rely on Windows Integrated Authentication (Kerberos or NTLM)?
  - Do you use Windows AD domain joins, machine accounts, or unconstrained delegation?
  - Consider: Windows authentication is easier to support in Windows containers with proper credential management, but containerized Windows apps can't be domain-joined the same way VMs are. Alternatives include [Windows Group Managed Service Accounts (GMSA)](./use-group-managed-service-accounts.md), Managed Identity, Microsoft Entra ID, or reverse-proxy patterns.

- Native code, COM interop, and 32-bit components
  - Does the app call COM objects or native DLLs tied to a specific Windows Server version or bitness?
    - If so, verify that those COM objects can run in a Windows Server Core container image (not every legacy driver or component is supported).

- Registry and local machine state
  - Does the application read or write machine-level registry keys or rely on local machine state (HKLM)?
  - Move machine-specific state into configuration or storage (Azure Files, Blob, or external DB).

- File system and session state
  - Does the app use file uploads, local temp files, or in-process session state?
  - Plan for externalizing state (Azure Cache for Redis, SQL, Blob storage, or shared SMB/Files).

- Networking and ports
  - What ports are required? Does the app open UDP sockets, use random ephemeral ports, or expect static IP?
  - Kubernetes services and load balancers change networking assumptions. Plan Service/Ingress and health probes accordingly.

- Dependencies on Windows-only services
  - Rethink print spooler, scheduled tasks (Task Scheduler), Windows services, or performance counters. You can sometimes package services into containers or re-architect them.

- Licensing and third-party constraints
  - Check any application licensing that ties to machine identity or hardware. Container-based licensing might require vendor coordination.

If many of the preceding items are blockers and hard to change (COM interop, heavy native dependencies, Windows authentication that you can't externalize), the Windows container pathway is more realistic. If you can move away from machine-level dependencies and the app primarily uses managed code, consider refactoring to .NET 8 on Linux for long-term maintainability and lower cost.

## Two migration pathways — decision guidance

### Path A — Containerize .NET Framework on Windows node pools (lift-and-shift)

- When to choose:
  - Heavy IIS usage, native COM dependencies, or limited budget or time for code rewrite.
  - You need minimal functional change and want to move off VMs quickly.

- Pros:
  - Least code change; preserves behavior of existing app.
  - Faster time to production compared to full refactor.

- Cons:
  - Windows container images are larger and have higher resource cost.
  - Some Azure and Kubernetes features have Windows limitations, such as some CSI drivers historically changing behavior on Windows.
  - Less ecosystem and portability compared to Linux containers.

### Path B — Refactor to .NET 8 and Linux node pools (modernize)

- When to choose:
  - App logic is primarily managed code and can be ported to .NET 8 with reasonable effort.
  - You want lower operating cost, smaller images, and broader tool support.

- Pros:
  - Smaller images, better density, faster startup, more community tooling and examples.
  - Easier to adopt sidecars, multi-arch images, and OSS ingress and observability stacks.

- Cons:
  - Requires developer time to port, test, and validate behavior (IIS features need replacement).
  - Some native Windows-only functionality needs redesign.

### Decision matrix (high level)

- If you must preserve IIS modules, Windows auth in-place, COM, or native dependencies, choose Windows containers.
- If the application is mostly managed code, or you want to modernize and optimize cost, port to .NET 8 and Linux containers.

## Azure Migrate: App Containerization — step‑by‑step for an ASP.NET app (target AKS)

Azure Migrate provides tooling for discovery and, in some flows, containerization assistance. The steps in the following section outline a practical flow: discover → produce container image → push to ACR → deploy to AKS.

1. Discover and inventory
   1. Run discovery on the VMs hosting your ASP.NET app (use Azure Migrate appliance or whatever inventory tool you have).
   1. Capture installed .NET version, IIS modules, native dependencies, registry keys read and written, and network ports.

1. Create a containerization plan
   1. Choose base image: For .NET Framework/ASP.NET use a Windows Server Core‑based ASP.NET base image (see Dockerfile example in the following section).
   1. Decide how to handle config: Move secrets to Azure Key Vault or Kubernetes Secrets, appSettings into environment variables or ConfigMaps.

1. Build a Windows container image (local proof)
   1. Create a Dockerfile that installs and configures IIS, copies your app, and exposes required ports (usually 80/443).
   1. Build and run locally (or on a Windows build agent) to verify application boots and serves pages.

1. Push to Azure Container Registry (ACR)
   1. Create ACR or reuse existing registry.
   1. Tag and push the image (`docker push`) from a Windows build host or Azure Pipelines with Windows build agents.

1. Prepare AKS cluster
   1. Create an AKS cluster with a Linux system node pool for control-plane workloads and ingress, and add a Windows node pool for your IIS app (see next section for node pool settings).
   1. Ensure network policies, policies for container images, and role-based access are configured.

1. Deploy manifests to AKS
   1. Create Kubernetes objects: Deployment (`nodeSelector: windows`), Service (`ClusterIP` or `LoadBalancer`), and any ConfigMaps or Secrets.
   1. Use a Linux-based ingress controller (nginx) running on Linux node pool to front Windows workloads, or expose with a `LoadBalancer` service.

1. Configure health probes and logging
   1. Configure liveness and readiness probes that hit an HTTP endpoint served by the app.
   1. Wire logs to Azure Monitor (Container insights) or a centralized logging solution.

1. Validate and cutover
   1. Run functional tests, performance tests, and validate session and behavior.
   1. Cutover traffic gradually (blue/green or canary) and monitor.

### Notes

- Building Windows container images requires a Windows build agent or runner. You can't build Windows images on Linux hosts.
- Ensure image OS version (Windows Server Core) matches or is compatible with the Windows node OS version in AKS.

## Worked example — migrate a legacy IIS/.NET Framework app from VM to AKS Windows container with Azure DevOps CI/CD

This worked example walks through moving a single IIS/.NET Framework 4.8 app hosted on a Windows Server VM to AKS using Windows containers. It demonstrates a Dockerfile, Kubernetes manifests, and a simple Azure DevOps pipeline.

Assumptions:
- You have an Azure subscription, AKS cluster with at least one Windows node pool, and an Azure Container Registry (ACR).
- You have an Azure DevOps project with a service connection to Azure and to the ACR (or the service connection can push to ACR).
- Your app runs on .NET Framework 4.8 and uses standard web.config.

1. Dockerfile for ASP.NET (.NET Framework 4.8) — Windows Server Core base

    ```dockerfile
    # Use an official ASP.NET image for .NET Framework on Windows Server Core
    FROM mcr.microsoft.com/dotnet/framework/aspnet:4.8-windowsservercore-ltsc2019
    
    # Optional: install additional Windows features or native dependencies here
    # RUN powershell -NoProfile -Command Install-WindowsFeature Web-Server, ...
    
    WORKDIR /inetpub/wwwroot
    
    # Remove default site files and copy your app
    RUN powershell -NoProfile -Command Remove-Item -Recurse -Force C:\inetpub\wwwroot\*
    COPY . C:\inetpub\wwwroot
    
    # Expose HTTP port
    EXPOSE 80
    
    # Default entry is IIS (already configured by base image)
    ```

    Notes:
   - Build this image on a Windows build agent (Azure DevOps self-hosted Windows agent or Microsoft-hosted windows-latest).
   - If your app depends on native installers or COM components, add RUN steps to install those during the image build.

1. Kubernetes manifests

    Deployment (windows-app-deployment.yml)

    ```yml
    apiVersion: apps/v1
    kind: Deployment
    metadata:
      name: legacy-iis-app
    spec:
      replicas: 2
      selector:
        matchLabels:
          app: legacy-iis-app
      template:
        metadata:
          labels:
            app: legacy-iis-app
        spec:
          nodeSelector:
            "kubernetes.io/os": windows
          containers:
          - name: legacy-iis-app
            image: <ACR_NAME>.azurecr.io/legacy-iis-app:$(TAG)
            ports:
            - containerPort: 80
            livenessProbe:
              httpGet:
                path: /healthz
                port: 80
              initialDelaySeconds: 30
              periodSeconds: 20
            readinessProbe:
              httpGet:
                path: /
                port: 80
              initialDelaySeconds: 10
              periodSeconds: 10
    ```

    Service (windows-app-service.yml)

    ```yml
    apiVersion: v1
    kind: Service
    metadata:
      name: legacy-iis-lb
    spec:
      type: LoadBalancer
      selector:
        app: legacy-iis-app
      ports:
      - protocol: TCP
        port: 80
        targetPort: 80
    ```

    Notes:
   - Alternatively, put a Linux-hosted ingress controller in front of this service (recommended for advanced routing, TLS, and WAF features). For a simple lift-and-shift, a LoadBalancer service will expose the app.

1. Azure DevOps pipeline (azure-pipelines.yml)

    ```yml
    trigger:
    - main
    
    variables:
      imageName: legacy-iis-app
      acrName: <ACR_NAME>
      kubernetesNamespace: default
      tag: $(Build.BuildId)
    
    pool:
      vmImage: 'windows-latest'
    
    steps:
    - task: Checkout@1
    
    - task: Docker@2
      displayName: Build and push Windows image to ACR
      inputs:
        containerRegistry: '<YourACRServiceConnection>' # service connection name
        repository: '$(acrName).azurecr.io/$(imageName)'
        command: buildAndPush
        Dockerfile: '**/Dockerfile'
        tags: |
          $(tag)
    
    - task: AzureCLI@2
      displayName: 'kubectl apply manifests'
      inputs:
        azureSubscription: '<YourAzureServiceConnection>'
        scriptType: bash
        scriptLocation: inlineScript
        inlineScript: |
          az aks get-credentials --resource-group <AKS_RESOURCE_GROUP> --name <AKS_CLUSTER_NAME> --overwrite-existing
          kubectl set image deployment/legacy-iis-app legacy-iis-app $(acrName).azurecr.io/$(imageName):$(tag) --namespace $(kubernetesNamespace) || kubectl apply -f k8s/
    ```

    Pipeline explanation:
   - Uses Windows host to build Windows container images.
   - Docker@2 buildAndPush requires a Docker host that can build Windows images — consider a self-hosted Windows agent if Microsoft-hosted doesn't support needed features.
   - The Azure CLI step authenticates to AKS and updates the deployment image (or applies manifests on first run).

1. AKS cluster and node pool creation (example CLI)
   -1. Create AKS cluster with Linux control plane and a Windows node pool (az cli example):

    ```azurecli-interactive
    # Create cluster with Linux node pool (default)
    az aks create \
       --resource-group my-rg \
       --name my-aks-cluster \
       --kubernetes-version <kubernetes-version> \
       --node-count 2 \
       --enable-managed-identity \
       --generate-ssh-keys
     
    # Add a Windows node pool
    az aks nodepool add \
       --resource-group my-rg \
       --cluster-name my-aks-cluster \
       --os-type Windows \
       --os-sku Windows2025 \
       --enable-fips-image \
       --name npwin \
       --node-count 2 \
       --node-vm-size Standard_D4s_v5 \
       --kubernetes-version <kubernetes-version>
    ```

    Notes:
   - Use AKS documentation for the exact az commands matching current Azure CLI and AKS versions.
   - Ensure the AKS Kubernetes version supports the Windows node pool version you select.

1. Deploy and validate
   1. Push the image; deploy manifests; wait for pods to be scheduled on Windows nodes.
   1. Validate using kubectl get pods -o wide to confirm the node OS and distribution.
   1. Run functional smoke tests and monitor logs via Azure Monitor.

## Common pitfalls and troubleshooting

- Building Windows images on Linux: you can't build Windows containers on Linux hosts — use Windows build agents.
- OS image mismatches: pods might fail to start with image errors if the container base image OS doesn't match the node OS version. Align LTSC2019 vs LTSC2022 across image and node.
- Unsupported CSI drivers or volume plugins: not all CSI drivers have Windows support. Verify persistent volume needs and driver compatibility.
- Health probes failing: IIS-based apps sometimes take longer to start; configure liveness/readiness probes with appropriate initialDelaySeconds and timeoutSeconds.
- Windows auth complexities: Integrated Windows Authentication often needs rework; consider fronting the app with a reverse proxy that handles auth, or move to Microsoft Entra ID authentication where possible.
- Firewall and NSG rules: ensure outbound/inbound rules and AKS network setup allows ACR pulls, Azure Monitor ingestion, and any backend dependencies.
- Logging and event collection: configure collection of Windows Event Logs and IIS logs; verify agent compatibility.

## When to re-architect rather than containerize

Containerizing preserves app behavior but doesn't automatically modernize the code base. Consider a refactor if:

- You want to adopt microservices, modern hosting patterns, or cross-platform compatibility.
- You need to reduce cost and improve density.
- The app requires heavy changes to function in containers (synchronous file system use, machine-level registry writes, etc.). At that point, invest in porting to .NET 8 and Linux where you gain more long-term flexibility.

## Next steps

- Run the readiness assessment on all candidate applications and classify them into "containerize on Windows", "refactor to .NET 8", or "decommission/replace".
- For quick wins, containerize least‑risky apps first and deploy them to a non‑production AKS cluster with a Windows node pool.
- For modernization, create a migration backlog to incrementally port functionality to .NET 8, design stateless services, and migrate state to managed services.
- Integrate CI/CD and DevOps practices (IaC for AKS cluster and node pools, pipeline builds for Windows images).
- Consult the AKS Windows node guidance and ASP.NET containerization docs:
   - [AKS documentation](/azure/aks)
   - [ASP.NET container guidance](/aspnet/core/host-and-deploy/docker)

This guide is intended as a practical roadmap for migrating legacy .NET/Windows applications to AKS. For large or highly stateful applications, plan for iterative migration with thorough testing, and consider engaging a migration partner if you have specialized COM/native dependencies or complex Windows auth requirements.
