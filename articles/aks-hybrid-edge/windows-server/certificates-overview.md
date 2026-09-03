---
title: Overview of certificate management in AKS on Windows Server
description: Learn how to manage certificates for secure communication between in-cluster components in AKS by provisioning and managing certificates in AKS on Windows Server.
author: davidsmatlak
ms.topic: concept-article
ms.date: 09/01/2026
ms.author: davidsmatlak 
ms.lastreviewed: 04/01/2023
ms.reviewer: leslielin
ms.custom: windows-server

# Intent: As an IT Pro, I want to learn how to use certificates to secure communication between in-cluster components on my AKS deployment.
# Keyword: control plane nodes secure communication certificate revocation

---

# Overview of certificate management in AKS on Windows Server

[!INCLUDE [applies-to-azure stack-hci-and-windows-server-skus](../includes/aks-hci-applies-to-skus/aks-hybrid-applies-to-azure-stack-hci-windows-server-sku.md)]

AKS on Windows Server uses a combination of certificate and token-based authentication to secure communication between services (or agents) responsible for different operations within the platform. Certificate-based authentication uses a digital certificate to identify an entity (agent, machine, user, or device) before granting access to a resource.

## Cloud agent

When you deploy AKS on Windows Server, AKS installs agents that are used to perform various functions within the cluster. These agents include:

- Cloud agent: a service that is responsible for the underlying platform orchestration.
- Node agent: a service that resides on each node that does the actual work of virtual machine creation, deletion, etc.
- Key Management System (KMS) pod: a service responsible for key management.
- Other services: cloud operator, certificate manager, etc.

The cloud agent service in AKS is responsible for orchestrating the create, read, update, and delete (CRUD) operations of infrastructure components such as Virtual Machines (VMs), Virtual Network Interfaces (VNICs), and Virtual Networks (VNETs) in the cluster.

To communicate with the cloud agent, clients require certificates to be provisioned in order to secure this communication. Each client requires an identity to be associated with it, which defines the Role Based Access Control (RBAC) rules associated with the client. Each identity consists of two entities:

- A token, used for initial authentication, which returns a certificate, and
- A certificate, obtained from the above sign-in process, and used for authentication in any communication.

Each entity is valid for a specific period (the default is 90 days), at the end of which it expires. For continued access to the cloud agent, each client requires the certificate to be renewed and the token rotated.

## Certificate types

There are two types of certificates used in AKS on Windows Server:

- Cloud agent CA certificate: the certificate used to sign/validate client certificates. This certificate is valid for 365 days (1 year).
- Client certificates: certificates issued by the cloud agent CA certificate for clients to authenticate to the cloud agent. These certificates are usually valid for 90 days.

Microsoft recommends that you update clusters within 60 days of a new release, not only for ensuring that internal certificates and tokens are kept up to date, but also to make sure that you get access to new features, bug fixes, and to stay up to date with critical security patches. During these monthly updates, the update process rotates any tokens that can't be auto-rotated during normal operations of the cluster. Certificate and token validity is reset to the default 90 days from the date that the cluster is updated.

## Secure communication with certificates in AKS on Windows Server

Certificates are used to build secure communication between in-cluster components. AKS provides zero-touch, out-of-the-box provisioning, and management of certificates for built-in Kubernetes components. In this article, you'll learn how to provision and manage certificates in AKS on Windows Server.

## Certificates and CAs

AKS generates and uses the following Certificate Authorities (CAs) and certificates.

### Cluster CA

- The API server has a Cluster CA, which signs certificates for one-way communication from the API server to `kubelet`.
- Each `kubelet` also creates a Certificate Signing Request (CSR), which is signed by the Cluster CA, for communication from the `kubelet` to the API server.
- The etcd key value store has a certificate signed by the Cluster CA for communication from etcd to the API server.

### etcd CA

The etcd key value store has an etcd CA that signs certificates to authenticate and authorize data replication between etcd replicas in the cluster.

### Front Proxy CA

The Front Proxy CA secures communication between the API server and the extension API server.

### Certificate provisioning

Certificate provisioning for a `kubelet` is done using [TLS bootstrapping](https://kubernetes.io/docs/reference/access-authn-authz/kubelet-tls-bootstrapping/). For all other certificates, use YAML-based key and certificate creation.

- The certificates are stored in **/etc/kubernetes/pki**.
- The keys are RSA 4096, EcdsaCurve: P384

> [!NOTE]
> The root certificates are valid for 10 years. All other, non-root certificates are short-lived and valid for four days.

### Certificate renewal and management

Non-root certificates are automatically renewed. All control plane certificates for Kubernetes except the following certificates are managed:

- Kubelet server certificate
- Kubeconfig client certificate

As a security best practice, you should use [Active Directory single sign-in](./ad-sso.md) for user authentication.

## Certificate revocation

Certificate revocation should be rare, and it should be done at the time of certificate renewal.

Once you have the serial number of the certificate you would like to revoke, use Kubernetes Custom Resource for defining and persisting revocation information. Each revocation object can consist of one or more revocation entries.  

To perform a revocation, use one of the following:

- Serial number
- Group
- DNS name
- IP address  

A `notBefore` time can be specified to revoke only certificates that are issued before a certain timestamp. If a `notBefore` time is not specified, all existing and future certificates matching the revocation will be revoked.

> [!NOTE]
> Revocation of `kubelet` server certificates is currently not available.

If you use a serial number when you perform a revocation, you can use the `Repair-AksHciClusterCerts` PowerShell command, described as follows, to get your cluster into a working state. If you use any of the other fields listed earlier, make sure to specify a `notBefore` time.

```yaml
apiVersion: certificates.microsoft.com/v1 
kind: RenewRevocation 
metadata: 
  name: my-renew-revocation 
  namespace: kube-system 
spec: 
  description: My list of renew revocations 
  revocations: 
  - description: Revoked certificates by serial number 
    kind: serialnumber 
    notBefore: "2020-04-17T17:22:05Z" 
    serialNumber: 77fdf4b1033b387aaace6ce1c18710c2 
  - description: Revoked certificates by group 
    group: system:nodes 
    kind: Group 
  - description: Revoked certificates by DNS 
    dns: kubernetes.default.svc. 
    kind: DNS 
  - description: Revoked certificates by DNS Suffix 
    dns: .cluster.local 
    kind: DNS 
  - description: Revoked certificates by IP 
    ip: 170.63.128.124 
    kind: IP 
```

## Next steps

- [Update certificates](update-certificates.md)
- [Deploy a Linux applications on a Kubernetes cluster](./deploy-linux-application.md)
- [Deploy a Windows Server application on a Kubernetes cluster](./deploy-windows-application.md)
