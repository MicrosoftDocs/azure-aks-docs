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
# Customer intent: As a cloud security administrator, I want to implement least privilege access for containers in Kubernetes so that I can minimize risks of unauthorized actions and potential attacks on our resources.
---

# Security container access to resources using built-in Linux security features

In this article, you learn how to secure container access to resources for your Azure Kubernetes Service (AKS) workloads.

## Overview

In the same way that you should grant users or groups the minimum privileges required, you should also limit containers to only necessary actions and processes. To minimize the risk of attack, avoid configuring applications and containers that require escalated privileges or root access. 

You can use built-in Kubernetes *pod security contexts* to define more permissions, such as the user or group to run as, the Linux capabilities to expose, or setting `allowPrivilegeEscalation: false` in the pod manifest. For more best practices, see [Secure pod access to resources][pod-security-contexts].

To improve the host isolation and decrease lateral movement on Linux, you can use *user-namespaces*.

For even more granular control of container actions, you can use built-in Linux security features such as *AppArmor* and *seccomp*.

1. Define Linux security features at the node level.
1. Implement features through a pod manifest.

Built-in Linux security features are only available on Linux nodes and pods.

> [!NOTE]
> Currently, Kubernetes environments aren't completely safe for hostile multitenant usage. Additional security features, like *Microsoft Defender for Containers*, *AppArmor*, *seccomp*, *user-namespaces*, *Pod Security Admission*, or *Kubernetes RBAC for nodes*, efficiently block exploits.
>
> For true security when running hostile multitenant workloads, only trust a hypervisor. The security domain for Kubernetes becomes the entire cluster, not an individual node. 
>
> For these types of hostile multitenant workloads, you should use physically isolated clusters.

## User-namespaces

Linux pods run using several namespaces by default: a network namespaces to isolate the network identity and a PID namespace to isolate the processes. A [user-namespace][userns-man] isolates the users inside the container from the users on the host. It also limits the scope of capabilities and the pod's interactions with the rest of the system.

The UIDs and GIDs inside the container are mapped to unprivileged users on the host, so all interaction with the rest of the host happen as those unprivileged UID and GID. For example, root inside the container (UID 0) can be mapped to user 65536 on the host. Kubernetes creates the mapping to guarantee it doesn't overlap with other pods using user-namespaces on the system.

The Kubernetes implementation has some key benefits:

 * **Increased host isolation**: If a container escapes the pod boundaries, even if it runs as root inside the container, it has no privileges on the host. The reason is because the UIDs and GIDs of the container are mapped to unprivileged users on the host. If there's a container escape, user-namespaces greatly protects what host files a container can read/write, which process it can send signals to. Capabilities granted are only valid inside the user namespace and not on the host.

 * **Prevention of lateral movement**: As the UIDs and GIDs for different containers are mapped to different, nonoverlapping UIDs and GIDs on the host, containers have a harder time attacking each other. For example, suppose container A runs with different UIDs and GIDs on the host than container B. In case of a container breakout, the operations it can do on container B's files and processes are limited: only read/write what a file allows to others. But not even that ends up being possible, as there's an extra prevention on the parent directory of the pod root volume to make sure only the pod GID can access it.

 * **Honor Least-privilege principle**: As the UIDs and GIDs are mapped to unprivileged users on the host, only users that need the privilege on the host (and disable user namespaces) get it. Without user namespaces, there's no separation between container’s users and host’s users. We can’t avoid giving privileges on the host to processes that don't need it, when they need privilege just inside the container.

 * **Enablement of new use cases**: User namespaces allow containers to gain certain capabilities inside their own user namespace without affecting the host. The capabilities granted restricted to the pod unlocks new possibilities, such as running applications that require privileged operations without granting full root access on the host. Common new use-cases that can be implemented securely are: running nested containers and unprivileged container builds.

 * **Unprivileged container setup**: Most of the container creation and setup doesn't run as root on the host, which significantly limits the impact of many CVEs.

None of these things are true when user-namespaces aren't used. If the container runs as root, when user-namespaces aren't used, the process is running as root on the host, the capabilities are valid on the host and the container setup is done as root on the host.

### Before you begin

