---
title: Use diagnostic checker to identify common causes for failures (preview)
description: Learn how to diagnose common causes for failures in AKS.
ms.topic: troubleshooting
author: davidsmatlak
ms.author: davidsmatlak
ms.date: 09/01/2026
ms.reviewer: srikantsarwa
ms.custom: hyperconverged
#Customer intent: As an AKS user, I want to use the diagnostic checker to run diagnostic checks on my AKS cluster to find out common causes for AKS cluster create failure.
---

# Use the diagnostic checker to diagnose and fix environment issues for AKS cluster creation failure (preview)

It can be difficult to identify environment-related issues, such as networking configuration, that can result in an AKS cluster creation failure. The diagnostic checker is a PowerShell tool that can help you identify AKS cluster creation failures due to potential issues in the environment.

> [!NOTE]
> You can only use the diagnostic checker tool if an AKS cluster was created, but is in a failed state. You can't use the tool if you don't see an AKS cluster on the Azure portal. If the AKS cluster creation fails before an Azure Resource Manager resource is created, [file a support request](help-support.md).

## Before you begin

Before you begin, make sure you have the following prerequisites. If you don't meet the requirements for running the diagnostic checker tool, [file a support request](help-support.md):

- Direct access to the Azure Local cluster where you created the AKS cluster. This access can be through remote desktop (RDP), or you can also sign in to one of the Azure Local physical nodes.
- Review the [networking concepts for creating an AKS cluster](network-system-requirements.md) and the [AKS cluster architecture](cluster-architecture.md).
- The name of the logical network attached to the AKS cluster.
- An SSH private key for the AKS cluster, used to sign in to the AKS cluster [control plane node](cluster-architecture.md#control-plane-nodes) VM.

## Obtain control plane node VM IP of the AKS cluster

Run the following command from any one physical node in your Azure Local cluster. Ensure that you're passing the name, and not the Azure Resource Manager ID of the AKS cluster:

```powershell
invoke-command -computername (get-clusternode) -script {get-vmnetworkadapter -vmname *} | Where-Object {$_.Name -like "$cluster_name*control-plane-*"} | select vmname, ipaddresses
```

Expected output:

```output
VMName                                                 IPAddresses
------                                                 -----------
<cluster-name>-XXXXXX-control-plane-XXXXXX {172.16.0.10, 172.16.0.4, fe80::ec:d3ff:fea0:1}
```

If you don't see a control plane VM as shown in the previous output, [file a support request](help-support.md).

If you see a control plane VM, and it has:

- 0 IPv4 addresses: file a [support request](help-support.md).
- 1 IP address: use the IPv4 address as the input for `vmIP` parameter.
- 2 IP addresses: use any one of the IPv4 address as an input for `vmIP` parameter in the diagnostic checker.

## Run the diagnostic checker script

Copy the following PowerShell script named `run_diagnostic.ps1` into any one node of your Azure Local cluster:

```powershell
<#
.SYNOPSIS
    Runs diagnostic checker tool in target cluster control plane VM and returns the result.

    This script runs the following tests from target cluster control plane VM:
    1. cloud-agent-connectivity-test: Checks whether the DNS server can resolve the Moc cloud agent FQDN and that the cloud agent is reachable from the control plane node VM. Cloud agent is created using one of the IP addresses from the [management IP pool](/azure/azure-local/plan/cloud-deployment-network-considerations#management-ip-pool), on port 55000. The control plane node VM is given an IP address from the Arc VM logical network.
    2. gateway-icmp-ping-test: Checks whether the gateway specified in the logical network attached to the AKS cluster is reachable from the AKS cluster control plane node VM.
    3. http-connectivity-required-url-test: Checks whether the required URLs are reachable from the AKS cluster control plane node VM.

.DESCRIPTION
    This script transfers a file from the local machine to a remote server using the SCP (Secure Copy Protocol) command.

.PARAMETER lnetName
    The name of the LNET used for the cluster.

.PARAMETER sshPath
    The path to the private SSH key for the target cluster.

.PARAMETER vmIP
    IP of the target cluster control plane VM.


.EXAMPLE
    .\run_diagnostic.ps1 -lnetName lnet1 -sshPath C:\Users\test\.ssh\test-ssh.pem -vmIP "172.16.0.10"
    This example runs diagnostic checker tool in the VM with IP 172.16.0.10 using ssh key C:\Users\test\.ssh\test-ssh.pem and outputs the result.
#>

param (
    [Parameter(Mandatory=$true)]
    [string]$lnetName,

    [Parameter(Mandatory=$true)]
    [string]$sshPath,

    [Parameter(Mandatory=$true)]
    [string]$vmIP
)

$urlArray = @(
    "https://management.azure.com",
    "https://eastus.dp.kubernetesconfiguration.azure.com",
    "https://login.microsoftonline.com",
    "https://eastus.login.microsoft.com",
    "https://login.windows.net",
    "https://mcr.microsoft.com",
    "https://gbl.his.arc.azure.com",
    "https://k8connecthelm.download.prss.microsoft.com",
    "https://guestnotificationservice.azure.com",
    "https://sts.windows.net",
    "https://graph.microsoft.com"
)
$urlList=$urlArray -join ","

# check vm is reachable
try {
  $pingResult = Test-Connection -ComputerName $vmIP -Count 1 -ErrorAction Stop
  if ($pingResult.StatusCode -eq 0) {
    Write-Host "Connection to $vmIP succeeded."
  } else {
    Write-Host "Connection to AKS cluster control plane VM $vmIP failed with status code: $($pingResult.StatusCode). Please make sure AKS cluster control plane VM $vmIP is reachable from the host"
    exit
  }
} catch {
  Write-Host "Connection to AKS cluster control plane VM $vmIP failed. Please make sure AKS cluster control plane VM $vmIP is reachable from the host"
  Write-Host "Exception message: $_"
  exit
}

# retreiving LNET
$lnet=get-mocvirtualnetwork -group Default_Group -name $lnetName
# getting gateway address from LNET
$gateway=$lnet.properties.subnets[0].properties.routeTable.properties.routes[0].properties.nextHopIpAddress
if (-not $gateway) {
  Write-Error "Check Gateway address in the AKS logical network $lnetName"
  exit
}

# getting cloudfqdn from archciconfig
$arcHCIConfig=get-archciconfig
$cloudFqdn="http://"+$arcHCIConfig.Item('cloudFQDN')+":55000"

$configContent = @"
checks:
- metadata:
    creationTimestamp: null
    name: cloud-agent-connectivity-test
  parameters:
    hostnames: <CLOUD_FQDN>
    skipeof: "true"
  type: HTTPConnectivity
- metadata:
    annotations:
      skip-error-on-failure: "true"
    creationTimestamp: null
    name: gateway-icmp-ping-test
  parameters:
    ips: <GATEWAY>
    packetLossThreshold: "20"
  type: ICMPPing
- metadata:
    creationTimestamp: null
    name: http-connectivity-required-url-test
  parameters:
    hostnames: <URL_LIST>
  type: HTTPConnectivity
exports:
- metadata:
    creationTimestamp: null
  parameters:
    filelocation: /home/clouduser/results.yaml
  type: FileSystem
metadata:
  creationTimestamp: null
"@

# update config file with the values of cloud fqdn, gateway and dns servers
$configContent = $configContent.replace("<CLOUD_FQDN>", $cloudFqdn)
$configContent = $configContent.replace("<GATEWAY>", $gateway)
$configContent = $configContent.replace("<URL_LIST>", $urlList)

$filePath = "config.yaml"
# Write to config.yaml
Set-Content -Path $filePath -Value $configContent

$dest = 'clouduser@' + $vmIP + ":config.yaml"

# Copy the config file to target cluster VM
Write-Host "Copying test config file to target cluster VM...."
$command = "scp -i $sshPath -o StrictHostKeyChecking=no -o BatchMode=yes config.yaml $dest"
try {
  $output=invoke-expression $command
  if ($LASTEXITCODE -ne 0) {
    Write-Error "Couldn't ssh to AKS cluster control plane VM $vmIP. Please check the ssh key"
    exit
  }
} catch {
  Write-Host "Couldn't ssh to AKS cluster control plane VM $vmIP. Please check the ssh key"
  Write-Host "Exception message: $_"
  exit
}
Write-Output "Copied config.yaml successfully."
$runScriptContent = @"
sudo su - root -c "/usr/bin/diagnostics-checker -c /home/clouduser/config.yaml"
"@

$filePath = "run_diag.sh"

Set-Content -Path $filePath -Value $runScriptContent
$dest = 'clouduser@' + $vmIP + ":run_diag.sh"
scp -i $sshPath -o StrictHostKeyChecking=no -o BatchMode=yes run_diag.sh $dest

$dest = 'clouduser@' + $vmIP
ssh -i $sshPath $dest -o StrictHostKeyChecking=no -o BatchMode=yes 'chmod +x run_diag.sh'

$sedCommand="sed -i -e 's/\r$//' run_diag.sh"
ssh -i $sshPath -o StrictHostKeyChecking=no -o BatchMode=yes $dest $sedCommand

if (Test-Path -Path "results.yaml") {
  Remove-Item results.yaml
}

ssh -i $sshPath -o StrictHostKeyChecking=no -o BatchMode=yes $dest './run_diag.sh'
ssh -i $sshPath -o StrictHostKeyChecking=no -o BatchMode=yes $dest "sudo su - root -c 'chmod a+r /home/clouduser/results.yaml'"

$src= 'clouduser@' + $vmIP + ":results.yaml"
scp -i $sshPath -o StrictHostKeyChecking=no -o BatchMode=yes $src results.yaml

if (-Not (Test-Path -Path "results.yaml")) {
  write-host "Test failed to perform"
  exit
}

Install-Module powershell-yaml

$resultContent = Get-Content -path results.yaml | ConvertFrom-Yaml

$testResults = @()
$cloudAgentRecommendation = @"
Make sure that the logical network IP addresses can connect to all the management IP pool addresses on the required ports. Check AKS network port and cross vlan requirements for detailed list of ports that need to be opened.
"@
$gatewayRecommendation = @"
- Ensure gateway is operational
- Verify routing configurations
- Adjust firewall rules to allow ICMP traffic
"@
$urlRecommendation = @"
Ensure that the logical network IP addresses have outbound internet access. If there's a firewall, ensure that AKS required URLs are accessible from Arc VM logical network.
"@


foreach ($check in $resultContent.spec.checks) {
  if ($check.result.outcome -like "Success") {
    $recommendation=""
  }elseif ($check.metadata.name -like "cloud-agent-connectivity-test") {
    $recommendation=$cloudAgentRecommendation
  }elseif ($check.metadata.name -like "gateway-icmp-ping-test") {
    $recommendation=$gatewayRecommendation
  }elseif ($check.metadata.name -like "http-connectivity-required-url-test") {
    $recommendation=$urlRecommendation
  }
  $testResults += [PSCustomObject]@{
    TestName=$check.metadata.name
    Outcome= $check.result.outcome
    Recommendation = $recommendation
  }
}

$testResults | Format-Table -Wrap -AutoSize
```

Sample output:

```output
TestName                            Outcome Recommendation
--------                            ------- --------------
cloud-agent-connectivity-test       Success
gateway-icmp-ping-test              Success
http-connectivity-required-url-test Failure Ensure that the logical network IP addresses have outbound internet access. If there's a firewall, ensure that AKS required URLs are accessible from Arc VM logical network.
```

## Analyze diagnostic checker output

The following table provides a summary of each test performed by the script, including possible causes for failure and recommendations for mitigation:

| Test name                           | Description                                                                                                                                                                                                                                                                                                                                                                                                          | Causes for failure                                                                                                                                                                                                                                                      | Mitigation Recommendations                                                                                                                                                                                                                                                                                        |
| ----------------------------------- | -------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------- | ----------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------- | ----------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------- |
| cloud-agent-connectivity-test       | Checks whether the DNS server can resolve the MOC cloud agent FQDN and that the cloud agent is reachable from the control plane node VM. The cloud agent is created using one of the IP addresses from the [management IP pool](/azure/azure-local/plan/cloud-deployment-network-considerations#management-ip-pool), on port 55000. The control plane node VM is given IP addresses from the Arc VM logical network. | Logical network IP addresses can't connect to management IP pool addresses due to: <br> - Incorrect DNS server resolution. <br> - Firewall rules. <br> - The logical network is in a different vlan than the management IP pool and there's no cross-vlan connectivity. | Make sure that the logical network IP addresses can connect to all the management IP pool addresses on the required ports. Check the [AKS network port and cross vlan requirements](network-system-requirements.md#network-port-and-cross-vlan-requirements) for a detailed list of ports that need to be opened. |
| gateway-icmp-ping-test              | Checks whether the gateway specified in the logical network attached to the AKS cluster is reachable from the AKS cluster control plane node VM.                                                                                                                                                                                                                                                                     | - Gateway is down or unreachable. <br>- Network routing issues between the AKS cluster control plane node VM and the gateway. <br>- Firewall blocking ICMP traffic.                                                                                                     | - Ensure the gateway is operational.<br>- Verify routing configurations.<br>- Adjust firewall rules to allow ICMP traffic.                                                                                                                                                                                        |
| http-connectivity-required-url-test | Checks whether the required URLs are reachable from the AKS cluster control plane node VM.                                                                                                                                                                                                                                                                                                                           | - Control plane node VM has no outbound internet access. <br> - Required URLs aren't allowed through the firewall.                                                                                                                                                      | Ensure that the logical network IP addresses have outbound internet access. If there's a firewall, ensure that the [AKS required URLs](network-system-requirements.md#firewall-url-exceptions) are accessible from the Arc VM logical network.                                                                    |

## Next steps

If the problem persists, collect [AKS cluster logs](get-on-demand-logs.md) before you [create a support request](help-support.md).
