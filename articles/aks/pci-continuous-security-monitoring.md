---
title: AKS Regulated Cluster for PCI DSS 4.0.1 - Continuous Security Monitoring
description: Continuous security monitoring guidance for AKS clusters under PCI DSS 4.0.1.
ms.date: 06/25/2025
ms.subservice: aks-security
ms.topic: concept-article
author: schaffererin
ms.author: schaffererin
ms.custom:
  - pci-dss
  - compliance
---

# Continuous security monitoring for an AKS regulated cluster for PCI DSS 4.0.1

This article describes continuous security monitoring considerations for an Azure Kubernetes Service (AKS) cluster that's configured in accordance with the Payment Card Industry Data Security Standard (PCI DSS 4.0.1).

> This article is part of a series. Read the [introduction](pci-intro.md).

PCI DSS 4.0.1 significantly emphasizes continuous security, monitoring, and threat detection as fundamental components of maintaining compliance. This architecture and the implementation are focused on infrastructure and not the workload. This article provides general considerations and best practices to help you make design decisions. Follow the requirements in the official PCI-DSS 4.0.1 standard and use this article as additional information, where applicable.

> [!IMPORTANT]
>
> The guidance and the accompanying implementation builds on the [AKS baseline architecture](/azure/architecture/reference-architectures/containers/aks/baseline-aks), which is based on a hub-spoke network topology. The hub virtual network contains the firewall to control egress traffic, gateway traffic from on-premises networks, and a third network for maintenance. The spoke virtual network contains the AKS cluster that provides the card-holder environment (CDE), and hosts the PCI DSS workload.
>
> ![GitHub logo](media/pci-dss/github.png) **Reference Implementation Coming Soon**: The Azure Kubernetes Service (AKS) baseline cluster for regulated workloads reference implementation for PCI DSS 4.0.1 is currently being updated and will be available soon. This implementation will demonstrate a regulated infrastructure that illustrates the use of various network and security controls within your CDE. This includes both network controls native to Azure and controls native to Kubernetes. It will also include an application to demonstrate the interactions between the environment and a sample workload. The focus of this article is the infrastructure. The sample will not be indicative of an actual PCI-DSS 4.0.1 workload.

## Regularly monitor and test networks

