# AI Governance & Security FAQ

## When should this automation run relative to Copilot, Microsoft Foundry, or ChatGPT Enterprise onboarding?
Run it on **Day 0**, before end-user AI workloads are deployed. Stage the scripts so Purview DSPM for AI and unified audit are enabled first, then follow immediately with Defender for AI and Foundry tagging. That guarantees telemetry and governance data flow as soon as AI apps launch.

## How can I run the scripts in stages?
Use `run.ps1 -Tags foundation,dspm` for the Purview/audit/policy modules, then `run.ps1 -Tags defender,foundry` for Defender plans and Foundry integrations. Each underlying PowerShell script is idempotent and can also be invoked individually for even finer control.

## Which steps remain manual?
Several portal toggles cannot be automated via API today and must be enabled manually:

**In Defender for Cloud** (Azure portal → Defender for Cloud → Environment settings → [subscription] → AI services → Settings):
- **Enable user prompt evidence** — Includes suspicious prompt segments in Defender alerts
- **Enable data security for AI interactions** — Connects Azure AI telemetry to Microsoft Purview for DSPM for AI

**In Microsoft Purview** (Purview portal → DSPM for AI):
- **Activate Microsoft Purview Audit** — Required for audit log ingestion (DSPM for AI → Overview → Get Started)
- **Secure interactions from enterprise apps** — The KYD collection policy for enterprise AI apps (DSPM for AI → Recommendations)

After the scripts run, you must enable these toggles **in the portal**, then rerun the verification script (`34-Validate-Posture.ps1`) to confirm the state.

## Can I test the Defender scripts by toggling settings off and rerunning them?
Yes—but rerunning the PowerShell will only detect that the portal toggle is off and remind you to re-enable it. It cannot flip the switch back on; do that manually in Defender for Cloud and re-run the validation script for confirmation.

## Do the scripts create DLP policies automatically?
Yes. `scripts/governance/dspmPurview/12-Create-DlpPolicy.ps1` uses Exchange Online PowerShell (similar to `New-DlpComplianceRule`) and only requires Purview Audit to be enabled plus Compliance Administrator-level permissions.

## Why does Unified Audit still show disabled even after the scripts run?
- `11-Enable-UnifiedAudit.ps1` calls `Set-AdminAuditLogConfig -UnifiedAuditLogIngestionEnabled $true`, but Exchange ignores the change unless the operator holds a high-privilege role such as **Compliance Administrator**, **Organization Management**, or **Audit Admin**.
- When the cmdlet lacks permissions, it returns "The command completed successfully but no settings have been modified." That’s your cue to rerun the m365 tag with an appropriately privileged account or flip the toggle manually in the Purview/Microsoft 365 Compliance portal.
- Managed identities/UAMIs cannot satisfy these M365 roles today, so keep using an interactive account (or certificate-based auth) that meets the compliance requirements.

