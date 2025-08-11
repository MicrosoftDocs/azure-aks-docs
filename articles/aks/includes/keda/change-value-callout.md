---
author: qpetraroia, wangamanda
ms.service: azure-kubernetes-service
ms.topic: include
ms.date: 06/04/2025
ms.author: qpetraroia
# Customer intent: "As a Kubernetes operator, I want to be informed about the limitations of the KEDA add-on for AKS regarding CPU requests and limits, so that I can effectively manage resource allocation without running into issues."
---

> [!IMPORTANT]
> The KEDA add-on for AKS doesn't currently support modifying the CPU requests or limits and other Helm values for the [Metrics Server](https://keda.sh/docs/2.14/operate/metrics-server/) or [Operator](https://keda.sh/docs/2.14/operate/cluster/). Keep this limitation in mind when using the add-on. If you have any questions, feel free to reach out [here](https://github.com/Azure/AKS/issues).