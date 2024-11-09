---
title: Secure container access to resources
titleSuffix: Azure Kubernetes Service (AKS)
description: Learn how to limit access to actions that containers can perform, provide the least number of permissions, and avoid the use of root access or privileged escalation.
author: allyford
ms.topic: how-to
ms.subservice: aks-security
ms.service: azure-kubernetes-service
ms.date: 11/08/2024
ms.author: allyford
---

# Security container access to resources using built-in Linux security features

In this article, you learn how to secure container access to resources for your Azure Kubernetes Service (AKS) workloads.

## Overview

In the same way that you should grant users or groups the minimum privileges required, you should also limit containers to only necessary actions and processes. To minimize the risk of attack, avoid configuring applications and containers that require escalated privileges or root access. 

You can use built-in Kubernetes *pod security contexts* to define additional permissions, such as the user or group to run as, the Linux capabilities to expose, or setting `allowPrivilegeEscalation: false` in the pod manifest. For more best practices, see [Secure pod access to resources][pod-security-contexts].

For even more granular control of container actions, you can use built-in Linux security features such as *AppArmor* and *seccomp*.

1. Define Linux security features at the node level.
1. Implement features through a pod manifest.

Built-in Linux security features are only available on Linux nodes and pods.

> [!NOTE]
> Currently, Kubernetes environments aren't completely safe for hostile multi-tenant usage. Additional security features, like *Microsoft Defender for Containers*, *AppArmor*, *seccomp*, *Pod Security Admission*, or *Kubernetes RBAC for nodes*, efficiently block exploits.
>
> For true security when running hostile multi-tenant workloads, only trust a hypervisor. The security domain for Kubernetes becomes the entire cluster, not an individual node. 
>
> For these types of hostile multi-tenant workloads, you should use physically isolated clusters.

## App Armor

To limit container actions, you can use the [AppArmor][k8s-apparmor] Linux kernel security module. AppArmor is available as part of the underlying AKS node OS and is enabled by default. You create AppArmor profiles that restrict read, write, or execute actions, or system functions like mounting filesystems. Default AppArmor profiles restrict access to various `/proc` and `/sys` locations and provide a means to logically isolate containers from the underlying node. AppArmor works for any application that runs on Linux, not just Kubernetes pods.

![AppArmor profiles in use in an AKS cluster to limit container actions](media/operator-best-practices-container-security/apparmor.png)

To see AppArmor in action, the following example creates a profile that prevents writing to files.

1. [SSH][aks-ssh] to an AKS node.
1. Create a file named *deny-write.profile*.
1. Copy and paste the following content:

    ```bash
    #include <tunables/global>
    profile k8s-apparmor-example-deny-write flags=(attach_disconnected) {
      #include <abstractions/base>
  
      file,
      # Deny all file writes.
      deny /** w,
    }
    ```

AppArmor profiles are added using the `apparmor_parser` command.

1. Add the profile to AppArmor.
1. Specify the name of the profile created in the previous step:

    ```console
    sudo apparmor_parser deny-write.profile
    ```

    If the profile is correctly parsed and applied to AppArmor, you won't see any output and you'll be returned to the command prompt.

1. From your local machine, create a pod manifest named *aks-apparmor.yaml*. This manifest:
    * Defines an annotation for `container.apparmor.security.beta.kubernetes`.
    * References the *deny-write* profile created in the previous steps.

    ```yaml
    apiVersion: v1
    kind: Pod
    metadata:
      name: hello-apparmor
      annotations:
        container.apparmor.security.beta.kubernetes.io/hello: localhost/k8s-apparmor-example-deny-write
    spec:
      containers:
      - name: hello
        image: mcr.microsoft.com/dotnet/runtime-deps:6.0
        command: [ "sh", "-c", "echo 'Hello AppArmor!' && sleep 1h" ]
    ```

1. With the pod deployed, run the following command and verify the *hello-apparmor* pod shows a *Running* status:

    ```bash
    kubectl get pods
    
    NAME             READY   STATUS    RESTARTS   AGE
    aks-ssh          1/1     Running   0          4m2s
    hello-apparmor   0/1     Running   0          50s
    ```

For more information about AppArmor, see [AppArmor profiles in Kubernetes][k8s-apparmor].

## Secure computing (seccomp)

While AppArmor works for any Linux application, [seccomp (*sec*ure *comp*uting)][seccomp] works at the process level. Seccomp is also a Linux kernel security module and is natively supported by the `containerd` runtime used by AKS nodes. With seccomp, you can limit a container's system calls. This establishes an extra layer of protection against common system call vulnerabilities exploited by malicious actors and allows you to specify a default seccomp profile for all workloads in the node.

### Configure a default seccomp profile (preview)

