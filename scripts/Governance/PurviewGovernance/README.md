# Purview Governance Automation Scripts

This folder contains PowerShell scripts for automating Microsoft Purview governance features, with a focus on Data Security Posture Management (DSPM) for AI.

## 📋 Overview

These scripts enable automated configuration and management of Microsoft Purview governance capabilities, including:

- **Data Security Posture Management (DSPM) for AI**: Monitor AI activity, enforce security policies, and prevent unauthorized data exposure
- **AI Foundry Integration**: Connect DSPM capabilities to Azure AI Foundry projects
- **Audit Configuration**: Enable Microsoft Purview auditing for comprehensive activity tracking
- **Policy Automation**: Create and manage DSPM policies for data protection

## 🔧 Scripts

### 1. `enable_purview_dspm.ps1`
Enables Microsoft Purview Data Security Posture Management (DSPM) for AI in your tenant.

**What it does:**
- Validates tenant prerequisites (M365 E5 license)
- Enables Microsoft Purview Audit
- Activates DSPM for AI hub
- Verifies audit status

**Usage:**
```powershell
./enable_purview_dspm.ps1
```

### 2. `create_dspm_policies.ps1`
Creates the recommended DSPM for AI one-click policies to protect enterprise AI applications.

**What it does:**
- **Automates Exchange Online connection** (no manual `Connect-IPPSSession` needed)
- **Creates KYD policy via PowerShell** - the only programmatic method available
- Provides guidance for portal-based policies (Communication Compliance, Insider Risk)
- Validates policy creation and reports status
- **Note**: Uses Exchange Online PowerShell because Microsoft doesn't provide REST APIs for DSPM policy creation

**Usage:**
```powershell
./create_dspm_policies.ps1
```

### 3. `connect_dspm_to_ai_foundry.ps1`
Connects DSPM capabilities to Azure AI Foundry projects for integrated governance.

**What it does:**
- Discovers AI Foundry projects in the subscription
- Configures DSPM monitoring for AI Foundry workspaces
- Sets up data governance policies for AI models
- Establishes secure connections between Purview and AI Foundry

**Usage:**
```powershell
./connect_dspm_to_ai_foundry.ps1
```

### 4. `verify_dspm_configuration.ps1`
Validates the DSPM configuration and reports on the status of governance features.

**What it does:**
- Checks audit status
- Validates policy creation and status
- Verifies AI app data collection
- Reports on sensitive data detection
- Provides configuration health summary

**Usage:**
```powershell
./verify_dspm_configuration.ps1
```

## 📚 Prerequisites

### Required Licenses
- Microsoft 365 E5 license

### Required Permissions
- **Microsoft Entra Compliance Admin**, **Global Admin**, or **Purview Compliance Admin** for DSPM configuration
- **Compliance Management** or **Organization Management** for audit enablement
- **Contributor** role on Azure subscription for AI Foundry connections

### Required PowerShell Modules
- PowerShell 7 or later
- Azure CLI (authenticated)
- Exchange Online Management module (for DSPM policy creation)

**Why Exchange Online Management?**
- Microsoft Purview DSPM policies are created using Exchange Online PowerShell cmdlets (`New-FeatureConfiguration`)
- These cmdlets are **only available** through Security & Compliance PowerShell connection
- There is **no REST API or ARM template alternative** currently available
- This is Microsoft's official method for programmatic policy creation
- Our scripts **automate** the connection and command execution for you

## 🚀 Getting Started

### 1. Install Prerequisites

```bash
# Install PowerShell 7 (if not already installed)
# For Ubuntu/Debian
sudo apt-get update
sudo apt-get install -y powershell

# Install Exchange Online Management module
pwsh -Command "Install-Module -Name ExchangeOnlineManagement -Force -AllowClobber"
```

### 2. Authenticate

```bash
# Azure CLI authentication
az login

# Connect to Security & Compliance PowerShell (required for policy creation)
pwsh -Command "Connect-IPPSSession"
```

### 3. Run Scripts in Order

```bash
# Step 1: Enable DSPM
pwsh ./enable_purview_dspm.ps1

# Step 2: Create DSPM policies
pwsh ./create_dspm_policies.ps1

# Step 3: Connect to AI Foundry (if you have AI Foundry projects)
pwsh ./connect_dspm_to_ai_foundry.ps1

# Step 4: Verify configuration
pwsh ./verify_dspm_configuration.ps1
```

