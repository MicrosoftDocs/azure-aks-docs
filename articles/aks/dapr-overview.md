---
title: Dapr extension for Azure Kubernetes Service (AKS) and Arc-enabled Kubernetes
description: Learn more about using Dapr on your Azure Kubernetes Service (AKS) cluster to develop applications.
author: davidsmatlak
ms.author: davidsmatlak
ms.topic: overview
ms.date: 03/06/2025
# Customer intent: "As a developer using Azure Kubernetes Service, I want to easily provision Dapr on my cluster, so that I can build resilient microservices without managing complex setup and dependencies."
---

# Dapr extension for Azure Kubernetes Service (AKS) and Arc-enabled Kubernetes

[Distributed Application Runtime (Dapr)][dapr-docs] offers APIs that help you write and implement simple, portable, resilient, and secured microservices. Dapr APIs run as a sidecar process in tandem with your applications and abstract away common complexities you may encounter when building distributed applications, such as:
- Service discovery
- Message broker integration
- Encryption
- Observability
- Secret management 

Dapr is incrementally adoptable. You can use any of the API building blocks as needed. [Learn the support level Microsoft offers for the Dapr extension.](#issue-handling)

## Capabilities and features

[Using the Dapr extension to provision Dapr on your AKS or Arc-enabled Kubernetes cluster][dapr-create-extension] eliminates the overhead of:
- Downloading Dapr tooling
- Manually installing and managing the Dapr runtime on your AKS cluster

[You can install, deploy, and configure the Dapr extension on your cluster using either the Azure CLI or a Bicep template.](./dapr.md) 

Additionally, the extension offers support for all [native Dapr configuration capabilities][dapr-configuration-options] through simple command-line arguments.

Dapr provides the following set of capabilities to help with your microservice development on AKS:

- Easy provisioning of Dapr on AKS through [cluster extensions][cluster-extensions]
- Portability enabled through HTTP and gRPC APIs which abstract underlying technologies choices
- Reliable, secure, and resilient service-to-service calls through HTTP and gRPC APIs
- Publish and subscribe messaging made easy with support for CloudEvent filtering and "at-least-once" semantics for message delivery
- Pluggable observability and monitoring through Open Telemetry API collector
- Independent of language, while also offering language specific software development kits (SDKs)
- Integration with Visual Studio Code through the Dapr extension
- [More APIs for solving distributed application challenges][dapr-blocks]

## Issue handling

Microsoft categorizes issues raised against the Dapr extension into two parts: 
- Extension operations
- Dapr runtime (including APIs and components)

The following table breaks down support priority levels for each of these categories.

|   | Description | Security risks/Regressions | Functional issues |
| - | ----------- | -------------------------- | ----------------- |
| **Extension operations** | Issues encountered during extension operations, such as installing/uninstalling or upgrading the Dapr extension. | Microsoft prioritizes for immediate resolution. | Microsoft investigates and addresses as needed. | 
| **Dapr runtime** | Issues encountered when using the Dapr runtime, APIs, and components via the extension, like cert expiration and unexpected component behavior. | [Work with the Dapr open source project](https://github.com/dapr/dapr/issues/new/choose) to resolve in a hotfix or future Dapr open source release. Once fixes are released in Dapr open source, they are then made available in the Dapr extension. Known open source security risks and regressions won't be investigated by Microsoft at this time. | [Discuss issues with the Dapr open source project](https://github.com/dapr/dapr/issues/new/choose) to resolve in a hotfix or future Dapr open source release. Known open source functional issues won't be investigated by Microsoft at this time. |

### Clouds/regions

Global Azure cloud is supported with AKS and Arc support on the following regions:

| Region | AKS support | Arc for Kubernetes support |
| ------ | ----------- | -------------------------- |
| `australiaeast` | :heavy_check_mark: | :heavy_check_mark: |
| `australiasoutheast` | :heavy_check_mark: | :x: |
| `brazilsouth` | :heavy_check_mark: | :x: |
| `canadacentral` | :heavy_check_mark: | :heavy_check_mark: |
| `canadaeast` | :heavy_check_mark: | :heavy_check_mark: |
| `centralindia` | :heavy_check_mark: | :heavy_check_mark: |
| `centralus` | :heavy_check_mark: | :heavy_check_mark: |
| `eastasia` | :heavy_check_mark: | :heavy_check_mark: |
| `eastus` | :heavy_check_mark: | :heavy_check_mark: |
| `eastus2` | :heavy_check_mark: | :heavy_check_mark: |
| `eastus2euap` | :x: | :heavy_check_mark: |
| `francecentral` | :heavy_check_mark: | :heavy_check_mark: |
| `francesouth` | :heavy_check_mark: | :x: |
| `germanywestcentral` | :heavy_check_mark: | :heavy_check_mark: |
| `japaneast` | :heavy_check_mark: | :heavy_check_mark: |
| `japanwest` | :heavy_check_mark: | :x: |
| `koreacentral` | :heavy_check_mark: | :heavy_check_mark: |
| `koreasouth` | :heavy_check_mark: | :x: |
| `northcentralus` | :heavy_check_mark: | :heavy_check_mark: |
| `northeurope` | :heavy_check_mark: | :heavy_check_mark: |
| `norwayeast` | :heavy_check_mark: | :x: |
| `southafricanorth` | :heavy_check_mark: | :x: |
| `southcentralus` | :heavy_check_mark: | :heavy_check_mark: |
| `southeastasia` | :heavy_check_mark: | :heavy_check_mark: |
| `southindia` | :heavy_check_mark: | :x: |
| `swedencentral` | :heavy_check_mark: | :heavy_check_mark: |
| `switzerlandnorth` | :heavy_check_mark: | :heavy_check_mark: |
| `uaenorth` | :heavy_check_mark: | :x: |
| `uksouth` | :heavy_check_mark: | :heavy_check_mark: |
| `ukwest` | :heavy_check_mark: | :x: |
| `westcentralus` | :heavy_check_mark: | :heavy_check_mark: |
| `westeurope` | :heavy_check_mark: | :heavy_check_mark: |
| `westus` | :heavy_check_mark: | :heavy_check_mark: |
| `westus2` | :heavy_check_mark: | :heavy_check_mark: |
| `westus3` | :heavy_check_mark: | :heavy_check_mark: |

## Frequently asked questions

### How do Dapr and Service meshes compare?

While Dapr and service meshes do offer some overlapping capabilities, a service mesh is focused on networking concerns, whereas Dapr is focused on providing building blocks that make building applications as microservices easier. Dapr is developer-centric, while service meshes are infrastructure-centric.  

Some common capabilities that Dapr shares with service meshes include:

- Secure service-to-service communication with mTLS encryption
- Service-to-service metric collection
- Service-to-service distributed tracing
- Resiliency through retries

Dapr provides other application-level building blocks for state management, pub/sub messaging, actors, and more. However, Dapr doesn't provide capabilities for traffic behavior, such as routing or traffic splitting. If your solution would benefit from the traffic splitting a service mesh provides, consider using [Open Service Mesh][osm-docs].  

For more information on Dapr and service meshes, and how they can be used together, visit the [Dapr documentation][dapr-docs].

### How does the Dapr secrets API compare to the Secrets Store CSI driver?

Both the Dapr secrets API and the managed Secrets Store CSI driver allow for the integration of secrets held in an external store, abstracting secret store technology from application code. 

The Secrets Store CSI driver mounts secrets held in Azure Key Vault as a CSI volume for consumption by an application. 

Dapr exposes secrets via a RESTful API that can be:
- Called by application code
- Configured with assorted secret stores 

The following table lists the capabilities of each offering:

| | Dapr secrets API | Secrets Store CSI driver |
| --- | --- | ---|
| **Supported secrets stores** | Local environment variables (for Development); Local file (for Development); Kubernetes Secrets; AWS Secrets Manager; Azure Key Vault secret store; Azure Key Vault with Managed Identities on Kubernetes; GCP Secret Manager; HashiCorp Vault | Azure Key Vault secret store|
| **Accessing secrets in application code** | Call the Dapr secrets API | Access the mounted volume or sync mounted content as a Kubernetes secret and set an environment variable |
| **Secret rotation** | New API calls obtain the updated secrets | Polls for secrets and updates the mount at a configurable interval |
| **Logging and metrics** | The Dapr sidecar generates logs, which can be configured with collectors such as Azure Monitor, emits metrics via Prometheus, and exposes an HTTP endpoint for health checks | Emits driver and Azure Key Vault provider metrics via Prometheus |

For more information on the secret management in Dapr, see the [secrets management overview][dapr-secrets].

For more information on the Secrets Store CSI driver and Azure Key Vault provider, see the [Secrets Store CSI driver overview][csi-secrets-store].

### How does the managed Dapr cluster extension compare to the open source Dapr offering?

The managed Dapr cluster extension is the easiest method to provision Dapr on an AKS cluster. With the extension, you're able to offload management of the Dapr runtime version by opting into automatic upgrades. Additionally, the extension installs Dapr with smart defaults (for example, provisioning the Dapr control plane in high availability mode).

When installing Dapr open source via helm or the Dapr CLI, developers and cluster maintainers are also responsible for runtime versions and configuration options.  

Lastly, the Dapr extension is an extension of AKS, therefore you can expect the same support policy as other AKS features.

[Learn more about migrating from Dapr open source to the Dapr extension for AKS][dapr-migration].

<a name='how-can-i-authenticate-dapr-components-with-azure-ad-using-managed-identities'></a>

### How can I authenticate Dapr components with Microsoft Entra ID using managed identities?

- Learn how [Dapr components authenticate with Microsoft Entra ID][dapr-msi].
- Learn about [using managed identities with AKS][aks-msi].

### How can I switch to using the Dapr extension if I've already installed Dapr via a method, such as Helm?

Recommended guidance is to completely uninstall Dapr from the AKS cluster and reinstall it via the cluster extension. [You can also check for the existing Dapr installation and migrate it to AKS.](./dapr-migration.md)

If you install Dapr through the AKS extension, our recommendation is to continue using the extension for future management of Dapr instead of the Dapr CLI. Combining the two tools can cause conflicts and result in undesired behavior.

## Next Steps

> [!div class="nextstepaction"]
> [Walk through the Dapr extension quickstart to demo how it works][dapr-quickstart]


<!-- Links Internal -->
[csi-secrets-store]: ./csi-secrets-store-driver.md
[osm-docs]: ./open-service-mesh-about.md
[cluster-extensions]: ./cluster-extensions.md
[dapr-quickstart]: ./quickstart-dapr.md
[dapr-migration]: ./dapr-migration.md
[aks-msi]: ./use-managed-identity.md
[dapr-configuration-options]: ./dapr-settings.md
[dapr-create-extension]: ./dapr.md

<!-- Links External -->
[dapr-docs]: https://docs.dapr.io/
[dapr-blocks]: https://docs.dapr.io/concepts/building-blocks-concept/
[dapr-msi]: https://docs.dapr.io/developing-applications/integrations/azure/azure-authentication
[dapr-pubsub]: https://docs.dapr.io/developing-applications/building-blocks/pubsub/pubsub-overview
[dapr-statemgmt]: https://docs.dapr.io/developing-applications/building-blocks/state-management/state-management-overview/
[dapr-serviceinvo]: https://docs.dapr.io/developing-applications/building-blocks/service-invocation/service-invocation-overview/
[dapr-bindings]: https://docs.dapr.io/developing-applications/building-blocks/bindings/bindings-overview/
[dapr-actors]: https://docs.dapr.io/developing-applications/building-blocks/actors/actors-overview/
[dapr-secrets]: https://docs.dapr.io/developing-applications/building-blocks/secrets/secrets-overview/
[dapr-config]: https://docs.dapr.io/developing-applications/building-blocks/configuration/
[dapr-distlock]: https://docs.dapr.io/developing-applications/building-blocks/distributed-lock/
[dapr-crypto]: https://docs.dapr.io/developing-applications/building-blocks/cryptography/
[dapr-subscriptions]: https://docs.dapr.io/developing-applications/building-blocks/pubsub/subscription-methods/#declarative-subscriptions
[dapr-supported-version]: https://docs.dapr.io/operations/support/support-release-policy/
[dapr-observability]: https://docs.dapr.io/operations/observability/
[dapr-alpha-beta]: https://docs.dapr.io/operations/support/alpha-beta-apis/
