---
title: Azure Kubernetes Service (AKS) Ubuntu image alignment with Center for Internet Security (CIS) benchmark
description: Learn how AKS applies the CIS benchmark to Ubuntu image used by Azure Kubernetes Service.
ms.date: 10/10/2025
ms.subservice: aks-security
ms.topic: concept-article
author: allyford
ms.author: allyford
# Customer intent: "As a security auditor, I want to verify the alignment of AKS Ubuntu images with CIS benchmarks, so that I can ensure compliance with industry standards and reduce vulnerabilities in our cloud-based applications."
---

# Center for Internet Security (CIS) Ubuntu 24.04 benchmark

> [!IMPORTANT]
> This article applies only to the Ubuntu 24.04 image used by AKS. The recommendation statuses and guidance reflect the [CIS Ubuntu 24.04 LTS Benchmark v1.0.0][cis-benchmark-ubuntu] and a point-in-time Ubuntu 24.04 image (released Sept 18, 2025). They might not apply to other Ubuntu releases (for example Ubuntu 22.04). Verify the OS version and benchmark version before applying guidance.

This article covers the security OS configuration applied to Ubuntu image used by AKS. As a secure service, AKS complies with SOC, ISO, PCI DSS, and HIPAA standards. For more information about the AKS security, see [Security concepts for clusters in Azure Kubernetes Service (AKS)][security-concepts-aks-apps-clusters]. To learn more about the CIS benchmark, see [Center for Internet Security (CIS) Benchmarks][cis-benchmarks]. For more information on the Azure security baselines for Linux, see [Linux security baseline][linux-security-baseline].

## Recommendations

The table has four sections:

* **CIS ID:** The associated rule ID with each of the baseline rules.
* **Recommendation description:** A description of the recommendation issued by the CIS benchmark.
* **Level:** L1, or Level 1, recommends essential basic security requirements that can be configured on any system and should cause little or no interruption of service or reduced functionality.
* **Status:**
    * *Pass* - The recommendation has been applied.
    * *Fail* - The recommendation hasn't been applied.
    * *Manual* - The recommendation can't be scanned automatically. There are instructions in the CIS benchmark to manually review.
    * *N/A* - The recommendation relates to manifest file permission requirements that aren't relevant to AKS.
    * *Depends on Environment* - The recommendation is applied in the user's specific environment and isn't controlled by AKS.
    * *Equivalent Control* - The recommendation has been implemented in a different equivalent manner.
* **Reason:**
    * *Potential Operation Impact* - The recommendation wasn't applied because it would have a negative effect on the service.
    * *Covered Elsewhere* - The recommendation is covered by another control in Azure cloud compute.

## Ubuntu LTS 24.04

AKS clusters are deployed on host virtual machines, which run an operating system with built-in secure configurations. This operating system is used for containers running on AKS. This host operating system is based on an **Ubuntu 24.04.LTS** image with security configurations applied. 

As a part of the security-optimized operating system:

* AKS provides a security-optimized host OS by default, but no option to select an alternate operating system.
* The security-optimized host OS is built and maintained specifically for AKS and **isn't** supported outside of the AKS platform.
* Some unnecessary kernel module drivers have been disabled in the OS to reduce the attack surface area.

> [!NOTE]
> Unrelated to the CIS benchmarks, Azure applies daily patches, including security patches, to AKS virtual machine hosts.

The goal of the secure configuration built into the host OS is to reduce the surface area of attack and optimize for the deployment of containers in a secure manner.

### Ubuntu LTS 24.04 Benchmark

The following are the results from the [CIS Ubuntu 24.04 LTS Benchmark v1.0.0][cis-benchmark-ubuntu] recommendations based on the CIS rules:

