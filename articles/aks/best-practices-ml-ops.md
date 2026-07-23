---
title: Machine Learning Operations (MLOps) Best Practices in Azure Kubernetes Service (AKS)
description: Learn MLOps best practices for AI and machine learning workflows on Azure Kubernetes Service (AKS), including guidance for AKS Automatic and AKS Standard.
ms.topic: best-practice
ms.service: azure-kubernetes-service
ms.custom: aks-ai-ml
ms.date: 07/22/2026
author: schaffererin
ms.author: schaffererin
# Customer intent: As a machine learning engineer, I want to implement MLOps best practices in my AI workflows on Kubernetes, so that I can ensure consistent, scalable, and secure deployment and management of machine learning models.
---

# Machine learning operations (MLOps) best practices in Azure Kubernetes Service (AKS)

**Applies to**: :heavy_check_mark: AKS Automatic :heavy_check_mark: AKS Standard

MLOps is a set of practices for deploying, monitoring, and managing machine learning models in production environments.

> **Key MLOps best practices covered in this article**:
>
> - Infrastructure as Code (IaC)
> - Containerization
> - Model management and versioning
> - Automation
> - Scalability and resource management
> - Security and compliance

This article describes best practices and considerations to keep in mind when using MLOps in AKS. For more information on MLOps, see [Machine learning operations (MLOps) for AI and machine learning workflows](./concepts-machine-learning-ops.md).

## Choose your AKS mode for MLOps

AKS supports two cluster modes: [**AKS Automatic**](./intro-aks-automatic.md) and **AKS Standard**. Choose AKS Automatic when you want a production-ready baseline with less day-2 platform management. Choose AKS Standard when you need deeper control over cluster infrastructure and platform configuration.

The MLOps practices in this article apply to both modes. However, implementation responsibility differs by mode: AKS Automatic provides more preconfigured defaults, while AKS Standard typically requires more explicit platform configuration and lifecycle ownership.

| Area | AKS Automatic | AKS Standard |
| --- | --- | --- |
| Baseline cluster setup | Preconfigured node pools, networking, and monitoring out-of-the-box | Requires manual configuration of node pools, CNI, and observability stack |
| System node pool operations | Automatic node provisioning and scaling managed by the service | Operator must configure node pool sizing, scaling rules, and maintenance windows |
| Security baseline controls | Network policies, pod security standards, and workload identity enabled by default | Operators must explicitly enable and configure network policies, pod security, and identity settings |
| Networking baseline | Preconfigured Azure CNI Overlay with default ingress patterns | Full flexibility to choose CNI plugin, configure custom ingress controllers, and define network topology |
| Operations and upgrades | Automatic node image and Kubernetes version upgrades | Operators schedule and manage upgrade timing and rollout strategy |
| MLOps implementation focus | Validate, govern, and tune defaults | Design and configure platform controls |
| GPU capacity and scheduling | Eligible GPU capacity can be provisioned automatically from workload resource requests and scheduling constraints, subject to regional SKU availability and subscription quota | Operators create and manage GPU node pools, labels, taints, autoscaler limits, drivers, and device plugin configuration |
| Distributed training | Default Kubernetes scheduling and automatic node provisioning provide a starting point; training operators, gang schedulers, and topology tuning remain workload-level choices | Operators explicitly install training operators and schedulers and design GPU node pools, networking, scaling, and placement for distributed jobs |

## Infrastructure as code (IaC)

**Key takeaway**: Define and version IaC templates for each stage of your AI pipeline to ensure consistency, cost-effectiveness, and faster deployments.

IaC enables consistent and reproducible infrastructure provisioning and management for a range of application types. With different application deployments, your IaC implementation might change throughout the AI pipeline, as the compute power and resources needed for inferencing, serving, training, and fine-tuning models can vary. Defining and versioning IaC templates for your AI developer teams can help ensure consistency and cost-effectiveness across job types while clarifying hardware requirements and accelerating the deployment process.

In AKS Automatic, IaC can focus more on workload definitions, policy guardrails, and environment consistency over platform defaults. In AKS Standard, IaC commonly includes more explicit cluster platform settings such as networking, scaling, and operational configuration choices.

## Containerization

**Key takeaway**: Package model weights, metadata, and configurations in container images to enable portability, simplified versioning, and reduced storage costs.

Managing your model weights, metadata, and configurations in container images allows for portability, simplified versioning, and reduced storage costs over time. With containerization, you can:

- Use existing container images, especially for large language models (LLMs) ranging in millions to billions of parameters in size and stable diffusion models, stored in secure container registries.
- Avoid a single point of failure in your pipeline by using multiple lightweight containers that contain the unique dependencies for each task instead of maintaining one large image.
- Store large text and image datasets outside of your base container image and reference them when needed at runtime.
[Get started with the Kubernetes AI Toolchain Operator (KAITO)](./ai-toolchain-operator.md) to deploy an LLM on AKS.

Container supply chain controls remain essential in both modes. Even with preconfigured platform defaults in AKS Automatic, image provenance, scanning, and runtime hardening are still core MLOps responsibilities.

Dockerfile pattern for ML workloads:

Use an explicit, CUDA-enabled base image tag for GPU training workloads (for example, `pytorch/pytorch:2.4.1-cuda12.4-cudnn9-runtime`) instead of an untagged base image reference. Pin the image by digest in production to ensure reproducible builds and predictable CUDA/cuDNN behavior. Maintain separate CPU and GPU image variants so scheduler placement and runtime dependencies stay explicit.

## Model management and versioning

**Key takeaway**: Version your models systematically to maintain consistency across environments and enable faster iteration with parameter-efficient fine-tuning methods.

Model management and versioning are essential for tracking changes to your models over time. By versioning your models, you can:

- Maintain consistency across your model containers for ease of deployment in different environments.
- Employ parameter-efficient fine-tuning (PEFT) methods to iterate faster on a subset of model weights and maintain new versions in lightweight containers.

In AKS Automatic, preconfigured platform baselines can simplify environment parity. In AKS Standard, teams often need to enforce parity more explicitly through platform and deployment configuration.

## Automation

**Key takeaway**: Automate data ingestion, model performance monitoring, and retraining pipelines to reduce manual errors and ensure consistency across the ML lifecycle.

Automation helps reduce manual errors, increase efficiency, and ensure consistency across the ML lifecycle. By automating tasks, you can:

- Integrate alerting tools to trigger a vector ingestion flow as new data flows into your application.
- Set model performance thresholds to track degradations and trigger retraining pipelines.

In both AKS modes, include automation for policy validation, configuration drift detection, and release governance in addition to model quality triggers.

## Scalability and resource management

**Key takeaway**: Optimize resource usage through distributed computing, autoscaling, and disaster recovery planning to handle varying AI pipeline demands cost-effectively.

Scalability and resource management are critical for ensuring that your AI pipeline can handle the demands of your application. By optimizing your resource usage, you can:

- Integrate tools that efficiently use your allocated CPU, GPU, and memory resources through distributed computing and multiple levels of parallelism, such as data, model, and pipeline parallelism.
- Enable autoscaling on your compute resources to support high model request volumes at peak times and scale down in off-peak hours.
- Plan for disaster recovery by following [AKS resiliency and reliability best practices](./best-practices-app-cluster-reliability.md).

AKS Automatic can reduce setup overhead for common scaling and operations patterns, while AKS Standard provides deeper control for custom scaling architectures.

## Security and compliance

**Key takeaway**: Implement CVE scanning, audit trails, and compliance controls to protect your data and meet regulatory requirements such as SOC 2, HIPAA, and GDPR.