Before you begin, make sure you have the following:

* An existing AKS cluster. If you don't have a cluster, create one using the [Azure CLI][aks-quickstart-cli], [Azure PowerShell][aks-quickstart-powershell], or the [Azure portal][aks-quickstart-portal].
* Minimum kubernetes version 1.33 for the control plane and worker nodes. If you're not using kubernetes version 1.33 or higher, you'll need to [upgrade your kubernetes version][upgrade-aks-cluster].
* Worker nodes running Azure Linux 3.0 or Ubuntu 24.04. If you're not using these OS versions, you will not have the minimum [stack requirements][userns-requirements] to enable user-namespaces. You'll need to [upgrade your OS version][upgrade-os-version].

### Limitations

* User-namespaces is a linux kernel feature and is not supported for Windows node pools.
* Don't hesitate to check the [Kubernetes documentation for user namespaces][k8s-userns], in particular the limitations section.


### How to use

There are no configurations needed to use this feature. If using the required AKS version, everything works out of the box.

Let's create an example pod. It needs to have the field `hostUsers: false`, to use user-namespces.

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

Save it to _mypod.yaml_ and run `kubectl apply -f mypod.yaml`. Check the pod state, until it's running: `kubectl get pods`.

Then, exec into the pod to check `/proc/self/uid_map`:

```
kubectl exec -ti userns -- bash
# Now inside the pod run
cat /proc/self/uid_map
```

The output should have 65536 in the last column. For example:

```output
0  833617920      65536
```

Don't hesitate to check the [Kubernetes documentation for user namespaces][k8s-userns], in particular the limitations section.

### CVEs mitigated

Here are some CVEs that are completely/partially mitigated with user-namespaces.

Bear in mind the list isn't exhaustive, it's just a selection of CVEs with high score that are mitigated:

* [CVE-2019-5736][cve-2019-5716] - Score 8.6 (HIGH)
* [CVE 2024-21262][cve-2024-21262]: Score 8.6 (HIGH)
* [CVE 2022-0492][cve-2022-0492]: Score 7.8 (HIGH)
* [CVE-2021-25741][cve-2021-25741]: Score: 8.1 (HIGH) / 8.8 (HIGH)
* [CVE-2017-1002101][cve-2017-1002101]: Score: 9.6 (CRITICAL) / 8.8(HIGH)
To learn more, read this [blog post](https://kubernetes.io/blog/2025/04/25/userns-enabled-by-default/) with additional information around user-namespaces. 

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

    If the profile is correctly parsed and applied to AppArmor, you won't see any output and you'll return to the command prompt.

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

While AppArmor works for any Linux application, [seccomp (*sec*ure *comp*uting)][seccomp] works at the process level. Seccomp is also a Linux kernel security module and is natively supported by the `containerd` runtime used by AKS nodes. With seccomp, you can limit a container's system calls. Seccomp establishes an extra layer of protection against common system call vulnerabilities exploited by malicious actors and allows you to specify a default profile for all workloads in the node.

### Configure a default seccomp profile (preview)

You can apply default seccomp profiles using [custom node configurations][custom-node-configuration] when creating a new Linux node pool. There are two values supported on AKS: `RuntimeDefault` and `Unconfined`. Some workloads might require a lower number of syscall restrictions than others. This means that they can fail during runtime with the 'RuntimeDefault' profile. To mitigate such a failure, you can specify the `Unconfined` profile. If your workload requires a custom profile, see [Configure a custom seccomp profile](#configure-a-custom-seccomp-profile).

#### Limitations

- SeccompDefault is not a supported parameter for windows node pools.
- SeccompDefault is available starting in 2024-09-02-preview API.

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

**1. [Follow steps to apply a seccomp profile in your kubelet configuration][custom-node-configuration] by specifying `"seccompDefault": "RuntimeDefault"`**.

`RuntimeDefault` uses containerd's default seccomp profile, restricting certain system calls to enhance security. Restricted syscalls will fail. For more information, see the [containerD default seccomp profile](https://github.com/containerd/containerd/blob/f0a32c66dad1e9de716c9960af806105d691cd78/contrib/seccomp/seccomp_default.go#L51). 

**2. Check that the configuration was applied**.

You can confirm the settings are applied to the nodes by [connecting to the host][node-access] and verifying configuration changes have been made on the filesystem.

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

1. Deploy the sample pod using the [kubectl apply][kubectl-apply] command:

    ```console
    kubectl apply -f ./aks-seccomp.yaml
    ```

1. View pod status using the [kubectl get pods][kubectl-get] command.

    * The pod reports an error. 
    * The `chmod` command is prevented from running by the seccomp filter, as shown in the example output:

    ```
    kubectl get pods

    NAME                      READY     STATUS    RESTARTS   AGE
    chmod-prevented           0/1       Error     0          7s
    ```

For help troubleshooting your seccomp profile see the article [Troubleshoot seccomp profile configuration in Azure Kubernetes Service](/troubleshoot/azure/azure-kubernetes/security/troubleshoot-seccomp-profiles).
## Seccomp security profile options

Seccomp security profiles are a set of defined syscalls that are allowed or restricted. Most container runtimes have a default seccomp profile that is similar if not the same as the one Docker uses. For more information about available profiles, see [Docker][seccomp] or [containerD](https://github.com/containerd/containerd/blob/f0a32c66dad1e9de716c9960af806105d691cd78/contrib/seccomp/seccomp_default.go#L51) default seccomp profiles.

AKS uses the [containerD](https://github.com/containerd/containerd/blob/f0a32c66dad1e9de716c9960af806105d691cd78/contrib/seccomp/seccomp_default.go#L51) default seccomp profile for our RuntimeDefault when you configure seccomp using [custom node configuration][custom-node-configuration].

### Significant syscalls blocked by default profile

Both [Docker][seccomp] and [containerD](https://github.com/containerd/containerd/blob/f0a32c66dad1e9de716c9960af806105d691cd78/contrib/seccomp/seccomp_default.go#L51)  maintain allowlists of safe syscalls. This table lists the significant (but not all) syscalls that are effectively blocked because they aren't on the allowlist. If any of the blocked syscalls are required by your workload, don't use the `RuntimeDefault` seccomp profile.

When changes are made to [Docker][seccomp] and [containerD](https://github.com/containerd/containerd/blob/f0a32c66dad1e9de716c9960af806105d691cd78/contrib/seccomp/seccomp_default.go#L51), AKS updates their default configuration to match. Updates to this list may cause workload failure. For release updates, see [AKS release notes](https://github.com/Azure/AKS/releases).

|  Blocked syscall | Description  | 
|--------------|-------------------|
| `acct`| Accounting syscall which could let containers disable their own resource limits or process accounting. Also gated by `CAP_SYS_PACCT`. | 
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
|`quotactl` |	Quota syscall which could let containers disable their own resource limits or process accounting. Also gated by `CAP_SYS_ADMIN`.|
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

## Next steps

For associated best practices, see [Best practices for cluster security and upgrades in AKS][operator-best-practices-cluster-security] and [Best practices for pod security in AKS][developer-best-practices-pod-security].

<!-- EXTERNAL LINKS -->
[k8s-apparmor]: https://kubernetes.io/docs/tutorials/clusters/apparmor/
[seccomp]: https://kubernetes.io/docs/reference/node/seccomp/
[kubectl-apply]: https://kubernetes.io/docs/reference/generated/kubectl/kubectl-commands#apply
[kubectl-exec]: https://kubernetes.io/docs/reference/generated/kubectl/kubectl-commands#exec
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
[security-best-practices]: /azure/aks/operator-best-practices-cluster-security
[az-feature-register]: /cli/azure/feature#az-feature-register
[az-feature-show]: /cli/azure/feature#az-feature-show
[az-provider-register]: /cli/azure/provider#az-provider-register
[aks-ssh]: manage-ssh-node-access.md
[pod-security-contexts]: https://kubernetes.io/docs/concepts/security/pod-security-standards/
[node-access]: node-access.md
[security-container-access]: secure-container-access.md
[troubleshoot-seccomp-profiles]: support\azure\azure-kubernetes\security\troubleshoot-seccomp-profiles.md
[ubuntu-2404]: upgrade-os-version.md
