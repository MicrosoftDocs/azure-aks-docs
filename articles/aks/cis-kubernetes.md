---
title: Center for Internet Security (CIS) Kubernetes benchmark
description: Learn how AKS applies the CIS Kubernetes benchmark.
ms.date: 07/30/2025
ms.subservice: aks-security
ms.topic: concept-article
author: allyford
ms.author: allyford
# Customer intent: "As a security compliance officer, I want to understand how Azure Kubernetes Service implements the CIS Kubernetes benchmark, so that I can ensure our container orchestration complies with necessary security standards."
---

# Center for Internet Security (CIS) Kubernetes benchmark

As a secure service, Azure Kubernetes Service (AKS) complies with SOC, ISO, PCI DSS, and HIPAA standards. This article covers the security hardening applied to AKS based on the CIS Kubernetes benchmark. For more information about AKS security, see [Security concepts for applications and clusters in Azure Kubernetes Service (AKS)][security-concepts-aks-apps-clusters]. For more information on the CIS benchmark, see [Center for Internet Security (CIS) Benchmarks][cis-benchmarks].

## Kubernetes CIS benchmark

The following are the results from the [CIS Kubernetes V1.27 Benchmark v1.11.1][cis-benchmark-kubernetes] recommendations on AKS. The results are applicable to AKS 1.29.x through AKS 1.32.x. For support timelines, see [supported Kubernetes versions][supported-kubernetes-versions].

### Security levels

CIS benchmarks provide two levels of security settings:

- _L1_, or Level 1, recommends essential basic security requirements that can be configured on any system and should cause little or no interruption of service or reduced functionality.
- _L2_, or Level 2, recommends security settings for environments requiring greater security that could result in some reduced functionality.

### Assessment status

An assessment status is included for every recommendation. The assessment status indicates whether the given recommendation can be automated or requires manual steps to implement. Both statuses are equally important and are determined and supported as follows:

- _Automated_: Represents recommendations for which assessment of a technical control can be fully automated and validated to a pass/fail state. Recommendations include the necessary information to implement automation.
- _Manual_: Represents recommendations for which assessment of a technical control can't be fully automated and requires all or some manual steps to validate that the configured state is set as expected. The expected state can vary depending on the environment.

_Automated_ recommendations affect the benchmark score if they aren't applied, while _Manual_ recommendations don't.

### Attestation status

Recommendations can have one of the following attestation statuses:

- _Pass_: The recommendation was applied.
- _Fail_: The recommendation wasn't applied.
- _N/A_: The recommendation relates to manifest file permission requirements that aren't relevant to AKS. Kubernetes clusters by default use a manifest model to deploy the control plane pods, which rely on files from the node VM. The CIS Kubernetes benchmark recommends these files must have certain permission requirements. AKS clusters use a Helm chart to deploy control plane pods and don't rely on files in the node VM.
- _Depends on Environment_: The recommendation is applied in the user's specific environment and isn't controlled by AKS. _Automated_ recommendations affect the benchmark score whether the recommendation applies to the user's specific environment or not.
- _Equivalent Control_: The recommendation was implemented in a different, equivalent manner.

### Benchmark details

