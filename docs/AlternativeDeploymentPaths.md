# Alternative Deployment Paths

This document covers deployment options beyond the standard `azd up` workflow. Use these paths when you need fine-grained control, CI/CD integration, or environment-specific configurations.

---

## Table of Contents

- [Direct run.ps1 Execution](#direct-runps1-execution)
- [Tag Reference](#tag-reference)
- [Microsoft 365 Desktop Deployment](#microsoft-365-desktop-deployment)
- [Foundry-Only Configuration](#foundry-only-configuration)
- [CI/CD Integration](#cicd-integration)
- [GitHub Actions with Federated Identity](#github-actions-with-federated-identity)
- [Local Quick Start](#local-quick-start)
- [Spec File Management](#spec-file-management)
- [Environment Variables](#environment-variables)
- [Run Plan Breakdown](#run-plan-breakdown)
- [Undo and Rollback](#undo-and-rollback)

---

## Direct run.ps1 Execution

Use `run.ps1` directly instead of `azd up` when you need to:

- **Run only specific modules** - Deploy just Defender plans without touching Purview or M365
- **Resume a failed deployment** - Pick up where you left off without re-running completed steps
- **Split work across teams** - Azure admin runs infrastructure tags; compliance admin runs M365 tags separately
- **Debug a single script** - Isolate and troubleshoot one automation step
- **Skip the Bicep layer** - Already have infrastructure and just need governance configuration
- **Use different spec files** - Point to environment-specific configs (dev, staging, prod)

```powershell
# Run specific governance modules
pwsh ./run.ps1 -Tags foundation,dspm,defender,foundry -SpecPath ./spec.local.json
```

### Prerequisites

Before running, authenticate in the same terminal:

```powershell
az login
azd auth login
Connect-AzAccount -Tenant <tenantId> -Subscription <subscriptionId>
Set-AzContext -Subscription <subscriptionId>
Get-AzContext  # Verify tenant/subscription match your spec
```

---

## Tag Reference

| Tag | What it runs | Example command |
| --- | ------------ | --------------- |
| `foundation` | Baseline Purview/DSPM bootstrap: resource group, Purview account, data-source registration + first scans | `./run.ps1 -Tags foundation -SpecPath ./spec.local.json` |
| `m365` | Exchange Online / Compliance Center steps requiring interactive auth: Unified Audit, Know Your Data policy, DLP/label/retention settings | `./run.ps1 -Tags m365 -SpecPath ./spec.local.json` |
| `dspm` | Broader Purview governance: scan registration, audit subscriptions/exports, Azure policy assignments, tagging, posture validation | `./run.ps1 -Tags foundation,dspm -SpecPath ./spec.local.json` |
| `defender` | Defender for AI enablement: plans, diagnostics, content-safety wiring | `./run.ps1 -Tags defender -SpecPath ./spec.local.json` |
| `foundry` | Azure AI Foundry integration: resource registration, tagging, diagnostics, content safety | `./run.ps1 -Tags foundry -SpecPath ./spec.local.json` |
| `audit` | Replay audit export scripts only | `./run.ps1 -Tags audit -SpecPath ./spec.local.json` |
| `all` | Runs everything end-to-end | `./run.ps1 -Tags all -SpecPath ./spec.local.json` |

### Common Deployment Scenarios

| I want to... | Run these tags | Prerequisites | Key spec sections |
|-------------|----------------|---------------|-------------------|
| **Secure Azure AI Foundry only** | `defender,foundry` | Azure Contributor on subscription with Foundry projects | `aiFoundry.*`, `foundry.resources[]`, `defenderForAI.enableDefenderForCloudPlans` |
| **Full Purview DSPM for AI (no M365)** | `foundation,dspm,defender,foundry` | Azure Contributor + Purview Data Source Admin | All Azure sections (skip `dlpPolicy`, `labels`, `retentionPolicies`) |
| **Enable M365 Copilot governance** | `m365` (run separately from desktop) | Desktop + MFA + Exchange Online admin + E5 license | `dlpPolicy`, `labels`, `retentionPolicies` |
| **Everything** | `all` | All of the above (may require multiple operators) | All spec sections |

---

## Microsoft 365 Desktop Deployment

The `m365` tag requires a desktop workstation with browser-based MFA capability. This cannot run in containers or Codespaces.

### Why desktop-only?

Exchange Online and Security & Compliance PowerShell require interactive authentication with MFA. Containerized environments lack the browser integration needed for this flow.

### Steps

1. **Open PowerShell 7 on your workstation**

2. **Install/update the Exchange Online Management module:**
   ```powershell
   Install-Module ExchangeOnlineManagement -Scope CurrentUser -Force
   ```

3. **Run the M365 tag:**
   ```powershell
   ./run.ps1 -Tags m365 -ConnectM365 -M365UserPrincipalName <your-upn> -SpecPath ./spec.local.json
   ```

4. **Complete the MFA prompts** in your browser when prompted

5. **Verify** that Unified Audit reports "Enabled" and the Secure interactions (KYD) policy appears in the Purview portal

### Team workflow

If your team splits responsibilities:
- **Azure admin** runs `foundation,dspm,defender,foundry` from containers/CI
- **Compliance admin** runs `m365` from their workstation independently

---

## Foundry-Only Configuration

For organizations that only need to govern Azure AI Foundry projects without full Purview DSPM or M365 setup:

### Prerequisites
- Azure Contributor RBAC on the subscription containing your Foundry projects
- PowerShell 7.x and Az modules installed
- Azure Developer CLI (azd) 1.9.0+ and Azure CLI 2.58.0+

### Minimal spec file

Populate only these sections in `spec.local.json`:

```json
{
  "tenantId": "<your-tenant-id>",
  "subscriptionId": "<subscription-with-foundry>",
  "aiFoundry": {
    "subscriptionId": "<same-subscription>",
    "resourceGroupName": "<foundry-resource-group>"
  },
  "foundry": {
    "resources": [
      {
        "name": "<foundry-project-name>",
        "resourceGroup": "<foundry-resource-group>"
      }
    ]
  },
  "defenderForAI": {
    "enableDefenderForCloudPlans": ["CognitiveServices", "Storage"]
  }
}
```

### Deploy commands

```powershell
# Sign in
az login
azd auth login
Connect-AzAccount -Tenant <tenantId> -Subscription <subscriptionId>
Set-AzContext -Subscription <subscriptionId>

# Run only Foundry + Defender tags
./run.ps1 -Tags defender,foundry -SpecPath ./spec.local.json
```

### What this enables
- Defender for AI plans on Cognitive Services resources
- Diagnostic settings streaming to Log Analytics
- Content Safety blocklists (if `foundry.contentSafety` configured in spec)
- Resource tagging for governance lineage

### What you DON'T get without other tags
- No Purview DSPM scanning of data sources
- No M365 KYD/DLP policies for Copilot
- No audit exports to external storage
- No Purview registration of Foundry projects (use `foundation` tag to add this)

---

## CI/CD Integration

### Devcontainer / azd post-provision flow

The `azure.yaml` and `infra/main.bicep` let you run `azd up` purely to trigger the post-provision hook - no infrastructure needs to be deployed.

The hook (`hooks/postprovision.ps1`) reuses the current `azd auth login` context by importing Azure CLI tokens into Az PowerShell before invoking `run.ps1`.

### Typical workflow inside devcontainer:

1. `azd auth login` (or `az login`) to seed the CLI context
2. Populate `spec.local.json`
3. Run `azd up` - the Bicep deployment no-ops, then the hook runs `run.ps1`

### Customize via main.bicepparam

Edit `infra/main.bicepparam` to control:
- `dagaSpecPath` - spec file path
- `dagaPostprovisionTags` - comma-separated tags to run
- `dagaPostprovisionConnectM365` - enable M365 steps
- `dagaPostprovisionM365Upn` - UPN for M365 auth

---

## GitHub Actions with Federated Identity

The workflow in `.github/workflows/daga-automation-oidc.yml` runs `./run.ps1 -Tags all -ConnectM365` on `ubuntu-latest` with OIDC-based Azure login.

### Required repository secrets

| Secret | Purpose |
| ------ | ------- |
| `AZURE_FEDERATED_CLIENT_ID` | Federated SPN client ID |
| `AZURE_FEDERATED_TENANT_ID` | Tenant ID |
| `AZURE_FEDERATED_SUBSCRIPTION_ID` | Subscription ID |
| `DAGA_SPEC_JSON` | Entire `spec.local.json` contents as JSON |
| `DAGA_M365_APP_ID` | App registration for M365 |
| `DAGA_M365_ORGANIZATION` | M365 organization |
| `DAGA_M365_CERT_PFX` | Base64-encoded PFX certificate |
| `DAGA_M365_CERT_PASSWORD` | Certificate password |

### Non-interactive Microsoft 365 auth

`run.ps1` supports certificate-based automation:

```powershell
./run.ps1 -Tags m365 -ConnectM365 `
  -M365AppId "<app-id>" `
  -M365Organization "<org>.onmicrosoft.com" `
  -M365CertificatePath "./cert.pfx" `
  -M365CertificatePassword "<password>"
```

Or via environment variables:
- `DAGA_M365_APP_ID`
- `DAGA_M365_ORGANIZATION`
- `DAGA_M365_CERT_PATH` / `DAGA_M365_CERT_PASSWORD`
- `DAGA_M365_CERT_THUMBPRINT` (alternative to path)

---

## Local Quick Start

### Step 1: Install tooling

```powershell
# PowerShell 7
Install-Module Az -Scope CurrentUser -Repository PSGallery -Force -AllowClobber
Install-Module Az.Security -Scope CurrentUser -Force
```

### Step 2: Sign in to Azure

```powershell
Connect-AzAccount -Tenant '<tenant-guid>' -Subscription '<subscription-guid>'
```

For automation, use a service principal:
```powershell
Connect-AzAccount -ServicePrincipal -Tenant '<tenant-guid>' -ApplicationId '<appId>' -Credential (Get-Credential)
```

### Step 3: Prepare the spec

```powershell
pwsh ./scripts/governance/00-New-DspmSpec.ps1 -OutFile ./spec.dspm.template.json
Copy-Item ./spec.dspm.template.json ./spec.local.json
```

Populate tenant/subscription IDs, Purview settings, Foundry resources, etc.

### Step 4: Execute modules

Run individual scripts or use tags:

**Foundation (Purview landing zone):**
```powershell
pwsh ./scripts/governance/01-Ensure-ResourceGroup.ps1 -SpecPath ./spec.local.json
pwsh ./scripts/governance/dspmPurview/02-Ensure-PurviewAccount.ps1 -SpecPath ./spec.local.json
```

**Defender for AI posture:**
```powershell
pwsh ./scripts/defender/defenderForAI/06-Enable-DefenderPlans.ps1 -SpecPath ./spec.local.json
pwsh ./scripts/defender/defenderForAI/07-Enable-Diagnostics.ps1 -SpecPath ./spec.local.json
```

**Foundry registration + Content Safety:**
```powershell
pwsh ./scripts/governance/dspmPurview/30-Foundry-RegisterResources.ps1 -SpecPath ./spec.local.json
pwsh ./scripts/governance/dspmPurview/31-Foundry-ConfigureContentSafety.ps1 -SpecPath ./spec.local.json
```

**Or use the orchestrator:**
```powershell
./run.ps1 -Tags dspm,defender,foundry -SpecPath ./spec.local.json
```

### Step 5: Review and export evidence

```powershell
pwsh ./scripts/governance/dspmPurview/17-Export-ComplianceInventory.ps1 -SpecPath ./spec.local.json
pwsh ./scripts/governance/dspmPurview/21-Export-Audit.ps1 -SpecPath ./spec.local.json
```

---

## Spec File Management

### Creating and maintaining spec files

The repo tracks a sanitized contract in `spec.dspm.template.json`. Create your working copy:

```powershell
Copy-Item ./spec.dspm.template.json ./spec.local.json
```

This file is listed in `.gitignore` so it stays on your machine.

### Multiple environments

Create additional local files for different environments:
- `spec.dev.json`
- `spec.staging.json`
- `spec.prod.json`

Point `run.ps1 -SpecPath` to the one you need.

### Key spec sections

| Section | Purpose | Consumed by tags |
| ------- | ------- | ---------------- |
| `tenantId`, `subscriptionId` | Target tenant and subscription | All |
| `purview.*` | Purview account and data source settings | `foundation`, `dspm` |
| `aiFoundry.*` | Foundry subscription and resource group | `foundry`, `defender` |
| `foundry.resources[]` | List of Foundry projects to govern | `foundry` |
| `defenderForAI.*` | Defender plans to enable | `defender` |
| `dlpPolicy`, `labels`, `retentionPolicies` | M365 compliance settings | `m365` |
| `activityExport.*` | Audit export configuration | `audit` |

See [spec-local-reference.md](./spec-local-reference.md) for field-by-field documentation.

### Secrets management

Keep secrets in Azure Key Vault rather than the spec file. Reference them using Key Vault URIs where scripts support it.

---

## Environment Variables

Environment variables override `main.bicepparam` values:

| Variable | Purpose |
| -------- | ------- |
| `DAGA_SPEC_PATH` | Spec file path (default: `./spec.local.json`) |
| `DAGA_POSTPROVISION_TAGS` | Comma-separated tags to run |
| `DAGA_POSTPROVISION_CONNECT_M365` | Enable M365 steps (`true`/`false`) |
| `DAGA_POSTPROVISION_M365_UPN` | UPN for interactive M365 auth |
| `DAGA_M365_APP_ID` | App ID for certificate-based M365 auth |
| `DAGA_M365_ORGANIZATION` | M365 organization for app auth |
| `DAGA_M365_CERT_THUMBPRINT` | Certificate thumbprint |
| `DAGA_M365_CERT_PATH` | Path to PFX certificate |
| `DAGA_M365_CERT_PASSWORD` | Certificate password |

---

## Run Plan Breakdown

`run.ps1` executes scripts in a fixed order. Here's the complete sequence:

| Order | Script | What happens |
| ----- | ------ | ------------ |
| 5 | `00-New-DspmSpec.ps1` | Generates/refreshes the spec contract |
| 10 | `01-Ensure-ResourceGroup.ps1` | Creates landing-zone resource group |
| 20 | `02-Ensure-PurviewAccount.ps1` | Ensures Purview account exists |
| 30 | `10-Connect-Compliance.ps1` | Establishes Exchange Online sessions |
| 40 | `11-Enable-UnifiedAudit.ps1` | Turns on Unified Audit |
| 50 | `12-Create-DlpPolicy.ps1` | Creates DLP/KYD policies |
| 60 | `13-Create-SensitivityLabel.ps1` | Publishes sensitivity labels |
| 70 | `14-Create-RetentionPolicy.ps1` | Creates retention policies |
| 80 | `03-Register-DataSource.ps1` | Registers data sources in Purview |
| 90 | `04-Run-Scan.ps1` | Triggers Purview scans |
| 100 | `20-Subscribe-ManagementActivity.ps1` | Sets up audit exports |
| 110 | `21-Export-Audit.ps1` | Executes audit export |
| 120 | `05-Assign-AzurePolicies.ps1` | Applies Azure Policy assignments |
| 130 | `06-Enable-DefenderPlans.ps1` | Enables Defender for Cloud plans |
| 140 | `07-Enable-Diagnostics.ps1` | Configures diagnostic settings |
| 150 | `25-Tag-ResourcesFromSpec.ps1` | Applies governance tags |
| 200 | `30-Foundry-RegisterResources.ps1` | Registers Foundry projects in Purview |
| 210 | `31-Foundry-ConfigureContentSafety.ps1` | Deploys Content Safety settings |
| 220 | `17-Export-ComplianceInventory.ps1` | Captures compliance inventory |
| 280 | `24-Create-BudgetAlert-Stub.ps1` | Budget alerts (placeholder) |

---

## Undo and Rollback

### Clean up with azd down

To remove all resources deployed by this accelerator:

```powershell
azd down
```

This deletes the resource group and all contained resources. It does NOT:
- Remove Purview data source registrations
- Delete M365 policies (DLP, labels, retention)
- Disable Defender for Cloud plans
- Remove audit subscriptions

### Manual cleanup steps

If `azd down` fails or you need selective cleanup:

**1. Delete the resource group:**
```powershell
Remove-AzResourceGroup -Name "<resource-group-name>" -Force
```

**2. Remove Purview data sources (if needed):**
Sign into the Purview portal and manually delete registered data sources.

**3. Remove M365 policies:**
- Navigate to Microsoft Purview Compliance Portal
- Delete DLP policies under **Data loss prevention > Policies**
- Delete sensitivity labels under **Information protection > Labels**
- Delete retention policies under **Data lifecycle management > Retention policies**

**4. Disable Defender plans:**
```powershell
# List current plans
Get-AzSecurityPricing

# Disable a specific plan
Set-AzSecurityPricing -Name "CognitiveServices" -PricingTier "Free"
```

**5. Remove diagnostic settings:**
```powershell
$resources = Get-AzResource -ResourceGroupName "<rg-name>"
foreach ($r in $resources) {
    $diag = Get-AzDiagnosticSetting -ResourceId $r.ResourceId -ErrorAction SilentlyContinue
    if ($diag) {
        Remove-AzDiagnosticSetting -ResourceId $r.ResourceId -Name $diag.Name
    }
}
```

### Partial deployment recovery

If a deployment fails partway through:

1. **Check the error** - Review the terminal output to identify which script failed
2. **Fix the issue** - Usually a missing permission, invalid spec value, or transient error
3. **Resume from where you left off** - Run only the remaining tags:
   ```powershell
   # If foundation succeeded but dspm failed
   ./run.ps1 -Tags dspm,defender,foundry -SpecPath ./spec.local.json
   ```

### Known safe operations

These scripts are idempotent and safe to re-run:
- All `Ensure-*` scripts (check before creating)
- `Register-DataSource.ps1` (skips existing registrations)
- `Enable-DefenderPlans.ps1` (skips already-enabled plans)
- `Tag-ResourcesFromSpec.ps1` (updates existing tags)

### Operations requiring caution

- `Create-DlpPolicy.ps1` - May create duplicate policies if names differ
- `Export-Audit.ps1` - Creates new export files each run
- Any script that modifies M365 settings - Changes take effect immediately

---

## Script families reference

| Folder | Purpose | Key scripts |
| ------ | ------- | ----------- |
| `scripts/governance` | Spec management, Purview bootstrap, policy creation, audit exports, Foundry integration | `00-New-DspmSpec.ps1`, `02-Ensure-PurviewAccount.ps1`, `12-Create-DlpPolicy.ps1`, `30-Foundry-RegisterResources.ps1` |
| `scripts/defender/defenderForAI` | Defender for Cloud AI plans, diagnostics | `06-Enable-DefenderPlans.ps1`, `07-Enable-Diagnostics.ps1` |
| `scripts/exchangeOnline` | Security and Compliance PowerShell (behind `m365` tag) | `10-Connect-Compliance.ps1`, `11-Enable-UnifiedAudit.ps1` |

Each script is idempotent and checks for prerequisites before applying changes.
