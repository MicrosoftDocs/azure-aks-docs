---
title: Secure container access to resources in Azure Kubernetes Service (AKS)
description: Learn how to limit access to actions that containers can perform, provide the least number of permissions, and avoid the use of root access or privileged escalation.
author: allyford
ms.topic: how-to
ms.subservice: aks-security
ms.service: azure-kubernetes-service
ms.date: 11/08/2024
ms.author: allyford
zone_pivot_groups: secure-container-access
# Customer intent: As a cloud security administrator, I want to implement least privilege access for containers in Kubernetes so that I can minimize risks of unauthorized actions and potential attacks on our resources.
---

# Secure container access to resources for Azure Kubernetes Service (AKS) workloads using built-in Linux security features

In this article, you learn how to secure container access to resources for your Azure Kubernetes Service (AKS) workloads using the _user namespaces_, _AppArmor_, and _seccomp_ built-in Linux security features.

> [!IMPORTANT]
> Starting on **30 November 2025**, AKS will no longer support or provide security updates for Azure Linux 2.0. Starting on **31 March 2026**, node images will be removed, and you'll be unable to scale your node pools. Migrate to a supported Azure Linux version by [**upgrading your node pools**](/azure/aks/upgrade-aks-cluster) to a supported Kubernetes version or migrating to [`osSku AzureLinux3`](/azure/aks/upgrade-os-version). For more information, see [[Retirement] Azure Linux 2.0 node pools on AKS](https://github.com/Azure/AKS/issues/4988).

## Overview of container access security

In the same way that you should grant users or groups the minimum privileges required, you should also limit containers to only necessary actions and processes. To minimize the risk of attack, avoid configuring applications and containers that require escalated privileges or root access.

You can use built-in Kubernetes _pod security contexts_ to define more permissions, such as the user or group to run as, the Linux capabilities to expose, or setting `allowPrivilegeEscalation: false` in the pod manifest. For more best practices, see [Secure pod access to resources][pod-security-contexts].

To improve the host isolation and decrease lateral movement on Linux, you can use _user namespaces_. For even more granular control of container actions, you can use built-in Linux security features such as _AppArmor_ and _seccomp_. These features help you limit the actions that containers can perform by defining Linux security features at the node level and implementing them through a pod manifest.

Built-in Linux security features are only available on Linux nodes and pods.

> [!NOTE]
> Currently, Kubernetes environments aren't safe for hostile multitenant usage. Other security features, like _Microsoft Defender for Containers_, _AppArmor_, _seccomp_, _user namespaces_, _Pod Security Admission_, or _Kubernetes Role-Based Access Control (RBAC) for nodes_, efficiently block exploits.
>
> For true security when running hostile multitenant workloads, only trust a hypervisor. The security domain for Kubernetes becomes the entire cluster, not an individual node.
>
> For these types of hostile multitenant workloads, you should use physically isolated clusters.

:::zone pivot="user-namespaces"

## Prerequisites for user namespaces

- An existing AKS cluster. If you don't have a cluster, create one using the [Azure CLI][aks-quickstart-cli], [Azure PowerShell][aks-quickstart-powershell], or the [Azure portal][aks-quickstart-portal].
- Minimum Kubernetes version 1.33 for the control plane and worker nodes. If you're not using Kubernetes version 1.33 or higher, you need to [upgrade your Kubernetes version][upgrade-aks-cluster].
- Worker nodes running Azure Linux 3.0 or Ubuntu 24.04 to ensure you meet the minimum [stack requirements][userns-requirements] to enable user namespaces. If you need to upgrade your operating system (OS) version, see [upgrade your OS version][upgrade-os-version].

## Limitations for user namespaces

- User namespaces is a Linux kernel feature and isn't supported for Windows node pools.
- Check the [Kubernetes documentation for user namespaces][k8s-userns] for any other limitations.

## Overview of user namespaces

