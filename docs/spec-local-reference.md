# spec.local.json reference

This guide documents every field that appears in the working `spec.local.json` **and** the sanitized `spec.dspm.template.json`. Use it to understand what each parameter drives inside `run.ps1` and the downstream scripts.

---

## Quick Start

**New to the spec file?** Start with the annotated example:

**[spec-example.json](./spec-example.json)** — A complete example with realistic (fictional) values and inline comments explaining each section.

**To create your spec file:**
```powershell
# Option 1: Copy from the example (recommended for learning)
Copy-Item ./docs/spec-example.json ./spec.local.json

# Option 2: Copy from the template (minimal starting point)
Copy-Item ./spec.dspm.template.json ./spec.local.json
```

Then edit `spec.local.json` with your actual Azure resource IDs and configuration.

---

## Core environment

| Path | Type | Description | Consumed by |
| ---- | ---- | ----------- | ----------- |
| `tenantId` | string | Entra ID tenant the automation authenticates against. | `Ensure-AzContext.ps1`, all Az scripts |
| `subscriptionId` | string | Default Azure subscription for Purview/DSPM resources. | `run.ps1`, Purview governance scripts |
| `resourceGroup` | string | Landing RG for Purview helpers (policies, tags). | `01-Ensure-ResourceGroup.ps1` |
| `location` | string | Azure region used when RGs or policies need a geography. | `01-Ensure-ResourceGroup.ps1` |
| `purviewAccount` | string | Name of the Microsoft Purview account to manage. | `02-Ensure-PurviewAccount.ps1`, scan scripts |
| `purviewResourceGroup` | string | RG containing the Purview account. | Purview scripts |
| `purviewSubscriptionId` | string | Subscription hosting Purview (can differ from `subscriptionId`). | Purview scripts |

## Azure AI / Foundry inputs

| Path | Type | Description | Consumed by |
| ---- | ---- | ----------- | ----------- |
| `aiResourceGroup` | string | Resource group that hosts Azure AI Foundry, Cognitive Services, and related assets. | Defender + Foundry scripts |
| `aiSubscriptionId` | string | Subscription that owns those AI resources. | Defender + Foundry scripts |
| `aiFoundry.name` | string | Canonical Azure AI Foundry project name that anchors registration flows. Used when a single “primary” project needs to be referenced. | `30-Foundry-RegisterResources.ps1`, docs |
| `aiFoundry.resourceId` | string | Full resource ID for that anchor project. Provides deterministic IDs for registration and recommendation linking. | `30-Foundry-RegisterResources.ps1`, `31-Foundry-ConfigureContentSafety.ps1` |
| `foundry.resources[]` | array of objects | Each object describes a Foundry project or Cognitive Services account the automation should manage. Add additional entries for every workspace you want tagged/monitored. | `25-Tag-ResourcesFromSpec.ps1`, `30-Foundry-RegisterResources.ps1`, `31-Foundry-ConfigureContentSafety.ps1`, `07-Enable-Diagnostics.ps1` |
| `foundry.resources[].name` | string | Friendly name for status messages. | Logging | 
| `foundry.resources[].resourceId` | string | Resource ID that diagnostics, tagging, and content safety scripts target. | Foundry + Defender scripts |
| `foundry.resources[].diagnostics` | bool | Flag indicating whether diagnostics should be turned on for this resource. | `07-Enable-Diagnostics.ps1` |
| `foundry.resources[].tags` | object | Arbitrary key/value tag pairs to stamp on the resource. | `25-Tag-ResourcesFromSpec.ps1` |
| `foundry.contentSafety.endpoint` | string | Optional Content Safety endpoint to apply across Foundry projects. Leave blank to skip Content Safety steps. | `31-Foundry-ConfigureContentSafety.ps1` |
| `foundry.contentSafety.apiKeySecretRef.*` | object | Points to a Key Vault secret with the Content Safety API key (resource ID + secret name). If omitted, the script requests an Entra token instead. | `31-Foundry-ConfigureContentSafety.ps1` |
| `foundry.contentSafety.textBlocklists` | array | Blocklist definitions to push into Content Safety. | `31-Foundry-ConfigureContentSafety.ps1` |
| `foundry.contentSafety.harmSeverityThreshold` | number/null | Overrides the default severity threshold when Content Safety evaluates prompts/responses. | `31-Foundry-ConfigureContentSafety.ps1` |

> **Why both `aiFoundry` and `foundry.resources`?** Purview automatically discovers Foundry accounts, but the automation only touches resources explicitly listed here. `aiFoundry` gives scripts one deterministic “primary” project to reference, while `foundry.resources[]` lets you manage any number of projects (tagging, diagnostics, Content Safety) in parallel.

## Fabric / OneLake preview inputs

