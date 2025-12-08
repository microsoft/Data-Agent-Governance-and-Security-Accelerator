# Deployment Guide

Follow this guide to deploy the Data Agent Governance and Security Accelerator (DAGA) into your Azure subscription using the Azure Developer CLI (azd).

---

## Before You Begin - Validation Checklist

Before starting, confirm you have the following ready:

### Tooling requirements

| Tool | Minimum Version | Check Command | Install Link |
|------|-----------------|---------------|---------------|
| Azure Developer CLI (azd) | 1.9.0+ | `azd version` | [Install azd](https://learn.microsoft.com/azure/developer/azure-developer-cli/install-azd) |
| Azure CLI | 2.58.0+ | `az --version` | [Install Azure CLI](https://learn.microsoft.com/cli/azure/install-azure-cli) |
| PowerShell | 7.x | `pwsh --version` | [Install PowerShell](https://learn.microsoft.com/powershell/scripting/install/installing-powershell) |
| Az PowerShell modules | Latest | `Get-Module Az -ListAvailable` | `Install-Module Az -Scope CurrentUser -Force` |
| Exchange Online module | Latest (for m365 tag) | `Get-Module ExchangeOnlineManagement -ListAvailable` | `Install-Module ExchangeOnlineManagement -Scope CurrentUser` |

### Azure resources you'll need to identify

Gather this information before configuring your spec file:

| Information | Where to find it | Example |
|-------------|------------------|----------|
| Tenant ID | Azure Portal → Entra ID → Overview | `12345678-1234-1234-1234-123456789012` |
| Subscription ID | Azure Portal → Subscriptions | `87654321-4321-4321-4321-210987654321` |
| Purview account name | Azure Portal → Microsoft Purview accounts | `contoso-purview` |
| Purview resource group | Azure Portal → Microsoft Purview accounts → Overview | `rg-purview-prod` |
| AI Foundry project name | Azure AI Foundry portal → Settings | `contoso-ai-project` |
| AI resource group | Azure Portal → Resource groups | `rg-ai-foundry` |
| Log Analytics workspace ID | Azure Portal → Log Analytics → Properties → Workspace ID | `/subscriptions/.../workspaces/contoso-logs` |

### Permissions checklist

- [ ] **Azure Contributor** on subscription(s) with Purview, AI Foundry, and Defender resources
- [ ] **Purview Data Source Administrator** for registering data sources
- [ ] **Microsoft 365 E5 or E5 Compliance license** (for m365 tag)
- [ ] **Compliance Administrator** role in Microsoft 365 (for Unified Audit and DLP)
- [ ] **Exchange Online admin** access from MFA-capable workstation (for m365 tag)

---

## 1. Clone and open the repository

```powershell
cd <working-directory>
git clone https://github.com/microsoft/Data-Agent-Governance-and-Security-Accelerator.git
cd Data-Agent-Governance-and-Security-Accelerator
```

Open the folder in VS Code, Codespaces, or a devcontainer if you prefer a managed environment.

---

## 2. Sign in to Azure

All provisioning relies on the credentials already cached by the Azure CLI and Az PowerShell. Run the following commands **in the same terminal** you will use for `azd up`:

```powershell
az login
azd auth login
Connect-AzAccount -Tenant <tenantId> -Subscription <subscriptionId>
Set-AzContext -Subscription <subscriptionId>
Get-AzContext    # confirm the tenant/subscription match your spec
```

Replace the placeholders with the values at the top of your `spec.local.json`. If you are using a service principal, pass `-ServicePrincipal` parameters to `Connect-AzAccount` instead.

---

## 3. Prepare the spec

The spec file (`spec.local.json`) is the central configuration that drives all automation. Here's how to configure it:

### Step 3.1: Create your local spec file

```powershell
# Optional: Regenerate template if schema has changed
pwsh ./scripts/governance/00-New-DspmSpec.ps1 -OutFile ./spec.dspm.template.json

# Create your working copy (this file is gitignored)
Copy-Item ./spec.dspm.template.json ./spec.local.json
```

### Step 3.2: Configure required fields

Open `spec.local.json` and replace placeholders with your actual values:

```json
{
  "tenantId": "12345678-1234-1234-1234-123456789012",
  "subscriptionId": "87654321-4321-4321-4321-210987654321",
  "resourceGroup": "rg-daga-governance",
  "location": "eastus",
  "purviewAccount": "contoso-purview",
  "purviewResourceGroup": "rg-purview-prod",
  "purviewSubscriptionId": "87654321-4321-4321-4321-210987654321"
}
```

### Step 3.3: Configure AI Foundry resources (for `foundry` tag)

```json
{
  "aiResourceGroup": "rg-ai-foundry",
  "aiSubscriptionId": "87654321-4321-4321-4321-210987654321",
  "aiFoundry": {
    "name": "contoso-ai-project",
    "resourceId": "/subscriptions/87654321-4321-4321-4321-210987654321/resourceGroups/rg-ai-foundry/providers/Microsoft.CognitiveServices/accounts/contoso-ai-project"
  },
  "foundry": {
    "resources": [
      {
        "name": "contoso-openai",
        "resourceId": "/subscriptions/87654321-4321-4321-4321-210987654321/resourceGroups/rg-ai-foundry/providers/Microsoft.CognitiveServices/accounts/contoso-openai",
        "diagnostics": true,
        "tags": { "environment": "production", "costCenter": "AI-governance" }
      }
    ]
  }
}
```

**Tip:** Find your resource IDs in Azure Portal → Resource → Properties → Resource ID

### Step 3.4: Configure Defender for AI (for `defender` tag)

```json
{
  "defenderForAI": {
    "enableDefenderForCloudPlans": [
      "CognitiveServices",
      "Storage"
    ],
    "logAnalyticsWorkspaceId": "/subscriptions/87654321-4321-4321-4321-210987654321/resourceGroups/rg-monitoring/providers/Microsoft.OperationalInsights/workspaces/contoso-logs",
    "diagnosticCategories": [
      "Audit",
      "RequestResponse",
      "AllMetrics"
    ]
  }
}
```

### Step 3.5: Configure M365 compliance (for `m365` tag) - Optional

These sections are only needed if you're running the `m365` tag for DLP, labels, and retention:

```json
{
  "dlpPolicy": {
    "name": "AI Egress Control",
    "mode": "Enforce",
    "locations": { "Exchange": "All", "SharePoint": "All", "OneDrive": "All", "Teams": "All" },
    "rules": [
      {
        "name": "Block Sensitive Data to AI",
        "sensitiveInfoTypes": [
          { "name": "Credit Card Number", "count": 1, "confidence": 85 }
        ],
        "blockAccess": true,
        "notifyUser": true
      }
    ]
  },
  "labels": [
    {
      "name": "Confidential - AI Restricted",
      "publishPolicyName": "Publish: Confidential",
      "encryptionEnabled": true
    }
  ],
  "retentionPolicies": [
    {
      "name": "AI Data - 7 Years",
      "rules": [{ "name": "Keep 7y then Delete", "durationDays": 2557, "action": "Delete" }],
      "locations": { "Exchange": "All", "SharePoint": "All", "OneDrive": "All" }
    }
  ]
}
```

### Step 3.6: Validate your spec

Before running, verify your JSON is valid:

```powershell
# Check JSON syntax
Get-Content ./spec.local.json | ConvertFrom-Json

# If no errors, you're ready to proceed
```

### Spec field reference

See the complete [Spec Field Reference](./spec-local-reference.md) for detailed documentation of every field.

---

## 4. Configure azd parameters (optional)

`infra/main.bicepparam` mirrors hook inputs. Update these values if you want `azd` to pass different tags or Microsoft 365 options to `run.ps1`:

```bicep-params
param dagaSpecPath = './spec.local.json'
param dagaTags = [
  'foundation'
  'dspm'
  'defender'
  'foundry'
]
param dagaConnectM365 = true
param dagaM365UserPrincipalName = 'admin@contoso.onmicrosoft.com'
```

Environment variables (`DAGA_SPEC_PATH`, `DAGA_POSTPROVISION_TAGS`, etc.) override the parameter file if you need temporary changes.

---

## 5. Deploy with `azd up`

```powershell
azd up
```

- The Bicep template is a no-op placeholder; provisioning time is dominated by the post-provision PowerShell hook.
- The hook imports your Azure CLI tokens, sets strict mode, and runs `run.ps1` with the tags defined earlier.
- Expect interactive prompts only if the Microsoft 365 steps need Exchange Online authentication.

If you are running outside of azd, you can execute the same automation directly:

```powershell
pwsh ./run.ps1 -Tags foundation,dspm,defender,foundry -SpecPath ./spec.local.json
```

Run `./run.ps1 -Tags m365 -ConnectM365 -M365UserPrincipalName <upn>` from a workstation that can satisfy MFA to publish the Secure Interactions / KYD policies.

---

## 6. Post-deployment actions

1. **Purview portal toggles** – enable *Secure interactions for enterprise AI apps* in the Purview portal (Data Security Posture Management for AI > Recommendations).
2. **Role assignments** – ensure the operator account has the Audit Reader (or Compliance Administrator) role before running the audit export scripts.
3. **Evidence collection** – rerun `./scripts/governance/dspmPurview/17-Export-ComplianceInventory.ps1` when you are ready to archive posture evidence.
4. **Cost management** – review [Cost Guidance](./CostGuidance.md) and set budget alerts or run `azd down` when the environment is no longer required.

---

## 7. Next steps

- Customize the spec for additional Foundry projects or Fabric workspaces.
- Integrate the accelerator into CI/CD by invoking `run.ps1` from GitHub Actions or Azure DevOps.
- Extend the stub scripts (for example, `15-Create-SensitiveInfoType-Stub.ps1`) with organization-specific logic.

Refer to the [Troubleshooting Guide](./TroubleshootingGuide.md) if `azd up` surfaces authentication or permission errors.