Security and compliance are critical for protecting your data and ensuring that your AI pipeline meets regulatory requirements. By implementing security and compliance best practices, you can:

- Integrate scanning for Common Vulnerabilities and Exposures (CVEs) to detect common vulnerabilities on open-source model container images.
- Use [Microsoft Defender for Containers](/azure/defender-for-cloud/defender-for-containers-introduction) for model container images stored in your Azure Container Registry.
- Maintain an audit trail of the ingested data, model changes, and metrics to remain compliant with your organizational policies.
- Support compliance frameworks such as SOC 2 (through Azure's audit logging and access controls), HIPAA (via encryption at rest and in transit, network isolation), and GDPR (through data residency options and access management policies).

In AKS Automatic, preconfigured security defaults improve baseline posture, but model-level, data-level, and pipeline-level security controls remain required.

## Schedule GPU workloads

**Key takeaway**: Expose GPUs through the NVIDIA device plugin, request GPUs explicitly, and isolate expensive GPU nodes with labels, taints, and tolerations.

Kubernetes schedules GPUs as extended resources. After the NVIDIA device plugin registers the GPUs on a node, a pod requests a GPU by setting `nvidia.com/gpu` in both `resources.requests` and `resources.limits`. The following pod requests one GPU and targets a node pool labeled `accelerator=nvidia`:

```yml
apiVersion: v1
kind: Pod
metadata:
  name: gpu-training-pod
  labels:
    app: gpu-training
spec:
  restartPolicy: Never
  nodeSelector:
    accelerator: nvidia
  tolerations:
  - key: sku
    operator: Equal
    value: gpu
    effect: NoSchedule
  containers:
  - name: trainer
    image: nvcr.io/nvidia/cuda:12.4.1-runtime-ubuntu22.04
    command:
    - /bin/bash
    - -c
    - |
      set -e
      nvidia-smi
      echo "GPU is available to the training container."
    resources:
      requests:
        cpu: "1"
        memory: 2Gi
        nvidia.com/gpu: 1
      limits:
        cpu: "1"
        memory: 2Gi
        nvidia.com/gpu: 1
```

Extended resources aren't overcommitted. Kubernetes treats a GPU limit as a GPU request when only the limit is specified, but setting both fields makes workload intent explicit and helps policy validation.

### Provision an AKS GPU node pool

For AKS Standard, create a dedicated user node pool with a supported NVIDIA GPU VM size. The following Azure CLI example creates an autoscaled `Standard_NC4as_T4_v3` node pool, applies the label used by the preceding pod, and taints the nodes to repel workloads that don't explicitly tolerate GPU nodes:

```azurecli-interactive
RESOURCE_GROUP=myResourceGroup
AKS_CLUSTER=myAKSCluster

az aks nodepool add \
  --resource-group "$RESOURCE_GROUP" \
  --cluster-name "$AKS_CLUSTER" \
  --name gpunp \
  --mode User \
  --node-vm-size Standard_NC4as_T4_v3 \
  --node-count 0 \
  --enable-cluster-autoscaler \
  --min-count 0 \
  --max-count 4 \
  --labels accelerator=nvidia workload=training \
  --node-taints sku=gpu:NoSchedule
```

Before creating the node pool, verify that the VM SKU is available in the cluster region and that the subscription has sufficient regional and VM-family quota. Select an NC-series size based on GPU memory, GPU count, CPU-to-GPU ratio, local storage, networking, and the CUDA capabilities required by the training framework. For example, NCas T4 v3 sizes are suitable for many single-GPU and smaller training workloads, while NC A100 v4 sizes support larger models and multi-instance GPU configurations.

AKS Automatic can provision eligible GPU capacity in response to pending pods. The workload must still request `nvidia.com/gpu`, and any node selectors, affinities, tolerations, topology constraints, subscription quotas, and regional SKU availability must be satisfiable. Use AKS Standard when you require a fixed VM SKU, custom node pool lifecycle, or detailed control over GPU pool scaling and topology.

### Verify or install the NVIDIA device plugin

AKS GPU configurations can provide managed GPU drivers and device plugin integration. Verify the effective configuration before installing another plugin:

```bash
kubectl get nodes -L accelerator,kubernetes.azure.com/agentpool
kubectl get daemonsets --all-namespaces | grep -i nvidia
kubectl describe node | grep -A5 -E "Capacity:|Allocatable:|nvidia.com/gpu"
```

Don't run multiple NVIDIA device plugin DaemonSets on the same nodes. If your AKS configuration doesn't manage the plugin, the following standalone DaemonSet registers NVIDIA GPUs with the kubelet. Install a device plugin version supported by your NVIDIA driver and Kubernetes versions:

```yml
apiVersion: apps/v1
kind: DaemonSet
metadata:
  name: nvidia-device-plugin
  namespace: kube-system
  labels:
    app.kubernetes.io/name: nvidia-device-plugin
spec:
  selector:
    matchLabels:
      app.kubernetes.io/name: nvidia-device-plugin
  updateStrategy:
    type: RollingUpdate
  template:
    metadata:
      labels:
        app.kubernetes.io/name: nvidia-device-plugin
    spec:
      priorityClassName: system-node-critical
      nodeSelector:
        accelerator: nvidia
      tolerations:
      - operator: Exists
      containers:
      - name: nvidia-device-plugin
        image: nvcr.io/nvidia/k8s-device-plugin:v0.17.1
        args:
        - --fail-on-init-error=false
        securityContext:
          allowPrivilegeEscalation: false
          capabilities:
            drop:
            - ALL
        volumeMounts:
        - name: device-plugin
          mountPath: /var/lib/kubelet/device-plugins
      volumes:
      - name: device-plugin
        hostPath:
          path: /var/lib/kubelet/device-plugins
          type: Directory
```

Confirm that `nvidia.com/gpu` appears under each GPU node's allocatable resources before submitting training jobs.

### Partition A100 and H100 GPUs with MIG

NVIDIA Multi-Instance GPU (MIG) can partition a supported A100 or H100 GPU into isolated GPU instances. MIG is useful for hyperparameter tuning and smaller fine-tuning jobs that don't require an entire physical GPU. Use full GPUs for workloads that require all GPU memory, maximum interconnect bandwidth, or a profile that isn't supported by the installed GPU.

Use the NVIDIA GPU Operator and MIG Manager when you need declarative MIG lifecycle management. The operator should own the device plugin and MIG configuration for the affected nodes; don't combine it with a second standalone device plugin. The exact profile names and number of instances depend on the GPU model and memory capacity. The following configuration creates seven `1g.10gb` instances on supported 80-GB A100 or H100 configurations:

```yml
apiVersion: v1
kind: Namespace
metadata:
  name: gpu-operator
---
apiVersion: v1
kind: ConfigMap
metadata:
  name: mig-parted-config
  namespace: gpu-operator
data:
  config.yaml: |
    version: v1
    mig-configs:
      all-disabled:
      - devices: all
        mig-enabled: false
      hptuning-1g10gb:
      - devices: all
        mig-enabled: true
        mig-devices:
          "1g.10gb": 7
---
apiVersion: v1
kind: Namespace
metadata:
  name: ml-training
---
apiVersion: batch/v1
kind: Job
metadata:
  name: mig-hyperparameter-trial
  namespace: ml-training
  labels:
    workload: hyperparameter-tuning
spec:
  backoffLimit: 2
  template:
    metadata:
      labels:
        workload: hyperparameter-tuning
    spec:
      restartPolicy: Never
      nodeSelector:
        accelerator: nvidia
        nvidia.com/mig.config: hptuning-1g10gb
        nvidia.com/mig.config.state: success
      tolerations:
      - key: sku
        operator: Equal
        value: gpu
        effect: NoSchedule
      containers:
      - name: trial
        image: nvcr.io/nvidia/cuda:12.4.1-runtime-ubuntu22.04
        command:
        - /bin/bash
        - -c
        - |
          set -e
          nvidia-smi
          echo "Starting one hyperparameter trial on a MIG instance."
          sleep 30
        resources:
          requests:
            cpu: "2"
            memory: 8Gi
            nvidia.com/mig-1g.10gb: 1
          limits:
            cpu: "2"
            memory: 8Gi
            nvidia.com/mig-1g.10gb: 1
```

Configure the GPU Operator's MIG Manager to consume the `mig-parted-config` ConfigMap, use the `mixed` MIG strategy when workloads request named MIG profiles, and then label the target nodes:

```bash
kubectl label nodes \
  -l accelerator=nvidia \
  nvidia.com/mig.config=hptuning-1g10gb \
  --overwrite
```

Changing a MIG layout disrupts workloads already using the GPU. Cordon and drain the target node, apply the configuration during a maintenance window, and confirm that the requested profile exists in node allocatable resources before submitting jobs.

### Isolate GPU workloads with taints and tolerations

A `NoSchedule` taint keeps ordinary application pods away from expensive GPU nodes. The node pool creation example applies `sku=gpu:NoSchedule`. The following complete Job includes the matching toleration and a node selector:

```yml
apiVersion: batch/v1
kind: Job
metadata:
  name: isolated-gpu-training
spec:
  backoffLimit: 3
  template:
    metadata:
      labels:
        app: isolated-gpu-training
    spec:
      restartPolicy: Never
      nodeSelector:
        accelerator: nvidia
        workload: training
      tolerations:
      - key: sku
        operator: Equal
        value: gpu
        effect: NoSchedule
      containers:
      - name: trainer
        image: nvcr.io/nvidia/cuda:12.4.1-runtime-ubuntu22.04
        command:
        - /bin/bash
        - -c
        - |
          set -e
          nvidia-smi
          sleep 60
        resources:
          requests:
            cpu: "4"
            memory: 16Gi
            nvidia.com/gpu: 1
          limits:
            cpu: "4"
            memory: 16Gi
            nvidia.com/gpu: 1
```

A toleration permits scheduling but doesn't force the pod onto a GPU node. Pair tolerations with a GPU resource request and a node selector or node affinity. Ensure that required platform DaemonSets, such as networking, monitoring, storage, and the device plugin, tolerate the GPU taint.

## Run distributed training workloads

**Key takeaway**: Use a training operator to manage worker identities and job lifecycle, validate multi-node network communication, and use gang admission when all workers must start together.

Distributed training uses multiple processes to divide data, model state, or pipeline stages. On Kubernetes, an operator can create worker pods, inject rendezvous configuration, track replica status, restart failed workers, and clean up the job. Install and version training operators through your platform's IaC and release process rather than allowing individual teams to install ungoverned cluster-wide CRDs.

### Build a portable CUDA training image

The following Dockerfile expands the Dockerfile pattern identified in the Containerization section. The image contains the CUDA runtime and PyTorch libraries, while the compatible NVIDIA driver remains on the AKS GPU node:

```dockerfile
FROM pytorch/pytorch:2.4.1-cuda12.4-cudnn9-runtime

WORKDIR /workspace

COPY requirements.txt .
RUN python -m pip install --no-cache-dir -r requirements.txt

COPY train.py .

ENTRYPOINT ["python", "/workspace/train.py"]
```

Pin the base image by an immutable digest in production. Keep datasets and frequently changing checkpoints outside the image, and scan the resulting image before pushing it to Azure Container Registry.

### Run a PyTorchJob

The Kubeflow Training Operator provides the `PyTorchJob` CRD. Install a Training Operator release compatible with your Kubernetes version before applying this manifest. The following two-replica example performs an NCCL all-reduce operation across one master and one worker:

```yml
apiVersion: v1
kind: Namespace
metadata:
  name: ml-training
  labels:
    purpose: ml-training
---
apiVersion: kubeflow.org/v1
kind: PyTorchJob
metadata:
  name: pytorch-nccl-example
  namespace: ml-training
spec:
  runPolicy:
    cleanPodPolicy: None
  pytorchReplicaSpecs:
    Master:
      replicas: 1
      restartPolicy: OnFailure
      template:
        metadata:
          labels:
            training-job: pytorch-nccl-example
        spec:
          nodeSelector:
            accelerator: nvidia
          tolerations:
          - key: sku
            operator: Equal
            value: gpu
            effect: NoSchedule
          containers:
          - name: pytorch
            image: pytorch/pytorch:2.4.1-cuda12.4-cudnn9-runtime
            command:
            - python
            - -c
            - |
              import os
              import torch
              import torch.distributed as dist

              torch.cuda.set_device(0)
              dist.init_process_group(backend="nccl")
              value = torch.tensor(
                  [float(dist.get_rank() + 1)],
                  device="cuda"
              )
              dist.all_reduce(value)
              print(
                  f"rank={dist.get_rank()} "
                  f"world_size={dist.get_world_size()} "
                  f"all_reduce_sum={value.item()}"
              )
              dist.destroy_process_group()
            env:
            - name: NCCL_DEBUG
              value: INFO
            - name: NCCL_SOCKET_IFNAME
              value: eth0
            - name: NCCL_IB_DISABLE
              value: "1"
            - name: TORCH_NCCL_ASYNC_ERROR_HANDLING
              value: "1"
            resources:
              requests:
                cpu: "4"
                memory: 16Gi
                nvidia.com/gpu: 1
              limits:
                cpu: "4"
                memory: 16Gi
                nvidia.com/gpu: 1
    Worker:
      replicas: 1
      restartPolicy: OnFailure
      template:
        metadata:
          labels:
            training-job: pytorch-nccl-example
        spec:
          nodeSelector:
            accelerator: nvidia
          tolerations:
          - key: sku
            operator: Equal
            value: gpu
            effect: NoSchedule
          containers:
          - name: pytorch
            image: pytorch/pytorch:2.4.1-cuda12.4-cudnn9-runtime
            command:
            - python
            - -c
            - |
              import os
              import torch
              import torch.distributed as dist

              torch.cuda.set_device(0)
              dist.init_process_group(backend="nccl")
              value = torch.tensor(
                  [float(dist.get_rank() + 1)],
                  device="cuda"
              )
              dist.all_reduce(value)
              print(
                  f"rank={dist.get_rank()} "
                  f"world_size={dist.get_world_size()} "
                  f"all_reduce_sum={value.item()}"
              )
              dist.destroy_process_group()
            env:
            - name: NCCL_DEBUG
              value: INFO
            - name: NCCL_SOCKET_IFNAME
              value: eth0
            - name: NCCL_IB_DISABLE
              value: "1"
            - name: TORCH_NCCL_ASYNC_ERROR_HANDLING
              value: "1"
            resources:
              requests:
                cpu: "4"
                memory: 16Gi
                nvidia.com/gpu: 1
              limits:
                cpu: "4"
                memory: 16Gi
                nvidia.com/gpu: 1
```

For production training, replace the inline test with your versioned training image and script. Align replica counts with the number of GPUs and processes required by the training framework.

### Run a TFJob

The Training Operator also provides the `TFJob` CRD. The following example runs synchronous TensorFlow training across two GPU workers by using `MultiWorkerMirroredStrategy`:

```yml
apiVersion: v1
kind: Namespace
metadata:
  name: ml-training
  labels:
    purpose: ml-training
---
apiVersion: kubeflow.org/v1
kind: TFJob
metadata:
  name: tensorflow-multiworker-example
  namespace: ml-training
spec:
  runPolicy:
    cleanPodPolicy: None
  tfReplicaSpecs:
    Worker:
      replicas: 2
      restartPolicy: OnFailure
      template:
        metadata:
          labels:
            training-job: tensorflow-multiworker-example
        spec:
          nodeSelector:
            accelerator: nvidia
          tolerations:
          - key: sku
            operator: Equal
            value: gpu
            effect: NoSchedule
          containers:
          - name: tensorflow
            image: tensorflow/tensorflow:2.16.1-gpu
            command:
            - python
            - -c
            - |
              import tensorflow as tf

              strategy = tf.distribute.MultiWorkerMirroredStrategy()
              print("workers:", strategy.num_replicas_in_sync)

              with strategy.scope():
                  model = tf.keras.Sequential([
                      tf.keras.layers.Input(shape=(32,)),
                      tf.keras.layers.Dense(64, activation="relu"),
                      tf.keras.layers.Dense(1)
                  ])
                  model.compile(
                      optimizer="adam",
                      loss="mean_squared_error"
                  )

              features = tf.random.normal([4096, 32])
              labels = tf.random.normal([4096, 1])
              dataset = (
                  tf.data.Dataset.from_tensor_slices((features, labels))
                  .shuffle(4096)
                  .repeat()
                  .batch(64)
              )
              model.fit(dataset, epochs=2, steps_per_epoch=32)
            resources:
              requests:
                cpu: "4"
                memory: 16Gi
                nvidia.com/gpu: 1
              limits:
                cpu: "4"
                memory: 16Gi
                nvidia.com/gpu: 1
```

For parameter-server training, define `Chief`, `Worker`, and `PS` replica types according to the TensorFlow distribution strategy. Measure the resulting network and parameter-server bottlenecks before increasing replica counts.

### Fine-tune a model with KAITO

KAITO provides an AKS-focused workspace abstraction for model deployment and fine-tuning. Enable the KAITO add-on or install a compatible KAITO release before applying a `Workspace`. Verify that the selected preset, VM SKU, and fine-tuning method are supported by the installed KAITO version.

The following workspace requests an A100 GPU VM and starts QLoRA fine-tuning for a supported Phi-3 preset using a publicly accessible dataset:

```yml
apiVersion: kaito.sh/v1alpha1
kind: Workspace
metadata:
  name: workspace-tuning-phi-3-mini
resource:
  instanceType: Standard_NC24ads_A100_v4
  labelSelector:
    matchLabels:
      apps: phi-3-mini-tuning
tuning:
  preset:
    name: phi-3-mini-4k-instruct
  method: qlora
  input:
    urls:
    - https://huggingface.co/datasets/yahma/alpaca-cleaned/resolve/main/alpaca_data_cleaned.json
```

KAITO can coordinate model preset configuration and the GPU infrastructure needed by the workspace. For production, store the training dataset in an approved Azure storage account, use private access and workload identity where supported, and persist the resulting model to a governed model registry or Azure Container Registry. Treat the workspace manifest, input dataset version, preset version, adapter configuration, and output image digest as one versioned training record.

### Configure NCCL communication with AKS CNI

NVIDIA Collective Communications Library (NCCL) handles collective operations such as all-reduce. For a portable TCP baseline on AKS CNI, use the pod network interface, normally `eth0`, and start with `NCCL_IB_DISABLE=1`. On supported RDMA-capable VM sizes, use the documented NVIDIA and Azure RDMA configuration and validate it before setting `NCCL_IB_DISABLE=0`.

Use these baseline environment variables:

- `NCCL_SOCKET_IFNAME=eth0` selects the pod network interface.
- `NCCL_DEBUG=INFO` provides diagnostics during validation. Reduce the log level after tuning.
- `NCCL_IB_DISABLE=1` selects TCP sockets when RDMA isn't configured.
- `TORCH_NCCL_ASYNC_ERROR_HANDLING=1` helps PyTorch terminate instead of hanging indefinitely after asynchronous communication failures.

If network policy is enabled, allow all required rendezvous and NCCL traffic among replicas. NCCL can negotiate dynamic ports, so a narrow fixed-port policy can cause training jobs to hang. The following policy permits unrestricted pod-to-pod communication only among replicas of the PyTorch job and allows DNS resolution:

```yml
apiVersion: networking.k8s.io/v1
kind: NetworkPolicy
metadata:
  name: allow-pytorch-nccl
  namespace: ml-training
spec:
  podSelector:
    matchLabels:
      training-job: pytorch-nccl-example
  policyTypes:
  - Ingress
  - Egress
  ingress:
  - from:
    - podSelector:
        matchLabels:
          training-job: pytorch-nccl-example
  egress:
  - to:
    - podSelector:
        matchLabels:
          training-job: pytorch-nccl-example
  - to:
    - namespaceSelector:
        matchLabels:
          kubernetes.io/metadata.name: kube-system
      podSelector:
        matchLabels:
          k8s-app: kube-dns
    ports:
    - protocol: UDP
      port: 53
    - protocol: TCP
      port: 53
```

Benchmark NCCL independently from model training before scaling out. Compare all-reduce bandwidth, latency, GPU utilization, and training throughput at each worker count. More workers can reduce performance when communication or data loading becomes the bottleneck.

## Use gang scheduling and workload queues

**Key takeaway**: Admit distributed workers as a group and enforce tenant GPU quotas so that partially scheduled jobs don't reserve GPUs while waiting for remaining workers.

The default Kubernetes scheduler places pods individually. For a distributed job that can't make progress until every worker is running, partial placement can waste GPU capacity. Kueue provides admission control and quota management before pods begin running. Volcano provides a scheduler and PodGroup-based all-or-nothing scheduling model.

AKS Automatic provides the default Kubernetes scheduler and automatic node provisioning as a starting point. Submit ordinary Jobs or operator-managed training jobs with accurate resource requests and let the platform provision eligible capacity. This behavior doesn't guarantee atomic admission for every worker. Install Kueue or Volcano when a workload requires gang scheduling, queueing, team quotas, fair sharing, or custom preemption behavior.

### Allocate multi-tenant GPU quota with Kueue

Install a Kueue version compatible with the Kubernetes version and enable integrations for the workload types you use. The following manifest creates:

- A GPU `ResourceFlavor` associated with nodes labeled `accelerator=nvidia`.
- A four-GPU `ClusterQueue` for team A.
- A two-GPU `ClusterQueue` for team B.
- A namespace-scoped `LocalQueue` for each team.
- A two-worker Job that Kueue admits only when its requested resources are available.

```yml
apiVersion: v1
kind: Namespace
metadata:
  name: team-a
---
apiVersion: v1
kind: Namespace
metadata:
  name: team-b
---
apiVersion: kueue.x-k8s.io/v1beta1
kind: ResourceFlavor
metadata:
  name: nvidia-gpu
spec:
  nodeLabels:
    accelerator: nvidia
---
apiVersion: kueue.x-k8s.io/v1beta1
kind: ClusterQueue
metadata:
  name: team-a-gpu
spec:
  namespaceSelector:
    matchLabels:
      kubernetes.io/metadata.name: team-a
  queueingStrategy: BestEffortFIFO
  resourceGroups:
  - flavors:
    - name: nvidia-gpu
      resources:
      - name: cpu
        nominalQuota: "64"
      - name: memory
        nominalQuota: 256Gi
      - name: nvidia.com/gpu
        nominalQuota: "4"
---
apiVersion: kueue.x-k8s.io/v1beta1
kind: ClusterQueue
metadata:
  name: team-b-gpu
spec:
  namespaceSelector:
    matchLabels:
      kubernetes.io/metadata.name: team-b
  queueingStrategy: BestEffortFIFO
  resourceGroups:
  - flavors:
    - name: nvidia-gpu
      resources:
      - name: cpu
        nominalQuota: "32"
      - name: memory
        nominalQuota: 128Gi
      - name: nvidia.com/gpu
        nominalQuota: "2"
---
apiVersion: kueue.x-k8s.io/v1beta1
kind: LocalQueue
metadata:
  name: gpu-queue
  namespace: team-a
spec:
  clusterQueue: team-a-gpu
---
apiVersion: kueue.x-k8s.io/v1beta1
kind: LocalQueue
metadata:
  name: gpu-queue
  namespace: team-b
spec:
  clusterQueue: team-b-gpu
---
apiVersion: batch/v1
kind: Job
metadata:
  name: team-a-two-gpu-training
  namespace: team-a
  labels:
    kueue.x-k8s.io/queue-name: gpu-queue
spec:
  suspend: true
  completions: 2
  parallelism: 2
  backoffLimit: 2
  template:
    metadata:
      labels:
        app: team-a-two-gpu-training
    spec:
      restartPolicy: Never
      tolerations:
      - key: sku
        operator: Equal
        value: gpu
        effect: NoSchedule
      containers:
      - name: worker
        image: nvcr.io/nvidia/cuda:12.4.1-runtime-ubuntu22.04
        command:
        - /bin/bash
        - -c
        - |
          set -e
          nvidia-smi
          echo "Kueue admitted this worker."
          sleep 120
        resources:
          requests:
            cpu: "4"
            memory: 16Gi
            nvidia.com/gpu: 1
          limits:
            cpu: "4"
            memory: 16Gi
            nvidia.com/gpu: 1
```

A `ClusterQueue` quota is a scheduling quota, not an Azure subscription quota. Ensure that the AKS cluster can provision the underlying VM capacity and that Azure GPU quota is sufficient for the aggregate admitted workload. Use cohorts and Kueue fair-sharing features when teams can borrow unused quota from one another.

### Use Volcano as an alternative

Volcano is an alternative when you want a dedicated batch scheduler with gang scheduling, queues, and job lifecycle policies. Install a Volcano release compatible with the cluster before applying its CRDs. The following Volcano Job requires both GPU workers to be available before the job runs:

```yml
apiVersion: batch.volcano.sh/v1alpha1
kind: Job
metadata:
  name: volcano-gpu-training
  namespace: default
spec:
  minAvailable: 2
  schedulerName: volcano
  policies:
  - event: PodEvicted
    action: RestartJob
  - event: PodFailed
    action: RestartJob
  tasks:
  - replicas: 2
    name: worker
    template:
      metadata:
        labels:
          app: volcano-gpu-training
      spec:
        restartPolicy: OnFailure
        nodeSelector:
          accelerator: nvidia
        tolerations:
        - key: sku
          operator: Equal
          value: gpu
          effect: NoSchedule
        containers:
        - name: worker
          image: nvcr.io/nvidia/cuda:12.4.1-runtime-ubuntu22.04
          command:
          - /bin/bash
          - -c
          - |
            set -e
            nvidia-smi
            echo "All Volcano workers were admitted."
            sleep 120
          resources:
            requests:
              cpu: "4"
              memory: 16Gi
              nvidia.com/gpu: 1
            limits:
              cpu: "4"
              memory: 16Gi
              nvidia.com/gpu: 1
```

Standardize on one primary queueing and gang-scheduling system unless you have a tested interoperability design. Multiple admission controllers or schedulers can otherwise make pending and preemption behavior difficult to reason about.

### Configure training and inference priorities

Latency-sensitive inference commonly requires a higher priority than interruptible batch training. The following `PriorityClass` resources allow inference pods to preempt lower-priority pods while preventing batch training pods from preempting other workloads:

```yml
apiVersion: scheduling.k8s.io/v1
kind: PriorityClass
metadata:
  name: training-batch
value: 10000
globalDefault: false
preemptionPolicy: Never
description: Batch training can wait and can be preempted by higher-priority workloads.
---
apiVersion: scheduling.k8s.io/v1
kind: PriorityClass
metadata:
  name: inference-critical
value: 100000
globalDefault: false
preemptionPolicy: PreemptLowerPriority
description: Latency-sensitive production inference can preempt lower-priority workloads.
```

Assign the class through `spec.priorityClassName` in the pod template. Kubernetes pod priority and Kueue workload priority affect different stages: Kueue controls queue admission, while Kubernetes priority influences scheduling and pod preemption after admission. Coordinate both policies so they express the same business priority.

Preemption terminates lower-priority pods. Training workloads that can be preempted must write checkpoints to persistent storage, tolerate duplicate work, and recover without relying on node-local files.

## Configure shared memory and resource management

**Key takeaway**: Replace the container runtime's small default `/dev/shm`, set resource requests from observed utilization, and configure node scaling around complete GPU workload requirements.

### Increase `/dev/shm` for ML data loaders

PyTorch data loaders, TensorFlow input pipelines, NCCL, and Python multiprocessing can use POSIX shared memory. The container default for `/dev/shm` is frequently too small for multi-process training, which can cause worker crashes, bus errors, or apparent training hangs.

Mount a memory-backed `emptyDir` at `/dev/shm` and set an explicit `sizeLimit`:

```yml
apiVersion: batch/v1
kind: Job
metadata:
  name: shared-memory-training
spec:
  backoffLimit: 2
  template:
    metadata:
      labels:
        app: shared-memory-training
    spec:
      restartPolicy: Never
      nodeSelector:
        accelerator: nvidia
      tolerations:
      - key: sku
        operator: Equal
        value: gpu
        effect: NoSchedule
      containers:
      - name: trainer
        image: pytorch/pytorch:2.4.1-cuda12.4-cudnn9-runtime
        command:
        - /bin/bash
        - -c
        - |
          set -e
          df -h /dev/shm
          python -c '
          import multiprocessing as mp
          import torch

          def worker(index):
              value = torch.ones(1024, 1024)
              print(f"worker={index}, sum={value.sum().item()}")

          if __name__ == "__main__":
              processes = [mp.Process(target=worker, args=(i,)) for i in range(4)]
              for process in processes:
                  process.start()
              for process in processes:
                  process.join()
                  if process.exitcode != 0:
                      raise SystemExit(process.exitcode)
          '
        volumeMounts:
        - name: shared-memory
          mountPath: /dev/shm
        resources:
          requests:
            cpu: "8"
            memory: 16Gi
            nvidia.com/gpu: 1
          limits:
            cpu: "8"
            memory: 16Gi
            nvidia.com/gpu: 1
      volumes:
      - name: shared-memory
        emptyDir:
          medium: Memory
          sizeLimit: 8Gi
```

Memory-backed `emptyDir` usage counts toward the pod's memory consumption. Include the maximum expected shared-memory usage when setting the container memory limit. If `/dev/shm` grows beyond the effective memory budget, the pod can be evicted or terminated for exceeding its memory limit.

### Size CPU and memory from observed utilization

Start with a benchmark based on representative model, batch size, sequence length, data-loader concurrency, augmentation, and checkpoint behavior. Then use monitoring data to adjust:

- Set CPU requests high enough to keep GPU input pipelines supplied. Persistent GPU idle periods can indicate CPU or storage starvation.
- Set memory requests near stable working-set usage plus a safety margin. Include `/dev/shm`, page cache behavior, framework allocator overhead, and checkpoint serialization peaks.
- Set memory limits above the observed peak. Investigate `OOMKilled` events rather than repeatedly increasing limits without finding the cause.
- Evaluate CPU throttling before using restrictive CPU limits. CPU limits that are too low can reduce GPU utilization even when average CPU usage appears acceptable.
- Set requests and limits equal for predictable, high-value training jobs when Guaranteed quality of service is more important than node packing.
- Profile every significant change to model size, precision, batch size, worker count, and data pipeline.

Use percentiles over complete training runs instead of a short average. Startup, validation, checkpoint, and data-shuffle phases often have different resource peaks.

### Configure cluster autoscaling for a GPU node pool

For AKS Standard, enable the cluster autoscaler on the GPU user node pool and define minimum and maximum capacity:

```azurecli-interactive
RESOURCE_GROUP=myResourceGroup
AKS_CLUSTER=myAKSCluster
GPU_NODE_POOL=gpunp

az aks nodepool update \
  --resource-group "$RESOURCE_GROUP" \
  --cluster-name "$AKS_CLUSTER" \
  --name "$GPU_NODE_POOL" \
  --enable-cluster-autoscaler \
  --min-count 0 \
  --max-count 8
```

You can tune supported cluster autoscaler profile settings at cluster scope. Test profile changes against both training and serving workloads:

```azurecli-interactive
az aks update \
  --resource-group "$RESOURCE_GROUP" \
  --name "$AKS_CLUSTER" \
  --cluster-autoscaler-profile \
    scan-interval=20s \
    scale-down-unneeded-time=10m \
    scale-down-delay-after-add=15m \
    max-graceful-termination-sec=120
```

A pending GPU pod triggers scale-up only when its complete scheduling requirements match a node pool template. Check the GPU resource request, VM capacity, labels, taints, tolerations, affinity, topology constraints, persistent volume topology, maximum node count, and Azure quota when scale-up doesn't occur.

Scale-to-zero is appropriate for interruptible training pools, but it adds VM provisioning, image-pull, dataset-mount, and model-initialization latency. Keep a nonzero minimum when startup latency has a material effect on service objectives. Pod disruption budgets, non-evictable pods, local storage, and long termination grace periods can delay scale-down.

AKS Automatic manages node provisioning and scaling as part of the service baseline. Focus on accurate pod requests and supported constraints instead of configuring a manual GPU node pool autoscaler.

## Store datasets and checkpoints

**Key takeaway**: Select storage based on access pattern, throughput, sharing, and recovery requirements, and persist checkpoints outside the node so training can recover from eviction or preemption.

Keep large datasets, model artifacts, and checkpoints out of container images. Choose a storage interface based on the workload:

- Use Azure Blob Storage for large object datasets, model artifacts, and high-capacity data repositories.
- Use Azure Files when multiple worker nodes require a shared POSIX-style file system.
- Use Azure Disk for high-performance, single-node read-write checkpoint or cache workloads where `ReadWriteOnce` is sufficient.
- Use node-local ephemeral storage only for reconstructable caches and temporary files.

### Access large datasets with the Azure Blob CSI driver

Enable the Azure Blob CSI driver on AKS Standard if it isn't already enabled:

```azurecli-interactive
RESOURCE_GROUP=myResourceGroup
AKS_CLUSTER=myAKSCluster

az aks update \
  --resource-group "$RESOURCE_GROUP" \
  --name "$AKS_CLUSTER" \
  --enable-blob-driver
```

The following example dynamically creates a premium Azure Blob container exposed through NFS and mounts it into a training pod. For an existing governed dataset, use a statically defined volume or a BlobFuse configuration with the appropriate identity and private networking controls instead of creating an empty dynamic container:

```yml
apiVersion: storage.k8s.io/v1
kind: StorageClass
metadata:
  name: ml-azureblob-nfs
provisioner: blob.csi.azure.com
parameters:
  protocol: nfs
  skuName: Premium_LRS
reclaimPolicy: Delete
allowVolumeExpansion: true
volumeBindingMode: Immediate
mountOptions:
- -o attr_timeout=120
- -o entry_timeout=120
- -o negative_timeout=120
- -o actimeo=120
- -o noresvport
- -o nconnect=4
---
apiVersion: v1
kind: PersistentVolumeClaim
metadata:
  name: blob-training-dataset
  namespace: default
spec:
  accessModes:
  - ReadWriteMany
  storageClassName: ml-azureblob-nfs
  resources:
    requests:
      storage: 1Ti
---
apiVersion: batch/v1
kind: Job
metadata:
  name: inspect-blob-dataset
  namespace: default
spec:
  backoffLimit: 2
  template:
    metadata:
      labels:
        app: inspect-blob-dataset
    spec:
      restartPolicy: Never
      containers:
      - name: dataset-reader
        image: ubuntu:24.04
        command:
        - /bin/bash
        - -c
        - |
          set -e
          echo "Mounted dataset path:"
          df -h /mnt/dataset
          find /mnt/dataset -maxdepth 2 -type f | head -100
        volumeMounts:
        - name: dataset
          mountPath: /mnt/dataset
      volumes:
      - name: dataset
        persistentVolumeClaim:
          claimName: blob-training-dataset
```

Benchmark the protocol and mount options against representative shard sizes and access patterns. Many workers reading many small files can produce different results from sequentially streaming large shards. Consider preprocessing datasets into appropriately sized shards and using node-local cache space when repeated epochs would otherwise download the same objects.

### Share training data with Azure Files

Azure Files supports `ReadWriteMany`, which allows distributed workers on different nodes to mount the same share. Premium Azure Files is appropriate when the workload requires predictable file-system performance and the selected region supports the required redundancy option.

The following manifest creates a premium Azure Files share and mounts it into two parallel worker pods:

```yml
apiVersion: storage.k8s.io/v1
kind: StorageClass
metadata:
  name: ml-azurefile-premium
provisioner: file.csi.azure.com
parameters:
  skuName: Premium_LRS
reclaimPolicy: Delete
allowVolumeExpansion: true
volumeBindingMode: Immediate
mountOptions:
- dir_mode=0770
- file_mode=0660
- uid=1000
- gid=1000
- mfsymlinks
- cache=strict
- actimeo=30
- nosharesock
---
apiVersion: v1
kind: PersistentVolumeClaim
metadata:
  name: shared-training-data
  namespace: default
spec:
  accessModes:
  - ReadWriteMany
  storageClassName: ml-azurefile-premium
  resources:
    requests:
      storage: 100Gi
---
apiVersion: batch/v1
kind: Job
metadata:
  name: shared-data-workers
  namespace: default
spec:
  completions: 2
  parallelism: 2
  completionMode: Indexed
  backoffLimitPerIndex: 2
  template:
    metadata:
      labels:
        app: shared-data-workers
    spec:
      restartPolicy: Never
      securityContext:
        runAsUser: 1000
        runAsGroup: 1000
        fsGroup: 1000
      containers:
      - name: worker
        image: ubuntu:24.04
        command:
        - /bin/bash
        - -c
        - |
          set -e
          WORKER_INDEX="${JOB_COMPLETION_INDEX:-0}"
          echo "worker=${WORKER_INDEX}" \
            > "/mnt/shared/worker-${WORKER_INDEX}.txt"
          ls -la /mnt/shared
        volumeMounts:
        - name: shared-data
          mountPath: /mnt/shared
      volumes:
      - name: shared-data
        persistentVolumeClaim:
          claimName: shared-training-data
```

Avoid having every worker repeatedly enumerate a directory containing millions of files. Use a manifest or deterministic shard assignment so each worker knows which objects to read.

### Checkpoint to persistent storage

A checkpoint should include enough state to resume correctly, such as model weights, optimizer state, scheduler state, scaler state, epoch or step number, random number generator state, and data-loader position when supported. Write checkpoints periodically and before graceful termination.

The following Job writes atomic PyTorch checkpoints to Azure Files, restores the latest checkpoint after a container restart or pod replacement, and handles `SIGTERM` so preemption can preserve recent progress:

```yml
apiVersion: storage.k8s.io/v1
kind: StorageClass
metadata:
  name: ml-checkpoints-azurefile
provisioner: file.csi.azure.com
parameters:
  skuName: Premium_LRS
reclaimPolicy: Retain
allowVolumeExpansion: true
volumeBindingMode: Immediate
mountOptions:
- dir_mode=0770
- file_mode=0660
- uid=1000
- gid=1000
- mfsymlinks
- cache=strict
- actimeo=30
- nosharesock
---
apiVersion: v1
kind: PersistentVolumeClaim
metadata:
  name: model-checkpoints
  namespace: default
spec:
  accessModes:
  - ReadWriteMany
  storageClassName: ml-checkpoints-azurefile
  resources:
    requests:
      storage: 100Gi
---
apiVersion: batch/v1
kind: Job
metadata:
  name: checkpointed-pytorch-training
  namespace: default
spec:
  backoffLimit: 6
  template:
    metadata:
      labels:
        app: checkpointed-pytorch-training
    spec:
      restartPolicy: OnFailure
      terminationGracePeriodSeconds: 120
      securityContext:
        runAsUser: 1000
        runAsGroup: 1000
        fsGroup: 1000
      containers:
      - name: trainer
        image: pytorch/pytorch:2.4.1-cuda12.4-cudnn9-runtime
        command:
        - python
        - -c
        - |
          import os
          import signal
          import sys
          import time
          import torch

          checkpoint_path = "/checkpoints/latest.pt"
          temporary_path = "/checkpoints/latest.pt.tmp"
          state = {"epoch": 0, "value": torch.tensor([0.0])}

          if os.path.exists(checkpoint_path):
              state = torch.load(checkpoint_path, map_location="cpu")
              print(f"Restored epoch {state['epoch']}", flush=True)

          def save_checkpoint():
              torch.save(state, temporary_path)
              os.replace(temporary_path, checkpoint_path)
              print(f"Saved epoch {state['epoch']}", flush=True)

          def terminate(signum, frame):
              print(f"Received signal {signum}", flush=True)
              save_checkpoint()
              sys.exit(143)

          signal.signal(signal.SIGTERM, terminate)
          signal.signal(signal.SIGINT, terminate)

          for epoch in range(state["epoch"] + 1, 21):
              state["epoch"] = epoch
              state["value"] += 1
              time.sleep(10)
              if epoch % 2 == 0:
                  save_checkpoint()

          save_checkpoint()
          print("Training completed.", flush=True)
        volumeMounts:
        - name: checkpoints
          mountPath: /checkpoints
        resources:
          requests:
            cpu: "1"
            memory: 2Gi
          limits:
            cpu: "1"
            memory: 2Gi
      volumes:
      - name: checkpoints
        persistentVolumeClaim:
          claimName: model-checkpoints
```

Use a `Retain` reclaim policy or an independently managed storage account for production checkpoints so deleting a PVC doesn't unintentionally delete the only recovery point. For distributed data-parallel training, normally have rank zero write the global checkpoint, or use a framework-supported sharded checkpoint format. Prevent multiple ranks from writing the same file concurrently.

Test recovery by deliberately deleting a worker pod during a nonproduction run. Verify that the controller recreates the workload, the new pod mounts the same persistent volume, and training resumes from the expected step.

## Monitor GPU utilization and training throughput

**Key takeaway**: Monitor GPU compute, GPU memory, data pipeline throughput, step duration, and checkpoint activity together so you can distinguish compute saturation from CPU, network, or storage bottlenecks.

Enable [Azure Monitor managed service for Prometheus](/azure/azure-monitor/containers/kubernetes-monitoring-enable) and [Container Insights](/azure/azure-monitor/containers/container-insights-overview) to correlate Kubernetes state, container logs, node health, and Prometheus metrics. Use [monitoring best practices for AKS](./monitor-aks.md) when designing alerting, retention, and operational dashboards.

### Collect NVIDIA GPU metrics

NVIDIA Data Center GPU Manager (DCGM) Exporter exposes Prometheus metrics for NVIDIA GPUs. If the NVIDIA GPU Operator already deploys DCGM Exporter, don't deploy a duplicate exporter. Configure Azure Monitor managed Prometheus to scrape the existing exporter.

The following `PodMonitor` uses the Azure Monitor managed Prometheus CRD and targets DCGM Exporter pods in the `gpu-operator` namespace. Adjust the label selector to match the labels used by your installed exporter:

```yml
apiVersion: azmonitoring.coreos.com/v1
kind: PodMonitor
metadata:
  name: nvidia-dcgm-exporter
  namespace: gpu-operator
spec:
  selector:
    matchLabels:
      app: nvidia-dcgm-exporter
  podMetricsEndpoints:
  - port: metrics
    interval: 30s
    scrapeTimeout: 10s
```

Verify the exporter service or pod port name before applying the monitor. Common DCGM metrics include:

| Metric | Purpose |
| --- | --- |
| `DCGM_FI_DEV_GPU_UTIL` | Percentage of time the GPU is active |
| `DCGM_FI_DEV_FB_USED` | Used frame-buffer memory |
| `DCGM_FI_DEV_FB_FREE` | Free frame-buffer memory |
| `DCGM_FI_DEV_MEM_COPY_UTIL` | Memory copy engine utilization |
| `DCGM_FI_DEV_POWER_USAGE` | GPU power consumption |
| `DCGM_FI_DEV_GPU_TEMP` | GPU temperature |
| `DCGM_FI_DEV_XID_ERRORS` | NVIDIA XID error events |

Metric availability depends on the GPU, driver, DCGM, and exporter versions.

### Export training throughput metrics

Instrument the training application with workload-level metrics. Useful metrics include:

- `ml_training_samples_total` for cumulative samples or tokens processed.
- `ml_training_steps_total` for completed optimizer steps.
- `ml_training_step_duration_seconds` for step latency.
- `ml_training_checkpoint_duration_seconds` for checkpoint latency.
- `ml_training_data_wait_seconds` for time waiting on input data.
- Model-specific loss, learning rate, gradient norm, and validation metrics.

The following runnable example exposes synthetic training metrics on port `8000`. Replace the simulation with metrics emitted by the real training loop:

```yml
apiVersion: v1
kind: Namespace
metadata:
  name: ml-observability
---
apiVersion: v1
kind: ConfigMap
metadata:
  name: training-metrics-server
  namespace: ml-observability
data:
  server.py: |
    import http.server
    import threading
    import time

    state = {
        "samples": 0,
        "steps": 0,
        "last_step_duration": 0.0,
    }

    def train():
        while True:
            started = time.time()
            time.sleep(1)
            state["samples"] += 256
            state["steps"] += 1
            state["last_step_duration"] = time.time() - started

    class MetricsHandler(http.server.BaseHTTPRequestHandler):
        def do_GET(self):
            if self.path != "/metrics":
                self.send_response(404)
                self.end_headers()
                return

            body = (
                "# HELP ml_training_samples_total Samples processed.\n"
                "# TYPE ml_training_samples_total counter\n"
                f"ml_training_samples_total{{job_name=\"metrics-demo\"}} "
                f"{state['samples']}\n"
                "# HELP ml_training_steps_total Training steps completed.\n"
                "# TYPE ml_training_steps_total counter\n"
                f"ml_training_steps_total{{job_name=\"metrics-demo\"}} "
                f"{state['steps']}\n"
                "# HELP ml_training_step_duration_seconds "
                "Duration of the most recent training step.\n"
                "# TYPE ml_training_step_duration_seconds gauge\n"
                f"ml_training_step_duration_seconds"
                f"{{job_name=\"metrics-demo\"}} "
                f"{state['last_step_duration']}\n"
            ).encode("utf-8")

            self.send_response(200)
            self.send_header("Content-Type", "text/plain; version=0.0.4")
            self.send_header("Content-Length", str(len(body)))
            self.end_headers()
            self.wfile.write(body)

        def log_message(self, format, *args):
            return

    threading.Thread(target=train, daemon=True).start()
    http.server.ThreadingHTTPServer(("0.0.0.0", 8000), MetricsHandler).serve_forever()
---
apiVersion: apps/v1
kind: Deployment
metadata:
  name: training-metrics-demo
  namespace: ml-observability
spec:
  replicas: 1
  selector:
    matchLabels:
      app: training-metrics-demo
  template:
    metadata:
      labels:
        app: training-metrics-demo
    spec:
      containers:
      - name: metrics
        image: python:3.12-slim
        command:
        - python
        - /app/server.py
        ports:
        - name: metrics
          containerPort: 8000
        readinessProbe:
          httpGet:
            path: /metrics
            port: metrics
          initialDelaySeconds: 2
          periodSeconds: 10
        resources:
          requests:
            cpu: 50m
            memory: 64Mi
          limits:
            cpu: 200m
            memory: 128Mi
        volumeMounts:
        - name: application
          mountPath: /app
          readOnly: true
      volumes:
      - name: application
        configMap:
          name: training-metrics-server
---
apiVersion: azmonitoring.coreos.com/v1
kind: PodMonitor
metadata:
  name: training-metrics-demo
  namespace: ml-observability
spec:
  selector:
    matchLabels:
      app: training-metrics-demo
  podMetricsEndpoints:
  - port: metrics
    path: /metrics
    interval: 30s
    scrapeTimeout: 10s
```

For a real distributed job, include stable labels such as model name, model version, job name, run ID, replica role, and team. Don't use unbounded labels such as sample IDs, request IDs, or raw dataset paths because high-cardinality labels increase monitoring cost and query latency.

### Build GPU and throughput dashboards

Use PromQL queries such as the following as starting points, and validate metric labels against your exporter:

```promql
avg by (namespace, pod, gpu) (
  avg_over_time(DCGM_FI_DEV_GPU_UTIL[5m])
)
```

The following query calculates frame-buffer memory usage as a percentage:

```promql
100 *
DCGM_FI_DEV_FB_USED
/
(DCGM_FI_DEV_FB_USED + DCGM_FI_DEV_FB_FREE)
```

The following query calculates training samples processed per second:

```promql
sum by (job_name) (
  rate(ml_training_samples_total[5m])
)
```

The following query displays average step duration:

```promql
avg by (job_name) (
  ml_training_step_duration_seconds
)
```

Interpret these signals together:

- Low GPU utilization and high data-wait time usually indicate storage, network, preprocessing, or CPU starvation.
- High GPU utilization with expected throughput indicates that the accelerator is being used effectively.
- High GPU memory and repeated out-of-memory errors indicate that batch size, sequence length, activation memory, optimizer state, or fragmentation needs adjustment.
- Falling throughput with stable GPU utilization can indicate longer sequences, communication overhead, thermal behavior, or a change in model computation.
- Low GPU utilization on allocated GPUs indicates idle capacity that might be reduced, queued differently, or partitioned with MIG.
- Long checkpoint duration can make preemption expensive and increase the amount of repeated work after recovery.

Create alerts for sustained GPU underutilization, near-capacity GPU memory, XID errors, stalled training throughput, failed workers, pending gang-scheduled workloads, and checkpoints that haven't completed within the expected recovery point objective.

## Frequently asked questions (FAQ)

### What's the difference between AKS Automatic and AKS Standard for MLOps?

AKS Automatic provides preconfigured defaults for node pools, networking, security, and upgrades, allowing MLOps teams to focus on workload definitions and governance. AKS Standard requires manual configuration of these platform components but offers deeper control for custom architectures and scaling requirements.

### How do I version ML models in AKS?

Version your models by packaging model weights, metadata, and configurations in container images with semantic version tags. Store these images in Azure Container Registry and reference specific versions in your Kubernetes deployment manifests to ensure consistency across environments.

### How do I schedule GPU workloads on AKS?

Ensure that the NVIDIA device plugin is available so GPU nodes advertise `nvidia.com/gpu`. On AKS Standard, provision a dedicated GPU user node pool with a supported VM size such as a Standard_NC-series SKU, and configure node labels, a `NoSchedule` taint, and cluster autoscaler limits. In each training pod, request `nvidia.com/gpu`, select an eligible GPU node, and add the matching toleration. AKS Automatic can provision eligible GPU capacity from pod requests, subject to supported SKUs, regional availability, scheduling constraints, and Azure subscription quota.

### How do I run distributed training jobs on AKS?

Install the Kubeflow Training Operator and submit a `PyTorchJob` or `TFJob` to manage distributed replicas, rendezvous configuration, restart behavior, and job status. KAITO provides an AKS-focused workspace abstraction for supported model fine-tuning workflows and can coordinate GPU infrastructure with model presets. For multi-node PyTorch training, configure and benchmark NCCL over the AKS CNI pod network, allow worker-to-worker traffic through network policy, and use supported RDMA configuration when the selected VM SKU and workload require it.

### How do I manage GPU quota across multiple teams?

Install Kueue and define `ClusterQueue` resources with CPU, memory, and `nvidia.com/gpu` quotas, then map each team's namespace to its assigned quota through a `LocalQueue`. Use Kueue cohorts or fair sharing when teams can borrow unused capacity. Volcano is an alternative when you require a batch scheduler with all-or-nothing worker admission. Coordinate queue priority with Kubernetes `PriorityClass` resources so latency-sensitive inference can preempt interruptible training, and ensure preemptible training jobs recover from checkpoints on persistent storage.

## Related content

Learn about best practices across other areas of your application deployment and operations on AKS:

- [AKS Automatic and AKS Standard feature comparison](./intro-aks-automatic.md#aks-automatic-and-standard-feature-comparison)
- [Application resiliency and reliability best practices](./best-practices-app-cluster-reliability.md)
- [Resource management best practices](./developer-best-practices-resource-management.md)
- [Pod security best practices](./developer-best-practices-pod-security.md)
- [Enforce best practices with Deployment Safeguards](./deployment-safeguards.md)
