---
title: Azure Kubernetes Service (AKS) Ubuntu image alignment with Center for Internet Security (CIS) benchmark
description: Learn how AKS applies the CIS benchmark to Ubuntu image used by Azure Kubernetes Service.
ms.date: 02/13/2026
ms.subservice: aks-security
ms.topic: concept-article
author: allyford
ms.author: allyford
ai-usage: ai-assisted
# Customer intent: "As a security auditor, I want to verify the alignment of AKS Ubuntu images with CIS benchmarks, so that I can ensure compliance with industry standards and reduce vulnerabilities in our cloud-based applications."
---

# Center for Internet Security (CIS) Ubuntu benchmark for AKS node images

> [!IMPORTANT]
> This article applies to Ubuntu 24.04 and Ubuntu 22.04 images used by AKS. The recommendation statuses and guidance reflect point-in-time scans and benchmark versions: [CIS Ubuntu 24.04 LTS Benchmark v1.0.0][cis-benchmark-ubuntu] for Ubuntu 24.04, and [CIS Ubuntu 22.04 LTS Benchmark v3.0.0][cis-benchmark-ubuntu] for Ubuntu 22.04. Verify the OS version and benchmark version before applying guidance.

This article covers the security OS configuration applied to Ubuntu image used by AKS. As a secure service, AKS complies with SOC, ISO, PCI DSS, and HIPAA standards. For more information about the AKS security, see [Security concepts for clusters in Azure Kubernetes Service (AKS)][security-concepts-aks-apps-clusters]. To learn more about the CIS benchmark, see [Center for Internet Security (CIS) Benchmarks][cis-benchmarks]. For more information on the Azure security baselines for Linux, see [Linux security baseline][linux-security-baseline].

## Recommendations

The table has five sections:

* **CIS ID:** The associated rule ID with each of the baseline rules.
* **Recommendation description:** A description of the recommendation issued by the CIS benchmark.
* **Level:** The severity of the recommended security requirements for a given environment.
  * *L1, or Level 1* - Recommends essential basic security requirements that can be configured on any system and should cause little or no interruption of service or reduced functionality.
  * *L2, or Level 2* - Recommends stricter requirements for environments with a higher security posture.
* **Status:**
    * *Pass* - The recommendation has been applied.
    * *Fail* - The recommendation hasn't been applied.
    * *Manual* - The recommendation can't be scanned automatically. There are instructions in the CIS benchmark to manually review.
    * *N/A* - The recommendation relates to manifest file permission requirements that aren't relevant to AKS.
    * *Depends on Environment* - The recommendation is applied in the user's specific environment and is not controlled by AKS.
    * *Equivalent Control* - The recommendation has been implemented in a different equivalent manner.
* **Reason:**
    * *Potential Operation Impact* - The recommendation wasn't applied because it would have a negative effect on the service.
    * *Covered Elsewhere* - The recommendation is covered by another control in Azure cloud compute.

## Ubuntu LTS 24.04

AKS clusters are deployed on host virtual machines, which run an operating system with built-in secure configurations. This operating system is used for containers running on AKS. This host operating system is based on an **Ubuntu 24.04.LTS** image with security configurations applied. 

As a part of the security-optimized operating system:

* AKS provides a security-optimized host OS by default, but no option to select an alternate operating system.
* The security-optimized host OS is built and maintained specifically for AKS and **is not** supported outside of the AKS platform.
* Some unnecessary kernel module drivers have been disabled in the OS to reduce the attack surface area.

> [!NOTE]
> Unrelated to the CIS benchmarks, Azure applies daily patches, including security patches, to AKS virtual machine hosts.

The goal of the secure configuration built into the host OS is to reduce the surface area of attack and optimize for the deployment of containers in a secure manner.
AKS node images aim to be compliant with the "L1 - Server" profile where possible in a way that doesn't interfere with Kubernetes node operations. L2 compliance status is provided for informational purposes only and the node configuration is not currently compliant.

### Ubuntu LTS 24.04 Benchmark

The following are the results from the [CIS Ubuntu 24.04 LTS Benchmark v1.0.0][cis-benchmark-ubuntu] recommendations based on the CIS rules:

| CIS paragraph number | Recommendation description | Level | Status | Reason |
|---|---|---|---|---|
| 1 | **Initial Setup** | | | |
| 1.1 | **Filesystem** | | | |
| 1.1.1 | **Configure Filesystem Kernel Modules** | | | |
| 1.1.1.1 | Ensure cramfs kernel module isn't available | L1 | Pass | |
| 1.1.1.2 | Ensure freevxfs kernel module isn't available | L1 | Pass | |
| 1.1.1.3 | Ensure hfs kernel module isn't available | L1 | Pass | |
| 1.1.1.4 | Ensure hfsplus kernel module isn't available | L1 | Pass | |
| 1.1.1.5 | Ensure jffs2 kernel module isn't available | L1 | Pass | |
| 1.1.1.6 | Ensure overlayfs kernel module isn't available | L2 | Fail | |
| 1.1.1.7 | Ensure squashfs kernel module isn't available | L2 | Pass | |
| 1.1.1.8 | Ensure udf kernel module isn't available | L2 | Fail | |
| 1.1.1.9 | Ensure usb-storage kernel module isn't available | L1 | Pass | |
| 1.1.1.10 | Ensure unused filesystems kernel modules aren't available | L1 | Manual | |
| 1.1.2 | **Configure Filesystem Partitions** | | | |
| 1.1.2.1 | **Configure /tmp** | | | |
| 1.1.2.1.1 | Ensure /tmp is a separate partition | L1 | Fail | Operational impact: Making /tmp a separate partition would require turning it into a tmpfs (in-memory filesystem) which would consume the same memory available for pods. |
| 1.1.2.1.2 | Ensure nodev option set on /tmp partition | L1 | Pass | |
| 1.1.2.1.3 | Ensure nosuid option set on /tmp partition | L1 | Pass | |
| 1.1.2.1.4 | Ensure noexec option set on /tmp partition | L1 | Pass | |
| 1.1.2.2 | **Configure /dev/shm** | | | |
| 1.1.2.2.1 | Ensure /dev/shm is a separate partition | L1 | Pass | |
| 1.1.2.2.2 | Ensure nodev option set on /dev/shm partition | L1 | Pass | |
| 1.1.2.2.3 | Ensure nosuid option set on /dev/shm partition | L1 | Pass | |
| 1.1.2.2.4 | Ensure noexec option set on /dev/shm partition | L1 | Pass | |
| 1.1.2.3 | **Configure /home** | | | |
| 1.1.2.3.1 | Ensure separate partition exists for /home | L2 | Fail | |
| 1.1.2.3.2 | Ensure nodev option set on /home partition | L1 | Pass | |
| 1.1.2.3.3 | Ensure nosuid option set on /home partition | L1 | Pass | |
| 1.1.2.4 | **Configure /var** | | | |
| 1.1.2.4.1 | Ensure separate partition exists for /var | L2 | Fail | |
| 1.1.2.4.2 | Ensure nodev option set on /var partition | L1 | Pass | |
| 1.1.2.4.3 | Ensure nosuid option set on /var partition | L1 | Pass | |
| 1.1.2.5 | **Configure /var/tmp** | | | |
| 1.1.2.5.1 | Ensure separate partition exists for /var/tmp | L2 | Fail | |
| 1.1.2.5.2 | Ensure nodev option set on /var/tmp partition | L1 | Pass | |
| 1.1.2.5.3 | Ensure nosuid option set on /var/tmp partition | L1 | Pass | |
| 1.1.2.5.4 | Ensure noexec option set on /var/tmp partition | L1 | Pass | |
| 1.1.2.6 | **Configure /var/log** | | | |
| 1.1.2.6.1 | Ensure separate partition exists for /var/log | L2 | Fail | |
| 1.1.2.6.2 | Ensure nodev option set on /var/log partition | L1 | Pass | |
| 1.1.2.6.3 | Ensure nosuid option set on /var/log partition | L1 | Pass | |
| 1.1.2.6.4 | Ensure noexec option set on /var/log partition | L1 | Pass | |
| 1.1.2.7 | **Configure /var/log/audit** | | | |
| 1.1.2.7.1 | Ensure separate partition exists for /var/log/audit | L2 | Fail | |
| 1.1.2.7.2 | Ensure nodev option set on /var/log/audit partition | L1 | Pass | |
| 1.1.2.7.3 | Ensure nosuid option set on /var/log/audit partition | L1 | Pass | |
| 1.1.2.7.4 | Ensure noexec option set on /var/log/audit partition | L1 | Pass | |
| 1.2 | **Package Management** | | | |
| 1.2.1 | **Configure Package Repositories** | | | |
| 1.2.1.1 | Ensure GPG keys are configured | L1 | Manual | Pass |
| 1.2.1.2 | Ensure package manager repositories are configured | L1 | Manual | Pass |
| 1.2.2 | **Configure Package Updates** | | | |
| 1.2.2.1 | Ensure updates, patches, and additional security software are installed | L1 | Depends on Environment | [Node OS Upgrade channels][auto-upgrade-node] can be used to automate updates and patches. |
| 1.3 | **Mandatory Access Control** | | | |
| 1.3.1 | **Configure AppArmor** | | | |
| 1.3.1.1 | Ensure AppArmor is installed | L1 | Pass | |
| 1.3.1.2 | Ensure AppArmor is enabled in the bootloader configuration | L1 | Pass | |
| 1.3.1.3 | Ensure all AppArmor Profiles are in enforce or complain mode | L1 | Fail | Operational impact: May block legitimate workloads and addons. |
| 1.3.1.4 | Ensure all AppArmor Profiles are enforcing | L2 | Fail | Operational impact: May block legitimate workloads and addons. |
| 1.4 | **Configure Bootloader** | | | |
| 1.4.1 | Ensure bootloader password is set | L1 | Pass | |
| 1.4.2 | Ensure access to bootloader config is configured | L1 | Pass | |
| 1.5 | **Configure Additional Process Hardening** | | | |
| 1.5.1 | Ensure address space layout randomization is enabled | L1 | Pass | |
| 1.5.2 | Ensure ptrace_scope is restricted | L1 | Pass | |
| 1.5.3 | Ensure core dumps are restricted | L1 | Pass | |
| 1.5.4 | Ensure prelink isn't installed | L1 | Pass | |
| 1.5.5 | Ensure Automatic Error Reporting isn't enabled | L1 | Pass | |
| 1.6 | **Configure Command Line Warning Banners** | | | |
| 1.6.1 | Ensure message of the day is configured properly | L1 | Pass | |
| 1.6.2 | Ensure local login warning banner is configured properly | L1 | Pass | |
| 1.6.3 | Ensure remote login warning banner is configured properly | L1 | Pass | |
| 1.6.4 | Ensure access to /etc/motd is configured | L1 | Pass | |
| 1.6.5 | Ensure access to /etc/issue is configured | L1 | Pass | |
| 1.6.6 | Ensure access to /etc/issue.net is configured | L1 | Pass | |
| 1.7 | **Configure GNOME Display Manager** | | | |
| 1.7.1 | Ensure GDM is removed | L2 | Pass | |
| 1.7.2 | Ensure GDM login banner is configured | L1 | Pass | |
| 1.7.3 | Ensure GDM disable-user-list option is enabled | L1 | Pass | |
| 1.7.4 | Ensure GDM screen locks when the user is idle | L1 | Pass | |
| 1.7.5 | Ensure GDM screen locks can't be overridden | L1 | Pass | |
| 1.7.6 | Ensure GDM automatic mounting of removable media is disabled | L1 | Pass | |
| 1.7.7 | Ensure GDM disabling automatic mounting of removable media isn't overridden | L1 | Pass | |
| 1.7.8 | Ensure GDM autorun-never is enabled | L1 | Pass | |
| 1.7.9 | Ensure GDM autorun-never isn't overridden | L1 | Pass | |
| 1.7.10 | Ensure XDMCP isn't enabled | L1 | Pass | |
| 2 | **Services** | | | |
| 2.1 | **Configure Server Services** | | | |
| 2.1.1 | Ensure autofs services aren't in use | L1 | Pass | |
| 2.1.2 | Ensure avahi daemon services aren't in use | L1 | Pass | |
| 2.1.3 | Ensure dhcp server services aren't in use | L1 | Pass | |
| 2.1.4 | Ensure dns server services aren't in use | L1 | Pass | |
| 2.1.5 | Ensure dnsmasq services aren't in use | L1 | Pass | |
| 2.1.6 | Ensure ftp server services aren't in use | L1 | Pass | |
| 2.1.7 | Ensure ldap server services aren't in use | L1 | Pass | |
| 2.1.8 | Ensure message access server services aren't in use | L1 | Pass | |
| 2.1.9 | Ensure network file system services aren't in use | L1 | Pass | |
| 2.1.10 | Ensure nis server services aren't in use | L1 | Pass | |
| 2.1.11 | Ensure print server services aren't in use | L1 | Pass | |
| 2.1.12 | Ensure rpcbind services aren't in use | L1 | Fail | Operational impact: rpcbind is a required dependency of NFS, used by the Azure CSI driver. |
| 2.1.13 | Ensure rsync services aren't in use | L1 | Pass | |
| 2.1.14 | Ensure samba file server services aren't in use | L1 | Pass | |
| 2.1.15 | Ensure snmp services aren't in use | L1 | Pass | |
| 2.1.16 | Ensure tftp server services aren't in use | L1 | Pass | |
| 2.1.17 | Ensure web proxy server services aren't in use | L1 | Pass | |
| 2.1.18 | Ensure web server services aren't in use | L1 | Pass | |
| 2.1.19 | Ensure xinetd services aren't in use | L1 | Pass | |
| 2.1.20 | Ensure X window server services aren't in use | L2 | Pass | |
| 2.1.21 | Ensure mail transfer agent is configured for local-only mode | L1 | Pass | |
| 2.1.22 | Ensure only approved services are listening on a network interface | L1 | Manual | Pass |
| 2.2 | **Configure Client Services** | | | |
| 2.2.1 | Ensure NIS Client isn't installed | L1 | Pass | |
| 2.2.2 | Ensure rsh client isn't installed | L1 | Pass | |
| 2.2.3 | Ensure talk client isn't installed | L1 | Pass | |
| 2.2.4 | Ensure telnet client isn't installed | L1 | Pass | |
| 2.2.5 | Ensure ldap client isn't installed | L1 | Pass | |
| 2.2.6 | Ensure ftp client isn't installed | L1 | Pass | |
| 2.3 | **Configure Time Synchronization** | | | |
| 2.3.1 | **Ensure time synchronization is in use** | | | |
| 2.3.1.1 | Ensure a single time synchronization daemon is in use | L1 | Pass | |
| 2.3.2 | **Configure systemd-timesyncd** | | | |
| 2.3.2.1 | Ensure systemd-timesyncd configured with authorized timeserver | L1 | Pass | |
| 2.3.2.2 | Ensure systemd-timesyncd is enabled and running | L1 | Pass | |
| 2.3.3 | **Configure chrony** | | | |
| 2.3.3.1 | Ensure chrony is configured with authorized timeserver | L1 | Fail | AKS nodes are configured to use chrony to sync to the host's PTP hardware clock using a hypervisor interface. The PTP hardware clock is the authorized timeserver for Azure. For more information, see the configuration of [chrony][chrony]. |
| 2.3.3.2 | Ensure chrony is running as user _chrony | L1 | Pass | |
| 2.3.3.3 | Ensure chrony is enabled and running | L1 | Pass | |
| 2.4 | **Job Schedulers** | | | |
| 2.4.1 | **Configure cron** | | | |
| 2.4.1.1 | Ensure cron daemon is enabled and active | L1 | Pass | |
| 2.4.1.2 | Ensure permissions on /etc/crontab are configured | L1 | Pass | |
| 2.4.1.3 | Ensure permissions on /etc/cron.hourly are configured | L1 | Pass | |
| 2.4.1.4 | Ensure permissions on /etc/cron.daily are configured | L1 | Pass | |
| 2.4.1.5 | Ensure permissions on /etc/cron.weekly are configured | L1 | Pass | |
| 2.4.1.6 | Ensure permissions on /etc/cron.monthly are configured | L1 | Pass | |
| 2.4.1.7 | Ensure permissions on /etc/cron.d are configured | L1 | Pass | |
| 2.4.1.8 | Ensure crontab is restricted to authorized users | L1 | Pass | |
| 2.4.2 | **Configure at** | | | |
| 2.4.2.1 | Ensure at is restricted to authorized users | L1 | Pass | |
| 3 | **Network** | | | |
| 3.1 | **Configure Network Devices** | | | |
| 3.1.1 | Ensure IPv6 status is identified | L1 | Manual | |
| 3.1.2 | Ensure wireless interfaces are disabled | L1 | Pass | |
| 3.1.3 | Ensure bluetooth services aren't in use | L1 | Pass | |
| 3.2 | **Configure Network Kernel Modules** | | | |
| 3.2.1 | Ensure dccp kernel module isn't available | L2 | Fail | |
| 3.2.2 | Ensure tipc kernel module isn't available | L2 | Fail | |
| 3.2.3 | Ensure rds kernel module isn't available | L2 | Fail | |
| 3.2.4 | Ensure sctp kernel module isn't available | L2 | Fail | |
| 3.3 | **Configure Network Kernel Parameters** | | | |
| 3.3.1 | Ensure ip forwarding is disabled | L1 | Fail | Operational impact: this is required for container networking to function. |
| 3.3.2 | Ensure packet redirect sending is disabled | L1 | Pass | |
| 3.3.3 | Ensure bogus icmp responses are ignored | L1 | Pass | |
| 3.3.4 | Ensure broadcast icmp requests are ignored | L1 | Pass | |
| 3.3.5 | Ensure icmp redirects aren't accepted | L1 | Pass | |
| 3.3.6 | Ensure secure icmp redirects aren't accepted | L1 | Pass | |
| 3.3.7 | Ensure reverse path filtering is enabled | L1 | Pass | |
| 3.3.8 | Ensure source routed packets aren't accepted | L1 | Pass | |
| 3.3.9 | Ensure suspicious packets are logged | L1 | Pass | |
| 3.3.10 | Ensure tcp syn cookies is enabled | L1 | Pass | |
| 3.3.11 | Ensure ipv6 router advertisements aren't accepted | L1 | Pass | |
| 4 | **Host Based Firewall** | | | |
| 4.1 | **Configure a single firewall utility** | | | |
| 4.1.1 | Ensure a single firewall configuration utility is in use | L1 | Covered elsewhere | |
| 4.2 | **Configure UncomplicatedFirewall** | | | |
| 4.2.1 | Ensure ufw is installed | L1 | Covered elsewhere | |
| 4.2.2 | Ensure iptables-persistent isn't installed with ufw | L1 | Covered elsewhere | |
| 4.2.3 | Ensure ufw service is enabled | L1 | Covered elsewhere | |
| 4.2.4 | Ensure ufw loopback traffic is configured | L1 | Covered elsewhere | |
| 4.2.5 | Ensure ufw outbound connections are configured | L1 | Covered elsewhere | |
| 4.2.6 | Ensure ufw firewall rules exist for all open ports | L1 | Covered elsewhere | |
| 4.2.7 | Ensure ufw default deny firewall policy | L1 | Covered elsewhere | |
| 4.3 | **Configure nftables** | | | |
| 4.3.1 | Ensure nftables is installed | L1 | Covered elsewhere | |
| 4.3.2 | Ensure ufw is uninstalled or disabled with nftables | L1 | Covered elsewhere | |
| 4.3.3 | Ensure iptables are flushed with nftables | L1 | Covered elsewhere | |
| 4.3.4 | Ensure a nftables table exists | L1 | Covered elsewhere | |
| 4.3.5 | Ensure nftables base chains exist | L1 | Covered elsewhere | |
| 4.3.6 | Ensure nftables loopback traffic is configured | L1 | Covered elsewhere | |
| 4.3.7 | Ensure nftables outbound and established connections are configured | L1 | Covered elsewhere | |
| 4.3.8 | Ensure nftables default deny firewall policy | L1 | Covered elsewhere | |
| 4.3.9 | Ensure nftables service is enabled | L1 | Covered elsewhere | |
| 4.3.10 | Ensure nftables rules are permanent | L1 | Covered elsewhere | |
| 4.4 | **Configure iptables** | | | |
| 4.4.1 | **Configure iptables software** | | | |
| 4.4.1.1 | Ensure iptables packages are installed | L1 | Covered elsewhere | |
| 4.4.1.2 | Ensure nftables isn't in use with iptables | L1 | Covered elsewhere | |
| 4.4.1.3 | Ensure ufw isn't in use with iptables | L1 | Covered elsewhere | |
| 4.4.2 | **Configure IPV4 iptables** | | | |
| 4.4.2.1 | Ensure iptables default deny firewall policy | L1 | Covered elsewhere | |
| 4.4.2.2 | Ensure iptables loopback traffic is configured | L1 | Covered elsewhere | |
| 4.4.2.3 | Ensure iptables outbound and established connections are configured | L1 | Covered elsewhere | |
| 4.4.2.4 | Ensure iptables firewall rules exist for all open ports | L1 | Covered elsewhere | |
| 4.4.3 | **Configure IPv6 ip6tables** | | | |
| 4.4.3.1 | Ensure ip6tables default deny firewall policy | L1 | Covered elsewhere | |
| 4.4.3.2 | Ensure ip6tables loopback traffic is configured | L1 | Covered elsewhere | |
| 4.4.3.3 | Ensure ip6tables outbound and established connections are configured | L1 | Covered elsewhere | |
| 4.4.3.4 | Ensure ip6tables firewall rules exist for all open ports | L1 | Covered elsewhere | |
| 5 | **Access Control** | | | |
| 5.1 | **Configure SSH Server** | | | |
| 5.1.1 | Ensure permissions on /etc/ssh/sshd_config are configured | L1 | Pass | |
| 5.1.2 | Ensure permissions on SSH private host key files are configured | L1 | Pass | |
| 5.1.3 | Ensure permissions on SSH public host key files are configured | L1 | Pass | |
| 5.1.4 | Ensure sshd access is configured | L1 | Pass | |
| 5.1.5 | Ensure sshd Banner is configured | L1 | Pass | |
| 5.1.6 | Ensure sshd Ciphers are configured | L1 | Pass | |
| 5.1.7 | Ensure sshd ClientAliveInterval and ClientAliveCountMax are configured | L1 | Pass | |
| 5.1.8 | Ensure sshd DisableForwarding is enabled | L2 | Fail | |
| 5.1.9 | Ensure sshd GSSAPIAuthentication is disabled | L2 | Pass | |
| 5.1.10 | Ensure sshd HostbasedAuthentication is disabled | L1 | Pass | |
| 5.1.11 | Ensure sshd IgnoreRhosts is enabled | L1 | Pass | |
| 5.1.12 | Ensure sshd KexAlgorithms is configured | L1 | Pass | |
| 5.1.13 | Ensure sshd LoginGraceTime is configured | L1 | Pass | |
| 5.1.14 | Ensure sshd LogLevel is configured | L1 | Pass | |
| 5.1.15 | Ensure sshd MACs are configured | L1 | Pass | |
| 5.1.16 | Ensure sshd MaxAuthTries is configured | L1 | Pass | |
| 5.1.17 | Ensure sshd MaxSessions is configured | L1 | Pass | |
| 5.1.18 | Ensure sshd MaxStartups is configured | L1 | Pass | |
| 5.1.19 | Ensure sshd PermitEmptyPasswords is disabled | L1 | Pass | |
| 5.1.20 | Ensure sshd PermitRootLogin is disabled | L1 | Pass | |
| 5.1.21 | Ensure sshd PermitUserEnvironment is disabled | L1 | Pass | |
| 5.1.22 | Ensure sshd UsePAM is enabled | L1 | Pass | |
| 5.2 | **Configure privilege escalation** | | | |
| 5.2.1 | Ensure sudo is installed | L1 | Pass | |
| 5.2.2 | Ensure sudo commands use pty | L1 | Pass | |
| 5.2.3 | Ensure sudo log file exists | L1 | Pass | |
| 5.2.4 | Ensure users must provide password for privilege escalation | L2 | Fail | |
| 5.2.5 | Ensure re-authentication for privilege escalation isn't disabled globally | L1 | Pass | |
| 5.2.6 | Ensure sudo authentication timeout is configured correctly | L1 | Pass | |
| 5.2.7 | Ensure access to the su command is restricted | L1 | Pass | |
| 5.3 | **Pluggable Authentication Modules** | | | |
| 5.3.1 | **Configure PAM software packages** | | | |
| 5.3.1.1 | Ensure latest version of pam is installed | L1 | Pass | |
| 5.3.1.2 | Ensure libpam-modules is installed | L1 | Pass | |
| 5.3.1.3 | Ensure libpam-pwquality is installed | L1 | Pass | |
| 5.3.2 | **Configure pam-auth-update profiles** | | | |
| 5.3.2.1 | Ensure pam_unix module is enabled | L1 | Pass | |
| 5.3.2.2 | Ensure pam_faillock module is enabled | L1 | Pass | |
| 5.3.2.3 | Ensure pam_pwquality module is enabled | L1 | Pass | |
| 5.3.2.4 | Ensure pam_pwhistory module is enabled | L1 | Pass | |
| 5.3.3 | **Configure PAM Arguments** | | | |
| 5.3.3.1 | **Configure pam_faillock module** | | | |
| 5.3.3.1.1 | Ensure password failed attempts lockout is configured | L1 | Pass | |
| 5.3.3.1.2 | Ensure password unlock time is configured | L1 | Pass | |
| 5.3.3.1.3 | Ensure password failed attempts lockout includes root account | L2 | Pass | |
| 5.3.3.2 | **Configure pam_pwquality module** | | | |
| 5.3.3.2.1 | Ensure password number of changed characters is configured | L1 | Pass | |
| 5.3.3.2.2 | Ensure minimum password length is configured | L1 | Pass | |
| 5.3.3.2.3 | Ensure password complexity is configured | L1 | Manual | Configured by default by AKS. |
| 5.3.3.2.4 | Ensure password same consecutive characters is configured | L1 | Pass | |
| 5.3.3.2.5 | Ensure password maximum sequential characters is configured | L1 | Pass | |
| 5.3.3.2.6 | Ensure password dictionary check is enabled | L1 | Pass | |
| 5.3.3.2.7 | Ensure password quality checking is enforced | L1 | Pass | |
| 5.3.3.2.8 | Ensure password quality is enforced for the root user | L1 | Pass | |
| 5.3.3.3 | **Configure pam_pwhistory module** | | | |
| 5.3.3.3.1 | Ensure password history remember is configured | L1 | Pass | |
| 5.3.3.3.2 | Ensure password history is enforced for the root user | L1 | Pass | |
| 5.3.3.3.3 | Ensure pam_pwhistory includes use_authtok | L1 | Pass | |
| 5.3.3.4 | **Configure pam_unix module** | | | |
| 5.3.3.4.1 | Ensure pam_unix doesn't include nullok | L1 | Pass | |
| 5.3.3.4.2 | Ensure pam_unix doesn't include remember | L1 | Pass | |
| 5.3.3.4.3 | Ensure pam_unix includes a strong password hashing algorithm | L1 | Pass | |
| 5.3.3.4.4 | Ensure pam_unix includes use_authtok | L1 | Pass | |
| 5.4 | **User Accounts and Environment** | | | |
| 5.4.1 | **Configure shadow password suite parameters** | | | |
| 5.4.1.1 | Ensure password expiration is configured | L1 | Fail | Operational impact: root user password expiry applies even to a locked password and impacts AKS operations |
| 5.4.1.2 | Ensure minimum password days is configured | L2 | Manual | |
| 5.4.1.3 | Ensure password expiration warning days is configured | L1 | Pass | |
| 5.4.1.4 | Ensure strong password hashing algorithm is configured | L1 | Pass | |
| 5.4.1.5 | Ensure inactive password lock is configured | L1 | Fail | Operational impact: root user inactive password lock applies even to a locked password and impacts AKS operations |
| 5.4.1.6 | Ensure all users last password change date is in the past | L1 | Pass | |
| 5.4.2 | **Configure root and system accounts and environment** | | | |
| 5.4.2.1 | Ensure root is the only UID 0 account | L1 | Pass | |
| 5.4.2.2 | Ensure root is the only GID 0 account | L1 | Pass | |
| 5.4.2.3 | Ensure group root is the only GID 0 group | L1 | Pass | |
| 5.4.2.4 | Ensure root account access is controlled | L1 | Pass | |
| 5.4.2.5 | Ensure root path integrity | L1 | Pass | |
| 5.4.2.6 | Ensure root user umask is configured | L1 | Pass | |
| 5.4.2.7 | Ensure system accounts don't have a valid login shell | L1 | Pass | |
| 5.4.2.8 | Ensure accounts without a valid login shell are locked | L1 | Pass | |
| 5.4.3 | **Configure user default environment** | | | |
| 5.4.3.1 | Ensure nologin isn't listed in /etc/shells | L2 | Pass | |
| 5.4.3.2 | Ensure default user shell timeout is configured | L1 | Pass | |
| 5.4.3.3 | Ensure default user umask is configured | L1 | Pass | |
| 6 | **Logging and Auditing** | | | |
| 6.1 | **System Logging** | | | |
| 6.1.1 | **Configure systemd-journald service** | | | |
| 6.1.1.1 | Ensure journald service is enabled and active | L1 | Pass | |
| 6.1.1.2 | Ensure journald log file access is configured | L1 | Manual | |
| 6.1.1.3 | Ensure journald log file rotation is configured | L1 | Manual | Configured by default on AKS. |
| 6.1.1.4 | Ensure only one logging system is in use | L1 | Pass | |
| 6.1.2 | **Configure journald** | | | |
| 6.1.2.1 | **Configure systemd-journal-remote** | | | |
| 6.1.2.1.1 | Ensure systemd-journal-remote is installed | L1 | Pass | |
| 6.1.2.1.2 | Ensure systemd-journal-upload authentication is configured | L1 | Not applicable | AKS doesn't use log uploading and relies on rsyslog. |
| 6.1.2.1.3 | Ensure systemd-journal-upload is enabled and active | L1 | Pass | |
| 6.1.2.1.4 | Ensure systemd-journal-remote service isn't in use | L1 | Pass | |
| 6.1.2.2 | Ensure journald ForwardToSyslog is disabled | L1 | Pass | |
| 6.1.2.3 | Ensure journald Compress is configured | L1 | Pass | |
| 6.1.2.4 | Ensure journald Storage is configured | L1 | Pass | |
| 6.1.3 | **Configure rsyslog** | | | |
| 6.1.3.1 | Ensure rsyslog is installed | L1 | Pass | |
| 6.1.3.2 | Ensure rsyslog service is enabled and active | L1 | Pass | |
| 6.1.3.3 | Ensure journald is configured to send logs to rsyslog | L1 | Pass | |
| 6.1.3.4 | Ensure rsyslog log file creation mode is configured | L1 | Pass | |
| 6.1.3.5 | Ensure rsyslog logging is configured | L1 | Manual | |
| 6.1.3.6 | Ensure rsyslog is configured to send logs to a remote log host | L1 | Not applicable | [Azure Monitor Agent for Linux is configured][azure-monitor-agent]. |
| 6.1.3.7 | Ensure rsyslog isn't configured to receive logs from a remote client | L1 | Pass | |
| 6.1.3.8 | Ensure logrotate is configured | L1 | Manual | |
| 6.1.4 | **Configure Logfiles** | | | |
| 6.1.4.1 | Ensure access to all logfiles has been configured | L1 | Pass | |
| 6.2 | **Configure auditd** | | | |
| 6.2.1 | **Configure auditd service** | | | |
| 6.2.1.1 | Ensure auditd packages are installed | L2 | Fail | auditd isn't enabled on AKS nodes to reduce overhead. |
| 6.2.1.2 | Ensure auditd service is enabled and active | L2 | Fail | |
| 6.2.1.3 | Ensure auditing for processes that start prior to auditd is enabled | L2 | Fail | |
| 6.2.1.4 | Ensure audit_backlog_limit is sufficient | L2 | Fail | |
| 6.2.2 | **Configure auditd logs** | | | |
| 6.2.2.1 | Ensure audit log storage size is configured | L2 | Fail | |
| 6.2.2.2 | Ensure audit logs are not automatically deleted | L2 | Fail | |
| 6.2.2.3 | Ensure system is disabled when audit logs are full | L2 | Fail | |
| 6.2.2.4 | Ensure system warns when audit logs are low on space | L2 | Fail | |
| 6.2.3 | **Configure auditd rules** | | | |
| 6.2.3.1 | Ensure changes to system administration scope (sudoers) is collected | L2 | Fail | |
| 6.2.3.2 | Ensure actions as another user are always logged | L2 | Fail | |
| 6.2.3.3 | Ensure events that modify the sudo log file are collected | L2 | Fail | |
| 6.2.3.4 | Ensure events that modify date and time information are collected | L2 | Fail | |
| 6.2.3.5 | Ensure events that modify the system's network environment are collected | L2 | Fail | |
| 6.2.3.6 | Ensure use of privileged commands are collected | L2 | Fail | |
| 6.2.3.7 | Ensure unsuccessful file access attempts are collected | L2 | Fail | |
| 6.2.3.8 | Ensure events that modify user/group information are collected | L2 | Fail | |
| 6.2.3.9 | Ensure discretionary access control permission modification events are collected | L2 | Fail | |
| 6.2.3.10 | Ensure successful file system mounts are collected | L2 | Fail | |
| 6.2.3.11 | Ensure session initiation information is collected | L2 | Fail | |
| 6.2.3.12 | Ensure login and logout events are collected | L2 | Fail | |
| 6.2.3.13 | Ensure file deletion events by users are collected | L2 | Fail | |
| 6.2.3.14 | Ensure events that modify the system's Mandatory Access Controls are collected | L2 | Fail | |
| 6.2.3.15 | Ensure successful and unsuccessful attempts to use the chcon command are collected | L2 | Fail | |
| 6.2.3.16 | Ensure successful and unsuccessful attempts to use the setfacl command are collected | L2 | Fail | |
| 6.2.3.17 | Ensure successful and unsuccessful attempts to use the chacl command are collected | L2 | Fail | |
| 6.2.3.18 | Ensure successful and unsuccessful attempts to use the usermod command are collected | L2 | Fail | |
| 6.2.3.19 | Ensure kernel module loading unloading and modification is collected | L2 | Fail | |
| 6.2.3.20 | Ensure the audit configuration is immutable | L2 | Fail | |
| 6.2.3.21 | Ensure the running and on disk configuration is the same | L2 | Manual | |
| 6.2.4 | **Configure auditd file access** | | | |
| 6.2.4.1 | Ensure audit log files mode is configured | L2 | Fail | |
| 6.2.4.2 | Ensure audit log files owner is configured | L2 | Fail | |
| 6.2.4.3 | Ensure audit log files group owner is configured | L2 | Pass | |
| 6.2.4.4 | Ensure the audit log file directory mode is configured | L2 | Fail | |
| 6.2.4.5 | Ensure audit configuration files mode is configured | L2 | Pass | |
| 6.2.4.6 | Ensure audit configuration files owner is configured | L2 | Pass | |
| 6.2.4.7 | Ensure audit configuration files group owner is configured | L2 | Pass | |
| 6.2.4.8 | Ensure audit tools mode is configured | L2 | Pass | |
| 6.2.4.9 | Ensure audit tools owner is configured | L2 | Pass | |
| 6.2.4.10 | Ensure audit tools group owner is configured | L2 | Pass | |
| 6.3 | **Configure Integrity Checking** | | | |
| 6.3.1 | Ensure AIDE is installed | L1 | Operational impact | Scanning would impact workloads periodically. |
| 6.3.2 | Ensure filesystem integrity is regularly checked | L1 | Operational impact | Scanning would impact workloads periodically. |
| 6.3.3 | Ensure cryptographic mechanisms are used to protect the integrity of audit tools | L2 | Fail | . |
| 7 | **System Maintenance** | | | |
| 7.1 | **System File Permissions** | | | |
| 7.1.1 | Ensure permissions on /etc/passwd are configured | L1 | Pass | |
| 7.1.2 | Ensure permissions on /etc/passwd- are configured | L1 | Pass | |
| 7.1.3 | Ensure permissions on /etc/group are configured | L1 | Pass | |
| 7.1.4 | Ensure permissions on /etc/group- are configured | L1 | Pass | |
| 7.1.5 | Ensure permissions on /etc/shadow are configured | L1 | Pass | |
| 7.1.6 | Ensure permissions on /etc/shadow- are configured | L1 | Pass | |
| 7.1.7 | Ensure permissions on /etc/gshadow are configured | L1 | Pass | |
| 7.1.8 | Ensure permissions on /etc/gshadow- are configured | L1 | Pass | |
| 7.1.9 | Ensure permissions on /etc/shells are configured | L1 | Pass | |
| 7.1.10 | Ensure permissions on /etc/security/opasswd are configured | L1 | Pass | |
| 7.1.11 | Ensure world writable files and directories are secured | L1 | Pass | |
| 7.1.12 | Ensure no files or directories without an owner and a group exist | L1 | Pass | |
| 7.1.13 | Ensure SUID and SGID files are reviewed | L1 | Manual | |
| 7.2 | **Local User and Group Settings** | | | |
| 7.2.1 | Ensure accounts in /etc/passwd use shadowed passwords | L1 | Pass | |
| 7.2.2 | Ensure /etc/shadow password fields aren't empty | L1 | Pass | |
| 7.2.3 | Ensure all groups in /etc/passwd exist in /etc/group | L1 | Pass | |
| 7.2.4 | Ensure shadow group is empty | L1 | Pass | |
| 7.2.5 | Ensure no duplicate UIDs exist | L1 | Pass | |
| 7.2.6 | Ensure no duplicate GIDs exist | L1 | Pass | |
| 7.2.7 | Ensure no duplicate user names exist | L1 | Pass | |
| 7.2.8 | Ensure no duplicate group names exist | L1 | Pass | |
| 7.2.9 | Ensure local interactive user home directories are configured | L1 | Pass | |
| 7.2.10 | Ensure local interactive user dot files access is configured | L1 | Pass | |

