# Microsoft Purview DSPM Automation Guide

This guide covers the spec-driven modules under `scripts/governance` that automate Microsoft Purview Data Security Posture Management (DSPM) for AI, Microsoft 365 compliance controls, and Azure AI Foundry governance. Every script is idempotent and reads the shared JSON contract—copy `spec.dspm.template.json` to your working file (for example `spec.local.json`)—so you can run them individually, in sequence, or via the tag-aware `run.ps1` orchestrator.

---

## Prerequisites

- **Licensing**: Microsoft 365 E5 (or E5 Compliance) assigned to the operator.
- **Roles**: Compliance Administrator (or Purview Administrator) plus Purview Data Source Administrator. Azure Contributor rights on the subscription that hosts Purview and AI assets.
- **Tools**: PowerShell 7, Azure CLI authenticated to the target tenant. Install the Exchange Online Management module on a workstation that can satisfy MFA prompts.
- **Spec**: Copy `spec.dspm.template.json` to a local file (for example `spec.local.json`) and populate tenant, subscription, resource group, Purview account, data source names, AI Foundry project, Key Vault, and Log Analytics workspace. Derived IDs are computed automatically by the spec template.

> Tip: Regenerate a skeleton spec any time with `pwsh ./scripts/governance/00-New-DspmSpec.ps1 -OutFile ./spec.dspm.template.json`, then copy it to your local filename when ready.

---

## Runbook summary

Follow the numbered flow to wire up Microsoft 365 governance, Azure resource posture, and AI Foundry guardrails.

1. **Foundation**
   - `01-Ensure-ResourceGroup.ps1` ensures the resource group described in the spec exists.
   - `dspmPurview/02-Ensure-PurviewAccount.ps1` creates or updates the Purview account and connects it to the spec metadata.

2. **Compliance backbone**
   - `../exchangeOnline/10-Connect-Compliance.ps1` opens an IPPS session (requires interactive MFA).
   - `../exchangeOnline/11-Enable-UnifiedAudit.ps1` turns on unified audit ingestion so DSPM and Activity Explorer receive data.

3. **Policies and protection**
   - `dspmPurview/12-Create-DlpPolicy.ps1` builds the DLP policy and rules defined in the spec.
   - `dspmPurview/13-Create-SensitivityLabel.ps1` creates sensitivity labels and publishes them.
   - `dspmPurview/14-Create-RetentionPolicy.ps1` configures retention labels and policies.

4. **Discovery and scans**
   - `dspmPurview/03-Register-DataSource.ps1` registers storage, SQL, OneLake, Fabric, and Foundry resources.
   - `dspmPurview/04-Run-Scan.ps1` triggers scans for each registered source.
   - `dspmPurview/26-Register-OneLake.ps1` and `27-Register-FabricWorkspace.ps1` onboard Fabric resources when present.
   - `dspmPurview/28-Trigger-OneLakeScan.ps1` and `29-Trigger-FabricWorkspaceScan.ps1` kick off catalog scans for Fabric assets.

5. **Audit and evidence**
   - `dspmPurview/19-Ensure-ActivityContentTypes.ps1` and `20-Subscribe-ManagementActivity.ps1` make sure audit subscriptions cover the required content types.
   - `dspmPurview/21-Export-Audit.ps1` exports audit logs to disk; `22-Ship-AuditToStorage.ps1` pushes them to ADLS; `23-Ship-AuditToFabricLakehouse-Stub.ps1` provides the extension point for Fabric analytics.
   - `dspmPurview/17-Export-ComplianceInventory.ps1` snapshots current labels, DLP rules, and retention policies.

6. **Azure policy and tagging**
   - `dspmPurview/05-Assign-AzurePolicies.ps1` applies built-in policies that harden AI services.
   - `dspmPurview/25-Tag-ResourcesFromSpec.ps1` propagates governance tags across Azure resources referenced in the spec.

7. **AI Foundry integration**
   - `dspmPurview/30-Foundry-RegisterResources.ps1` validates and tags Azure AI Foundry resources.
   - `dspmPurview/31-Foundry-ConfigureContentSafety.ps1` pushes Content Safety blocklists from the spec into Key Vault and updates the Foundry project.
   - `dspmPurview/32-Foundry-GenerateBindings-Stub.ps1` and `34-Validate-Posture.ps1` are extension points for app bindings and end-to-end validation.

8. **Optional stubs**
   - `15-Create-SensitiveInfoType-Stub.ps1`, `16-Create-TrainableClassifier-Stub.ps1`, and `24-Create-BudgetAlert-Stub.ps1` outline where to plug in custom detection or FinOps policies.

---

## Script reference