| Path | Type | Description | Consumed by |
| ---- | ---- | ----------- | ----------- |
| `fabric.oneLakeRoots[]` | array | List of OneLake roots that should be registered with Purview DSPM for AI. Keep entries even while scripts 26–29 stay commented so values are ready when you enable the scans. | `26-Register-OneLake.ps1`, `28-Trigger-OneLakeScan.ps1` |
| `fabric.oneLakeRoots[].name` | string | Friendly name that becomes the Purview data-source ID. | `26-Register-OneLake.ps1` |
| `fabric.oneLakeRoots[].resourceId` | string | Fabric ARM resource ID for the root (for example `/providers/Microsoft.Fabric/oneLakeWorkspaces/...`). | `26-Register-OneLake.ps1` |
| `fabric.oneLakeRoots[].scanName` | string | Name of the Purview scan definition to create/execute against that root. | `28-Trigger-OneLakeScan.ps1` |
| `fabric.workspaces[]` | array | Fabric workspaces whose assets (lakehouses, warehouses, etc.) should be crawled. | `27-Register-FabricWorkspace.ps1`, `29-Trigger-FabricWorkspaceScan.ps1` |
| `fabric.workspaces[].name` | string | Name/identifier used when registering the Fabric workspace in Purview. | `27-Register-FabricWorkspace.ps1` |
| `fabric.workspaces[].resourceId` | string | `/providers/Microsoft.Fabric/workspaces/...` resource ID for the workspace. | `27-Register-FabricWorkspace.ps1` |
| `fabric.workspaces[].scanName` | string | Purview scan definition name to associate with that workspace. | `29-Trigger-FabricWorkspaceScan.ps1` |

> **Status:** The Fabric scripts are commented out in `run.ps1` until they gracefully handle empty arrays. Populate these fields now so you can unlock Fabric scans simply by uncommenting the steps when ready.

## Global Content Safety configuration

| Path | Type | Description | Consumed by |
| ---- | ---- | ----------- | ----------- |
| `contentSafety.endpoint` | string | Optional tenant-wide Content Safety endpoint (outside the Foundry-only block) for scenarios that reuse a central Content Safety resource. | Future Content Safety extensions |
| `contentSafety.keyVault.*` | object | Key Vault reference (vault name, resource ID, secret) storing the API key if you prefer key auth instead of Entra tokens. | Future Content Safety extensions |

## Logging & telemetry

| Path | Type | Description | Consumed by |
| ---- | ---- | ----------- | ----------- |
| `logAnalyticsWorkspaceId` | string | Default Log Analytics workspace (resource ID or GUID) used by diagnostics/config steps when no per-feature override exists. | `07-Enable-Diagnostics.ps1`, Purview scripts |

## Data source onboarding

| Path | Type | Description | Consumed by |
| ---- | ---- | ----------- | ----------- |
| `dataSources[]` | array | (Empty today) Each entry would describe a data source Purview should register (e.g., Storage account). | `03-Register-DataSource.ps1` |
| `scans[]` | array | (Empty today) Each entry instructs Purview scanning scripts which collections to crawl. | `04-Run-Scan.ps1` |

## Microsoft 365 controls

| Path | Type | Description | Consumed by |
| ---- | ---- | ----------- | ----------- |
| `dlpPolicy.*` | object | Defines the single DLP policy created by `12-Create-DlpPolicy.ps1`. Includes rule definitions, workloads, and sensitive info selections. | `12-Create-DlpPolicy.ps1` |
| `labels[]` | array | Sensitivity label definitions to create/publish (name, publish policy, encryption, scopes). | `13-Create-SensitivityLabel.ps1` |
| `retentionPolicies[]` | array | Retention policies (name, rules, locations) that the automation publishes to keep AI interactions for the desired duration. | `14-Create-RetentionPolicy.ps1` |
| `retentionPolicies[].rules[]` | array | Rule objects controlling duration and action (Keep/Delete). | `14-Create-RetentionPolicy.ps1` |

## Evidence export and activity feeds

| Path | Type | Description | Consumed by |
| ---- | ---- | ----------- | ----------- |
| `activityExport.outputPath` | string | Filesystem destination for audit exports and Management Activity payloads. | `21-Export-Audit.ps1`, `22-Ship-AuditToStorage.ps1` |
| `activityExport.contentTypes[]` | array | Management Activity content types to subscribe to and export. | `20-Subscribe-ManagementActivity.ps1`, `21-Export-Audit.ps1` |

## Defender for AI settings

| Path | Type | Description | Consumed by |
| ---- | ---- | ----------- | ----------- |
| `defenderForAI.enableDefenderForCloudPlans[]` | array | Defender plan names to enable (e.g., `CognitiveServices`, `Storage`). | `06-Enable-DefenderPlans.ps1` |
| `defenderForAI.logAnalyticsWorkspaceId` | string | Workspace dedicated to Defender diagnostics. Falls back to the top-level ID if omitted. | `07-Enable-Diagnostics.ps1` |
| `defenderForAI.diagnosticCategories[]` | array | Diagnostic categories (logs/metrics) to enable per resource. | `07-Enable-Diagnostics.ps1` |

## Azure policy orchestration

| Path | Type | Description | Consumed by |
| ---- | ---- | ----------- | ----------- |
| `azurePolicies[]` | array | Declarative list of policy assignments to enforce (scope, definition name, parameters, enabled flag). | `05-Assign-AzurePolicies.ps1` |
| `azurePolicies[].enabled` | bool | Flip to `false` to leave an entry documented but skipped during assignment. | `05-Assign-AzurePolicies.ps1` |

---
Need another field explained? Add it to `spec.local.json` and append a new row so this document stays the source of truth.
