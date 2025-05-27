---
author: qpetraroia
ms.service: azure-kubernetes-service
ms.topic: include
ms.date: 03/13/2025
ms.author: qpetraroia
# Customer intent: "As a Kubernetes operator, I want to be informed about the limitations of the KEDA add-on for AKS regarding CPU requests and limits, so that I can effectively manage resource allocation without running into issues."
---

> [!IMPORTANT]
> The KEDA add-on for AKS doesn't currently support modifying the CPU requests or limits for the Metrics Server or Operator. Keep this limitation in mind when using the add-on. If you have any questions, feel free to reach out [here](https://github.com/Azure/AKS/issues).