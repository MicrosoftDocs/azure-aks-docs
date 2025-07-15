---
title: AKS regulated cluster for PCI DSS 4.0.1 - Security awareness training
description: Security awareness training guidance for AKS clusters under PCI DSS 4.0.1.
ms.date: 06/25/2025
ms.subservice: aks-security
ms.topic: concept-article
author: phillipgibson
ms.author: pgibson
ms.custom:
  - pci-dss
  - compliance
---

# Security awareness training for an AKS regulated cluster for PCI DSS 4.0.1

This article describes security awareness training considerations for an Azure Kubernetes Service (AKS) cluster that's configured in accordance with the Payment Card Industry Data Security Standard (PCI DSS 4.0.1).

> This article is part of a series. Read the [introduction](pci-intro.md).

PCI DSS 4.0.1 requires comprehensive security awareness and training for all personnel with access to the cardholder data environment (CDE). This architecture and the implementation are focused on infrastructure and not the workload. This article provides general considerations and best practices to help you make design decisions. Follow the requirements in the official PCI-DSS 4.0.1 standard and use this article as additional information, where applicable.

> [!IMPORTANT]
>
> The guidance and the accompanying implementation builds on the [AKS baseline architecture](/azure/architecture/reference-architectures/containers/aks/baseline-aks), which is based on a hub-spoke network topology. The hub virtual network contains the firewall to control egress traffic, gateway traffic from on-premises networks, and a third network for maintenance. The spoke virtual network contains the AKS cluster that provides the card-holder environment (CDE), and hosts the PCI DSS workload.
>
> ![GitHub logo](media/pci-dss/github.png) **Reference Implementation Coming Soon**: The Azure Kubernetes Service (AKS) baseline cluster for regulated workloads reference implementation for PCI DSS 4.0.1 is currently being updated and will be available soon. This implementation will demonstrate a regulated infrastructure that illustrates the use of various network and security controls within your CDE. This includes both network controls native to Azure and controls native to Kubernetes. It will also include an application to demonstrate the interactions between the environment and a sample workload. The focus of this article is the infrastructure. The sample will not be indicative of an actual PCI-DSS 4.0.1 workload.

## Maintain an information security policy

