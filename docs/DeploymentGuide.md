# Deployment Guide

Follow this guide to deploy the Data and Agent Governance and Security Accelerator (DAGSA) into your Azure subscription using the Azure Developer CLI (azd).

---

## Before You Begin - Validation Checklist

Before starting, confirm you have the following ready:

### Tooling requirements

| Tool | Minimum Version | Check Command | Install Link |
|------|-----------------|---------------|---------------|
| Azure Developer CLI (azd) | 1.9.0+ | `azd version` | [Install azd](https://learn.microsoft.com/azure/developer/azure-developer-cli/install-azd) |
| Bicep CLI | 0.33.0+ | `bicep --version` | [Install Bicep](https://learn.microsoft.com/azure/azure-resource-manager/bicep/install) |
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
| Resource Group | Azure Portal → Resource groups | `rg-resourcegroup-name` |
| Purview account name | Azure Portal → Microsoft Purview accounts | `contoso-purview` |
| Purview resource group | Azure Portal → Microsoft Purview accounts → Overview | `rg-purview-prod` |
| Microsoft Foundry project name | Microsoft Foundry portal → Settings | `contoso-ai-project` |
| AI resource group | Azure Portal → Resource groups | `rg-ai-foundry` |
| Log Analytics workspace ID | Azure Portal → Log Analytics → Properties → Workspace ID | `/subscriptions/.../workspaces/contoso-logs` |

### Permissions checklist

- [ ] **Azure Contributor** on subscription(s) with Purview, Microsoft Foundry, and Defender resources
- [ ] **Purview Data Source Administrator** for registering data sources
- [ ] **Purview Data Security and Posture Management (DSPM)** for AI access
- [ ] **Purview Data Security AI Content Viewer** role for accessing AI prompts
- [ ] **Microsoft 365 E5 or E5 Compliance license** (for m365 tag)
- [ ] **Compliance Administrator** role in Microsoft 365 (for Unified Audit and DLP)
- [ ] **Exchange Online admin** access with MFA (for m365 tag). In containers/Codespaces, device-code flow is used — open the URL shown in the terminal on a local browser to authenticate

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
# Azure CLI - for resource management operations
az login

# Azure Developer CLI - for azd-specific deployment operations
azd auth login

# PowerShell Az module - for automation scripts and governance operations
Connect-AzAccount -Tenant <tenantId> -Subscription <subscriptionId>

# Set active context - ensures all subsequent commands target the correct subscription
Set-AzContext -Subscription <subscriptionId>

# Verify your authentication context matches your spec file
Get-AzContext
```

Replace the placeholders (`<tenantId>` and `<subscriptionId>`) with the values at the top of your `spec.local.json`.

**Expected output from `Get-AzContext`:**
Verify that the following values match your `spec.local.json`:
- **Name**: Your subscription name
- **Account**: Your signed-in user account
- **TenantId**: Should match the `tenantId` in your spec file
- **SubscriptionId**: Should match the `subscriptionId` in your spec file

**Using a service principal:**
If you are using a service principal for authentication instead of interactive login, use the following command:

```powershell
# Service principal authentication
$credential = Get-Credential  # Enter Application (client) ID as username and secret as password
Connect-AzAccount -ServicePrincipal -Tenant <tenantId> -Credential $credential -Subscription <subscriptionId>

# Or using a certificate
Connect-AzAccount -ServicePrincipal -Tenant <tenantId> -CertificateThumbprint <thumbprint> -ApplicationId <appId> -Subscription <subscriptionId>
```

---

## 3. Prepare the spec

The spec file (`spec.local.json`) is the central configuration that drives all automation. Here's how to configure it:

### Step 3.1: Create your local spec file

When you run `azd up`, the preprovision hook creates `spec.local.json` automatically if it doesn't exist. The hook writes the minimum run parameters (tenant, subscription, resource group, location) and supplies empty placeholders for optional sections so the scripts can skip them safely.

If you want to scaffold manually:
```powershell
# Optional: Regenerate template if schema has changed
pwsh ./scripts/governance/00-New-DspmSpec.ps1 -OutFile ./spec.dspm.template.json

# Create your working copy (this file is gitignored)
Copy-Item ./spec.dspm.template.json ./spec.local.json
```
```bash
# Bash command
cp ./spec.dspm.template.json ./spec.local.json
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

### Step 3.3: Configure Microsoft Foundry resources (for `foundry` tag)

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

## 4. Configure Microsoft 365 environment variables

If your deployment includes Fabric sensitivity labels or M365 compliance steps, set the following `azd` environment variables so the post-provision hook can authenticate to Exchange Online:

```powershell
azd env set DAGA_POSTPROVISION_CONNECT_M365 true
azd env set DAGA_POSTPROVISION_M365_UPN "<add-your-upn>"
```

Replace `<add-your-upn>` with your Microsoft 365 user principal name (e.g., `admin@contoso.onmicrosoft.com`).

In containers or Codespaces, authentication uses device-code flow — the terminal will display a URL and code for you to open on a local browser to complete sign-in.

---

## 5. Configure azd parameters (optional)

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

## 6. Install AZ modules (Optional)

If you don't have the required Azure PowerShell modules installed, run the following commands to install them:

```powershell
# Installs the main Azure PowerShell module, which provides cmdlets for managing Azure resources
Install-Module Az -Scope CurrentUser -Repository PSGallery -Force

# Installs the Azure Accounts module for authentication and context management
Install-Module Az.Accounts -Scope CurrentUser -Repository PSGallery -Force

# Installs the Azure Purview module for managing Microsoft Purview resources and data governance
Install-Module Az.Purview -Scope CurrentUser -Repository PSGallery -Force

# Installs the Azure Security module for managing Microsoft Defender for Cloud and security policies
Install-Module Az.Security -Scope CurrentUser -Repository PSGallery -Force
```

These modules enable the PowerShell automation scripts to interact with Azure services. The `-Scope CurrentUser` parameter installs the modules for your user profile only, without requiring administrator privileges.

---

## 7. Deploy with `azd up`

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

## 8. Post-deployment actions

1. **Purview portal toggles** – enable *Secure interactions for enterprise AI apps* in the Purview portal (Data Security Posture Management for AI > Recommendations).
2. **Role assignments** – ensure the operator account has the Audit Reader (or Compliance Administrator) role before running the audit export scripts.
3. **Fabric labeling prerequisites** – Confirm Fabric sensitivity labels are already available in the tenant, the referenced Purview labels already exist, and the operator can authenticate both to Exchange Online / Security & Compliance and to Fabric admin APIs. The accelerator applies labels; it does not enable the Fabric tenant feature for you.
4. **Set scan automation mode** – Keep `fabric.scanAutomationMode` set to `runOnly` in `spec.local.json` when the Fabric scan definitions are already managed in the Purview portal and you only want automation to retrigger them. Use `full` if automation should create or update the scan definition before running it. Use `disabled` if you want to skip scan triggering altogether.
5. **Retrigger scans** – Run `azd hooks run postprovision` (or `./scripts/governance/dspmPurview/29-Trigger-FabricWorkspaceScan.ps1 -SpecPath ./spec.local.json`) to trigger both scans using the configured definitions. If `runOnly` is set, the named scan must already exist.
6. **Evidence collection** – rerun `./scripts/governance/dspmPurview/17-Export-ComplianceInventory.ps1` when you are ready to archive posture evidence.
7. **Cost management** – review [Cost Guidance](./CostGuidance.md) and set budget alerts or run `azd down` when the environment is no longer required.

For a portal-by-portal validation checklist after provisioning, see [Post-Provisioning Validation](./PostProvisioningValidation.md).

---

## 9. Next steps

- Customize the spec for additional Foundry projects or Fabric workspaces.
- Integrate the accelerator into CI/CD by invoking `run.ps1` from GitHub Actions or Azure DevOps.
- Extend the stub scripts (for example, `15-Create-SensitiveInfoType-Stub.ps1`) with organization-specific logic.

Refer to the [Troubleshooting Guide](./TroubleshootingGuide.md) if `azd up` surfaces authentication or permission errors.