| CIS ID | Recommendation description | Assessment status | Level | Status | Reason |
|--|--|--|--|--|--|
| 1 | Control Plane Components| | | | |
| 1.1 | Control Plane Node Configuration Files| | | | |
| 1.1.1 | Ensure that the API server pod specification file permissions are set to 600 or more restrictive | Automated | L1 | N/A |N/A because AKS is a managed solution |
| 1.1.2 | Ensure that the API server pod specification file ownership is set to ``root: root`` | Automated | L1 | N/A | N/A because AKS is a managed solution |
| 1.1.3 | Ensure that the controller manager pod specification file permissions are set to 600 or more restrictive | Automated | L1 | N/A | N/A because AKS is a managed solution |
| 1.1.4 | Ensure that the controller manager pod specification file ownership is set to `root: root` | Automated | L1 | N/A | N/A because AKS is a managed solution |
| 1.1.5 | Ensure that the scheduler pod specification file permissions are set to 600 or more restrictive | Automated | L1 | N/A | N/A because AKS is a managed solution |
| 1.1.6 | Ensure that the scheduler pod specification file ownership is set to `root: root` | Automated | L1 | N/A | N/A because AKS is a managed solution |
| 1.1.7 | Ensure that the etcd pod specification file permissions are set to 600 or more restrictive | Automated | L1| N/A | N/A because AKS is a managed solution |
| 1.1.8 | Ensure that the etcd pod specification file ownership is set to `root: root` | Automated | L1 | N/A | N/A because AKS is a managed solution |
| 1.1.9 | Ensure that the Container Network Interface file permissions are set to 600 or more restrictive |Manual | L1 | N/A | N/A because AKS is a managed solution |
| 1.1.10 | Ensure that the Container Network Interface file ownership is set to `root: root` | Manual | L1 | N/A | N/A because AKS is a managed solution |
| 1.1.11 | Ensure that the etcd data directory permissions are set to 700 or more restrictive | Automated | L1 | N/A | N/A because AKS is a managed solution |
| 1.1.12 | Ensure that the etcd data directory ownership is set to `etcd:etcd` | Automated | L1 | N/A | N/A because AKS is a managed solution |
| 1.1.13 | Ensure that the admin.conf file permissions are set to 600 or more restrictive | Automated | L1 | N/A | N/A because AKS is a managed solution |
| 1.1.14 | Ensure that the admin.conf file ownership is set to `root: root` | Automated | L1 | N/A | N/A because AKS is a managed solution |
| 1.1.15 | Ensure that the scheduler.conf file permissions are set to 600 or more restrictive | Automated | L1 | N/A | N/A because AKS is a managed solution |
| 1.1.16 | Ensure that the scheduler.conf file ownership is set to `root: root` | Automated | L1 | N/A | N/A because AKS is a managed solution |
| 1.1.17 | Ensure that the controller-manager.conf file permissions are set to 600 or more restrictive | Automated | L1 | N/A | N/A because AKS is a managed solution |
| 1.1.18 | Ensure that the controller-manager.conf file ownership is set to `root: root` | Automated | L1 | N/A | N/A because AKS is a managed solution |
| 1.1.19 | Ensure that the Kubernetes PKI directory and file ownership are set to `root: root` | Automated |L1 | N/A |N/A because AKS is a managed solution  |
| 1.1.20 | Ensure that the Kubernetes PKI certificate file permissions are set to 600 or more restrictive | Manual | L1 | N/A |N/A because AKS is a managed solution |
| 1.1.21 | Ensure that the Kubernetes PKI key file permissions are set to 600 | Manual | L1 | N/A |N/A because AKS is a managed solution |
| 1.2 | API Server | | | | |
| 1.2.1 | Ensure that the `--anonymous-auth` argument is set to false | Manual | L1 | Pass | |
| 1.2.2 | Ensure that the `--token-auth-file` parameter isn't set | Automated | L1 | Fail | Auto-rotated by AKS, currently parameter is set |
| 1.2.3 | Ensure that `--DenyServiceExternalIPs` isn't set |Manual | L1 | Fail | Customers can use Azure Policy for Kubernetes to deny services with External IP. |
| 1.2.4 | Ensure that the `--kubelet-client-certificate` and `--kubelet-client-key` arguments are set as appropriate | Automated | L1 | Pass | |
| 1.2.5 | Ensure that the `--kubelet-certificate-authority` argument is set as appropriate | Automated | L1 | Fail | Kubelet serving certificate uses self-signed certificate |
| 1.2.6 | Ensure that the `--authorization-mode` argument isn't set to `AlwaysAllow` | Automated | L1 | Pass | |
| 1.2.7 | Ensure that the `--authorization-mode` argument includes Node | Automated | L1 | Pass | |
| 1.2.8 | Ensure that the `--authorization-mode` argument includes RBAC | Automated | L1 | Pass | |
| 1.2.9 | Ensure that the admission control plugin EventRateLimit is set | Manual | L1 | Fail | Operational impact |
| 1.2.10 | Ensure that the admission control plugin AlwaysAdmit isn't set | Automated | L1 | Pass | |
| 1.2.11 | Ensure that the admission control plugin AlwaysPullImages is set | Manual | L1 | Fail | Operational impact |
| 1.2.12 | Ensure that the admission control plugin ServiceAccount is set | Automated | L2 | Pass |  |  |
| 1.2.13 | Ensure that the admission control plugin NamespaceLifecycle is set | Automated | L2 | Pass | |
| 1.2.14 | Ensure that the admission control plugin NodeRestriction is set | Automated | L2 | Pass | |
| 1.2.15 | Ensure that the `--profiling` argument is set to false | Automated | L1 | Pass | |
| 1.2.16 | Ensure that the `--audit-log-path` argument is set | Automated | L1 | Pass | |
| 1.2.17 | Ensure that the `--audit-log-maxage` argument is set to 30 or as appropriate | Automated | L1 | Equivalent Control | AKS stores audit log for 14 days, Deployment.yaml has value of 0.|
| 1.2.18 | Ensure that the `--audit-log-maxbackup` argument is set to 10 or as appropriate | Automated | L1 | Equivalent Control | AKS stores audit log for 14 days, Deployment.yaml has value of 0.|
| 1.2.19 | Ensure that the `--audit-log-maxsize` argument is set to 100 or as appropriate | Automated | L1 | Pass | |
| 1.2.20 | Ensure that the `--request-timeout` argument is set as appropriate | Manual | L1 | Pass | Parameter is not set, which will set default value = 60s (which is compliant) |
| 1.2.21 | Ensure that the `--service-account-lookup` argument is set to true | Automated | L1 | Pass | Parameter is not set, which will set the default value as true (which is compliant) |
| 1.2.22 | Ensure that the `--service-account-key-file` argument is set as appropriate | Automated | L1 | Pass | |
| 1.2.23 | Ensure that the `--etcd-certfile` and `--etcd-keyfile` arguments are set as appropriate | Automated | L1 | Pass | |
| 1.2.24 | Ensure that the `--tls-cert-file` and `--tls-private-key-file` arguments are set as appropriate | Automated | L1 | Pass | |
| 1.2.25 | Ensure that the `--client-ca-file` argument is set as appropriate | Automated | L1 | Pass | |
| 1.2.26 | Ensure that the `--etcd-cafile` argument is set as appropriate | Automated | L1 | Pass | |
| 1.2.27 | Ensure that the `--encryption-provider-config` argument is set as appropriate | Manual | L1 | Depends on Environment | Argument is set when [Azure KMS][azure-kms] is enabled|
| 1.2.28 | Ensure that encryption providers are appropriately configured | Manual | L1 | Depends on Environment | Argument is set when [Azure KMS][azure-kms] is enabled |
| 1.2.29 | Ensure that the API Server only makes use of Strong Cryptographic Ciphers | Manual | L1 | Pass | AKS supports a subset of 4 Strong Ciphersuites out of 21 recommended ones from CIS |
| 1.2.30 | Ensure that the `--service-account-extend-token-expiration` parameter is set to false | Automated | L1 | Depends on Environment | This parameter is set to false when [OIDC][oidc] is enabled on the cluster |
| 1.3 | Controller Manager | | | | |
| 1.3.1 | Ensure that the `--terminated-pod-gc-threshold` argument is set as appropriate | Manual | L1 | Pass | AKS sets the default value to 6000 instead of 12500|
| 1.3.2 | Ensure that the `--profiling` argument is set to false | Automated | L1 | Pass | |
| 1.3.3 | Ensure that the `--use-service-account-credentials` argument is set to true | Automated | L1 | Pass| |
| 1.3.4 | Ensure that the `--service-account-private-key-file` argument is set as appropriate | Automated | L1 | Pass |  |
| 1.3.5 | Ensure that the `--root-ca-file` argument is set as appropriate | Automated | L1 | Pass |  |
| 1.3.6 | Ensure that the RotateKubeletServerCertificate argument is set to true | Automated | L2 | Pass | Parameter is set to true, see [Kubelet Serving Certificate Rotation][kscr] |
| 1.3.7 | Ensure that the `--bind-address` argument is set to 127.0.0.1 | Automated | L1 | Equivalent Control | Pod's IP is used|
| 1.4 | Scheduler | | | | |
| 1.4.1 | Ensure that the `--profiling` argument is set to false | Automated | L1 | Pass | |
| 1.4.2 | Ensure that the `--bind-address` argument is set to 127.0.0.1 | Automated | L1 | Equivalent Control | Pod's IP is used|
| 2 | `etcd` | | | | |
| 2.1 | Ensure that the `--cert-file` and `--key-file` arguments are set as appropriate | Automated | L1 | Pass | |
| 2.2 | Ensure that the `--cert-file` and `--key-file` arguments are set as appropriate | Automated | L1 | Pass | |
| 2.3 | Ensure that the `--client-cert-auth` argument is set to true | Automated | L1 | Pass | |
| 2.4 | Ensure that the `--auto-tls` argument isn't set to true | Automated | L1 | Pass | Parameter is not set, which will set the default value as false (which is compliant) |
| 2.5 | Ensure that the `--peer-cert-file` and `--peer-key-file` arguments are set as appropriate | Automated | L1 | Pass | |
| 2.6 | Ensure that the `--peer-client-cert-auth` argument is set to true | Automated | L1 | Pass | |
| 2.7 | Ensure that the `--peer-auto-tls` argument isn't set to true | Automated | L1 | Pass | Parameter is not set, which will set the default value as false (which is compliant) |
| 2.8 | Ensure that a unique Certificate Authority is used for `etcd` | Manual | L2 | Pass | `--client-ca-file` for api-server is different from `--trusted-ca-file` for etcd|
| 3 | Control Plane Configuration | | | | |
| 3.1 | Authentication and Authorization | | | | |
| 3.1.1 | Client certificate authentication shouldn't be used for users | Manual | L1 | Pass | When you deploy an AKS cluster, local accounts are enabled by default. You can [disable local accounts][disable-local-accounts] to disable client certificates for authentication. |
| 3.1.2 | Service account token authentication shouldn't be used for users | Manual | L1 | Pass | AKS provides support for [Microsoft Entra authentication][entra-auth] for requests sent to the cluster control plane. The usage of service acccount tokens is left up to the customer (to enforce a a best practice, as needed) |
| 3.1.3 | Bootstrap token authentication shouldn't be used for users | Manual | L1 | Pass | Bootstrap tokens can't be used by users |
| 3.2 | Logging | | | | |
| 3.2.1 | Ensure that a minimal audit policy is created | Manual | L1 | Pass | |
| 3.2.2 | Ensure that the audit policy covers key security concerns | Manual | L2 | Pass | |
| 4 | Worker Nodes | | | | |
| 4.1 | Worker Node Configuration Files | | | | |
| 4.1.1 | Ensure that the kubelet service file permissions are set to 600 or more restrictive | Automated | L1 | Pass | |
| 4.1.2 | Ensure that the kubelet service file ownership is set to `root: root` | Automated | L1 | Pass | |
| 4.1.3 | If a proxy kubeconfig file exists, ensure permissions are set to 600 or more restrictive | Manual | L1 | N/A | |
| 4.1.4 | If a proxy kubeconfig file exists, ensure ownership is set to `root: root` | Manual | L1 | N/A | |
| 4.1.5 | Ensure that the `--kubeconfig` kubelet.conf file permissions are set to 600 or more restrictive | Automated | L1 | Pass | |
| 4.1.6 | Ensure that the `--kubeconfig` kubelet.conf file ownership is set to `root: root` | Automated | L1 | Pass | |
| 4.1.7 | Ensure that the certificate authorities file permissions are set to 600 or more restrictive |Manual | L1 | Pass | |
| 4.1.8 | Ensure that the client certificate authorities file ownership is set to `root: root` | Manual | L1 | Pass | |
| 4.1.9 | If the kubelet config.yaml configuration file is being used, ensure permissions set to 600 or more restrictive | Automated | L1 | Pass | |
| 4.1.10 | If the kubelet config.yaml configuration file is being used, ensure file ownership is set to `root: root` | Automated | L1 | Pass | |
| 4.2 | Kubelet | | | | |
| 4.2.1 | Ensure that the `--anonymous-auth` argument is set to false | Automated | L1 | Pass | |
| 4.2.2 | Ensure that the `--authorization-mode` argument isn't set to `AlwaysAllow` | Automated | L1 | Pass | |
| 4.2.3 | Ensure that the `--client-ca-file` argument is set as appropriate | Automated | L1 | Pass | |
| 4.2.4 | Ensure that the `--read-only-port` argument is set to 0 | Manual | L1 | Pass | |
| 4.2.5 | Ensure that the `--streaming-connection-idle-timeout` argument isn't set to 0 | Manual | L1 | Pass | |
| 4.2.6 | Ensure that the `--make-iptables-util-chains` argument is set to true | Automated | L1 | Pass | |
| 4.2.7 | Ensure that the `--hostname-override` argument isn't set | Manual | L1 | Pass | |
| 4.2.8 | Ensure that the `--eventRecordQPS` argument is set to a level which ensures appropriate event capture | Manual | L2 | Pass | |
| 4.2.9 | Ensure that the `--tls-cert-file` and `--tls-private-key-file` arguments are set as appropriate | Manual | L1 | Pass | |
| 4.2.10 | Ensure that the `--rotate-certificates` argument isn't set to false | Automated | L1 | Pass | |
| 4.2.11 | Verify that the RotateKubeletServerCertificate argument is set to true | Manual | L1 | Fail | |
| 4.2.12 | Ensure that the Kubelet only makes use of Strong Cryptographic Ciphers | Manual | L1 | Pass | |
| 4.2.13 | Ensure that a limit is set on pod PIDs | Manual | L1 | Pass | |
| 4.3 | kube-proxy | | | | |
| 4.3.1 | Ensure that the kube-proxy metrics service is bound to localhost | Automated | L1 | Fail | AKS has central Prometheus scraping for kube-proxy and applies alert and auto-remediation when `KubeProxyStale` is detected. The `metrics-bind-address` is set for that purpose. |
| 5 | Policies | | | | |
| 5.1 | RBAC and Service Accounts| | | | |
| 5.1.1 | Ensure that the cluster-admin role is only used where required | Automated | L1 | Depends on Environment | Use [Azure Policy built-in policy definitions][azure-policies] for Azure Kubernetes Service  |
| 5.1.2 | Minimize access to secrets | Automated | L1 | Depends on Environment | |
| 5.1.3 | Minimize wildcard use in Roles and ClusterRoles | Automated | L1 | Depends on Environment | Use [Azure Policy built-in policy definitions][azure-policies] for Azure Kubernetes Service |
| 5.1.4 | Minimize access to create pods | Automated | L1| Depends on Environment | |
| 5.1.5 | Ensure that default service accounts aren't actively used | Automated | L1 | Depends on Environment | |
| 5.1.6 | Ensure that Service Account Tokens are only mounted where necessary | Automated | L1 | Depends on Environment | |
| 5.1.7 | Avoid use of system: masters group | Manual | L1 | Depends on Environment | |
| 5.1.8 | Limit use of the Bind, Impersonate, and Escalate permissions in the Kubernetes cluster | Manual | L1 | Depends on Environment | |
| 5.1.9 | Minimize access to create persistent volumes | Manual | L1 | Depends on Environment | |
| 5.1.10 | Minimize access to the proxy subresource of nodes | Manual | L1 | Depends on Environment | |
| 5.1.11 | Minimize access to the approval subresource of `certificatesigningrequests` objects | Manual | L1 | Depends on Environment | |
| 5.1.12 | Minimize access to webhook configuration objects | Manual | L1 | Depends on Environment | |
| 5.1.13 | Minimize access to the service account token creation | Manual | L1 | Depends on Environment | |
| 5.2 | Pod Security Standards | | | | |
| 5.2.1 | Ensure that the cluster has at least one active policy control mechanism in place | Manual | L1 | Depends on Environment | Use [Azure Policy built-in policy definitions][azure-policies] for Azure Kubernetes Service  |
| 5.2.2 | Minimize the admission of privileged containers | Manual | L1 | Depends on Environment | Use [Azure Policy built-in policy definitions][azure-policies] for Azure Kubernetes Service |
| 5.2.3 | Minimize the admission of containers wishing to share the host process ID namespace | Manual | L1 | Depends on Environment | Use [Azure Policy built-in policy definitions][azure-policies] for Azure Kubernetes Service |
| 5.2.4 | Minimize the admission of containers wishing to share the host IPC namespace | Manual | L1 | Depends on Environment | Use [Azure Policy built-in policy definitions][azure-policies] for Azure Kubernetes Service  |
| 5.2.5 | Minimize the admission of containers wishing to share the host network namespace | Manual | L1 | Depends on Environment | Use [Azure Policy built-in policy definitions][azure-policies] for Azure Kubernetes Service  |
| 5.2.6 | Minimize the admission of containers with allowPrivilegeEscalation | Manual | L1 | Depends on Environment | Use [Azure Policy built-in policy definitions][azure-policies] for Azure Kubernetes Service |
| 5.2.7 | Minimize the admission of root containers | Manual | L2 | Depends on Environment | |
| 5.2.8 | Minimize the admission of containers with the NET_RAW capability | Manual | L1 | Depends on Environment | Use [Azure Policy built-in policy definitions][azure-policies] for Azure Kubernetes Service |
| 5.2.9 | Minimize the admission of containers with added capabilities | Manual | L1 | Depends on Environment | Use [Azure Policy built-in policy definitions][azure-policies] for Azure Kubernetes Service|
| 5.2.10 | Minimize the admission of containers with capabilities assigned | Manual | L2 | Depends on Environment | |
| 5.2.11 | Minimize the admission of Windows HostProcess Containers | Manual | L1 | Depends on Environment | |
| 5.2.12 | Minimize the admission of HostPath volumes | Manual | L1 | Depends on Environment | Use [Azure Policy built-in policy definitions][azure-policies] for Azure Kubernetes Service  |
| 5.2.13 | Minimize the admission of containers which use HostPorts | Manual | L1 | Depends on Environment | |
| 5.3 | Network Policies and CNI | | | | |
| 5.3.1 | Ensure that the CNI in use supports Network Policies | Manual | L1 | Pass | |
| 5.3.2 | Ensure that all Namespaces have Network Policies defined | Manual | L2 | Depends on Environment | |
| 5.4 | Secrets Management | | | | |
| 5.4.1 | Prefer using secrets as files over secrets as environment variables | Manual | L2 | Depends on Environment | |
| 5.4.2 | Consider external secret storage | Manual | L2 | Depends on Environment | |
| 5.5 | Extensible Admission Control | | | | |
| 5.5.1 | Configure Image Provenance using ImagePolicyWebhook admission controller | Manual | L2 | Fail | Equivalent control implemented |
| 5.6 | General Policies | | | | |
| 5.6.1 | Create administrative boundaries between resources using namespaces | Manual | L1 | Depends on Environment | |
| 5.6.2 | Ensure that the seccomp profile is set to docker/default in your pod definitions | Manual | L2 | Depends on Environment | |
| 5.6.3 | Apply Security Context to Your Pods and Containers | Manual | L2 | Depends on Environment | |
| 5.6.4 | The default namespace shouldn't be used | Manual | L2 | Depends on Environment | |