> **Note:** This article has been updated for PCI DSS 4.0.1. Major changes include expanded requirements for security awareness training, enhanced focus on cloud and container security, and requirements for role-based training programs. The standard now emphasizes continuous security education and incident response training. Ensure you review the official [PCI DSS 4.0.1 documentation](https://www.pcisecuritystandards.org/document_library) for full details and future-dated requirements.

### Requirement 12: Support information security with organizational policies and programs

#### AKS feature support

AKS provides several features to help you meet PCI DSS 4.0.1 security awareness training requirements:

- **Azure Policy**: Enforce mandatory security awareness training compliance for all AKS users and administrators through governance policies.
- **Microsoft Defender for Cloud**: Provides security recommendations and compliance tracking capabilities that can help monitor training requirements.
- **Microsoft Entra ID (Azure AD)**: Integrates with learning management systems and can be used to track user training completion and certification status.
- **Azure Monitor**: Can track and log training completion events and generate compliance reports.
- **Azure RBAC**: Ensures only trained personnel have access to sensitive AKS resources and operations.

### Requirement 12.6

Security awareness training is provided to all personnel.

#### Your responsibilities

|Requirement|Responsibility|
|---|---|
|[Requirement 12.6.1](#requirement-1261)|A formal security awareness training program is implemented to make all personnel aware of the importance of cardholder data security.|
|[Requirement 12.6.2](#requirement-1262)|The security awareness training program is reviewed at least once every 12 months and updated as needed.|
|[Requirement 12.6.3](#requirement-1263)|Personnel acknowledge that they have read and understood the security policy and procedures.|

#### Requirement 12.6.1

A formal security awareness training program is implemented to make all personnel aware of the importance of cardholder data security.

##### Your responsibilities

Implement a comprehensive security awareness training program that covers all aspects of AKS security and PCI DSS compliance:

**Core training components:**

- **PCI DSS fundamentals**: Understanding the standard, compliance requirements, and business impact.
- **Cloud security principles**: Azure security model, shared responsibility, and cloud-specific threats.
- **Container security**: Docker security, Kubernetes security, and container image vulnerability management.
- **Data protection**: Cardholder data handling, encryption requirements, and data lifecycle management.
- **Network security**: AKS networking, private clusters, and network policy implementation.
- **Identity and access management**: Azure AD integration, MFA requirements, and privilege management.

**Implementation steps:**

1. Develop role-specific training curricula:

   ```yaml
   # Example training matrix for different roles
   TrainingMatrix:
     AKS_Platform_Engineer:
       - PCI_DSS_Fundamentals
       - Azure_Security_Fundamentals
       - AKS_Security_Configuration
       - Container_Security_Best_Practices
       - Network_Security_Controls
       - Key_Management_Procedures
       - Incident_Response_Procedures
       - Compliance_Monitoring
   
     Application_Developer:
       - PCI_DSS_Fundamentals
       - Secure_Coding_Practices
       - Container_Security_Development
       - Data_Protection_Requirements
       - Authentication_Authorization
       - Vulnerability_Management
       - Code_Review_Security
   
     Security_Administrator:
       - PCI_DSS_Advanced_Requirements
       - Threat_Detection_Response
       - Compliance_Auditing
       - Risk_Assessment_Management
       - Policy_Enforcement
       - Forensic_Analysis
   ```

2. Create AKS-specific training modules:

   - **AKS cluster security configuration**: Private clusters, network policies, and security contexts.
   - **Container image security**: Vulnerability scanning, image signing, and secure base images.
   - **Secret management**: Azure Key Vault integration, secret rotation, and secure secret injection.
   - **Monitoring and logging**: Security event detection, log analysis, and incident investigation.
   - **Compliance automation**: Azure Policy implementation, continuous compliance monitoring.

3. Implement training delivery mechanisms:

   ```powershell
   # Example PowerShell script for tracking training completion
   # This integrates with Azure AD and a learning management system
   
   function Track-TrainingCompletion {
       param(
           [string]$UserId,
           [string]$TrainingModule,
           [datetime]$CompletionDate,
           [string]$CertificationScore
       )
   
       # Log training completion to Azure Monitor
       $logData = @{
           UserId = $UserId
           TrainingModule = $TrainingModule
           CompletionDate = $CompletionDate
           CertificationScore = $CertificationScore
           ComplianceStatus = if ($CertificationScore -ge 80) { "Compliant" } else { "Non-Compliant" }
       }
   
       # Send to Log Analytics workspace
       Send-AzMonitorLog -WorkspaceId $WorkspaceId -LogData $logData -LogType "PCITrainingCompliance"
   
       # Update user's training status in Azure AD
       Update-AzADUser -ObjectId $UserId -ExtensionProperty @{
           "PCITrainingStatus" = $logData.ComplianceStatus
           "LastTrainingDate" = $CompletionDate
       }
   }
   ```

#### Requirement 12.6.2

The security awareness training program is reviewed at least once every 12 months and updated as needed.

##### Your responsibilities

Establish processes for regular review and updates of your security awareness training program:

**Annual review process:**

- **Threat landscape assessment**: Review current threats affecting AKS and containerized environments.
- **Compliance updates**: Incorporate changes in PCI DSS requirements and Azure security features.
- **Incident analysis**: Review security incidents from the past year and update training accordingly.
- **Technology updates**: Update training for new AKS features and security capabilities.
- **Effectiveness evaluation**: Assess training effectiveness through testing and incident response performance.

**Implementation steps:**

1. Create annual training review schedule:

   ```yaml
   # Annual training review calendar
   TrainingReviewSchedule:
     Q1:
       - Review_Previous_Year_Incidents
       - Update_Threat_Intelligence
       - Assess_New_Azure_Security_Features
     Q2:
       - Review_PCI_DSS_Updates
       - Update_AKS_Security_Training
       - Conduct_Training_Effectiveness_Assessment
     Q3:
       - Review_Compliance_Audit_Findings
       - Update_Role_Specific_Training
       - Refresh_Incident_Response_Procedures
     Q4:
       - Plan_Next_Year_Training_Program
       - Update_Training_Materials
       - Schedule_Mandatory_Refresher_Training
   ```

2. Implement training effectiveness metrics:

   ```kusto
   // KQL query to track training effectiveness
   PCITrainingCompliance
   | where TimeGenerated > ago(365d)
   | summarize 
       TotalTrainees = dcount(UserId),
       CompletedTraining = countif(ComplianceStatus == "Compliant"),
       AverageScore = avg(toint(CertificationScore)),
       TrainingModules = dcount(TrainingModule)
   by bin(TimeGenerated, 30d)
   | extend CompletionRate = (CompletedTraining * 100.0) / TotalTrainees
   | project TimeGenerated, CompletionRate, AverageScore, TotalTrainees, TrainingModules
   | render timechart
   ```

3. Establish feedback mechanisms:

   - **Post-training surveys**: Collect feedback on training content and delivery.
   - **Incident correlation**: Analyze whether security incidents correlate with training gaps.
   - **Skills assessments**: Regular testing to ensure knowledge retention.
   - **Continuous improvement**: Update training based on feedback and changing requirements.

#### Requirement 12.6.3

Personnel acknowledge that they have read and understood the security policy and procedures.

##### Your responsibilities

Implement formal acknowledgment processes to ensure personnel understand their security responsibilities:

**Documentation and acknowledgment requirements:**

- **Security policy acknowledgment**: Formal written acknowledgment of security policies.
- **Role-specific procedures**: Acknowledgment of specific procedures relevant to their role.
- **Training completion certificates**: Formal certification of training completion.
- **Periodic re-acknowledgment**: Regular renewal of policy acknowledgments.

**Implementation steps:**

1. Create digital acknowledgment system:

   ```json
   {
     "acknowledgmentRecord": {
       "userId": "user@company.com",
       "employeeId": "EMP001",
       "acknowledgmentDate": "2025-07-08T10:30:00Z",
       "policies": [
         {
           "policyName": "PCI DSS Security Policy",
           "version": "v4.0.1",
           "acknowledged": true,
           "digitalSignature": "SHA256:abc123..."
         },
         {
           "policyName": "AKS Security Procedures",
           "version": "v1.2",
           "acknowledged": true,
           "digitalSignature": "SHA256:def456..."
         }
       ],
       "trainingCompleted": [
         {
           "trainingModule": "AKS Security Fundamentals",
           "completionDate": "2025-07-01T14:00:00Z",
           "score": 95,
           "certificateId": "CERT-AKS-001"
         }
       ],
       "nextReviewDate": "2026-07-08T10:30:00Z"
     }
   }
   ```

2. Implement compliance tracking:

   ```azurecli-interactive
   # Azure CLI script to track policy acknowledgments
   #!/bin/bash
   
   # Create custom table in Log Analytics for tracking acknowledgments
   az monitor log-analytics workspace table create \
     --resource-group $RESOURCE_GROUP \
     --workspace-name $WORKSPACE_NAME \
     --name PolicyAcknowledgments \
     --columns '[
       {"name": "TimeGenerated", "type": "datetime"},
       {"name": "UserId", "type": "string"},
       {"name": "PolicyName", "type": "string"},
       {"name": "PolicyVersion", "type": "string"},
       {"name": "AcknowledgmentStatus", "type": "string"},
       {"name": "DigitalSignature", "type": "string"}
     ]'
   
   # Set up alerts for missing acknowledgments
   az monitor scheduled-query create \
     --name "Missing Policy Acknowledgments" \
     --resource-group $RESOURCE_GROUP \
     --scopes "/subscriptions/$SUBSCRIPTION_ID/resourceGroups/$RESOURCE_GROUP/providers/Microsoft.OperationalInsights/workspaces/$WORKSPACE_NAME" \
     --condition "count > 0" \
     --condition-query "
       let RequiredPolicies = datatable(PolicyName:string) [
         'PCI DSS Security Policy',
         'AKS Security Procedures',
         'Incident Response Policy'
       ];
       let CurrentUsers = AADUsers | where TimeGenerated > ago(1d) | distinct UserId;
       CurrentUsers
       | join kind=leftanti (
         PolicyAcknowledgments
         | where TimeGenerated > ago(365d)
         | where AcknowledgmentStatus == 'Acknowledged'
       ) on UserId
       | count
     " \
     --description "Alert when users have not acknowledged required policies" \
     --evaluation-frequency "24h" \
     --window-size "24h"
   ```

### Requirement 12.6.4

Security awareness training addresses how to identify and report security incidents and anomalies.

#### Your responsibilities

Ensure all personnel are trained on incident identification and reporting procedures specific to AKS environments:

**Incident identification training:**

- **AKS-specific threats**: Container escape, privilege escalation, and resource exhaustion attacks.
- **Anomaly detection**: Unusual network traffic, unexpected resource usage, and suspicious user behavior.
- **Log analysis**: Interpreting AKS audit logs, container logs, and security alerts.
- **Threat indicators**: Recognizing signs of compromise in containerized environments.

**Incident reporting procedures:**

- **Immediate response**: Who to contact and how to escalate security incidents.
- **Documentation requirements**: What information to collect and how to preserve evidence.
- **Communication protocols**: Internal and external communication during incidents.
- **Post-incident activities**: Lessons learned and process improvements.

**Implementation steps:**

1. Develop incident response training scenarios:

   ```yaml
   # Example incident response training scenarios
   IncidentScenarios:
     ContainerEscape:
       Description: "Container breaks out of its security context"
       Indicators:
         - "Unexpected file system modifications outside container"
         - "Unusual system call patterns"
         - "Privilege escalation attempts"
       Response:
         - "Isolate affected node"
         - "Collect forensic evidence"
         - "Notify security team immediately"
   
     PrivilegeEscalation:
       Description: "User attempts to gain unauthorized privileges"
       Indicators:
         - "Failed sudo attempts"
         - "Unexpected role binding changes"
         - "Abnormal kubectl commands"
       Response:
         - "Revoke user access"
         - "Review audit logs"
         - "Investigate user activity"
   
     DataExfiltration:
       Description: "Unauthorized data access or transfer"
       Indicators:
         - "Large data transfers"
         - "Unusual database queries"
         - "Abnormal network traffic patterns"
       Response:
         - "Block suspicious traffic"
         - "Preserve evidence"
         - "Activate incident response team"
   ```

2. Create incident reporting templates:

   ```markdown
   # Security Incident Report Template
   
   ## Incident Details
   - **Incident ID**: [Auto-generated]
   - **Reporter**: [Name and contact information]
   - **Date/Time Discovered**: [ISO 8601 format]
   - **Date/Time Incident Occurred**: [ISO 8601 format]
   - **Incident Type**: [Container Security, Network Security, Data Breach, etc.]
   - **Severity Level**: [Critical, High, Medium, Low]
   
   ## AKS Environment Details
   - **Cluster Name**: [AKS cluster name]
   - **Namespace**: [Kubernetes namespace]
   - **Affected Workloads**: [List of affected pods/services]
   - **Node Information**: [Affected nodes]
   
   ## Incident Description
   [Detailed description of what happened]
   
   ## Immediate Actions Taken
   [List of immediate response actions]
   
   ## Evidence Collected
   - **Log Files**: [Paths to relevant logs]
   - **Screenshots**: [Any relevant screenshots]
   - **Network Captures**: [Any network traffic captures]
   - **System State**: [Memory dumps, process lists, etc.]
   
   ## Impact Assessment
   - **Systems Affected**: [List of affected systems]
   - **Data Involved**: [Any cardholder data involved]
   - **Business Impact**: [Description of business impact]
   
   ## Next Steps
   [Planned follow-up actions]
   ```

## Next steps

Implement comprehensive anti-phishing and social engineering controls to protect against human-factor security threats.

> [!div class="nextstepaction"]
> [Implement anti-phishing and social engineering controls](pci-anti-phishing-social-engineering.md)

## Related resources

For more information about implementing security awareness training in AKS environments, see:

- [Azure Security Center training resources](/azure/security-center/security-center-provide-security-contact-details)
- [Microsoft Learn security training paths](/learn/browse/?subjects=security)
- [Kubernetes security training resources](https://kubernetes.io/docs/concepts/security/)
- [Container security best practices](/azure/container-instances/container-instances-image-security)
- [Azure Monitor training and certification](/azure/azure-monitor/logs/manage-access)

For more information about PCI DSS 4.0.1 requirements, review the official [PCI DSS 4.0.1 documentation](https://www.pcisecuritystandards.org/).