You can apply default seccomp profiles using [custom node configurations][custom-node-configuration] when creating a new Linux node pool. There are two values supported on AKS: `RuntimeDefault` and `Unconfined`. Some workloads might require a lower amount of syscall restrictions than others. This means that they can fail during runtime with the 'RuntimeDefault' profile. To mitigate such a failure, you can specify the `Unconfined` profile. If your workload requires a completely custom profile, see [Configure a custom seccomp profile](#configure-a-custom-seccomp-profile).

[!INCLUDE [preview features callout](~/reusable-content/ce-skilling/azure/includes/aks/includes/preview/preview-callout.md)]

#### Register the `KubeletDefaultSeccompProfilePreview` feature flag

1. Register the `KubeletDefaultSeccompProfilePreview` feature flag using the [`az feature register`][az-feature-register] command.

    ```azurecli-interactive
    az feature register --namespace "Microsoft.ContainerService" --name "KubeletDefaultSeccompProfilePreview"
    ```

    It takes a few minutes for the status to show *Registered*.

2. Verify the registration status using the [`az feature show`][az-feature-show] command.

    ```azurecli-interactive
    az feature show --namespace "Microsoft.ContainerService" --name "KubeletDefaultSeccompProfilePreview"
    ```

3. When the status reflects *Registered*, refresh the registration of the *Microsoft.ContainerService* resource provider using the [`az provider register`][az-provider-register] command.

    ```azurecli-interactive
    az provider register --namespace Microsoft.ContainerService
    ```

#### Restrict your container's system calls with seccomp

**1. [Follow steps to apply a seccomp profile in your kubelet configuration][custom-node-configuration] by specifying `"seccompDefualt": "RuntimeDefault"`**.

`RuntimeDefault` uses containerd's default seccomp profile, restricting certain system calls to enhance security. Restricted syscalls will fail. For more details, see the [containerD default seccomp profile](https://github.com/containerd/containerd/blob/f0a32c66dad1e9de716c9960af806105d691cd78/contrib/seccomp/seccomp_default.go#L51). 

**2. Check that the configuration was applied**.

After you apply custom node configuration, you can confirm the settings have been applied to the nodes by [connecting to the host][node-access] and verifying configuration changes have been made on the filesystem.

**3. Troubleshoot workload failures**.

When SeccompDefault is enabled, the container runtime default seccomp profile is used by default for all workloads scheduled on the node. This might cause workloads to fail due to blocked syscalls. If a workload failure has occurred, you might see errors such as:

- Workload is existing unexpectedly after the feature is enabled, with "permission denied" error.
- Seccomp error messages can also be seen in auditd or syslog by replacing SCMP_ACT_ERRNO with SCMP_ACT_LOG in the default profile.

If you experience the above errors, we recommend that you change your seccomp profile to `Unconfined`. `Unconfined` places no restrictions on syscalls, allowing all system calls, which reduces security.

### Configure a custom seccomp profile

With a custom seccomp profile, you can have more granular control over restricted syscalls. Align to the best practice of granting the container minimal permission only to run by:

* Defining with filters what actions to allow or deny.
* Annotating within a pod YAML manifest to associate with the seccomp filter.

To see seccomp in action, create a filter that prevents changing permissions on a file.

1. [SSH][aks-ssh] to an AKS node.
1. Create a seccomp filter named */var/lib/kubelet/seccomp/prevent-chmod*.
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

    In version 1.19 and later, you need to configure the following:

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

1. From your local machine, create a pod manifest named *aks-seccomp.yaml* and paste the following content. This manifest:

    * Defines an annotation for `seccomp.security.alpha.kubernetes.io`.
    * References the *prevent-chmod* filter created in the previous step.

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

    In version 1.19 and later, you need to configure the following:

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

1. Deploy the sample pod using the [kubectl apply][kubectl-apply] command:

    ```console
    kubectl apply -f ./aks-seccomp.yaml
    ```

1. View pod status using the [kubectl get pods][kubectl-get] command.

    * The pod reports an error. 
    * The `chmod` command is prevented from running by the seccomp filter, as shown in the following example output:

    ```
    kubectl get pods

    NAME                      READY     STATUS    RESTARTS   AGE
    chmod-prevented           0/1       Error     0          7s
    ```

## Seccomp security profile options

Seccomp security profiles are a set of defined syscalls that are allowed or restricted. Most container runtimes will have a default seccomp profile that are similar if not the same as the one Docker uses. For more information about available profiles, see [Docker][seccomp] or [containerD](https://github.com/containerd/containerd/blob/f0a32c66dad1e9de716c9960af806105d691cd78/contrib/seccomp/seccomp_default.go#L51) default seccomp profiles.

AKS uses the [containerD](https://github.com/containerd/containerd/blob/f0a32c66dad1e9de716c9960af806105d691cd78/contrib/seccomp/seccomp_default.go#L51) default seccomp profile for our RuntimeDefault when you configure seccomp using [custom node configuration][custom-node-configuration].

### Significant syscalls blocked by default profile

Both [Docker][seccomp] and [containerD](https://github.com/containerd/containerd/blob/f0a32c66dad1e9de716c9960af806105d691cd78/contrib/seccomp/seccomp_default.go#L51)  maintain allowlists of safe syscalls. The table below lists the significant (but not all) syscalls that are effectively blocked because they are not on the allowlist. If any of the below syscalls are required by your workload, do not use the `RuntimeDefault` seccomp profile.

When changes are made to [Docker][seccomp] and [containerD](https://github.com/containerd/containerd/blob/f0a32c66dad1e9de716c9960af806105d691cd78/contrib/seccomp/seccomp_default.go#L51), AKS will update their default configuration to match. Updates to this list may cause workload failure. For release updates, see [AKS release notes](https://github.com/Azure/AKS/releases).

|  Blocked syscall | Description  | 
|--------------|-------------------|
| `acct`| Accounting syscall which could let containers disable their own resource limits or process accounting. Also gated by `CAP_SYS_PACCT`. | 
|`add_key` | Prevent containers from using the kernel keyring, which is not namespaced. |
| `bpf` |	Deny loading potentially persistent bpf programs into kernel, already gated by `CAP_SYS_ADMIN`. |
| `clock_adjtime` |	Time/date is not namespaced. Also gated by `CAP_SYS_TIME`. |
|`clock_settime` |	Time/date is not namespaced. Also gated by `CAP_SYS_TIME`.|
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
|`keyctl` |	Prevent containers from using the kernel keyring, which is not namespaced.|
|`lookup_dcookie` |	Tracing/profiling syscall, which could leak a lot of information on the host. Also gated by `CAP_SYS_ADMIN`.|
|`mbind` |	Syscall that modifies kernel memory and NUMA settings. Already gated by `CAP_SYS_NICE`.|
|`mount` |	Deny mounting, already gated by `CAP_SYS_ADMIN`.|
|`move_pages` |	Syscall that modifies kernel memory and NUMA settings.|
|`nfsservctl` |	Deny interaction with the kernel nfs daemon. Obsolete since Linux 3.1.|
|`open_by_handle_at` |	Cause of an old container breakout. Also gated by `CAP_DAC_READ_SEARCH`.|
|`perf_event_open` |	Tracing/profiling syscall, which could leak a lot of information on the host.|
|`personality` |	Prevent container from enabling BSD emulation. Not inherently dangerous, but poorly tested, potential for a lot of kernel vulns.|
|`pivot_root` |	Deny pivot_root, should be privileged operation.|
|`process_vm_readv` |	Restrict process inspection capabilities, already blocked by dropping `CAP_SYS_PTRACE`.|
|`process_vm_writev` |	Restrict process inspection capabilities, already blocked by dropping `CAP_SYS_PTRACE`.|
|`ptrace` |	Tracing/profiling syscall. Blocked in Linux kernel versions before 4.8 to avoid seccomp bypass. Tracing/profiling arbitrary processes is already blocked by dropping CAP_SYS_PTRACE, because it could leak a lot of information on the host.|
|`query_module` |	Deny manipulation and functions on kernel modules. Obsolete.|
|`quotactl` |	Quota syscall which could let containers disable their own resource limits or process accounting. Also gated by `CAP_SYS_ADMIN`.|
|`reboot` |	Don't let containers reboot the host. Also gated by `CAP_SYS_BOOT`.|
|`request_key` |	Prevent containers from using the kernel keyring, which is not namespaced.|
|`set_mempolicy` |	Syscall that modifies kernel memory and NUMA settings. Already gated by `CAP_SYS_NICE`.|
|`setns` |	Deny associating a thread with a namespace. Also gated by `CAP_SYS_ADMIN`.|
|`settimeofday` |	Time/date is not namespaced. Also gated by `CAP_SYS_TIME`.|
|`stime` |	Time/date is not namespaced. Also gated by `CAP_SYS_TIME`.|
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

## Next steps

For associated best practices, see [Best practices for cluster security and upgrades in AKS][operator-best-practices-cluster-security] and [Best practices for pod security in AKS][developer-best-practices-pod-security].

<!-- EXTERNAL LINKS -->
[k8s-apparmor]: https://kubernetes.io/docs/tutorials/clusters/apparmor/
[seccomp]: https://kubernetes.io/docs/reference/node/seccomp/
[kubectl-apply]: https://kubernetes.io/docs/reference/generated/kubectl/kubectl-commands#apply
[kubectl-exec]: https://kubernetes.io/docs/reference/generated/kubectl/kubectl-commands#exec
[kubectl-get]: https://kubernetes.io/docs/reference/generated/kubectl/kubectl-commands#get

<!-- LINKS - Internal -->
[operator-best-practices-cluster-security]: operator-best-practices-cluster-security.md
[developer-best-practices-pod-security]: developer-best-practices-pod-security.md
[custom-node-configuration]: /azure/aks/custom-node-configuration
[security-best-practices]: /azure/aks/operator-best-practices-cluster-security
[az-feature-register]: /cli/azure/feature#az-feature-register
[az-feature-show]: /cli/azure/feature#az-feature-show
[az-provider-register]: /cli/azure/provider#az-provider-register
[aks-ssh]: manage-ssh-node-access.md
[pod-security-contexts]: https://kubernetes.io/docs/concepts/security/pod-security-standards/
[node-access]: node-access.md
[security-container-access]: secure-container-access.md