> [!NOTE]
> This article has been updated for PCI DSS 4.0.1. Major changes include expanded requirements for continuous monitoring, automated threat detection, real-time alerting, and comprehensive logging. The standard now emphasizes proactive security monitoring and automated response capabilities. Ensure you review the official [PCI DSS 4.0.1 documentation](https://www.pcisecuritystandards.org/document_library) for full details and future-dated requirements.

### Requirement 10: Log and monitor all access to network resources and cardholder data

#### AKS feature support

AKS provides several features to help you meet PCI DSS 4.0.1 continuous security monitoring requirements:

- **Azure Monitor**: Provides real-time monitoring, alerting, and log analytics for AKS clusters and workloads with comprehensive observability.
- **Microsoft Defender for Cloud**: Delivers threat detection, vulnerability management, and compliance reporting for containerized workloads.
- **Azure Policy**: Enables continuous compliance checks and enforcement of security standards with automated remediation.
- **Container Insights**: Provides detailed performance and health monitoring for containerized applications.
- **Integration with SIEM/SOAR**: AKS logs and alerts can be integrated with SIEM/SOAR platforms for advanced threat detection and automated response.

### Requirement 10.1

Processes and mechanisms for logging and monitoring all access to network resources and cardholder data are defined and understood.

#### Your responsibilities

|Requirement|Responsibility|
|---|---|
|[Requirement 10.1.1](#requirement-1011)|All security policies and operational procedures that are identified in Requirement 10 are documented, in use, and known to all affected parties.|
|[Requirement 10.1.2](#requirement-1012)|Roles and responsibilities for performing activities in Requirement 10 are documented, assigned, and understood.|

#### Requirement 10.1.1

All security policies and operational procedures that are identified in Requirement 10 are documented, in use, and known to all affected parties.

##### Your responsibilities

Document comprehensive logging and monitoring procedures for your AKS environment:

- **Create logging and monitoring policies**: Define what events must be logged, retention periods, and access controls for log data.
- **Document monitoring procedures**: Create operational procedures for reviewing logs, investigating anomalies, and responding to security events.
- **Define incident response procedures**: Document how to respond to security events detected through monitoring.
- **Establish training procedures**: Ensure all personnel understand their roles in logging and monitoring activities.

**Implementation steps:**

1. Create a comprehensive logging policy document that includes:

   ```yaml
   # Example Azure Policy for AKS logging requirements
   apiVersion: policy.azure.com/v1
   kind: PolicyDefinition
   metadata:
     name: enforce-aks-logging
   spec:
     displayName: "Enforce AKS Logging Requirements"
     description: "Ensure all AKS clusters have appropriate logging enabled"
     mode: All
     parameters:
       retentionDays:
         type: Integer
         defaultValue: 365
     policyRule:
       if:
         type: Microsoft.ContainerService/managedClusters
       then:
         effect: DeployIfNotExists
         details:
           type: Microsoft.Insights/diagnosticSettings
           existenceCondition:
             allOf:
               - field: Microsoft.Insights/diagnosticSettings/logs[*].enabled
                 equals: true
               - field: Microsoft.Insights/diagnosticSettings/logs[*].retentionPolicy.days
                 greaterOrEquals: "[parameters('retentionDays')]"
   ```

2. Implement comprehensive logging for AKS clusters:

   ```azurecli-interactive
   # Enable diagnostic settings for AKS cluster
   az monitor diagnostic-settings create \
     --resource "/subscriptions/{subscription-id}/resourcegroups/{resource-group}/providers/Microsoft.ContainerService/managedClusters/{cluster-name}" \
     --name "pci-dss-logging" \
     --workspace "/subscriptions/{subscription-id}/resourcegroups/{resource-group}/providers/Microsoft.OperationalInsights/workspaces/{workspace-name}" \
     --logs '[
       {
         "category": "kube-apiserver",
         "enabled": true,
         "retentionPolicy": {
           "enabled": true,
           "days": 365
         }
       },
       {
         "category": "kube-audit",
         "enabled": true,
         "retentionPolicy": {
           "enabled": true,
           "days": 365
         }
       },
       {
         "category": "kube-audit-admin",
         "enabled": true,
         "retentionPolicy": {
           "enabled": true,
           "days": 365
         }
       }
     ]'
   ```

#### Requirement 10.1.2

Roles and responsibilities for performing activities in Requirement 10 are documented, assigned, and understood.

##### Your responsibilities

Define and assign clear roles and responsibilities for monitoring activities:

- **Security Operations Center (SOC) team**: Primary responsibility for monitoring and responding to security events.
- **Platform team**: Responsible for maintaining logging infrastructure and ensuring log collection.
- **Development teams**: Responsible for implementing application-level logging and monitoring.
- **Compliance team**: Responsible for ensuring monitoring meets PCI DSS requirements.

**Implementation steps:**

1. Create a RACI matrix for monitoring responsibilities:

   ```markdown
   | Activity | SOC Team | Platform Team | Dev Team | Compliance Team |
   |----------|----------|---------------|----------|-----------------|
   | 24/7 monitoring | R | S | I | I |
   | Log infrastructure | I | R | I | A |
   | Application logging | I | S | R | I |
   | Compliance reporting | S | I | I | R |
   ```

2. Implement Azure RBAC for monitoring access:

   ```azurecli-interactive
   # Assign monitoring roles
   az role assignment create \
     --assignee-object-id {soc-team-group-id} \
     --role "Monitoring Reader" \
     --scope "/subscriptions/{subscription-id}/resourceGroups/{resource-group}"
   
   az role assignment create \
     --assignee-object-id {platform-team-group-id} \
     --role "Monitoring Contributor" \
     --scope "/subscriptions/{subscription-id}/resourceGroups/{resource-group}"
   ```

### Requirement 10.2

Audit logs are implemented to support the detection of anomalies and suspicious activity, and the forensic analysis of events.

#### Your responsibilities

|Requirement|Responsibility|
|---|---|
|[Requirement 10.2.1](#requirement-1021)|Audit logs capture all individual user access to cardholder data.|
|[Requirement 10.2.2](#requirement-1022)|Audit logs capture all actions taken by any individual with administrative access, including any application, system, or cloud access.|
|Requirement 10.2.3|Audit logs capture all access to audit logs.|
|Requirement 10.2.4|Audit logs capture all invalid logical access attempts.|
|Requirement 10.2.5|Audit logs capture all changes to identification and authentication credentials.|
|Requirement 10.2.6|Audit logs capture all initialization of audit logs.|
|Requirement 10.2.7|Audit logs capture all creation and deletion of system-level objects.|

#### Requirement 10.2.1

Audit logs capture all individual user access to cardholder data.

##### Your responsibilities

Implement comprehensive logging for cardholder data access:

- **Enable application-level logging**: Ensure applications log all cardholder data access with user identification.
- **Implement audit logging in pods**: Use structured logging to capture data access events.
- **Configure log aggregation**: Collect application logs centrally for analysis.
- **Monitor data access patterns**: Implement automated detection of unusual access patterns.

**Implementation steps:**

1. Configure Container Insights for comprehensive application monitoring:

   ```azurecli-interactive
   # Enable Container Insights on AKS cluster
   az aks enable-addons \
     --resource-group {resource-group} \
     --name {cluster-name} \
     --addons monitoring \
     --workspace-resource-id "/subscriptions/{subscription-id}/resourcegroups/{resource-group}/providers/Microsoft.OperationalInsights/workspaces/{workspace-name}"
   ```

2. Implement structured logging in applications:

   ```yaml
   # Example logging configuration for applications
   apiVersion: v1
   kind: ConfigMap
   metadata:
     name: logging-config
   data:
     log-config.json: |
       {
         "level": "INFO",
         "format": "json",
         "fields": {
           "timestamp": "required",
           "user_id": "required",
           "action": "required",
           "resource": "required",
           "result": "required",
           "source_ip": "required"
         }
       }
   ```

#### Requirement 10.2.2

Audit logs capture all actions taken by any individual with administrative access, including any application, system, or cloud access.

##### Your responsibilities

Implement comprehensive administrative access logging:

- **Enable Azure AD audit logging**: Capture all administrative actions in Azure AD.
- **Configure Kubernetes audit logging**: Enable comprehensive audit logging for the Kubernetes API server.
- **Monitor privileged operations**: Track all privileged operations within the cluster.
- **Implement cloud access logging**: Log all administrative access to Azure resources.

**Implementation steps:**

1. Configure comprehensive Kubernetes audit logging:

   ```yaml
   # Audit policy for comprehensive administrative logging
   apiVersion: audit.k8s.io/v1
   kind: Policy
   rules:
   - level: RequestResponse
     namespaces: ["kube-system", "default"]
     verbs: ["create", "update", "patch", "delete"]
     resources:
     - group: ""
       resources: ["pods", "services", "secrets", "configmaps"]
   - level: Request
     verbs: ["get", "list", "watch"]
     resources:
     - group: ""
       resources: ["secrets"]
   - level: Metadata
     verbs: ["get", "list", "watch"]
     resources:
     - group: ""
       resources: ["pods", "services", "configmaps"]
   ```

2. Set up Azure Monitor queries for administrative access:

   ```kusto
   // Monitor administrative access to AKS
   AzureActivity
   | where TimeGenerated > ago(24h)
   | where ResourceProvider == "Microsoft.ContainerService"
   | where ActivityLevel == "Informational"
   | where CategoryValue == "Administrative"
   | project TimeGenerated, Caller, OperationName, ResourceGroup, SubscriptionId, Properties
   | order by TimeGenerated desc
   ```

### Requirement 10.3

Audit logs are protected from destruction and unauthorized modifications.

#### Your responsibilities

|Requirement|Responsibility|
|---|---|
|[Requirement 10.3.1](#requirement-1031)|Read access to audit logs is limited to those with a job-related need.|
|[Requirement 10.3.2](#requirement-1032)|Write access to audit logs is limited to those with a job-related need.|
|[Requirement 10.3.3](#requirement-1033)|Audit logs are backed up to a secure, centralized internal log server or media.|
|Requirement 10.3.4|File integrity monitoring and/or change-detection mechanisms are deployed on logs to ensure that existing log data cannot be changed without generating alerts.|

#### Requirement 10.3.1

Read access to audit logs is limited to those with a job-related need.

##### Your responsibilities

Implement strict access controls for audit log reading:

- **Use Azure RBAC**: Implement role-based access control for Log Analytics workspaces.
- **Implement resource-level permissions**: Grant access only to specific log categories based on job requirements.
- **Regular access reviews**: Conduct periodic reviews of who has access to audit logs.
- **Audit log access**: Monitor and log all access to audit logs themselves.

**Implementation steps:**

1. Configure granular RBAC for log access:

   ```azurecli-interactive
   # Create custom role for SOC team with limited log access
   az role definition create --role-definition '{
     "Name": "PCI DSS Log Reader",
     "Description": "Can read security logs for PCI DSS compliance",
     "Actions": [
       "Microsoft.OperationalInsights/workspaces/query/*/read",
       "Microsoft.OperationalInsights/workspaces/sharedKeys/action"
     ],
     "NotActions": [
       "Microsoft.OperationalInsights/workspaces/*/write",
       "Microsoft.OperationalInsights/workspaces/*/delete"
     ],
     "AssignableScopes": ["/subscriptions/{subscription-id}"]
   }'
   
   # Assign the custom role to SOC team
   az role assignment create \
     --assignee-object-id {soc-team-group-id} \
     --role "PCI DSS Log Reader" \
     --scope "/subscriptions/{subscription-id}/resourceGroups/{resource-group}/providers/Microsoft.OperationalInsights/workspaces/{workspace-name}"
   ```

2. Implement log access monitoring:

   ```kusto
   // Monitor access to audit logs
   AzureActivity
   | where TimeGenerated > ago(24h)
   | where ResourceProvider == "Microsoft.OperationalInsights"
   | where OperationName contains "Query"
   | project TimeGenerated, Caller, OperationName, ResourceGroup, Properties
   | order by TimeGenerated desc
   ```

#### Requirement 10.3.2

Write access to audit logs is limited to those with a job-related need.

##### Your responsibilities

Strictly control who can modify or delete audit logs:

- **Implement immutable storage**: Use Azure Storage immutable policies for long-term log retention.
- **Restrict administrative access**: Limit write access to only essential personnel.
- **Use managed services**: Leverage Azure-managed logging services that provide built-in protection.
- **Implement approval workflows**: Require approval for any log configuration changes.

**Implementation steps:**

1. Configure immutable storage for log retention:
  
   ```azurecli-interactive
   # Create storage account with immutable policy
   az storage account create \
     --name {storage-account-name} \
     --resource-group {resource-group} \
     --location {location} \
     --sku Standard_LRS \
     --kind StorageV2
   
   # Enable immutable policy for log container
   az storage container immutability-policy create \
     --account-name {storage-account-name} \
     --container-name logs \
     --period 2555 \
     --resource-group {resource-group}
   ```

2. Configure Log Analytics workspace with strict access controls:

   ```azurecli-interactive
   # Lock the Log Analytics workspace to prevent accidental deletion
   az lock create \
     --name "pci-dss-logs-lock" \
     --lock-type CanNotDelete \
     --resource-group {resource-group} \
     --resource-name {workspace-name} \
     --resource-type Microsoft.OperationalInsights/workspaces
   ```

#### Requirement 10.3.3

Audit logs are backed up to a secure, centralized internal log server or media.

##### Your responsibilities

Implement comprehensive backup and archival for audit logs:

- **Configure log export**: Set up automatic export of logs to secure storage.
- **Implement geo-redundant storage**: Use Azure Storage with geo-redundancy for log backups.
- **Establish retention policies**: Define appropriate retention periods for different types of logs.
- **Test backup recovery**: Regularly test the ability to restore logs from backups.

**Implementation steps:**

1. Configure automated log export:

   ```azurecli-interactive
   # Create data export rule for critical logs
   az monitor log-analytics workspace data-export create \
     --resource-group {resource-group} \
     --workspace-name {workspace-name} \
     --name "pci-dss-log-export" \
     --destination "/subscriptions/{subscription-id}/resourceGroups/{resource-group}/providers/Microsoft.Storage/storageAccounts/{storage-account-name}" \
     --table-names "AzureActivity" "KubePodInventory" "KubeEvents" "ContainerLog" \
     --enabled true
   ```

2. Set up geo-redundant storage for log backups:

   ```azurecli-interactive
   # Create geo-redundant storage for log backups
   az storage account create \
     --name {backup-storage-account-name} \
     --resource-group {resource-group} \
     --location {location} \
     --sku Standard_GRS \
     --kind StorageV2 \
     --encryption-services blob file \
     --https-only true
   ```

### Requirement 10.4

Audit logs are reviewed to identify anomalies or suspicious activity.

#### Your responsibilities

|Requirement|Responsibility|
|---|---|
|[Requirement 10.4.1](#requirement-1041)|The following audit logs are reviewed at least once daily.|
|[Requirement 10.4.2](#requirement-1042)|Logs of all other system components are reviewed periodically.|
|Requirement 10.4.3|Exceptions and anomalies identified during the review process are addressed.|

#### Requirement 10.4.1

The following audit logs are reviewed at least once daily.

##### Your responsibilities

Implement daily review processes for critical audit logs:

- **Automate daily log reviews**: Use Azure Monitor workbooks and alerts for daily log analysis.
- **Focus on high-risk activities**: Prioritize review of administrative access, failed logins, and data access.
- **Implement anomaly detection**: Use machine learning-based anomaly detection for automated analysis.
- **Document review findings**: Maintain records of daily log reviews and any actions taken.

**Implementation steps:**

1. Create automated daily log review workbook:

   ```kusto
   // Daily security review query
   let StartTime = ago(1d);
   let EndTime = now();
   
   // Failed authentication attempts
   SigninLogs
   | where TimeGenerated between(StartTime .. EndTime)
   | where ResultType != 0
   | where AppDisplayName contains "Azure Kubernetes Service"
   | summarize FailedAttempts = count() by UserPrincipalName, IPAddress, ResultType
   | order by FailedAttempts desc
   
   // Administrative activities
   union
   (AzureActivity
   | where TimeGenerated between(StartTime .. EndTime)
   | where CategoryValue == "Administrative"
   | where ResourceProvider == "Microsoft.ContainerService"),
   
   // Kubernetes audit events
   (KubeAuditLogs
   | where TimeGenerated between(StartTime .. EndTime)
   | where Verb in ("create", "update", "delete")
   | where ObjectRef_Resource in ("secrets", "configmaps", "pods"))
   
   | project TimeGenerated, Caller, OperationName, ResourceGroup, Level
   | order by TimeGenerated desc
   ```

2. Set up automated daily alerts:

   ```azurecli-interactive
   # Create action group for daily alerts
   az monitor action-group create \
     --name "pci-dss-daily-alerts" \
     --resource-group {resource-group} \
     --short-name "PCIAlerts" \
     --email-receiver name="SOC Team" email="soc@company.com"
   
   # Create scheduled query alert for daily review
   az monitor scheduled-query create \
     --name "Daily Security Review Alert" \
     --resource-group {resource-group} \
     --scopes "/subscriptions/{subscription-id}/resourceGroups/{resource-group}/providers/Microsoft.OperationalInsights/workspaces/{workspace-name}" \
     --condition "count > 0" \
     --condition-query "SigninLogs | where TimeGenerated > ago(1d) | where ResultType != 0 | where AppDisplayName contains 'Azure Kubernetes Service' | count" \
     --description "Daily alert for failed authentication attempts" \
     --evaluation-frequency "24h" \
     --window-size "24h" \
     --action-groups "/subscriptions/{subscription-id}/resourceGroups/{resource-group}/providers/Microsoft.Insights/actionGroups/pci-dss-daily-alerts"
   ```

#### Requirement 10.4.2

Logs of all other system components are reviewed periodically.

##### Your responsibilities

Establish periodic review processes for all system logs:

- **Create review schedules**: Define weekly, monthly, and quarterly review cycles for different log types.
- **Automate periodic analysis**: Use Azure Monitor workbooks for automated periodic log analysis.
- **Implement trending analysis**: Track security metrics over time to identify patterns.
- **Document review procedures**: Maintain procedures for periodic log reviews.

**Implementation steps:**

1. Create weekly security trend analysis:

   ```kusto
   // Weekly security trends
   let WeeklyData = AzureActivity
   | where TimeGenerated > ago(7d)
   | where ResourceProvider == "Microsoft.ContainerService"
   | summarize 
       TotalActivities = count(),
       UniqueUsers = dcount(Caller),
       FailedOperations = countif(ActivityStatus == "Failed")
   by bin(TimeGenerated, 1d)
   | order by TimeGenerated desc;
   
   WeeklyData
   | render timechart
   ```

2. Set up monthly compliance reporting:

   ```azurecli-interactive
   # Create monthly compliance report automation
   az automation runbook create \
     --automation-account-name {automation-account-name} \
     --resource-group {resource-group} \
     --name "monthly-pci-compliance-report" \
     --type PowerShell \
     --description "Generate monthly PCI DSS compliance report"
   ```

### Requirement 10.5

Audit logs are secured such that they cannot be altered.

#### Your responsibilities

|Requirement|Responsibility|
|---|---|
|[Requirement 10.5.1](#requirement-1051)|Audit logs are protected from destruction and unauthorized modifications.|

#### Requirement 10.5.1

Audit logs are protected from destruction and unauthorized modifications.

##### Your responsibilities

Implement comprehensive protection for audit logs:

- **Use immutable storage**: Implement write-once-read-many (WORM) storage for critical logs.
- **Implement file integrity monitoring**: Use Azure Security Center for file integrity monitoring.
- **Configure log forwarding**: Forward logs to external SIEM systems for additional protection.
- **Implement cryptographic protection**: Use digital signatures or checksums for log integrity.

**Implementation steps:**

1. Configure file integrity monitoring:

   ```azurecli-interactive
   # Enable file integrity monitoring in Microsoft Defender for Cloud
   az security workspace-setting create \
     --name default \
     --target-workspace "/subscriptions/{subscription-id}/resourceGroups/{resource-group}/providers/Microsoft.OperationalInsights/workspaces/{workspace-name}" \
     --enabled true
   ```

2. Set up log forwarding to external SIEM:

   ```yaml
   # Example Fluentd configuration for log forwarding
   apiVersion: v1
   kind: ConfigMap
   metadata:
     name: fluentd-config
   data:
     fluent.conf: |
       <source>
         @type tail
         path /var/log/containers/*.log
         pos_file /var/log/fluentd-containers.log.pos
         tag kubernetes.*
         read_from_head true
         <parse>
           @type json
           time_key time
           time_format %Y-%m-%dT%H:%M:%S.%NZ
         </parse>
       </source>
       
       <filter kubernetes.**>
         @type kubernetes_metadata
       </filter>
       
       <match **>
         @type copy
         <store>
           @type elasticsearch
           host {elasticsearch-host}
           port 9200
           logstash_format true
           logstash_prefix kubernetes
           include_timestamp true
           type_name _doc
           <buffer>
             @type file
             path /var/log/fluentd-buffers/kubernetes.system.buffer
             flush_mode interval
             retry_type exponential_backoff
             flush_thread_count 2
             flush_interval 5s
             retry_forever
             retry_max_interval 30
             chunk_limit_size 2M
             queue_limit_length 8
             overflow_action block
           </buffer>
         </store>
         <store>
           @type syslog
           host {siem-host}
           port 514
           protocol tcp
           format rfc5424
         </store>
       </match>
   ```

## Next steps

Implement comprehensive security policies and operational procedures to maintain and govern your PCI DSS compliance framework.

> [!div class="nextstepaction"]
> [Implement security policies](pci-policy.md)

## Related resources

For more information about implementing continuous security monitoring in AKS environments, see:

- [Azure Monitor for containers](/azure/azure-monitor/containers/container-insights-overview)
- [Microsoft Defender for Cloud](/azure/defender-for-cloud/)
- [Azure Policy for AKS](/azure/governance/policy/concepts/policy-for-kubernetes)
- [Kubernetes audit logging](/azure/aks/view-control-plane-logs)
- [Azure Monitor workbooks](/azure/azure-monitor/visualize/workbooks-overview)

For more information about PCI DSS 4.0.1 requirements, review the official [PCI DSS 4.0.1 documentation](https://www.pcisecuritystandards.org/).