## 🔐 Security Features

### Data Protection
- **Sensitive Data Detection**: Automatically detects sensitive information in AI prompts and responses
- **Data Loss Prevention**: Prevents unauthorized data exposure through AI interactions
- **Access Control**: Enforces least-privilege access to AI resources

### Monitoring & Compliance
- **Activity Tracking**: Comprehensive audit logs for all AI interactions
- **Risk Analytics**: Identifies risky AI usage patterns
- **Compliance Reporting**: Ready-to-use reports for regulatory compliance

### Policy Enforcement
- **Know Your Data (KYD)**: Collects and analyzes AI app interactions
- **Communication Compliance**: Detects unethical behavior in AI usage
- **Insider Risk Management**: Identifies risky AI usage patterns

## 📊 Monitoring & Validation

After configuration, monitor your DSPM deployment:

1. **Portal Access**: Visit [Microsoft Purview DSPM for AI](https://purview.microsoft.com/purviewforai/overview)
2. **Activity Explorer**: View AI interaction details, sensitive data detections
3. **Reports**: Review AI security reports and analytics
4. **Recommendations**: Apply additional security recommendations

### Key Metrics to Monitor
- Number of AI interactions collected
- Sensitive data detections
- Policy violations
- User risk scores
- AI app usage patterns

## 🏗️ Architecture Integration

```
┌─────────────────────────────────────────────────────────────┐
│                    Azure AI Foundry                         │
│  ┌────────────────┐    ┌────────────────┐                   │
│  │  AI Projects   │    │   AI Models    │                   │
│  │  & Workspaces  │────│   & Prompts    │                   │
│  └────────────────┘    └────────────────┘                   │
└─────────────────────────────────────────────────────────────┘
                              │
                              │ Data Governance
                              ▼
┌─────────────────────────────────────────────────────────────┐
│           Microsoft Purview DSPM for AI                     │
├─────────────────────────────────────────────────────────────┤
│  ┌─────────────────┐  ┌─────────────────┐  ┌─────────────┐ │
│  │  KYD Policies   │  │  Audit Logs     │  │  Risk       │ │
│  │  (Collection)   │  │  (Tracking)     │  │  Analytics  │ │
│  └─────────────────┘  └─────────────────┘  └─────────────┘ │
│                                                             │
│  ┌─────────────────┐  ┌─────────────────┐  ┌─────────────┐ │
│  │  Communication  │  │  Insider Risk   │  │  Sensitive  │ │
│  │  Compliance     │  │  Management     │  │  Data       │ │
│  └─────────────────┘  └─────────────────┘  └─────────────┘ │
└─────────────────────────────────────────────────────────────┘
```

## 🔧 Troubleshooting

### Common Issues

**Policy Creation Fails**
- Ensure you're connected to Security & Compliance PowerShell: `Connect-IPPSSession`
- Verify you have appropriate admin roles
- Check if policies already exist: `Get-FeatureConfiguration`

**Audit Not Enabling**
- Confirm M365 E5 license is active
- Wait up to 60 minutes for initial audit activation
- Check tenant admin settings

**AI Foundry Connection Issues**
- Verify Azure RBAC permissions
- Ensure AI Foundry projects exist in the subscription
- Check network connectivity to Azure endpoints

## 📖 References

- [Microsoft Purview DSPM for AI Overview](https://learn.microsoft.com/en-us/purview/ai-microsoft-purview)
- [Configure DSPM for AI](https://learn.microsoft.com/en-us/purview/developer/configurepurview)
- [DSPM for AI Prerequisites](https://learn.microsoft.com/en-us/purview/ai-microsoft-purview-considerations)
- [Azure AI Foundry Integration](https://learn.microsoft.com/en-us/purview/developer/secure-ai-with-purview)
- [PowerShell Policy Configuration](https://learn.microsoft.com/en-us/purview/developer/configurepurview#creating-dspm-for-ai-know-your-data-kyd-policies-using-powershell)

## 🤝 Integration with Existing Scripts

These governance scripts complement the existing automation:

- **Fabric_Purview_Automation**: Creates domains, workspaces, and collections
- **PurviewGovernance** (new): Adds DSPM and AI governance capabilities
- **OneLakeIndex**: Enables AI Search integration

Together, they provide end-to-end data governance from creation to AI-powered insights.