## What does enabling Unified Audit actually do, and when is it needed?
- Unified audit logging turns on the Microsoft 365-wide pipeline that aggregates events from Exchange Online, SharePoint/OneDrive, Teams, Entra ID, Power BI, etc., into the central Purview audit log.
- Without it, M365 workloads either don't emit audit events at all or keep them locked in per-service logs, so M365 Copilot governance features (DLP, Insider Risk, eDiscovery, Communication Compliance) have nothing to reference.
- Once enabled, the Purview compliance portal (**https://compliance.microsoft.com** → **Audit**) can search across all M365 workloads with one query, and downstream APIs (Management Activity, Office 365 Management API, Purview Audit (Premium), scripts `21-Export-Audit.ps1` / `22-Ship-AuditToStorage.ps1`) can stream those events to SIEMs, storage, or Fabric Lakehouse.
- It's needed for M365 Copilot governance: the `m365` tag publishes DLP/labels/retention for M365 Copilot prompt/response capture.
- **Note:** Microsoft Foundry prompts do NOT flow through Unified Audit. Foundry telemetry is captured via Azure diagnostics and Defender for AI instead.

## Why are there two `logAnalyticsWorkspaceId` fields in the spec?
- The top-level `logAnalyticsWorkspaceId` (near the subscription/resourceGroup fields) is the “general purpose” workspace. Purview scans, tagging diagnostics, and other scripts wire telemetry here if they need a workspace and you don’t override it elsewhere.
- `defenderForAI.logAnalyticsWorkspaceId` lives under the `defenderForAI` block because the Defender diagnostics script (`07-Enable-Diagnostics.ps1`) can push logs to a different workspace than the rest of the automation. Leave it blank to fall back to the top-level ID, or supply a dedicated Defender workspace if your security team requires isolation.
- Both fields exist so you can either reuse a single workspace or split Defender telemetry from the broader operations log stream without editing the scripts.

## Why does the spec have both `aiFoundry` and `foundry.resources` (and two Content Safety blocks)?
- `aiFoundry` is the single “anchor” Microsoft Foundry project that scripts such as `30-Foundry-RegisterResources.ps1` expect. It provides one canonical project name/resourceId even if you only manage a single workspace.
- `foundry.resources` is an array so you can tag/monitor multiple Cognitive Services or Microsoft Foundry workloads. Each entry feeds `25-Tag-ResourcesFromSpec.ps1`, `31-Foundry-ConfigureContentSafety.ps1`, and similar automation. If you only have one project, you’ll see the same resource repeated just so the array isn’t empty.
- `foundry.contentSafety` contains the Content Safety configuration that should be applied to those Foundry-linked resources (endpoint, Key Vault secret, blocklists, severity threshold).
- The top-level `contentSafety` section is for standalone Content Safety deployments outside Foundry—for example, when you attach Content Safety to Azure OpenAI directly. Different scripts reference each block, so both remain even if some fields are empty.

## Why do I need to add every Foundry project to the spec if Purview already shows it?
- Purview discovers Microsoft Foundry accounts on its own once Defender for Cloud plans are enabled, so new workspaces appear in the DSPM blades even if you never rerun the automation.
- The scripts only touch resources listed in `spec.local.json` (`foundry.resources[]` plus the anchor `aiFoundry`). If a workspace is missing there, rerunning `run.ps1` will skip it entirely.
- Adding the resource name/ID unlocks the downstream automation:
	- `25-Tag-ResourcesFromSpec.ps1` applies the governance tags defined in the spec.
	- `30-Foundry-RegisterResources.ps1` registers the project so DSPM recommendations stay in sync with the rest of your estate.
	- `31-Foundry-ConfigureContentSafety.ps1` pushes the configured blocklists, allow lists, and severity threshold.
	- `07-Enable-Diagnostics.ps1` only enables diagnostics on the resource IDs it knows, so omitting the workspace means no Defender log stream.
- Bottom line: Purview can display any discovered Foundry account, but listing it in the spec is what ties it into tagging, Content Safety configuration, diagnostics routing, and subsequent posture validation when you rerun the accelerator.

## Do I need Azure diagnostics for Foundry?
- Yes—Azure diagnostics capture logs from Foundry/OpenAI resources (API calls, request/response payload metadata, Content Safety enforcement) and send them to Log Analytics.
- `07-Enable-Diagnostics.ps1` enables Diagnostic Settings on each Foundry/Cognitive Services resource listed in the spec and ships them to the specified Log Analytics workspace. Those logs power Defender for AI detections and give you platform-level visibility.
- Note: Unified Audit is a separate M365 control for Teams, SharePoint, Exchange, and M365 Copilot. Microsoft Foundry prompts do NOT flow through Unified Audit—they are captured via Azure diagnostics and Defender for AI instead.

## How does Purview DSPM use the Foundry diagnostics stream?
- `30-Foundry-RegisterResources.ps1` links every listed Microsoft Foundry workspace/project to its diagnostic stream so Purview knows which resource emitted which prompts and posture signals.
- `07-Enable-Diagnostics.ps1` pushes Foundry logs and metrics into Log Analytics; Defender for AI ingests those signals for threat detection (prompt injection, jailbreaks, data exfiltration).
- With telemetry flowing, DSPM can correlate Foundry resources with sensitivity labels and raise alerts when prompts touch sensitive data or a workspace drifts from the prescribed guardrails.
- The same telemetry flows into DSPM dashboards so auditors can prove prompts/responses were monitored via Defender for AI.

## Why does a deleted Foundry account or project still show up in DSPM for AI?
- Microsoft Purview DSPM for AI retains historical telemetry and risk assessments so compliance teams can investigate past activity. Removing the Microsoft Foundry account/project (or deleting the subscription) stops **future** data collection, but previously captured evidence stays in the DSPM dashboard until retention policies purge it.
- There is no automatic cleanup tied to account deletion because DSPM is designed for audit scenarios—erasing the record would break investigations and regulatory traceability.
- If a name must be removed immediately, use the Purview compliance portal to adjust or purge retention: review **Data lifecycle management** policies, Communication Compliance/Insider Risk retention, or purge content under **Audit (Premium)** exports. This is a manual action; the accelerator does not issue deletions.
- As a best practice, confirm what still appears via **Data Risk Assessment** reports and review the retention policies assigned to those workloads so stakeholders know when the historical entries will naturally expire.

## Why doesn’t `30-Foundry-RegisterResources.ps1` touch Azure OpenAI accounts?

Confirming what’s happening: the only part of the accelerator that “registers a project” in Purview today is `30-Foundry-RegisterResources.ps1`, and that script only knows how to work with Microsoft Foundry projects (`…/accounts/<foundry>/projects/<project>` resource IDs). When you append an Azure OpenAI account (for example `/accounts/oai-cwydhg7zp`) to `foundry.resources[]`, the run still loops through the array, but this module deliberately ignores non-Foundry items because Purview already discovers plain Azure OpenAI accounts automatically. The end result matches what you see in the portal: the manual **Secure interactions for enterprise AI apps** toggle only surfaces for Foundry projects. As of today’s change, the script prints “Skipping non-Foundry resource” whenever it encounters an entry without the `/projects/` segment so the run log makes that behavior explicit.

## Can I run everything from azd, GitHub Actions, or another automation platform?
- **azd hooks / GitHub Actions / Azure Automation** work for Azure resource tasks (Purview account, Defender plans, policies). Use a service principal with `Contributor` or `Security Admin` rights.
- **Exchange Online & Compliance Center** tasks (audit enablement, DLP creation) still require interactive or certificate-based authentication tied to a high-privilege M365 role. They usually run from a workstation or secure automation account capable of satisfying MFA.

## What do I need to do before running `run.ps1` in a fresh shell or container?
1. **Install the Az PowerShell modules** (once per environment):
	```powershell
	Install-Module Az -Scope CurrentUser -Repository PSGallery -Force -AllowClobber
	```
2. **Authenticate to Azure** before invoking the orchestrator. Use a standard interactive login from a workstation with a browser:
	```powershell
	Connect-AzAccount -Tenant '<tenant-guid>' -Subscription '<subscription-guid>'
	```
	If you need headless or automated execution, use a service principal or managed identity rather than device-code auth:
	```powershell
	Connect-AzAccount -ServicePrincipal -Tenant '<tenant-guid>' -ApplicationId '<appId>' -Credential (Get-Credential)
	```
	Store credentials securely (Key Vault, automation account variables) and avoid device-code flows because they are disabled in this accelerator.
3. **Run the orchestrator** from the repo root once the session is authenticated:
	```powershell
	./run.ps1 -Tags dspm defender -SpecPath ./spec.local.json   # from bash/zsh use: pwsh ./run.ps1 -Tags ...
	```
## How will Azure Based data get labeled and honored by DSPM?

1. DSPM doesn’t reach into Azure storage to stamp labels directly; it honors whatever classification signals Purview already has for those resources. Scans (Purview Data Map, Fabric/Purview ingestion, Defender for Cloud policy evaluations) tag tables, files, and data stores with sensitivity info.
1. When you run the accelerator, scripts 02-Ensure-PurviewAccount.ps1, 03-Register-DataSource.ps1, and the scan modules onboard the Azure resources into Purview, so classification scans and rules apply the same labels you use elsewhere (e.g., “Confidential”).
1. Those labels feed DSPM’s policy engine. When Diagnostics + Foundry registration report that a prompt accessed /subscriptions/.../storageAccounts/foo, DSPM cross-references the existing Purview classification metadata. If the storage account, container, or table is marked Confidential, DSPM issues a “Sensitive data touched” alert.
1. Enforcement happens by tying those DSPM signals back into your policies: DLP (script 12), retention/labels (scripts 13–14), and Defender for Cloud guardrails. Purview doesn’t rewrite the data, but because it tracks lineage between Azure resources and labeled datasets, the DSPM dashboards can show when Foundry/AI traffic interacts with sensitive stores and ensure your policies respond.