| CIS paragraph number | Recommendation description|Status| Reason |
|---|---|---|---|
| 1 | **Initial Setup** ||| 
| 1.1 | **Filesystem** ||| 
| 1.1.1 | **Configure Filesystem Kernel Modules** ||| 
| 1.1.1.1 | Ensure cramfs kernel module isn't available | Pass || 
| 1.1.1.2 | Ensure freevxfs kernel module isn't available | Pass || 
| 1.1.1.3 | Ensure hfs kernel module isn't available | Pass || 
| 1.1.1.4 | Ensure hfsplus kernel module isn't available | Pass || 
| 1.1.1.5 | Ensure jffs2 kernel module isn't available | Pass ||
| 1.1.1.9 | Ensure usb-storage kernel module isn't available | Pass || 
| 1.1.1.10 | Ensure unused filesystems kernel modules aren't available | Manual || 
| 1.1.2 | **Configure Filesystem Partitions** ||| 
| 1.1.2.1 | **Configure /tmp** |||
| 1.1.2.1.1 | Ensure /tmp is a separate partition | Fail |Operational impact: Making /tmp a separate partition would require turning it into a tmpfs (in-memory filesystem) which would consume the same memory available for pods. | 
| 1.1.2.1.2 | Ensure nodev option set on /tmp partition | Pass || 
| 1.1.2.1.3 | Ensure nosuid option set on /tmp partition | Pass || 
| 1.1.2.1.4 | Ensure noexec option set on /tmp partition | Pass || 
| 1.1.2.2 | **Configure /dev/shm** ||| 
| 1.1.2.2.1 | Ensure /dev/shm is a separate partition | Pass || 
| 1.1.2.2.2 | Ensure nodev option set on /dev/shm partition | Pass || 
| 1.1.2.2.3 | Ensure nosuid option set on /dev/shm partition | Pass || 
| 1.1.2.2.4 | Ensure noexec option set on /dev/shm partition | Pass || 
| 1.1.2.3 | **Configure /home** ||| 
| 1.1.2.3.2 | Ensure nodev option set on /home partition | Pass || 
| 1.1.2.3.3 | Ensure nosuid option set on /home partition | Pass || 
| 1.1.2.4 | **Configure /var** ||| 
| 1.1.2.4.2 | Ensure nodev option set on /var partition | Pass || 
| 1.1.2.4.3 | Ensure nosuid option set on /var partition | Pass || 
| 1.1.2.5 | **Configure /var/tmp** ||| 
| 1.1.2.5.2 | Ensure nodev option set on /var/tmp partition | Pass || 
| 1.1.2.5.3 | Ensure nosuid option set on /var/tmp partition | Pass || 
| 1.1.2.5.4 | Ensure noexec option set on /var/tmp partition | Pass || 
| 1.1.2.6 | **Configure /var/log** ||| 
| 1.1.2.6.2 | Ensure nodev option set on /var/log partition | Pass || 
| 1.1.2.6.3 | Ensure nosuid option set on /var/log partition | Pass || 
| 1.1.2.6.4 | Ensure noexec option set on /var/log partition | Pass || 
| 1.1.2.7 | **Configure /var/log/audit** ||| 
| 1.1.2.7.2 | Ensure nodev option set on /var/log/audit partition | Pass || 
| 1.1.2.7.3 | Ensure nosuid option set on /var/log/audit partition | Pass || 
| 1.1.2.7.4 | Ensure noexec option set on /var/log/audit partition | Pass || 
| 1.2 | **Package Management** ||| 
| 1.2.1| **Configure Package Repositories** |||
| 1.2.1.1 | Ensure GPG keys are configured | Manual || 
| 1.2.1.2 | Ensure package manager repositories are configured | Pass || 
| 1.2.2 | **Configure Package Updates** |||
| 1.2.2.1 | Ensure updates, patches, and additional security software are installed | Depends on Environment| [Node OS Upgrade channels][auto-upgrade-node] can be used to automate updates and patches. | 
| 1.3 | **Mandatory Access Control** ||| 
| 1.3.1| **Configure AppArmor** |||
| 1.3.1.1 | Ensure AppArmor is installed | Pass || 
| 1.3.1.2 | Ensure AppArmor is enabled in the bootloader configuration | Pass || 
| 1.3.1.3 | Ensure all AppArmor Profiles are in enforce or complain mode | Fail | Operational impact: May block legitimate workloads and addons. | 
| 1.4 | **Configure Bootloader** ||| 
| 1.4.1 | Ensure bootloader password is set | Pass || 
| 1.4.2 | Ensure access to bootloader config is configured | Pass || 
| 1.5 | **Configure Additional Process Hardening** ||| 
| 1.5.1 | Ensure address space layout randomization is enabled | Pass || 
| 1.5.2 | Ensure ptrace_scope is restricted | Pass || 
| 1.5.3 | Ensure core dumps are restricted | Pass || 
| 1.5.4 | Ensure prelink isn't installed | Pass || 
| 1.5.5 | Ensure Automatic Error Reporting isn't enabled | Pass || 
| 1.6 | **Configure Command Line Warning Banners** ||| 
| 1.6.1 | Ensure message of the day is configured properly | Pass || 
| 1.6.2 | Ensure local login warning banner is configured properly | Pass || 
| 1.6.3 | Ensure remote login warning banner is configured properly | Pass || 
| 1.6.4 | Ensure access to /etc/motd is configured | Pass || 
| 1.6.5 | Ensure access to /etc/issue is configured | Pass || 
| 1.6.6 | Ensure access to /etc/issue.net is configured | Pass || 
| 1.7 | **Configure GNOME Display Manager** ||| 
| 1.7.2 | Ensure GDM login banner is configured | Pass || 
| 1.7.3 | Ensure GDM disable-user-list option is enabled | Pass || 
| 1.7.4 | Ensure GDM screen locks when the user is idle | Pass || 
| 1.7.5 | Ensure GDM screen locks can't be overridden | Pass || 
| 1.7.6 | Ensure GDM automatic mounting of removable media is disabled | Pass || 
| 1.7.7 | Ensure GDM disabling automatic mounting of removable media isn't overridden | Pass || 
| 1.7.8 | Ensure GDM autorun-never is enabled | Pass || 
| 1.7.9 | Ensure GDM autorun-never isn't overridden | Pass || 
| 1.7.10 | Ensure XDMCP isn't enabled | Pass || 
| 2 | **Services** ||| 
| 2.1 | **Configure Server Services** ||| 
| 2.1.1 | Ensure autofs services aren't in use | Pass || 
| 2.1.2 | Ensure avahi daemon services aren't in use | Pass || 
| 2.1.3 | Ensure dhcp server services aren't in use | Pass || 
| 2.1.4 | Ensure dns server services aren't in use | Pass || 
| 2.1.5 | Ensure dnsmasq services aren't in use | Pass || 
| 2.1.6 | Ensure ftp server services aren't in use | Pass || 
| 2.1.7 | Ensure ldap server services aren't in use | Pass || 
| 2.1.8 | Ensure message access server services aren't in use | Pass || 
| 2.1.9 | Ensure network file system services aren't in use | Pass || 
| 2.1.10 | Ensure nis server services aren't in use | Pass || 
| 2.1.11 | Ensure print server services aren't in use | Pass || 
| 2.1.12 | Ensure rpcbind services aren't in use | Fail |Operational impact: rpcbind is a required dependency of NFS, used by the Azure CSI driver.| 
| 2.1.13 | Ensure rsync services aren't in use | Pass || 
| 2.1.14 | Ensure samba file server services aren't in use | Pass || 
| 2.1.15 | Ensure snmp services aren't in use | Pass || 
| 2.1.16 | Ensure tftp server services aren't in use | Pass || 
| 2.1.17 | Ensure web proxy server services aren't in use | Pass || 
| 2.1.18 | Ensure web server services aren't in use | Pass || 
| 2.1.19 | Ensure xinetd services aren't in use | Pass || 
| 2.1.21 | Ensure mail transfer agent is configured for local-only mode | Pass ||
| 2.1.22 | Ensure only approved services are listening on a network interface | Pass || 
| 2.2 | **Configure Client Services** ||| 
| 2.2.1 | Ensure NIS Client isn't installed | Pass || 
| 2.2.2 | Ensure rsh client isn't installed | Pass || 
| 2.2.3 | Ensure talk client isn't installed | Pass || 
| 2.2.4 | Ensure telnet client isn't installed | Pass || 
| 2.2.5 | Ensure ldap client isn't installed | Pass || 
| 2.2.6 | Ensure ftp client isn't installed | Pass || 
| 2.3 | **Configure Time Synchronization** ||| 
| 2.3.1 | **Ensure time synchronization is in use** |||
| 2.3.1.1 | Ensure a single time synchronization daemon is in use | Pass || 
|2.3.2| **Configure systemd-timesyncd** |||
| 2.3.2.1 | Ensure systemd-timesyncd configured with authorized timeserver | Pass || 
| 2.3.2.2 | Ensure systemd-timesyncd is enabled and running | Pass || 
| 2.3.3| **Configure chrony** |||
| 2.3.3.1 | Ensure chrony is configured with authorized timeserver | Fail | AKS Nodes are configured to use chrony to sync to the hosts PTP hardware clock using a hypervisor interface. The PTP hardware clock is the authorized timeserver for Azure. For more information, see the configuration of [chrony][chrony].| 
| 2.3.3.2 | Ensure chrony is running as user _chrony | Pass || 
| 2.3.3.3 | Ensure chrony is enabled and running | Pass || 
| 2.4 | **Job Schedulers** |||
| 2.4.1| **Configure cron** |||
| 2.4.1.1 | Ensure cron daemon is enabled and active | Pass || 
| 2.4.1.2 | Ensure permissions on /etc/crontab are configured | Pass || 
| 2.4.1.3 | Ensure permissions on /etc/cron.hourly are configured | Pass || 
| 2.4.1.4 | Ensure permissions on /etc/cron.daily are configured | Pass || 
| 2.4.1.5 | Ensure permissions on /etc/cron.weekly are configured | Pass || 
| 2.4.1.6 | Ensure permissions on /etc/cron.monthly are configured | Pass || 
| 2.4.1.7 | Ensure permissions on /etc/cron.d are configured | Pass || 
| 2.4.1.8 | Ensure crontab is restricted to authorized users | Pass || 
| 2.4.2 | **Configure at** |||
| 2.4.2.1 | Ensure at is restricted to authorized users | Pass || 
| 3 | **Network** ||| 
| 3.1| **Configure Network Devices** |||
| 3.1.1 | Ensure IPv6 status is identified | Pass|| 
| 3.1.2 | Ensure wireless interfaces are disabled | Pass || 
| 3.1.3 | Ensure bluetooth services aren't in use | Pass || 
|3.3| **Configure Network Kernel Parameters** |||
| 3.3.1 | Ensure ip forwarding is disabled | Fail | Operational impact: this is required for container networking to function.| 
| 3.3.2 | Ensure packet redirect sending is disabled | Pass || 
| 3.3.3 | Ensure bogus icmp responses are ignored | Pass || 
| 3.3.4 | Ensure broadcast icmp requests are ignored | Pass || 
| 3.3.5 | Ensure icmp redirects aren't accepted | Pass || 
| 3.3.6 | Ensure secure icmp redirects aren't accepted | Pass || 
| 3.3.7 | Ensure reverse path filtering is enabled | Pass || 
| 3.3.8 | Ensure source routed packets aren't accepted | Pass || 
| 3.3.9 | Ensure suspicious packets are logged | Pass || 
| 3.3.10 | Ensure tcp syn cookies is enabled | Pass || 
| 3.3.11 | Ensure ipv6 router advertisements aren't accepted | Pass || 
| 4 | **Host Based Firewall** ||| 
| 4.1| **Configure a single firewall utility** |||
| 4.1.1 | Ensure a single firewall configuration utility is in use |Covered elsewhere|| 
| 4.2| **Configure UncomplicatedFirewall** |||
| 4.2.1 | Ensure ufw is installed | Covered elsewhere || 
| 4.2.2 | Ensure iptables-persistent isn't installed with ufw | Covered elsewhere|| 
| 4.2.3 | Ensure ufw service is enabled | Covered elsewhere|| 
| 4.2.4 | Ensure ufw loopback traffic is configured | Covered elsewhere || 
| 4.2.5 | Ensure ufw outbound connections are configured | Covered elsewhere || 
| 4.2.6 | Ensure ufw firewall rules exist for all open ports | Covered elsewhere || 
| 4.2.7 | Ensure ufw default deny firewall policy |Covered elsewhere|| 
| 4.3| **Configure nftables** |||
| 4.3.1 | Ensure nftables is installed | Covered elsewhere|| 
| 4.3.2 | Ensure ufw is uninstalled or disabled with nftables | Covered elsewhere|| 
| 4.3.3 | Ensure iptables are flushed with nftables | Covered elsewhere || 
| 4.3.4 | Ensure a nftables table exists | Covered elsewhere || 
| 4.3.5 | Ensure nftables base chains exist | Covered elsewhere|| 
| 4.3.6 | Ensure nftables loopback traffic is configured | Covered elsewhere || 
| 4.3.7 | Ensure nftables outbound and established connections are configured | Covered elsewhere|| 
| 4.3.8 | Ensure nftables default deny firewall policy | Covered elsewhere || 
| 4.3.9 | Ensure nftables service is enabled | Covered elsewhere || 
| 4.3.10 | Ensure nftables rules are permanent | Covered elsewhere || 
| 4.4| **Configure iptables** |||
| 4.4.1 | **Configure iptables software** |||
| 4.4.1.1 | Ensure iptables packages are installed | Covered elsewhere || 
| 4.4.1.2 | Ensure nftables isn't in use with iptables | Covered elsewhere|| 
| 4.4.1.3 | Ensure ufw isn't in use with iptables | Covered elsewhere|| 
| 4.4.2| **Configure IPV4 iptables** |||
| 4.4.2.1 | Ensure iptables default deny firewall policy | Covered elsewhere || 
| 4.4.2.2 | Ensure iptables loopback traffic is configured | Covered elsewhere || 
| 4.4.2.3 | Ensure iptables outbound and established connections are configured | Covered elsewhere || 
| 4.4.2.4 | Ensure iptables firewall rules exist for all open ports |Covered elsewhere || 
| 4.4.3| **Configure IPv6 ip6tables** |||
| 4.4.3.1 | Ensure ip6tables default deny firewall policy | Covered elsewhere|| 
| 4.4.3.2 | Ensure ip6tables loopback traffic is configured | Covered elsewhere || 
| 4.4.3.3 | Ensure ip6tables outbound and established connections are configured | Covered elsewhere || 
| 4.4.3.4 | Ensure ip6tables firewall rules exist for all open ports | Covered elsewhere|| 
| 5 | **Access Control** ||| 
| 5.1 | **Configure SSH Server** |||
| 5.1.1 | Ensure permissions on /etc/ssh/sshd_config are configured | Pass || 
| 5.1.2 | Ensure permissions on SSH private host key files are configured | Pass || 
| 5.1.3 | Ensure permissions on SSH public host key files are configured | Pass || 
| 5.1.4 | Ensure sshd access is configured | Pass || 
| 5.1.5 | Ensure sshd Banner is configured | Pass || 
| 5.1.6 | Ensure sshd Ciphers are configured | Pass || 
| 5.1.7 | Ensure sshd ClientAliveInterval and ClientAliveCountMax are configured | Pass || 
| 5.1.10 | Ensure sshd HostbasedAuthentication is disabled | Pass || 
| 5.1.11 | Ensure sshd IgnoreRhosts is enabled | Pass || 
| 5.1.12 | Ensure sshd KexAlgorithms is configured | Pass || 
| 5.1.13 | Ensure sshd LoginGraceTime is configured | Pass || 
| 5.1.14 | Ensure sshd LogLevel is configured | Pass || 
| 5.1.15 | Ensure sshd MACs are configured | Pass || 
| 5.1.16 | Ensure sshd MaxAuthTries is configured | Pass || 
| 5.1.17 | Ensure sshd MaxSessions is configured | Pass || 
| 5.1.18 | Ensure sshd MaxStartups is configured | Pass || 
| 5.1.19 | Ensure sshd PermitEmptyPasswords is disabled | Pass || 
| 5.1.20 | Ensure sshd PermitRootLogin is disabled | Pass || 
| 5.1.21 | Ensure sshd PermitUserEnvironment is disabled | Pass || 
| 5.1.22 | Ensure sshd UsePAM is enabled | Pass || 
| 5.2| **Configure privilege escalation** |||
| 5.2.1 | Ensure sudo is installed | Pass || 
| 5.2.2 | Ensure sudo commands use pty | Pass || 
| 5.2.3 | Ensure sudo log file exists | Pass || 
| 5.2.5 | Ensure re-authentication for privilege escalation isn't disabled globally | Pass || 
| 5.2.6 | Ensure sudo authentication timeout is configured correctly | Pass || 
| 5.2.7 | Ensure access to the su command is restricted | Pass || 
| 5.3| **Pluggable Authentication Modules** |||
| 5.3.1 | **Configure PAM software packages** |||
| 5.3.1.1 | Ensure latest version of pam is installed | Pass || 
| 5.3.1.2 | Ensure libpam-modules is installed | Pass || 
| 5.3.1.3 | Ensure libpam-pwquality is installed | Pass || 
| 5.3.2 | **Configure pam-auth-update profiles** |||
| 5.3.2.1 | Ensure pam_unix module is enabled | Pass || 
| 5.3.2.2 | Ensure pam_faillock module is enabled | Pass || 
| 5.3.2.3 | Ensure pam_pwquality module is enabled | Pass || 
| 5.3.2.4 | Ensure pam_pwhistory module is enabled | Pass || 
| 5.3.3 | **Configure PAM Arguments** |||
| 5.3.3.1 | **Configure pam_faillock module** |||
| 5.3.3.1.1 | Ensure password failed attempts lockout is configured | Pass || 
| 5.3.3.1.2 | Ensure password unlock time is configured | Pass ||
| 5.3.3.1.3 | Ensure password failed attempts lockout includes root account | Pass ||
| 5.3.3.2 | **Configure pam_pwquality module** |||
| 5.3.3.2.1 | Ensure password number of changed characters is configured | Pass || 
| 5.3.3.2.2 | Ensure minimum password length is configured | Pass || 
| 5.3.3.2.3 | Ensure password complexity is configured | Manual |Configured by default by AKS| 
| 5.3.3.2.4 | Ensure password same consecutive characters is configured | Pass || 
| 5.3.3.2.5 | Ensure password maximum sequential characters is configured | Pass || 
| 5.3.3.2.6 | Ensure password dictionary check is enabled | Pass || 
| 5.3.3.2.7 | Ensure password quality checking is enforced | Pass || 
| 5.3.3.2.8 | Ensure password quality is enforced for the root user | Pass || 
| 5.3.3.3 | **Configure pam_pwhistory module** |||
| 5.3.3.3.1 | Ensure password history remember is configured | Pass || 
| 5.3.3.3.2 | Ensure password history is enforced for the root user | Pass || 
| 5.3.3.3.3 | Ensure pam_pwhistory includes use_authtok | Pass || 
| 5.3.3.4 | **Configure pam_unix module** |||
| 5.3.3.4.1 | Ensure pam_unix doesn't include nullok | Pass || 
| 5.3.3.4.2 | Ensure pam_unix doesn't include remember | Pass || 
| 5.3.3.4.3 | Ensure pam_unix includes a strong password hashing algorithm | Pass || 
| 5.3.3.4.4 | Ensure pam_unix includes use_authtok | Pass || 
| 5.4 | **User Accounts and Environment** |||
| 5.4.1 | **Configure shadow password suite parameters** |||
| 5.4.1.1 | Ensure password expiration is configured | Pass ||
| 5.4.1.2 | Ensure minimum password days is configured | Pass ||
| 5.4.1.3 | Ensure password expiration warning days is configured | Pass || 
| 5.4.1.4 | Ensure strong password hashing algorithm is configured | Pass || 
| 5.4.1.5 | Ensure inactive password lock is configured | Pass || 
| 5.4.1.6 | Ensure all users last password change date is in the past | Pass || 
| 5.4.2 | **Configure root and system accounts and environment** |||
| 5.4.2.1 | Ensure root is the only UID 0 account | Pass || 
| 5.4.2.2 | Ensure root is the only GID 0 account | Pass || 
| 5.4.2.3 | Ensure group root is the only GID 0 group | Pass || 
| 5.4.2.4 | Ensure root account access is controlled | Pass || 
| 5.4.2.5 | Ensure root path integrity | Pass || 
| 5.4.2.6 | Ensure root user umask is configured | Pass || 
| 5.4.2.7 | Ensure system accounts don't have a valid login shell | Pass || 
| 5.4.2.8 | Ensure accounts without a valid login shell are locked | Pass || 
| 5.4.3 | **Configure user default environment** |||
| 5.4.3.1 | Ensure nologin isn't listed in /etc/shells | Pass ||
| 5.4.3.2 | Ensure default user shell timeout is configured | Pass || 
| 5.4.3.3 | Ensure default user umask is configured | Pass || 
| 6 | **Logging and Auditing** ||| 
| 6.1 | **System Logging** |||
| 6.1.1 | **Configure systemd-journald service** |||
| 6.1.1.1 | Ensure journald service is enabled and active | Pass || 
| 6.1.1.2 | Ensure journald log file access is configured | Manual || 
| 6.1.1.3 | Ensure journald log file rotation is configured | Manual | Configured by default on AKS| 
| 6.1.1.4 | Ensure only one logging system is in use | Pass || 
| 6.1.2 | **Configure journald** |||
| 6.1.2.1 | **Configure systemd-journal-remote** |||
| 6.1.2.1.1 | Ensure systemd-journal-remote is installed | Pass || 
| 6.1.2.1.2 | Ensure systemd-journal-upload authentication is configured | Not applicable| AKS doesn't use log uploading and relies on rsyslog.| 
| 6.1.2.1.3 | Ensure systemd-journal-upload is enabled and active | Pass || 
| 6.1.2.1.4 | Ensure systemd-journal-remote service isn't in use | Pass || 
| 6.1.2.2 | Ensure journald ForwardToSyslog is disabled | Pass || 
| 6.1.2.3 | Ensure journald Compress is configured | Pass || 
| 6.1.2.4 | Ensure journald Storage is configured | Pass || 
| 6.1.3 | **Configure rsyslog** |||
| 6.1.3.1 | Ensure rsyslog is installed | Pass || 
| 6.1.3.2 | Ensure rsyslog service is enabled and active | Pass || 
| 6.1.3.3 | Ensure journald is configured to send logs to rsyslog | Pass || 
| 6.1.3.4 | Ensure rsyslog log file creation mode is configured | Pass || 
| 6.1.3.5 | Ensure rsyslog logging is configured | Pass || 
| 6.1.3.6 | Ensure rsyslog is configured to send logs to a remote log host |Not applicable| [Azure Monitor Agent for Linux is configured][azure-monitor-agent] |
| 6.1.3.7 | Ensure rsyslog is not configured to receive logs from a remote client | Pass || 
| 6.1.3.8 | Ensure logrotate is configured | Pass || 
| 6.1.4 | **Configure Logfiles** |||
| 6.1.4.1 | Ensure access to all logfiles has been configured | Pass || 
| 6.3 | **Configure Integrity Checking** |||
| 6.3.1 | Ensure AIDE is installed | Operational impact|Scanning would impact workloads periodically| 
| 6.3.2 | Ensure filesystem integrity is regularly checked | Operational impact|Scanning would impact workloads periodically| 
| 7 | **System Maintenance** ||| 
| 7.1 | **System File Permissions** |||
| 7.1.1 | Ensure permissions on /etc/passwd are configured | Pass || 
| 7.1.2 | Ensure permissions on /etc/passwd- are configured | Pass || 
| 7.1.3 | Ensure permissions on /etc/group are configured | Pass || 
| 7.1.4 | Ensure permissions on /etc/group- are configured | Pass || 
| 7.1.5 | Ensure permissions on /etc/shadow are configured | Pass || 
| 7.1.6 | Ensure permissions on /etc/shadow- are configured | Pass || 
| 7.1.7 | Ensure permissions on /etc/gshadow are configured | Pass || 
| 7.1.8 | Ensure permissions on /etc/gshadow- are configured | Pass || 
| 7.1.9 | Ensure permissions on /etc/shells are configured | Pass || 
| 7.1.10 | Ensure permissions on /etc/security/opasswd are configured | Pass || 
| 7.1.11 | Ensure world writable files and directories are secured | Pass || 
| 7.1.12 | Ensure no files or directories without an owner and a group exist | Pass || 
| 7.1.13 | Ensure SUID and SGID files are reviewed | Manual || 
| 7.2 | **Local User and Group Settings** |||
| 7.2.1 | Ensure accounts in /etc/passwd use shadowed passwords | Pass || 
| 7.2.2 | Ensure /etc/shadow password fields aren't empty | Pass || 
| 7.2.3 | Ensure all groups in /etc/passwd exist in /etc/group | Pass || 
| 7.2.4 | Ensure shadow group is empty | Pass || 
| 7.2.5 | Ensure no duplicate UIDs exist | Pass || 
| 7.2.6 | Ensure no duplicate GIDs exist | Pass || 
| 7.2.7 | Ensure no duplicate user names exist | Pass || 
| 7.2.8 | Ensure no duplicate group names exist | Pass || 
| 7.2.9 | Ensure local interactive user home directories are configured | Pass || 
| 7.2.10 | Ensure local interactive user dot files access is configured | Pass| |

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