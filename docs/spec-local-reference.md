# spec.local.json reference

This guide documents every field that appears in the working `spec.local.json` **and** the sanitized `spec.dspm.template.json`. Use it to understand what each parameter drives inside `run.ps1` and the downstream scripts.

---

## Quick Start

**New to the spec file?** Start with the annotated example:

**[spec-example.json](./spec-example.json)** — A complete example with realistic (fictional) values and inline comments explaining each section.

The example mirrors the current production `spec.local.json` schema and includes Fabric lakehouse sensitivity-label examples (`Public`, `Personal`, and parent/child format like `Confidential\\All Employees`).

**To create your spec file:**
```powershell
# Option 1: Copy from the example (recommended for learning)
Copy-Item ./docs/spec-example.json ./spec.local.json

# Option 2: Copy from the template (minimal starting point)
Copy-Item ./spec.dspm.template.json ./spec.local.json
```
```bash
# Bash command
cp ./spec.dspm.template.json ./spec.local.json
```

Then edit `spec.local.json` with your actual Azure resource IDs and configuration.

---

## Example spec.local.json (synthetic)

This example mirrors the most recently tested spec file content but uses **synthetic** tenant IDs, subscription IDs, resource names, and workspace GUIDs. Replace all values with those from your tenant.

```json
{
	"tenantId": "11111111-2222-3333-4444-555555555555",
	"subscriptionId": "aaaaaaaa-bbbb-cccc-dddd-eeeeeeeeeeee",
	"resourceGroup": "rg-governance-sample",
	"location": "eastus2",
	"purviewAccount": "contoso-purview",
	"purviewResourceGroup": "rg-governance-sample",
	"purviewSubscriptionId": "bbbbbbbb-cccc-dddd-eeee-ffffffffffff",
	"aiResourceGroup": "rg-ai-sample",
	"aiSubscriptionId": "aaaaaaaa-bbbb-cccc-dddd-eeeeeeeeeeee",
	"aiFoundry": {
		"name": "project-sample-a",
		"resourceId": "/subscriptions/aaaaaaaa-bbbb-cccc-dddd-eeeeeeeeeeee/resourceGroups/rg-ai-sample/providers/Microsoft.CognitiveServices/accounts/ai-sample-a/projects/project-sample-a"
	},
	"foundry": {
		"resources": [
			{
				"name": "project-sample-a",
				"resourceId": "/subscriptions/aaaaaaaa-bbbb-cccc-dddd-eeeeeeeeeeee/resourceGroups/rg-ai-sample/providers/Microsoft.CognitiveServices/accounts/ai-sample-a",
				"diagnostics": true,
				"tags": {
					"Environment": "Dev",
					"Owner": "DataGov",
					"CostCenter": "sample-a"
				}
			},
			{
				"name": "project-sample-b",
				"resourceId": "/subscriptions/aaaaaaaa-bbbb-cccc-dddd-eeeeeeeeeeee/resourceGroups/rg-ai-sample/providers/Microsoft.CognitiveServices/accounts/ai-sample-b/projects/project-sample-b",
				"diagnostics": true,
				"tags": {
					"Environment": "Dev",
					"Owner": "DataGov",
					"CostCenter": "sample-b"
				}
			}
		],
		"contentSafety": {
			"endpoint": "",
			"apiKeySecretRef": {
				"keyVaultResourceId": "",
				"secretName": ""
			},
			"textBlocklists": [],
			"harmSeverityThreshold": null
		}
	},
	"fabric": {
		"scanAutomationMode": "runOnly",
		"workspaces": [
			{
				"name": "workspace-sample-a",
				"workspaceId": "",
				"workspaceUrl": "https://app.powerbi.com/groups/11111111-aaaa-bbbb-cccc-222222222222",
				"scanName": "scan-[name]",
				"lakehouses": [
					{
						"name": "bronze",
						"sensitivityLabel": "Personal"
					},
					{
						"name": "silver",
						"sensitivityLabel": "Confidential\\All Employees"
					}
				]
			},
			{
				"name": "workspace-sample-b",
				"workspaceId": "33333333-4444-5555-6666-777777777777",
				"workspaceUrl": "https://app.powerbi.com/groups/33333333-4444-5555-6666-777777777777",
				"scanName": "scan-[name]",
				"lakehouses": [
					{
						"name": "bronze",
						"sensitivityLabel": "Public"
					},
					{
						"name": "silver",
						"sensitivityLabel": "Public"
					},
					{
						"name": "gold",
						"sensitivityLabel": "Public"
					}
				]
			}
		]
	},
	"logAnalyticsWorkspaceId": "88888888-9999-aaaa-bbbb-cccccccccccc",
	"dataSources": [],
	"scans": [],
	"dlpPolicy": {
		"name": "AI Egress Control",
		"mode": "Enforce",
		"locations": {
			"Exchange": "All",
			"SharePoint": "All",
			"OneDrive": "All"
		},
		"rules": [
			{
				"name": "Block Sensitive Data to AI Destinations",
				"sensitiveInfoTypes": [
					{
						"name": "Credit Card Number",
						"count": 1,
						"confidence": 85
					},
					{
						"name": "U.S. Social Security Number (SSN)",
						"count": 1,
						"confidence": 85
					}
				],
				"blockAccess": true,
				"notifyUser": true
			}
		]
	},
	"labels": [
		{
			"name": "SemiConfidential",
			"publishPolicyName": "Publish: Confidential",
			"encryptionEnabled": false,
			"publishScopes": {
				"Exchange": "All",
				"SharePoint": "All",
				"OneDrive": "All"
			}
		}
	],
	"retentionPolicies": [],
	"activityExport": null,
	"defenderForAI": {
		"enableDefenderForCloudPlans": [
			"CognitiveServices",
			"Storage",
			"Containers"
		],
		"logAnalyticsWorkspaceId": "88888888-9999-aaaa-bbbb-cccccccccccc",
		"diagnosticCategories": [
			"Audit",
			"RequestResponse",
			"AllMetrics"
		]
	}
}
```

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