> [!NOTE]
> In addition to the Kubernetes CIS benchmark, there's an [AKS CIS benchmark][cis-benchmark-aks] available as well.

## Other notes

- The security hardened OS is built and maintained specifically for AKS and is **not** supported outside of the AKS platform.
- To further reduce the attack surface area, some unnecessary kernel module drivers are disabled in the OS.

## Next steps

For more information about AKS security, see the following articles:

- [Azure Kubernetes Service (AKS)](./intro-kubernetes.md)
- [AKS security considerations](./concepts-security.md)
- [AKS best practices](./best-practices.md)

<!-- EXTERNAL LINKS -->
[cis-benchmark-aks]: https://www.cisecurity.org/benchmark/kubernetes/
[cis-benchmark-kubernetes]: https://www.cisecurity.org/benchmark/kubernetes/

<!-- INTERNAL LINKS -->
[cis-benchmarks]: /compliance/regulatory/offering-CIS-Benchmark
[security-concepts-aks-apps-clusters]: concepts-security.md
[supported-kubernetes-versions]: ./supported-kubernetes-versions.md
[azure-kms]: ./use-kms-etcd-encryption.md
[oidc]: ./use-oidc-issuer.md
[kscr]: ./certificate-rotation.md
[azure-policies]: ./policy-reference.md
[entra-auth]: ./enable-authentication-microsoft-entra-id.md
[disable-local-accounts]: ./manage-local-accounts-managed-azure-ad.md