## Ubuntu LTS 22.04

AKS node images aim to be compliant with the "L1 - Server" profile where possible in a way that doesn't interfere with Kubernetes node operations. L2 compliance status is provided for informational purposes only and the node configuration is not currently compliant.

### Ubuntu LTS 22.04 Benchmark

The following are the results from [CIS Ubuntu 22.04 LTS Benchmark v3.0.0][cis-benchmark-ubuntu] recommendations based on the CIS rules:

| CIS paragraph number | Recommendation description | Level | Status | Reason |
|---|---|---|---|---|
| 1 | **Initial Setup** | | | |
| 1.1 | **Filesystem** | | | |
| 1.1.1 | **Configure Filesystem Kernel Modules** | | | |
| 1.1.1.1 | Ensure cramfs kernel module isn't available | L1 | Pass | |
| 1.1.1.2 | Ensure freevxfs kernel module isn't available | L1 | Pass | |
| 1.1.1.3 | Ensure hfs kernel module isn't available | L1 | Pass | |
| 1.1.1.4 | Ensure hfsplus kernel module isn't available | L1 | Pass | |
| 1.1.1.5 | Ensure jffs2 kernel module isn't available | L1 | Pass | |
| 1.1.1.6 | Ensure overlay kernel module isn't available | L2 | Fail | |
| 1.1.1.7 | Ensure squashfs kernel module isn't available | L2 | Pass | |
| 1.1.1.8 | Ensure udf kernel module isn't available | L2 | Fail | |
| 1.1.1.9 | Ensure usb-storage kernel module isn't available | L1 | Pass | |
| 1.1.1.10 | Ensure unused filesystems kernel modules aren't available | L1 | Manual | |
| 1.1.1.11 | Ensure firewire-core kernel module isn't available | L1 | Fail | |
| 1.1.2 | **Configure Filesystem Partitions** | | | |
| 1.1.2.1 | **Configure /tmp** | | | |
| 1.1.2.1.1 | Ensure /tmp is tmpfs or a separate partition | L1 | Fail | Operational impact: Making /tmp a separate partition would require turning it into a tmpfs (in-memory filesystem) which would consume the same memory available for pods. |
| 1.1.2.1.2 | Ensure nodev option set on /tmp partition | L1 | Pass | |
| 1.1.2.1.3 | Ensure nosuid option set on /tmp partition | L1 | Pass | |
| 1.1.2.1.4 | Ensure noexec option set on /tmp partition | L1 | Pass | |
| 1.1.2.2 | **Configure /dev/shm** | | | |
| 1.1.2.2.1 | Ensure /dev/shm is tmpfs or a separate partition | L1 | Pass | |
| 1.1.2.2.2 | Ensure nodev option set on /dev/shm partition | L1 | Pass | |
| 1.1.2.2.3 | Ensure nosuid option set on /dev/shm partition | L1 | Pass | |
| 1.1.2.2.4 | Ensure noexec option set on /dev/shm partition | L1 | Pass | |
| 1.1.2.3 | **Configure /home** | | | |
| 1.1.2.3.1 | Ensure separate partition exists for /home | L2 | Fail | |
| 1.1.2.3.2 | Ensure nodev option set on /home partition | L1 | Pass | |
| 1.1.2.3.3 | Ensure nosuid option set on /home partition | L1 | Pass | |
| 1.1.2.4 | **Configure /var** | | | |
| 1.1.2.4.1 | Ensure separate partition exists for /var | L2 | Fail | |
| 1.1.2.4.2 | Ensure nodev option set on /var partition | L1 | Pass | |
| 1.1.2.4.3 | Ensure nosuid option set on /var partition | L1 | Pass | |
| 1.1.2.5 | **Configure /var/tmp** | | | |
| 1.1.2.5.1 | Ensure separate partition exists for /var/tmp | L2 | Fail | |
| 1.1.2.5.2 | Ensure nodev option set on /var/tmp partition | L1 | Pass | |
| 1.1.2.5.3 | Ensure nosuid option set on /var/tmp partition | L1 | Pass | |
| 1.1.2.5.4 | Ensure noexec option set on /var/tmp partition | L1 | Pass | |
| 1.1.2.6 | **Configure /var/log** | | | |
| 1.1.2.6.1 | Ensure separate partition exists for /var/log | L2 | Fail | |
| 1.1.2.6.2 | Ensure nodev option set on /var/log partition | L1 | Pass | |
| 1.1.2.6.3 | Ensure nosuid option set on /var/log partition | L1 | Pass | |
| 1.1.2.6.4 | Ensure noexec option set on /var/log partition | L1 | Pass | |
| 1.1.2.7 | **Configure /var/log/audit** | | | |
| 1.1.2.7.1 | Ensure separate partition exists for /var/log/audit | L2 | Fail | |
| 1.1.2.7.2 | Ensure nodev option set on /var/log/audit partition | L1 | Pass | |
| 1.1.2.7.3 | Ensure nosuid option set on /var/log/audit partition | L1 | Pass | |
| 1.1.2.7.4 | Ensure noexec option set on /var/log/audit partition | L1 | Pass | |
| 1.2 | **Package Management** | | | |
| 1.2.1 | **Configure Package Repositories** | | | |
| 1.2.1.1 | Ensure GPG keys are configured | L1 | Manual | |
| 1.2.1.2 | Ensure package manager repositories are configured | L1 | Manual | |
| 1.2.2 | **Configure Package Updates** | | | |
| 1.2.2.1 | Ensure updates, patches, and additional security software are installed | L1 | Depends on Environment | [Node OS Upgrade channels][auto-upgrade-node] can be used to automate updates and patches. |
| 1.3 | **Mandatory Access Control** | | | |
| 1.3.1 | **Configure AppArmor** | | | |
| 1.3.1.1 | Ensure the apparmor packages are installed | L1 | Pass | |
| 1.3.1.2 | Ensure AppArmor is enabled | L1 | Pass | |
| 1.3.1.3 | Ensure all AppArmor Profiles are not disabled | L1 | Pass | |
| 1.3.1.4 | Ensure all AppArmor Profiles are enforcing | L2 | Pass | |
| 1.4 | **Configure Bootloader** | | | |
| 1.4.1 | Ensure bootloader password is set | L1 | Pass | |
| 1.4.2 | Ensure access to bootloader config is configured | L1 | Pass | |
| 1.5 | **Configure Additional Process Hardening** | | | |
| 1.5.1 | Ensure randomize_va_space is configured | L1 | Pass | |
| 1.5.2 | Ensure ptrace_scope is configured | L1 | Pass | |
| 1.5.3 | Ensure suid_dumpable is configured | L1 | Pass | |
| 1.5.4 | Ensure core file size is configured | L1 | Pass | |
| 1.5.5 | Ensure prelink isn't installed | L1 | Pass | |
| 1.5.6 | Ensure Automatic Error Reporting is configured | L1 | Pass | |
| 1.6 | **Configure Command Line Warning Banners** | | | |
| 1.6.1 | Ensure /etc/motd is configured | L1 | Pass | |
| 1.6.2 | Ensure /etc/issue is configured | L1 | Pass | |
| 1.6.3 | Ensure /etc/issue.net is configured | L1 | Pass | |
| 1.6.4 | Ensure access to /etc/motd is configured | L1 | Pass | |
| 1.6.5 | Ensure access to /etc/issue is configured | L1 | Pass | |
| 1.6.6 | Ensure access to /etc/issue.net is configured | L1 | Pass | |
| 1.7 | **Configure GNOME Display Manager** | | | |
| 1.7.1 | Ensure GDM is removed | L2 | Pass | |
| 1.7.2 | Ensure GDM login banner is configured | L1 | Pass | |
| 1.7.3 | Ensure GDM disable-user-list option is enabled | L1 | Pass | |
| 1.7.4 | Ensure GDM screen locks when the user is idle | L1 | Pass | |
| 1.7.5 | Ensure GDM screen locks cannot be overridden | L1 | Pass | |
| 1.7.6 | Ensure GDM automatic mounting of removable media is disabled | L1 | Pass | |
| 1.7.7 | Ensure GDM disabling automatic mounting of removable media is not overridden | L1 | Pass | |
| 1.7.8 | Ensure GDM autorun-never is enabled | L1 | Pass | |
| 1.7.9 | Ensure GDM autorun-never is not overridden | L1 | Pass | |
| 1.7.10 | Ensure XDMCP is not enabled | L1 | Pass | |
| 1.7.11 | Ensure Xwayland is configured | L2 | Pass | |
| 2 | **Services** | | | |
| 2.1 | **Configure Server Services** | | | |
| 2.1.1 | Ensure autofs services aren't in use | L1 | Pass | |
| 2.1.2 | Ensure avahi daemon services aren't in use | L1 | Pass | |
| 2.1.3 | Ensure dhcp server services aren't in use | L1 | Pass | |
| 2.1.4 | Ensure dns server services aren't in use | L1 | Pass | |
| 2.1.5 | Ensure dnsmasq services aren't in use | L1 | Pass | |
| 2.1.6 | Ensure ftp server services aren't in use | L1 | Pass | |
| 2.1.7 | Ensure ldap server services aren't in use | L1 | Pass | |
| 2.1.8 | Ensure message access server services aren't in use | L1 | Pass | |
| 2.1.9 | Ensure network file system services aren't in use | L1 | Pass | |
| 2.1.10 | Ensure nis server services aren't in use | L1 | Pass | |
| 2.1.11 | Ensure print server services aren't in use | L1 | Pass | |
| 2.1.12 | Ensure rpcbind services aren't in use | L1 | Fail | Operational impact: rpcbind is a required dependency of NFS, used by the Azure CSI driver. |
| 2.1.13 | Ensure rsync services aren't in use | L1 | Pass | |
| 2.1.14 | Ensure samba file server services aren't in use | L1 | Pass | |
| 2.1.15 | Ensure snmp services aren't in use | L1 | Pass | |
| 2.1.16 | Ensure tftp server services aren't in use | L1 | Pass | |
| 2.1.17 | Ensure web proxy server services aren't in use | L1 | Pass | |
| 2.1.18 | Ensure web server services aren't in use | L1 | Pass | |
| 2.1.19 | Ensure xinetd services aren't in use | L1 | Pass | |
| 2.1.20 | Ensure X window server services aren't in use | L2 | Pass | |
| 2.1.21 | Ensure mail transfer agents are configured for local-only mode | L1 | Pass | |
| 2.1.22 | Ensure only approved services are listening on a network interface | L1 | Manual | |
| 2.2 | **Configure Client Services** | | | |
| 2.2.1 | Ensure nis client isn't installed | L1 | Pass | |
| 2.2.2 | Ensure rsh client isn't installed | L1 | Pass | |
| 2.2.3 | Ensure talk client isn't installed | L1 | Pass | |
| 2.2.4 | Ensure telnet client isn't installed | L1 | Pass | |
| 2.2.5 | Ensure ldap client isn't installed | L1 | Pass | |
| 2.2.6 | Ensure ftp client isn't installed | L1 | Pass | |
| 2.3 | **Configure Time Synchronization** | | | |
| 2.3.1 | **Ensure time synchronization is in use** | | | |
| 2.3.1.1 | Ensure a single time synchronization daemon is in use | L1 | Pass | |
| 2.3.2 | **Configure systemd-timesyncd** | | | |
| 2.3.2.1 | Ensure systemd-timesyncd configured with authorized timeserver | L1 | Pass | |
| 2.3.2.2 | Ensure systemd-timesyncd is enabled and running | L1 | Pass | |
| 2.3.3 | **Configure chrony** | | | |
| 2.3.3.1 | Ensure chrony is configured with authorized timeserver | L1 | Fail | AKS nodes are configured to use chrony to sync to the host's PTP hardware clock using a hypervisor interface. The PTP hardware clock is the authorized timeserver for Azure. For more information, see the configuration of [chrony][chrony]. |
| 2.3.3.2 | Ensure chrony is running as user _chrony | L1 | Pass | |
| 2.3.3.3 | Ensure chrony is enabled and running | L1 | Pass | |
| 2.4 | **Job Schedulers** | | | |
| 2.4.1 | **Configure cron** | | | |
| 2.4.1.1 | Ensure cron daemon is enabled and active | L1 | Pass | |
| 2.4.1.2 | Ensure access to /etc/crontab is configured | L1 | Pass | |
| 2.4.1.3 | Ensure access to /etc/cron.hourly is configured | L1 | Pass | |
| 2.4.1.4 | Ensure access to /etc/cron.daily is configured | L1 | Pass | |
| 2.4.1.5 | Ensure access to /etc/cron.weekly is configured | L1 | Pass | |
| 2.4.1.6 | Ensure access to /etc/cron.monthly is configured | L1 | Pass | |
| 2.4.1.7 | Ensure access to /etc/cron.yearly is configured | L1 | Pass | |
| 2.4.1.8 | Ensure access to /etc/cron.d is configured | L1 | Pass | |
| 2.4.1.9 | Ensure access to crontab is configured | L1 | Pass | |
| 2.4.2 | **Configure at** | | | |
| 2.4.2.1 | Ensure access to at is configured | L1 | Pass | |
| 3 | **Network Configuration** | | | |
| 3.1 | **Configure Network Devices** | | | |
| 3.1.1 | Ensure IPv6 status is identified | L1 | Manual | |
| 3.1.2 | Ensure wireless interfaces are not available | L1 | Pass | |
| 3.1.3 | Ensure bluetooth services are not in use | L1 | Pass | |
| 3.2 | **Configure Network Kernel Modules** | | | |
| 3.2.1 | Ensure dccp kernel module isn't available | L1 | Fail | Operational impact: this module is kept available for compatibility with user workloads. |
| 3.2.2 | Ensure tipc kernel module isn't available | L1 | Fail | Operational impact: this module is kept available for compatibility with user workloads. |
| 3.2.3 | Ensure rds kernel module isn't available | L1 | Fail | Operational impact: this module is kept available for compatibility with user workloads. |
| 3.2.4 | Ensure sctp kernel module isn't available | L1 | Fail | Operational impact: this module is kept available for compatibility with user workloads. |
| 3.3 | **Configure Network Kernel Parameters** | | | |
| 3.3.1.1 | Ensure net.ipv4.ip_forward is configured | L2 | Fail | |
| 3.3.1.2 | Ensure net.ipv4.conf.all.forwarding is configured | L1 | Fail | Operational impact: this is required for container networking to function. |
| 3.3.1.3 | Ensure net.ipv4.conf.default.forwarding is configured | L1 | Fail | Operational impact: this is required for container networking to function. |
| 3.3.1.4 | Ensure net.ipv4.conf.all.send_redirects is configured | L1 | Pass | |
| 3.3.1.5 | Ensure net.ipv4.conf.default.send_redirects is configured | L1 | Pass | |
| 3.3.1.6 | Ensure net.ipv4.icmp_ignore_bogus_error_responses is configured | L1 | Pass | |
| 3.3.1.7 | Ensure net.ipv4.icmp_echo_ignore_broadcasts is configured | L1 | Pass | |
| 3.3.1.8 | Ensure net.ipv4.conf.all.accept_redirects is configured | L1 | Pass | |
| 3.3.1.9 | Ensure net.ipv4.conf.default.accept_redirects is configured | L1 | Pass | |
| 3.3.1.10 | Ensure net.ipv4.conf.all.secure_redirects is configured | L1 | Pass | |
| 3.3.1.11 | Ensure net.ipv4.conf.default.secure_redirects is configured | L1 | Pass | |
| 3.3.1.12 | Ensure net.ipv4.conf.all.rp_filter is configured | L1 | Pass | |
| 3.3.1.13 | Ensure net.ipv4.conf.default.rp_filter is configured | L1 | Pass | |
| 3.3.1.14 | Ensure net.ipv4.conf.all.accept_source_route is configured | L1 | Pass | |
| 3.3.1.15 | Ensure net.ipv4.conf.default.accept_source_route is configured | L1 | Pass | |
| 3.3.1.16 | Ensure net.ipv4.conf.all.log_martians is configured | L1 | Pass | |
| 3.3.1.17 | Ensure net.ipv4.conf.default.log_martians is configured | L1 | Pass | |
| 3.3.1.18 | Ensure net.ipv4.tcp_syncookies is configured | L1 | Pass | |
| 3.3.2.1 | Ensure net.ipv6.conf.all.forwarding is configured | L1 | Fail | Operational impact: this is required for container networking to function. |
| 3.3.2.2 | Ensure net.ipv6.conf.default.forwarding is configured | L1 | Fail | Operational impact: this is required for container networking to function. |
| 3.3.2.3 | Ensure net.ipv6.conf.all.accept_redirects is configured | L1 | Pass | |
| 3.3.2.4 | Ensure net.ipv6.conf.default.accept_redirects is configured | L1 | Pass | |
| 3.3.2.5 | Ensure net.ipv6.conf.all.accept_source_route is configured | L1 | Pass | |
| 3.3.2.6 | Ensure net.ipv6.conf.default.accept_source_route is configured | L1 | Pass | |
| 3.3.2.7 | Ensure net.ipv6.conf.all.accept_ra is configured | L1 | Pass | |
| 3.3.2.8 | Ensure net.ipv6.conf.default.accept_ra is configured | L1 | Pass | |
| 4 | **Host Based Firewall** | | | |
| 4.1.1 | Ensure ufw is installed | L1 | Covered elsewhere | |
| 4.1.2 | Ensure ufw service is configured | L1 | Covered elsewhere | |
| 4.1.3 | Ensure ufw incoming default is configured | L1 | Covered elsewhere | |
| 4.1.4 | Ensure ufw outgoing default is configured | L2 | Covered elsewhere | |
| 4.1.5 | Ensure ufw routed default is configured | L1 | Covered elsewhere | |
| 5 | **Access, Authentication, and Authorization** | | | |
| 5.1 | **Configure SSH Server** | | | |
| 5.1.1 | Ensure access to /etc/ssh/sshd_config is configured | L1 | Pass | |
| 5.1.2 | Ensure access to SSH private host key files is configured | L1 | Pass | |
| 5.1.3 | Ensure access to SSH public host key files is configured | L1 | Pass | |
| 5.1.4 | Ensure sshd access is configured | L1 | Pass | |
| 5.1.5 | Ensure sshd Banner is configured | L1 | Pass | |
| 5.1.6 | Ensure sshd Ciphers are configured | L1 | Pass | |
| 5.1.7 | Ensure sshd ClientAliveInterval and ClientAliveCountMax are configured | L1 | Pass | |
| 5.1.8 | Ensure sshd DisableForwarding is enabled | L2 | Fail | |
| 5.1.9 | Ensure sshd GSSAPIAuthentication is disabled | L2 | Pass | |
| 5.1.10 | Ensure sshd HostbasedAuthentication is disabled | L1 | Pass | |
| 5.1.11 | Ensure sshd IgnoreRhosts is enabled | L1 | Pass | |
| 5.1.12 | Ensure sshd KexAlgorithms is configured | L1 | Pass | |
| 5.1.13 | Ensure sshd LoginGraceTime is configured | L1 | Pass | |
| 5.1.14 | Ensure sshd LogLevel is configured | L1 | Pass | |
| 5.1.15 | Ensure sshd MACs are configured | L1 | Pass | |
| 5.1.16 | Ensure sshd MaxAuthTries is configured | L1 | Pass | |
| 5.1.17 | Ensure sshd MaxSessions is configured | L1 | Pass | |
| 5.1.18 | Ensure sshd MaxStartups is configured | L1 | Pass | |
| 5.1.19 | Ensure sshd PermitEmptyPasswords is disabled | L1 | Pass | |
| 5.1.20 | Ensure sshd PermitRootLogin is disabled | L1 | Pass | |
| 5.1.21 | Ensure sshd PermitUserEnvironment is disabled | L1 | Pass | |
| 5.1.22 | Ensure sshd UsePAM is enabled | L1 | Pass | |
| 5.2 | **Configure privilege escalation** | | | |
| 5.2.1 | Ensure sudo is installed | L1 | Pass | |
| 5.2.2 | Ensure sudo commands use pty | L1 | Pass | |
| 5.2.3 | Ensure sudo log file exists | L1 | Pass | |
| 5.2.4 | Ensure users must provide password for escalation | L2 | Fail | |
| 5.2.5 | Ensure re-authentication for privilege escalation is not disabled globally | L1 | Pass | |
| 5.2.6 | Ensure sudo timestamp_timeout is configured | L1 | Pass | |
| 5.2.7 | Ensure access to the su command is restricted | L1 | Pass | |
| 5.3 | **Pluggable Authentication Modules** | | | |
| 5.3.1 | **Configure PAM software packages** | | | |
| 5.3.1.1 | Ensure latest version of pam is installed | L1 | Pass | |
| 5.3.1.2 | Ensure latest version of libpam-modules is installed | L1 | Pass | |
| 5.3.1.3 | Ensure latest version of libpam-pwquality is installed | L1 | Pass | |
| 5.3.2 | **Configure pam-auth-update profiles** | | | |
| 5.3.2.1 | Ensure pam_unix module is enabled | L1 | Pass | |
| 5.3.2.2 | Ensure pam_faillock module is enabled | L1 | Pass | |
| 5.3.2.3 | Ensure pam_pwquality module is enabled | L1 | Pass | |
| 5.3.2.4 | Ensure pam_pwhistory module is enabled | L1 | Pass | |
| 5.3.3 | **Configure PAM Arguments** | | | |
| 5.3.3.1.1 | Ensure password failed attempts lockout is configured | L1 | Pass | |
| 5.3.3.1.2 | Ensure password unlock time is configured | L1 | Pass | |
| 5.3.3.1.3 | Ensure password failed attempts lockout includes root account | L2 | Pass | |
| 5.3.3.2.1 | Ensure password number of changed characters is configured | L1 | Pass | |
| 5.3.3.2.2 | Ensure minimum password length is configured | L1 | Pass | |
| 5.3.3.2.3 | Ensure password complexity is configured | L1 | Manual | Configured by default by AKS. |
| 5.3.3.2.4 | Ensure password same consecutive characters is configured | L1 | Pass | |
| 5.3.3.2.5 | Ensure password maximum sequential characters is configured | L1 | Pass | |
| 5.3.3.2.6 | Ensure password dictionary check is enabled | L1 | Pass | |
| 5.3.3.2.7 | Ensure password quality checking is enforced | L1 | Pass | |
| 5.3.3.2.8 | Ensure password quality is enforced for the root user | L1 | Pass | |
| 5.3.3.3.1 | Ensure password history remember is configured | L1 | Pass | |
| 5.3.3.3.2 | Ensure password history is enforced for the root user | L1 | Pass | |
| 5.3.3.3.3 | Ensure pam_pwhistory includes use_authtok | L1 | Pass | |
| 5.3.3.4.1 | Ensure pam_unix does not include nullok | L1 | Pass | |
| 5.3.3.4.2 | Ensure pam_unix does not include remember | L1 | Pass | |
| 5.3.3.4.3 | Ensure pam_unix includes a strong password hashing algorithm | L1 | Pass | |
| 5.3.3.4.4 | Ensure pam_unix includes use_authtok | L1 | Pass | |
| 5.4 | **User Accounts and Environment** | | | |
| 5.4.1 | **Configure shadow password suite parameters** | | | |
| 5.4.1.1 | Ensure password expiration is configured | L1 | Fail | Operational impact: root user password expiry applies even to a locked password and impacts AKS operations. |
| 5.4.1.2 | Ensure minimum password days is configured | L2 | Manual | |
| 5.4.1.3 | Ensure password expiration warning days is configured | L1 | Pass | |
| 5.4.1.4 | Ensure strong password hashing algorithm is configured | L1 | Pass | |
| 5.4.1.5 | Ensure inactive password lock is configured | L1 | Fail | Operational impact: root user inactive password lock applies even to a locked password and impacts AKS operations. |
| 5.4.1.6 | Ensure all users last password change date is in the past | L1 | Pass | |
| 5.4.2.1 | Ensure root is the only UID 0 account | L1 | Pass | |
| 5.4.2.2 | Ensure root is the only GID 0 account | L1 | Pass | |
| 5.4.2.3 | Ensure group root is the only GID 0 group | L1 | Pass | |
| 5.4.2.4 | Ensure root account access is controlled | L1 | Pass | |
| 5.4.2.5 | Ensure root path integrity | L1 | Pass | |
| 5.4.2.6 | Ensure root user umask is configured | L1 | Pass | |
| 5.4.2.7 | Ensure system accounts do not have a valid login shell | L1 | Pass | |
| 5.4.2.8 | Ensure accounts without a valid login shell are locked | L1 | Pass | |
| 5.4.3.1 | Ensure nologin is not listed in /etc/shells | L2 | Pass | |
| 5.4.3.2 | Ensure default user shell timeout is configured | L1 | Pass | |
| 5.4.3.3 | Ensure default user umask is configured | L1 | Pass | |
| 6 | **Logging and Auditing** | | | |
| 6.1 | **System Logging** | | | |
| 6.1.1.1.1 | Ensure journald service is active | L1 | Pass | |
| 6.1.1.1.2 | Ensure journald log file access is configured | L1 | Manual | |
| 6.1.1.1.3 | Ensure journald log file rotation is configured | L1 | Manual | Configured by default on AKS. |
| 6.1.1.1.4 | Ensure journald ForwardToSyslog is disabled | L1 | Pass | |
| 6.1.1.1.5 | Ensure journald Storage is configured | L1 | Pass | |
| 6.1.1.1.6 | Ensure journald Compress is configured | L1 | Pass | |
| 6.1.1.2.1 | Ensure systemd-journal-remote is installed | L1 | Pass | |
| 6.1.1.2.2 | Ensure systemd-journal-upload authentication is configured | L1 | Not applicable | AKS doesn't use log uploading and relies on rsyslog. |
| 6.1.1.2.3 | Ensure systemd-journal-upload is enabled and active | L1 | Pass | |
| 6.1.1.2.4 | Ensure systemd-journal-remote service is not in use | L1 | Pass | |
| 6.1.2.1 | Ensure rsyslog is installed | L1 | Pass | |
| 6.1.2.2 | Ensure rsyslog service is enabled and active | L1 | Pass | |
| 6.1.2.3 | Ensure journald is configured to send logs to rsyslog | L1 | Pass | |
| 6.1.2.4 | Ensure rsyslog log file creation mode is configured | L1 | Pass | |
| 6.1.2.5 | Ensure rsyslog logging is configured | L1 | Manual | |
| 6.1.2.6 | Ensure rsyslog is configured to send logs to a remote log host | L1 | Not applicable | [Azure Monitor Agent for Linux is configured][azure-monitor-agent]. |
| 6.1.2.7 | Ensure rsyslog is not configured to receive logs from a remote client | L1 | Pass | |
| 6.1.2.8 | Ensure logrotate is configured | L1 | Manual | |
| 6.1.3.1 | Ensure access to all logfiles has been configured | L1 | Pass | |
| 6.2 | **Configure auditd** | | | |
| 6.2.1.1 | Ensure auditd packages are installed | L2 | Fail | |
| 6.2.1.2 | Ensure auditd service is enabled and active | L2 | Fail | |
| 6.2.1.3 | Ensure auditing for processes that start prior to auditd is enabled | L2 | Fail | |
| 6.2.1.4 | Ensure audit_backlog_limit is configured | L2 | Fail | |
| 6.2.2.1 | Ensure audit log storage size is configured | L2 | Fail | |
| 6.2.2.2 | Ensure audit logs are not automatically deleted | L2 | Fail | |
| 6.2.2.3 | Ensure system is disabled when audit logs are full | L2 | Fail | |
| 6.2.2.4 | Ensure system warns when audit logs are low on space | L2 | Fail | |
| 6.2.3.1 | Ensure changes to system administration scope (sudoers) is collected | L2 | Fail | |
| 6.2.3.2 | Ensure actions as another user are always logged | L2 | Fail | |
| 6.2.3.3 | Ensure events that modify the sudo log file are collected | L2 | Fail | |
| 6.2.3.4 | Ensure events that modify date and time information are collected | L2 | Fail | |
| 6.2.3.5 | Ensure events that modify the system's network environment are collected | L2 | Fail | |
| 6.2.3.6 | Ensure use of privileged commands are collected | L2 | Fail | |
| 6.2.3.7 | Ensure unsuccessful file access attempts are collected | L2 | Fail | |
| 6.2.3.8 | Ensure events that modify user/group information are collected | L2 | Fail | |
| 6.2.3.9 | Ensure discretionary access control permission modification events are collected | L2 | Fail | |
| 6.2.3.10 | Ensure successful file system mounts are collected | L2 | Fail | |
| 6.2.3.11 | Ensure session initiation information is collected | L2 | Fail | |
| 6.2.3.12 | Ensure login and logout events are collected | L2 | Fail | |
| 6.2.3.13 | Ensure file deletion events by users are collected | L2 | Fail | |
| 6.2.3.14 | Ensure events that modify the system's Mandatory Access Controls are collected | L2 | Fail | |
| 6.2.3.15 | Ensure successful and unsuccessful attempts to use the chcon command are collected | L2 | Fail | |
| 6.2.3.16 | Ensure successful and unsuccessful attempts to use the setfacl command are collected | L2 | Fail | |
| 6.2.3.17 | Ensure successful and unsuccessful attempts to use the chacl command are collected | L2 | Fail | |
| 6.2.3.18 | Ensure successful and unsuccessful attempts to use the usermod command are collected | L2 | Fail | |
| 6.2.3.19 | Ensure kernel module loading unloading and modification is collected | L2 | Fail | |
| 6.2.3.20 | Ensure the audit configuration is immutable | L2 | Fail | |
| 6.2.3.21 | Ensure the running and on disk configuration is the same | L2 | Manual | |
| 6.2.4.1 | Ensure audit log files mode is configured | L2 | Fail | |
| 6.2.4.2 | Ensure audit log files owner is configured | L2 | Fail | |
| 6.2.4.3 | Ensure audit log files group owner is configured | L2 | Pass | |
| 6.2.4.4 | Ensure the audit log file directory mode is configured | L2 | Fail | |
| 6.2.4.5 | Ensure audit configuration files mode is configured | L2 | Pass | |
| 6.2.4.6 | Ensure audit configuration files owner is configured | L2 | Pass | |
| 6.2.4.7 | Ensure audit configuration files group owner is configured | L2 | Pass | |
| 6.2.4.8 | Ensure audit tools mode is configured | L2 | Pass | |
| 6.2.4.9 | Ensure audit tools owner is configured | L2 | Pass | |
| 6.2.4.10 | Ensure audit tools group owner is configured | L2 | Pass | |
| 6.3 | **Configure Integrity Checking** | | | |
| 6.3.1 | Ensure AIDE is installed | L1 | Operational impact | Scanning would impact workloads periodically. |
| 6.3.2 | Ensure filesystem integrity is regularly checked | L1 | Operational impact | Scanning would impact workloads periodically. |
| 6.3.3 | Ensure cryptographic mechanisms are used to protect the integrity of audit tools | L2 | Pass | |
| 7 | **System Maintenance** | | | |
| 7.1 | **System File Permissions** | | | |
| 7.1.1 | Ensure access to /etc/passwd is configured | L1 | Pass | |
| 7.1.2 | Ensure access to /etc/passwd- is configured | L1 | Pass | |
| 7.1.3 | Ensure access to /etc/group is configured | L1 | Pass | |
| 7.1.4 | Ensure access to /etc/group- is configured | L1 | Pass | |
| 7.1.5 | Ensure access to /etc/shadow is configured | L1 | Pass | |
| 7.1.6 | Ensure access to /etc/shadow- is configured | L1 | Pass | |
| 7.1.7 | Ensure access to /etc/gshadow is configured | L1 | Pass | |
| 7.1.8 | Ensure access to /etc/gshadow- is configured | L1 | Pass | |
| 7.1.9 | Ensure access to /etc/shells is configured | L1 | Pass | |
| 7.1.10 | Ensure access to /etc/security/opasswd is configured | L1 | Pass | |
| 7.1.11 | Ensure world writable files and directories are secured | L1 | Pass | |
| 7.1.12 | Ensure no files or directories without an owner and a group exist | L1 | Pass | |
| 7.1.13 | Ensure SUID and SGID files are reviewed | L1 | Manual | |
| 7.2 | **Local User and Group Settings** | | | |
| 7.2.1 | Ensure accounts in /etc/passwd use shadowed passwords | L1 | Pass | |
| 7.2.2 | Ensure /etc/shadow password fields are not empty | L1 | Pass | |
| 7.2.3 | Ensure all groups in /etc/passwd exist in /etc/group | L1 | Pass | |
| 7.2.4 | Ensure shadow group is empty | L1 | Pass | |
| 7.2.5 | Ensure no duplicate UIDs exist | L1 | Pass | |
| 7.2.6 | Ensure no duplicate GIDs exist | L1 | Pass | |
| 7.2.7 | Ensure no duplicate user names exist | L1 | Pass | |
| 7.2.8 | Ensure no duplicate group names exist | L1 | Pass | |
| 7.2.9 | Ensure local interactive user home directories are configured | L1 | Pass | |
| 7.2.10 | Ensure local interactive user dot files access is configured | L1 | Pass | |

## Next steps  

For more information about AKS security, see the following articles:

* [Azure Kubernetes Service (AKS)](./intro-kubernetes.md)
* [AKS security considerations](./concepts-security.md)
* [AKS best practices](./best-practices.md)

<!-- EXTERNAL LINKS -->
[cis-benchmark-ubuntu]: https://www.cisecurity.org/benchmark/ubuntu_linux

<!-- INTERNAL LINKS -->
[cis-benchmarks]: /compliance/regulatory/offering-CIS-Benchmark
[linux-security-baseline]: /azure/governance/policy/samples/guest-configuration-baseline-linux
[security-concepts-aks-apps-clusters]: concepts-security.md
[chrony]: /azure/virtual-machines/linux/time-sync#chrony
[azure-monitor-agent]: /azure/azure-monitor/agents/azure-monitor-agent-troubleshoot-linux-vm-rsyslog
[auto-upgrade-node]: auto-upgrade-node-os-image.md