| Script | Purpose | Spec required? | Tags |
|--------|---------|----------------|------|
| `00-New-DspmSpec.ps1` | Scaffold or refresh a parameter-driven spec | No | `ops` |
| `01-Ensure-ResourceGroup.ps1` | Guarantee resource group exists | Yes | `foundation`, `dspm` |
| `dspmPurview/02-Ensure-PurviewAccount.ps1` | Create or update Purview account | Yes | `foundation`, `dspm` |
| `dspmPurview/03-Register-DataSource.ps1` | Register data sources for scanning | Yes | `scans`, `dspm` |
| `dspmPurview/04-Run-Scan.ps1` | Trigger DSPM scans | Yes | `scans`, `dspm` |
| `dspmPurview/05-Assign-AzurePolicies.ps1` | Apply Azure Policies from the spec | Yes | `policies`, `dspm` |
| `dspmPurview/12-Create-DlpPolicy.ps1` | Create DLP policy and rules | Yes | `policies`, `dspm` |
| `dspmPurview/13-Create-SensitivityLabel.ps1` | Create and publish labels | Yes | `policies`, `dspm` |
| `dspmPurview/14-Create-RetentionPolicy.ps1` | Create retention labels and policies | Yes | `policies`, `dspm` |
| `dspmPurview/19-Ensure-ActivityContentTypes.ps1` | Ensure audit content types are subscribed | Yes | `audit`, `dspm` |
| `dspmPurview/20-Subscribe-ManagementActivity.ps1` | Start Management Activity subscriptions | Yes | `audit`, `dspm` |
| `dspmPurview/21-Export-Audit.ps1` | Export audit logs | Yes | `audit`, `ops` |
| `dspmPurview/22-Ship-AuditToStorage.ps1` | Upload audit exports to storage | No | `audit`, `ops` |
| `dspmPurview/25-Tag-ResourcesFromSpec.ps1` | Apply governance tags to Azure resources | Yes | `ops`, `foundry`, `dspm` |
| `dspmPurview/26-Register-OneLake.ps1` | Register OneLake as a data source | Yes | `scans`, `dspm`, `foundry` |
| `dspmPurview/27-Register-FabricWorkspace.ps1` | Register Fabric workspace | Yes | `scans`, `dspm`, `foundry` |
| `dspmPurview/28-Trigger-OneLakeScan.ps1` | Trigger OneLake scan | Yes | `scans`, `dspm`, `foundry` |
| `dspmPurview/29-Trigger-FabricWorkspaceScan.ps1` | Trigger Fabric workspace scan | Yes | `scans`, `dspm`, `foundry` |
| `dspmPurview/30-Foundry-RegisterResources.ps1` | Validate and tag Foundry assets | Yes | `foundry`, `ops` |
| `dspmPurview/31-Foundry-ConfigureContentSafety.ps1` | Configure Content Safety blocklists | Yes | `foundry`, `defender` |
| `dspmPurview/34-Validate-Posture.ps1` | Summarize DSPM posture | Yes | `ops`, `dspm`, `defender` |

---

## Usage patterns

### Manual execution

Run scripts from the repo root to keep relative paths intact.

```powershell
pwsh ./scripts/governance/dspmPurview/03-Register-DataSource.ps1 -SpecPath ./spec.local.json
```

### Orchestrated execution

Use the tag-aware runner to execute multiple modules in order. The example below enables foundational DSPM and audit steps in one go.

```powershell
pwsh ./run.ps1 -Tags foundation,dspm,audit -SpecPath ./spec.local.json
```

### Day-two validation

- `dspmPurview/17-Export-ComplianceInventory.ps1` for quarterly evidence packets.
- `dspmPurview/21-Export-Audit.ps1` and `22-Ship-AuditToStorage.ps1` for incident response handoffs.
- `dspmPurview/34-Validate-Posture.ps1` to confirm audit ingestion, policy status, and Defender telemetry.

---

## Manual follow-up checklist

Some features still require a human in the loop because Microsoft has not released public APIs.

- Review Purview portal recommendations for Communication Compliance and Insider Risk policies and create them manually if the scripts flagged them as stubs.
- Enable Microsoft Defender for AI portal toggles that remain preview-only (for example, "Enable data security for AI interactions").
- Monitor Purview Activity Explorer and Fabric governance dashboards 24 to 48 hours after scans to verify telemetry is landing.

Document completion of these tasks alongside the generated spec so auditors understand which steps were automated versus manual.

---

## Supportability tips

- Keep environment-specific values in the spec; avoid parameter duplication inside scripts.
- Re-run modules at any time—each script checks for existing resources before making changes.
- Extend the stub scripts in a separate folder if you need organization-specific detection, then call them from `run.ps1` using new tags.

This DSPM guide, combined with the Defender playbook, provides the governance half of the AI security story surfaced in the repository root README.
