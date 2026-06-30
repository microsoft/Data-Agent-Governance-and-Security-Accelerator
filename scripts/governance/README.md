# Governance Script Reference

This folder contains the orchestration entry scripts for Purview DSPM governance and links to the detailed `dspmPurview` modules executed by `run.ps1`.

## Top-level governance scripts

| Script | Purpose |
| --- | --- |
| `00-New-DspmSpec.ps1` | Scaffolds a starter spec file. |
| `01-Ensure-ResourceGroup.ps1` | Ensures the target resource group exists. |

## Purview DSPM modules (`dspmPurview`)

Note: Script numbers `08` and `09` are intentionally unused to reserve space for future steps.

| Script | Purpose |
| --- | --- |
| `02-Ensure-PurviewAccount.ps1` | Validates/ensures Purview account availability. |
| `03-Register-DataSource.ps1` | Registers Purview data sources from spec. |
| `04-Run-Scan.ps1` | Creates/runs Purview scans from spec. |
| `05-Assign-AzurePolicies.ps1` | Applies Azure Policy assignments from spec. |
| `12-Create-DlpPolicy.ps1` | Creates M365 DLP policy rules. |
| `13-Create-SensitivityLabel.ps1` | Creates/publishes M365 sensitivity labels. |
| `14-Create-RetentionPolicy.ps1` | Creates retention policies/rules. |
| `17-Export-ComplianceInventory.ps1` | Exports compliance inventory snapshot. |
| `20-Subscribe-ManagementActivity.ps1` | Subscribes to activity content feeds. |
| `21-Export-Audit.ps1` | Exports audit data from configured feeds. |
| `22-Ship-AuditToStorage.ps1` | Ships exported audit to storage target. |
| `25-Tag-ResourcesFromSpec.ps1` | Applies tags to resources listed in spec. |
| `26-Ensure-FabricWorkspaceSensitivity.ps1` | Resolves/validates Fabric lakehouse sensitivity labels. |
| `26-Apply-FabricLakehouseSensitivity.ps1` | Applies Fabric lakehouse sensitivity labels. |
| `27-Register-FabricWorkspace.ps1` | Registers Fabric workspace datasource in Purview. |
| `28-Ensure-PurviewCollectionsForFabricWorkspaces.ps1` | Ensures workspace-level Purview collections. |
| `29-Trigger-FabricWorkspaceScan.ps1` | Creates/runs Fabric workspace scans. |
| `30-Foundry-RegisterResources.ps1` | Registers Foundry resources in governance flow. |
| `31-Foundry-ConfigureContentSafety.ps1` | Configures Content Safety settings/blocklists. |

## Related docs

- `../../docs/spec-local-reference.md`
- `../../docs/AlternativeDeploymentPaths.md`
- `../../README.md`
