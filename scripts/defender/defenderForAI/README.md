### 1. Install Prerequisites

```bash
# Install PowerShell 7 (if not already installed)
# For Ubuntu/Debian
sudo apt-get update
sudo apt-get install -y powershell

# Install Azure CLI (if not already installed)
curl -sL https://aka.ms/InstallAzureCLIDeb | sudo bash
```

### 2. Authenticate

```bash
# Azure CLI authentication
az login

# Set your subscription
az account set --subscription "Your-Subscription-Name"
```

### 3. Run Scripts in Order

```bash
# Step 1: Enable Defender for Cloud
pwsh ./enable_defender_for_cloud.ps1

# Step 2: Enable Defender for AI services
pwsh ./enable_defender_for_ai.ps1

# Step 3: Enable user prompt evidence
pwsh ./enable_user_prompt_evidence.ps1

# Step 4: Connect to Purview DSPM (optional but recommended)
pwsh ./connect_defender_to_purview.ps1

# Step 5: Verify configuration
pwsh ./verify_defender_ai_configuration.ps1
```

## 🔐 Security Features

### Threat Protection
- **Prompt Injection Detection**: Identifies malicious prompts attempting to bypass AI guardrails
- **Data Exfiltration Prevention**: Detects attempts to extract sensitive data through AI
- **Jailbreak Attempts**: Monitors for attempts to circumvent AI safety measures
- **Anomalous Usage Patterns**: Identifies unusual AI usage that may indicate compromise

### Evidence Collection
- **User Prompt Capture**: Records AI prompts for security analysis
- **Model Response Tracking**: Captures AI responses for threat investigation
- **Metadata Collection**: Gathers contextual information (user, timestamp, IP)
- **Sensitive Data Detection**: Identifies sensitive information in prompts/responses

### Compliance & Governance
- **Purview Integration**: Sends data to Purview DSPM for compliance tracking
- **SIT Classification**: Automatically classifies sensitive information types
- **Audit Logging**: Complete audit trail for all AI interactions
- **Retention Policies**: Configurable data retention for compliance

## Monitoring & Alerts

After configuration, monitor your AI security:

1. **Defender for Cloud Portal**: [Azure Portal - Defender for Cloud](https://portal.azure.com/#view/Microsoft_Azure_Security/SecurityMenuBlade/~/0)
2. **AI Security Alerts**: Navigate to Security Alerts and filter by "AI"
3. **Data and AI Dashboard**: Review the Data and AI security dashboard (Preview)
4. **Purview Integration**: View AI data in [Purview DSPM](https://purview.microsoft.com/purviewforai/overview)

### Key Metrics to Monitor
- Number of AI threat alerts
- Prompt injection attempts
- Data exfiltration detections
- Jailbreak attempts
- User prompt evidence collected
- Purview integration status

## Architecture Integration

```
┌──────────────────────────────────────────────────────────────┐
│                    Azure AI Services                         │
│  ┌────────────────┐    ┌────────────────┐    ┌────────────┐ │
│  │ Azure OpenAI   │    │  AI Search     │    │ AI Foundry │ │
│  │ (Prompts/      │    │  (Documents)   │    │ (Projects) │ │
│  │  Responses)    │    │                │    │            │ │
│  └────────────────┘    └────────────────┘    └────────────┘ │
└──────────────────────────────────────────────────────────────┘
                              │
                    Security Monitoring
                              ▼
┌──────────────────────────────────────────────────────────────┐
│              Microsoft Defender for Cloud                    │
├──────────────────────────────────────────────────────────────┤
│  ┌────────────────┐  ┌────────────────┐  ┌────────────────┐ │
│  │  AI Services   │  │ User Prompt    │  │ Threat         │ │
│  │  Plan          │  │ Evidence       │  │ Detection      │ │
│  └────────────────┘  └────────────────┘  └────────────────┘ │
└──────────────────────────────────────────────────────────────┘
                              │
                    Governance Integration
                              ▼
┌──────────────────────────────────────────────────────────────┐
│           Microsoft Purview DSPM for AI                      │
│  • Sensitive Information Classification                      │
│  • Compliance Reporting                                      │
│  • Audit Logging                                             │
│  • Risk Analytics                                            │
└──────────────────────────────────────────────────────────────┘
```

## Troubleshooting

### Common Issues

**Defender for Cloud Not Enabling**
- Verify you have appropriate permissions (Security Admin or Contributor)
- Check subscription is not disabled or in grace period
- Ensure no Azure Policy blocking Defender enablement

**AI Services Plan Not Available**
- Confirm you have AI services deployed in subscription
- Verify subscription supports Defender for AI (check region availability)
- Wait 10-15 minutes after Defender for Cloud enablement

**User Prompt Evidence Not Collecting**
- Ensure Azure OpenAI uses Microsoft Entra ID authentication
- Verify user context is included in API calls
- Check content filtering is not opted out
- Allow 24-48 hours for data collection to begin

**Purview Integration Issues**
- Confirm Microsoft Purview DSPM is enabled (requires M365 E5)
- Verify Purview account is in same tenant
- Check network connectivity between services

## Cost Considerations

### Defender for Cloud Pricing
- **Free tier**: Basic security hygiene and recommendations
- **Defender CSPM**: ~$5/resource/month for enhanced security posture
- **Defender for AI Services**: Based on API transactions volume

### What's Included
- Threat detection for AI workloads
- Security alerts and recommendations
- User prompt evidence collection (limited retention)
- Integration with Microsoft Sentinel

### Additional Costs
- **Extended data retention**: Beyond default retention period
- **Log Analytics**: If routing logs to Log Analytics workspace
- **Purview DSPM**: Requires Microsoft 365 E5 license (separate)

**Cost estimation**: [Defender for Cloud Pricing](https://azure.microsoft.com/pricing/details/defender-for-cloud/)

## References

### Microsoft Documentation
- [Enable threat protection for AI services](https://learn.microsoft.com/azure/defender-for-cloud/ai-onboarding)
- [AI threat protection overview](https://learn.microsoft.com/azure/defender-for-cloud/ai-threat-protection)
- [Data and AI security dashboard](https://learn.microsoft.com/azure/defender-for-cloud/data-aware-security-dashboard-overview)
- [Gain end-user context for Azure AI](https://learn.microsoft.com/azure/defender-for-cloud/gain-end-user-context-ai)
- [Prepare for AI security](https://learn.microsoft.com/security/security-for-ai/prepare)

### Integration Documentation
- [Connect Defender to Purview](https://learn.microsoft.com/azure/defender-for-cloud/ai-onboarding#enable-data-security-for-azure-ai-with-microsoft-purview)
- [Purview DSPM for AI](https://learn.microsoft.com/purview/ai-microsoft-purview)
- [Security for AI guide](https://learn.microsoft.com/security/security-for-ai/)

## Integration with Existing Scripts

These Defender scripts complement the existing automation:

- **Fabric_Purview_Automation**: Creates data infrastructure and governance
- **PurviewGovernance**: Enables DSPM for AI and compliance policies
- **DefenderScripts** (NEW): Adds threat protection and security monitoring
- **OneLakeIndex**: Enables AI Search integration

Together, they provide **comprehensive AI security** from infrastructure to threat detection with integrated governance and compliance.

## Orchestration via azure.yaml

These scripts are designed to be orchestrated via the `azure.yaml` file in the post-provisioning hooks:

```yaml
hooks:
  postprovision:
    posix:
      shell: pwsh
      run: |
        pwsh ./scripts/Governance/PurviewGovernance/enable_purview_dspm.ps1
        pwsh ./scripts/Governance/PurviewGovernance/create_dspm_policies.ps1
        pwsh ./scripts/Governance/PurviewGovernance/connect_dspm_to_ai_foundry.ps1
        pwsh ./scripts/Governance/PurviewGovernance/verify_dspm_configuration.ps1
        pwsh ./scripts/Governance/DefenderScripts/enable_defender_for_cloud.ps1
        pwsh ./scripts/Governance/DefenderScripts/enable_defender_for_ai.ps1
        pwsh ./scripts/Governance/DefenderScripts/enable_user_prompt_evidence.ps1
        pwsh ./scripts/Governance/DefenderScripts/connect_defender_to_purview.ps1
        pwsh ./scripts/Governance/DefenderScripts/verify_defender_ai_configuration.ps1
```

See [azure.yaml](../../azure.yaml) for complete orchestration configuration.