Linux pods run using several namespaces by default: a network namespaces to isolate the network identity and a PID namespace to isolate the processes. A [user namespace (user_namespace)][userns-man] isolates the users inside the container from the users on the host. It also limits the scope of capabilities and the pod's interactions with the rest of the system.

The UIDs and GIDs inside the container are mapped to unprivileged users on the host, so all interaction with the rest of the host happen as those unprivileged UID and GID. For example, root inside the container (UID 0) can be mapped to user 65536 on the host. Kubernetes creates the mapping to guarantee it doesn't overlap with other pods using user-namespaces on the system.

The Kubernetes implementation has some key benefits. To learn more, see the [Kubernetes User Namespaces documentation](https://kubernetes.io/docs/concepts/workloads/pods/user-namespaces/).

## Enable user namespaces

1. Create a file named `mypod.yaml` and copy in the following manifest. To use user-namespaces, the YAML needs to have the field `hostUsers: false`.

    ```yaml
    apiVersion: v1
    kind: Pod
    metadata:
      name: userns
    spec:
      hostUsers: false
      containers:
      - name: shell
        command: ["sleep", "infinity"]
        image: debian
    ```

1. Deploy the application using the `kubectl apply` command and specify the name of your YAML manifest.

    ```bash
    kubectl apply -f mypod.yaml
    ```

1. Check the status of the deployed pods using the `kubectl get pods` command.

    ```bash
    kubectl get pods
    ```

1. Exec into the pod using the `kubectl exec` command.

    ```bash
    kubectl exec -ti userns -- bash
    ```

1. Inside the pod, check `/proc/self/uid_map` using the following command:

    ```bash
    cat /proc/self/uid_map
    ```

    The output should have _65536_ in the last column. For example:

    ```output
    0  833617920      65536
    ```

    This output indicates that root inside the container (UID 0) is mapped to user 65536 on the host.

## Common vulnerabilities and exposures (CVEs) mitigated by user namespaces

The following table outlines some common vulnerabilities and exposures (CVEs) that are either partially or fully mitigated by using user_namespaces:

| CVE | Severity score |
|-----|----------------|
| [CVE-2019-5736][cve-2019-5716] | Score 8.6 (HIGH) |
| [CVE 2024-21262][cve-2024-21262] | Score 8.6 (HIGH) |
| [CVE 2022-0492][cve-2022-0492] | Score 7.8 (HIGH) |
| [CVE-2021-25741][cve-2021-25741] | Score: 8.1 (HIGH) / 8.8 (HIGH) |
| [CVE-2017-1002101][cve-2017-1002101] | Score: 9.6 (CRITICAL) / 8.8 (HIGH) |

Keep in mind that this list isn't exhaustive. To learn more, see [Kubernetes v1.33: User Namespaces enabled by default](https://kubernetes.io/blog/2025/04/25/userns-enabled-by-default/).

:::zone-end

:::zone pivot="apparmor"

## AppArmor prerequisites

- An existing AKS cluster. If you don't have a cluster, create one using the [Azure CLI][aks-quickstart-cli], [Azure PowerShell][aks-quickstart-powershell], or the [Azure portal][aks-quickstart-portal].

## AppArmor limitations

- Azure Linux 3.0 doesn't offer AppArmor support. For Azure Linux 3.0 nodes, we recommend using SELinux instead of AppArmor for mandatory access control.

## Overview of AppArmor

To limit container actions, you can use the [AppArmor][k8s-apparmor] Linux kernel security module. AppArmor is available as part of the underlying AKS node operating system (OS) and is enabled by default. You can create AppArmor profiles that restrict read, write, or execute actions, or system functions like mounting filesystems. Default AppArmor profiles restrict access to various `/proc` and `/sys` locations and provide a means to logically isolate containers from the underlying node. AppArmor works for any application that runs on Linux, not just Kubernetes pods.

> [!NOTE]
> Before Kubernetes v1.30, AppArmor was specified through annotations. From v1.30 onwards, AppArmor is specified through the `securityContext` field in the pod specification. For more information, see the [Kubernetes AppArmor documentation][k8s-apparmor].

![AppArmor profiles in use in an AKS cluster to limit container actions](media/operator-best-practices-container-security/apparmor.png)

## Secure pods with AppArmor

You can specify AppArmor profiles at the pod or container level. The container AppArmor profile takes precedence over the pod AppArmor profile. If neither is specified, the container runs unconfined. For more information on AppArmor profiles, see the [Securing a Pod with AppArmor Kubernetes documentation][k8s-apparmor].

## Configure a custom AppArmor profile

The following example creates a profile that prevents writing to files from within a container.

1. [SSH][aks-ssh] to an AKS node.
1. Create a file named _deny-write.profile_ and paste in the following content:

    ```bash
    #include <tunables/global>
    
    profile k8s-apparmor-example-deny-write flags=(attach_disconnected) {
      #include <abstractions/base>
    
      file,
    
      # Deny all file writes.
      deny /** w,
    }
    ```

1. Load the AppArmor profile onto the node.

    ```bash
    # This example assumes that node names match host names, and are reachable via SSH.
    NODES=($( kubectl get node -o jsonpath='{.items[*].status.addresses[?(.type == "Hostname")].address}' ))
    
    for NODE in ${NODES[*]}; do ssh $NODE 'sudo apparmor_parser -q <<EOF
    #include <tunables/global>
    
    profile k8s-apparmor-example-deny-write flags=(attach_disconnected) {
      #include <abstractions/base>
    
      file,
    
      # Deny all file writes.
      deny /** w,
    }
    EOF'
    done
    ```

## Deploy a pod with the custom AppArmor profile

1. Deploy a _"Hello AppArmor"_ pod with the deny-write profile.

    ```yml
    apiVersion: v1
    kind: Pod
    metadata:
      name: hello-apparmor
    spec:
      securityContext:
        appArmorProfile:
          type: Localhost
          localhostProfile: k8s-apparmor-example-deny-write
      containers:
      - name: hello
        image: busybox:1.28
        command: [ "sh", "-c", "echo 'Hello AppArmor!' && sleep 1h" ]
    ```

2. Apply the pod manifest using the `kubectl apply` command.

    ```bash
    kubectl apply -f hello-apparmor.yaml
    ```

3. Exec into the pod and verify the container is running with the AppArmor profile.

    ```bash
    kubectl exec hello-apparmor -- cat /proc/1/attr/current
    ```

    The output should show the AppArmor profile in use. For example:

    ```output
    k8s-apparmor-example-deny-write (enforce)
    ```

:::zone-end

:::zone pivot="seccomp"

## Seccomp prerequisites

- An existing AKS cluster. If you don't have a cluster, create one using the [Azure CLI][aks-quickstart-cli], [Azure PowerShell][aks-quickstart-powershell], or the [Azure portal][aks-quickstart-portal].
- You need to [register the `KubeletDefaultSeccompProfilePreview` feature flag](#register-the-kubeletdefaultseccompprofilepreview-feature-flag) to use default seccomp profiles on your node pools.

### Register the `KubeletDefaultSeccompProfilePreview` feature flag

[!INCLUDE [preview features callout](~/reusable-content/ce-skilling/azure/includes/aks/includes/preview/preview-callout.md)]

1. Register the `KubeletDefaultSeccompProfilePreview` feature flag using the [`az feature register`][az-feature-register] command.

    ```azurecli-interactive
    az feature register --namespace "Microsoft.ContainerService" --name "KubeletDefaultSeccompProfilePreview"
    ```

    It takes a few minutes for the status to show _Registered_.

1. Verify the registration status using the [`az feature show`][az-feature-show] command.

    ```azurecli-interactive
    az feature show --namespace "Microsoft.ContainerService" --name "KubeletDefaultSeccompProfilePreview"
    ```

1. When the status reflects _Registered_, refresh the registration of the _Microsoft.ContainerService_ resource provider using the [`az provider register`][az-provider-register] command.

    ```azurecli-interactive
    az provider register --namespace Microsoft.ContainerService
    ```

## Seccomp limitations

- `SeccompDefault` isn't a supported parameter for Windows node pools.
- `SeccompDefault` is available starting with the `2024-09-02-preview` API.

## Overview of default seccomp profiles (preview)

While AppArmor works for any Linux application, [seccomp (or _secure computing_)][seccomp] works at the process level. Seccomp is also a Linux kernel security module and is natively supported by the `containerd` runtime used by AKS nodes. With seccomp, you can limit a container's system calls. Seccomp establishes an extra layer of protection against common system call vulnerabilities exploited by malicious actors and allows you to specify a default profile for all workloads in the node.

You can apply default seccomp profiles using [custom node configurations][custom-node-configuration] when creating a new Linux node pool. There are two values supported on AKS include `RuntimeDefault` and `Unconfined`. Some workloads might require a lower number of syscall restrictions than others. This means that they can fail during runtime with the `RuntimeDefault` profile. To mitigate such a failure, you can specify the `Unconfined` profile. If your workload requires a custom profile, see [Configure a custom seccomp profile](#configure-a-custom-seccomp-profile).

### Restrict container system calls with seccomp

1. [Follow steps to apply a seccomp profile in your kubelet configuration][custom-node-configuration] by specifying `"seccompDefault": "RuntimeDefault"`.
1. Check that the configuration was applied to the nodes by [connecting to the host][node-access] and verifying configuration changes were made on the filesystem.

#### Resolve workload failures with seccomp

When `SeccompDefault` is enabled, the container runtime default seccomp profile is used by default for all workloads scheduled on the node, which might cause workloads to fail due to blocked syscalls. If a workload failure occurs, you might see errors such as:

- Workload is existing unexpectedly after the feature is enabled, with "permission denied" error.
- Seccomp error messages can also be seen in auditd or syslog by replacing SCMP_ACT_ERRNO with SCMP_ACT_LOG in the default profile.

If you experience these errors, we recommend that you change your seccomp profile to `Unconfined`. `Unconfined` places no restrictions on syscalls, allowing all system calls to be executed.

## Overview of custom seccomp profiles

With a custom seccomp profile, you have more granular control over restricted syscalls by using filters to specify what actions to allow or deny, and annotating within a pod YAML manifest to associate with the seccomp filter.

> [!NOTE]
> For help troubleshooting your seccomp profile, see [Troubleshoot seccomp profile configuration in Azure Kubernetes Service (AKS)](/troubleshoot/azure/azure-kubernetes/security/troubleshoot-seccomp-profiles).

### Configure a custom seccomp profile

To see seccomp in action, create a filter that prevents changing permissions on a file.

1. [SSH][aks-ssh] to an AKS node.
1. Create a seccomp filter named _/var/lib/kubelet/seccomp/prevent-chmod_.
1. Copy and paste the following content:

    ```json
    {
      "defaultAction": "SCMP_ACT_ALLOW",
      "syscalls": [
        {
          "name": "chmod",
          "action": "SCMP_ACT_ERRNO"
        },
        {
          "name": "fchmodat",
          "action": "SCMP_ACT_ERRNO"
        },
        {
          "name": "chmodat",
          "action": "SCMP_ACT_ERRNO"
        }
      ]
    }
    ```

    In version 1.19 and later, you need to configure:

    ```json
    {
      "defaultAction": "SCMP_ACT_ALLOW",
      "syscalls": [
        {
          "names": ["chmod","fchmodat","chmodat"],
          "action": "SCMP_ACT_ERRNO"
        }
      ]
    }
    ```

1. From your local machine, create a pod manifest named _aks-seccomp.yaml_ and paste the following content. This manifest defines an annotation for `seccomp.security.alpha.kubernetes.io` and references the existing _prevent-chmod_ filter.

    ```yaml
    apiVersion: v1
    kind: Pod
    metadata:
      name: chmod-prevented
      annotations:
        seccomp.security.alpha.kubernetes.io/pod: localhost/prevent-chmod
    spec:
      containers:
      - name: chmod
        image: mcr.microsoft.com/dotnet/runtime-deps:6.0
        command:
          - "chmod"
        args:
         - "777"
         - /etc/hostname
      restartPolicy: Never
    ```

    In version 1.19 and later, you need to configure:

    ```yaml
    apiVersion: v1
    kind: Pod
    metadata:
      name: chmod-prevented
    spec:
      securityContext:
        seccompProfile:
          type: Localhost
          localhostProfile: prevent-chmod
      containers:
      - name: chmod
        image: mcr.microsoft.com/dotnet/runtime-deps:6.0
        command:
          - "chmod"
        args:
         - "777"
         - /etc/hostname
      restartPolicy: Never
    ```

1. Deploy the sample pod using the [`kubectl apply`][kubectl-apply] command:

    ```bash
    kubectl apply -f ./aks-seccomp.yaml
    ```

1. View the pod status using the [`kubectl get pods`][kubectl-get] command.

    ```bash
    kubectl get pods
    ```

    In the output, you should see the pod reports an error. The `chmod` command is prevented from running by the seccomp filter, as shown in the example output:

    ```output
    NAME                      READY     STATUS    RESTARTS   AGE
    chmod-prevented           0/1       Error     0          7s
    ```

:::zone-end

## Seccomp security profile options

Seccomp security profiles are a set of defined syscalls that are allowed or restricted. Most container runtimes have a default seccomp profile that's similar if not the same as the one Docker uses. For more information about available profiles, see the [Docker][seccomp] or [containerd](https://github.com/containerd/containerd/blob/f0a32c66dad1e9de716c9960af806105d691cd78/contrib/seccomp/seccomp_default.go#L51) default seccomp profiles.

AKS uses the [containerd](https://github.com/containerd/containerd/blob/f0a32c66dad1e9de716c9960af806105d691cd78/contrib/seccomp/seccomp_default.go#L51) default seccomp profile for the `RuntimeDefault` when you configure seccomp using [custom node configuration][custom-node-configuration].

### Significant syscalls blocked by default profile

Both [Docker][seccomp] and [containerd](https://github.com/containerd/containerd/blob/f0a32c66dad1e9de716c9960af806105d691cd78/contrib/seccomp/seccomp_default.go#L51) maintain allowlists of safe syscalls. When changes are made to [Docker][seccomp] and [containerd](https://github.com/containerd/containerd/blob/f0a32c66dad1e9de716c9960af806105d691cd78/contrib/seccomp/seccomp_default.go#L51), AKS updates the default configuration to match. Updates to this list might cause workload failure. For release updates, see [AKS release notes](https://github.com/Azure/AKS/releases).

The following table lists significant syscalls that are effectively blocked because they aren't on the allowlist. This list isn't exhaustive. If your workload requires any of the blocked syscalls, don't use the `RuntimeDefault` seccomp profile.

|  Blocked syscall | Description  |
|--------------|-------------------|
| `acct`| Accounting syscall, which could let containers disable their own resource limits or process accounting. Also gated by `CAP_SYS_PACCT`. |
|`add_key` | Prevent containers from using the kernel keyring, which isn't namespaced. |
| `bpf` |	Deny loading potentially persistent bpf programs into kernel, already gated by `CAP_SYS_ADMIN`. |
| `clock_adjtime` |	Time/date isn't namespaced. Also gated by `CAP_SYS_TIME`. |
|`clock_settime` |	Time/date isn't namespaced. Also gated by `CAP_SYS_TIME`.|
| `clone` |	Deny cloning new namespaces. Also gated by `CAP_SYS_ADMIN for CLONE_*` flags, except `CLONE_NEWUSER`. |
| `create_module` |	Deny manipulation and functions on kernel modules. Obsolete. Also gated by `CAP_SYS_MODULE`. |
| `delete_module` |	Deny manipulation and functions on kernel modules. Also gated by `CAP_SYS_MODULE`. |
| `finit_module` |	Deny manipulation and functions on kernel modules. Also gated by `CAP_SYS_MODULE`.|
| `get_kernel_syms`|	Deny retrieval of exported kernel and module symbols. Obsolete.|
|`get_mempolicy` |	Syscall that modifies kernel memory and NUMA settings. Already gated by `CAP_SYS_NICE`. |
|`init_module` |	Deny manipulation and functions on kernel modules. Also gated by `CAP_SYS_MODULE`.|
|`ioperm` |	Prevent containers from modifying kernel I/O privilege levels. Already gated by `CAP_SYS_RAWIO`.|
|`iopl` |	Prevent containers from modifying kernel I/O privilege levels. Already gated by `CAP_SYS_RAWIO`.|
|`kcmp` |	Restrict process inspection capabilities, already blocked by dropping `CAP_SYS_PTRACE`.|
|`kexec_file_load` |	Sister syscall of kexec_load that does the same thing, slightly different arguments. Also gated by `CAP_SYS_BOOT`.|
|`kexec_load` |	Deny loading a new kernel for later execution. Also gated by `CAP_SYS_BOOT`.|
|`keyctl` |	Prevent containers from using the kernel keyring, which isn't namespaced.|
|`lookup_dcookie` |	Tracing/profiling syscall, which could leak information on the host. Also gated by `CAP_SYS_ADMIN`.|
|`mbind` |	Syscall that modifies kernel memory and NUMA settings. Already gated by `CAP_SYS_NICE`.|
|`mount` |	Deny mounting, already gated by `CAP_SYS_ADMIN`.|
|`move_pages` |	Syscall that modifies kernel memory and NUMA settings.|
|`nfsservctl` |	Deny interaction with the kernel nfs daemon. Obsolete since Linux 3.1.|
|`open_by_handle_at` |	Cause of an old container breakout. Also gated by `CAP_DAC_READ_SEARCH`.|
|`perf_event_open` |	Tracing/profiling syscall, which could leak information on the host.|
|`personality` |	Prevent container from enabling BSD emulation. Not inherently dangerous, but poorly tested, potential for kernel vulns.|
|`pivot_root` |	Deny pivot_root, should be privileged operation.|
|`process_vm_readv` |	Restrict process inspection capabilities, already blocked by dropping `CAP_SYS_PTRACE`.|
|`process_vm_writev` |	Restrict process inspection capabilities, already blocked by dropping `CAP_SYS_PTRACE`.|
|`ptrace` |	Tracing/profiling syscall. Blocked in Linux kernel versions before 4.8 to avoid seccomp bypass. Tracing/profiling arbitrary processes is already blocked by dropping CAP_SYS_PTRACE, because it could leak information on the host.|
|`query_module` |	Deny manipulation and functions on kernel modules. Obsolete.|
|`quotactl` |	Quota syscall, which could let containers disable their own resource limits or process accounting. Also gated by `CAP_SYS_ADMIN`.|
|`reboot` |	Don't let containers reboot the host. Also gated by `CAP_SYS_BOOT`.|
|`request_key` |	Prevent containers from using the kernel keyring, which isn't namespaced.|
|`set_mempolicy` |	Syscall that modifies kernel memory and NUMA settings. Already gated by `CAP_SYS_NICE`.|
|`setns` |	Deny associating a thread with a namespace. Also gated by `CAP_SYS_ADMIN`.|
|`settimeofday` |	Time/date isn't namespaced. Also gated by `CAP_SYS_TIME`.|
|`stime` |	Time/date isn't namespaced. Also gated by `CAP_SYS_TIME`.|
|`swapon` |	Deny start/stop swapping to file/device. Also gated by `CAP_SYS_ADMIN`.|
|`swapoff` |	Deny start/stop swapping to file/device. Also gated by `CAP_SYS_ADMIN`.|
|`sysfs` |	Obsolete syscall.|
|`_sysctl` |	Obsolete, replaced by /proc/sys.|
|`umount` |	Should be a privileged operation. Also gated by `CAP_SYS_ADMIN`.|
|`umount2` |	Should be a privileged operation. Also gated by `CAP_SYS_ADMIN`.|
|`unshare` |	Deny cloning new namespaces for processes. Also gated by `CAP_SYS_ADMIN`, with the exception of unshare --user.|
|`uselib` |	Older syscall related to shared libraries, unused for a long time.|
|`userfaultfd` |	Userspace page fault handling, largely needed for process migration.|
|`ustat` |	Obsolete syscall.|
|`vm86` |	In kernel x86 real mode virtual machine. Also gated by `CAP_SYS_ADMIN`.|
|`vm86old` |	In kernel x86 real mode virtual machine. Also gated by `CAP_SYS_ADMIN`.|

## Related content

To learn more about securing your AKS cluster, see the following articles:

- [Best practices for cluster security and upgrades in AKS][operator-best-practices-cluster-security]
- [Best practices for pod security in AKS][developer-best-practices-pod-security]

<!-- EXTERNAL LINKS -->
[k8s-apparmor]: https://kubernetes.io/docs/tutorials/clusters/apparmor/
[seccomp]: https://kubernetes.io/docs/reference/node/seccomp/
[kubectl-apply]: https://kubernetes.io/docs/reference/generated/kubectl/kubectl-commands#apply
[kubectl-get]: https://kubernetes.io/docs/reference/generated/kubectl/kubectl-commands#get
[userns-man]: https://man7.org/linux/man-pages/man7/user_namespaces.7.html
[cve-2019-5716]: https://nvd.nist.gov/vuln/detail/CVE-2019-5736
[cve-2024-21262]: https://github.com/opencontainers/runc/security/advisories/GHSA-xr7r-f8xq-vfvv
[cve-2022-0492]: https://unit42.paloaltonetworks.com/cve-2022-0492-cgroups/
[cve-2021-25741]: https://nvd.nist.gov/vuln/detail/CVE-2021-25741
[cve-2017-1002101]: https://nvd.nist.gov/vuln/detail/CVE-2017-1002101
[k8s-userns]: https://kubernetes.io/docs/concepts/workloads/pods/user-namespaces/
[userns-requirements]: https://kubernetes.io/docs/concepts/workloads/pods/user-namespaces/#before-you-begin

<!-- LINKS - Internal -->
[operator-best-practices-cluster-security]: operator-best-practices-cluster-security.md
[developer-best-practices-pod-security]: developer-best-practices-pod-security.md
[custom-node-configuration]: /azure/aks/custom-node-configuration
[az-feature-register]: /cli/azure/feature#az-feature-register
[az-feature-show]: /cli/azure/feature#az-feature-show
[az-provider-register]: /cli/azure/provider#az-provider-register
[aks-ssh]: manage-ssh-node-access.md
[pod-security-contexts]: https://kubernetes.io/docs/concepts/security/pod-security-standards/
[node-access]: node-access.md
[upgrade-os-version]: upgrade-os-version.md
[aks-quickstart-cli]: ./learn/quick-kubernetes-deploy-cli.md
[aks-quickstart-portal]: ./learn/quick-kubernetes-deploy-portal.md
[aks-quickstart-powershell]: ./learn/quick-kubernetes-deploy-powershell.md
[upgrade-aks-cluster]: ./upgrade-aks-cluster.md