## Microsoft Foundry inputs

| Path | Type | Description | Consumed by |
| ---- | ---- | ----------- | ----------- |
| `aiResourceGroup` | string | Resource group that hosts Microsoft Foundry, Cognitive Services, and related assets. | Defender + Foundry scripts |
| `aiSubscriptionId` | string | Subscription that owns those AI resources. | Defender + Foundry scripts |
| `aiFoundry.name` | string | Canonical Microsoft Foundry project name that anchors registration flows. Used when a single “primary” project needs to be referenced. | `30-Foundry-RegisterResources.ps1`, docs |
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

## Fabric workspace inputs

| Path | Type | Description | Consumed by |
| ---- | ---- | ----------- | ----------- |
| `fabric.scanAutomationMode` | string | Controls scan-definition automation behavior for Fabric workspaces. Supported values: `full` (create or update the scan definition, then run it), `runOnly` (preserve the existing Purview scan definition and only trigger it), `disabled` (skip the Fabric scan trigger step entirely). Use `runOnly` when scoped scans are managed in the Purview portal and you do not want automation to overwrite them. If an unknown value is supplied, the scripts warn and fall back to `full`. | `27-Register-FabricWorkspace.ps1`, `29-Trigger-FabricWorkspaceScan.ps1` |
| `fabric.workspaces[]` | array | Fabric workspaces whose assets (lakehouses, warehouses, etc.) should be crawled. This flow is workspace-scoped and does not register OneLake roots. | `26-Ensure-FabricWorkspaceSensitivity.ps1`, `26-Apply-FabricLakehouseSensitivity.ps1`, `27-Register-FabricWorkspace.ps1`, `29-Trigger-FabricWorkspaceScan.ps1` |
| `fabric.workspaces[].name` | string | Fabric workspace name. This is sufficient in most cases; the script attempts to resolve workspace GUID by name automatically. | `27-Register-FabricWorkspace.ps1` |
| `fabric.workspaces[].resourceId` | string | Optional identifier used only as an additional input for workspace GUID resolution. It is not sent directly in the Purview datasource registration payload. This value can be an ARM-style resource ID or a Fabric workspace URL (`https://app.powerbi.com/groups/<workspaceGuid>`). | `27-Register-FabricWorkspace.ps1` |
| `fabric.workspaces[].workspaceUrl` | string | Optional explicit Fabric workspace URL (`https://app.powerbi.com/groups/<workspaceGuid>`). Use this if name-based resolution is ambiguous or blocked by API permissions. | `27-Register-FabricWorkspace.ps1` |
| `fabric.workspaces[].workspaceId` | string | Optional workspace GUID fallback. Use this if multiple workspaces share the same name or when API lookup is unavailable. | `27-Register-FabricWorkspace.ps1`, `29-Trigger-FabricWorkspaceScan.ps1` |
| `fabric.workspaces[].scanName` | string | Purview scan definition name to associate with that workspace. | `29-Trigger-FabricWorkspaceScan.ps1` |
| `fabric.workspaces[].lakehouses[]` | array | Lakehouse-level sensitivity targets for validation and application. | `26-Ensure-FabricWorkspaceSensitivity.ps1`, `26-Apply-FabricLakehouseSensitivity.ps1` |
| `fabric.workspaces[].lakehouses[].name` | string | Lakehouse item name in the Fabric workspace. | `26-Ensure-FabricWorkspaceSensitivity.ps1`, `26-Apply-FabricLakehouseSensitivity.ps1` |
| `fabric.workspaces[].lakehouses[].sensitivityLabel` | string | Desired sensitivity label on that lakehouse item. Use display names (for example `Public`) or parent/child display paths (for example `Confidential\All Employees`). The pre-step resolves these values to internal label identities, validates existence, and emits a target map for the apply step. | `26-Ensure-FabricWorkspaceSensitivity.ps1`, `26-Apply-FabricLakehouseSensitivity.ps1` |

> **Execution order:** Label validation runs first, then label apply, then workspace registration, then workspace scan trigger. This preserves a workspace-only Purview map and avoids tenant-wide OneLake scanning.

> **Label format tip:** In JSON, represent parent/child labels with escaped backslashes (for example `"Confidential\\All Employees"`).
**Label name matching:** The `sensitivityLabel` value must match the **exact display name** shown in the Microsoft Purview compliance portal under Information protection → Labels (e.g., `General` not `General usage`). Run `Get-Label | Select-Object DisplayName` in a connected Exchange Online session to list available names. Unresolved labels are flagged at runtime and skipped during the apply step.

> **Fabric label prerequisites:** The accelerator does not turn on Fabric sensitivity-labeling features at the tenant level. It expects your environment to already support Fabric sensitivity labels, the operator to have permission to call the Fabric admin labeling API, and the referenced Purview sensitivity labels to already exist and be discoverable through Exchange Online / Security & Compliance PowerShell (`Get-Label`). If those prerequisites are missing, the validation/apply steps fail or skip; they do not enable the feature for you.

> **`runOnly` prerequisite:** `runOnly` assumes the named Purview Fabric scan already exists. If it does not, create it once in the Purview portal or switch temporarily to `full` so automation can create it.

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
