# AI Governance & Security FAQ

## When should this automation run relative to Copilot, Azure AI Foundry, or ChatGPT Enterprise onboarding?
Run it on **Day 0**, before end-user AI workloads are deployed. Stage the scripts so Purview DSPM for AI and unified audit are enabled first, then follow immediately with Defender for AI and Foundry tagging. That guarantees telemetry and governance data flow as soon as AI apps launch.

## Why does Purview DSPM for AI need to live on the same subscription as Defender for AI?
The Defender toggle **Enable data security for AI interactions** only streams prompt evidence to the Purview account that sits in the same subscription. If they differ, Purview’s DSPM dashboards never receive the Foundry telemetry.

## How can I run the scripts in stages?
Use `run.ps1 -Tags foundation,dspm` for the Purview/audit/policy modules, then `run.ps1 -Tags defender,foundry` for Defender plans and Foundry integrations. Each underlying PowerShell script is idempotent and can also be invoked individually for even finer control.

## Which steps remain manual?
Microsoft has not published APIs for the Defender portal toggles ("Enable data security for AI interactions" and "Enable suspicious prompt evidence"). After the scripts run, you must flip those switches **in the portal**, then rerun the verification script to confirm the state.

## Can I test the Defender scripts by toggling settings off and rerunning them?
Yes—but rerunning the PowerShell will only detect that the portal toggle is off and remind you to re-enable it. It cannot flip the switch back on; do that manually in Defender for Cloud and re-run the validation script for confirmation.

## Do the scripts create DLP policies automatically?
Yes. `scripts/governance/dspmPurview/12-Create-DlpPolicy.ps1` uses Exchange Online PowerShell (similar to `New-DlpComplianceRule`) and only requires Purview Audit to be enabled plus Compliance Administrator-level permissions.

## Why does Unified Audit still show disabled even after the scripts run?
- `11-Enable-UnifiedAudit.ps1` calls `Set-AdminAuditLogConfig -UnifiedAuditLogIngestionEnabled $true`, but Exchange ignores the change unless the operator holds a high-privilege role such as **Compliance Administrator**, **Organization Management**, or **Audit Admin**.
- When the cmdlet lacks permissions, it returns "The command completed successfully but no settings have been modified." That’s your cue to rerun the m365 tag with an appropriately privileged account or flip the toggle manually in the Purview/Microsoft 365 Compliance portal.
- Managed identities/UAMIs cannot satisfy these M365 roles today, so keep using an interactive account (or certificate-based auth) that meets the compliance requirements.

## What does enabling Unified Audit actually do, and why is it mandatory?
- Unified audit logging turns on the Microsoft 365-wide pipeline that aggregates events from Exchange Online, SharePoint/OneDrive, Teams, Entra ID, Power BI, etc., into the central Purview audit log.
- Without it, workloads either don’t emit audit events at all or keep them locked in per-service logs, so KYD, DLP, Insider Risk, eDiscovery, and Communication Compliance have nothing to reference.
- Once enabled, the Purview compliance portal (**https://compliance.microsoft.com** → **Audit**) can search across all workloads with one query, and downstream APIs (Management Activity, Office 365 Management API, Purview Audit (Premium), scripts `21-Export-Audit.ps1` / `22-Ship-AuditToStorage.ps1`) can stream those events to SIEMs, storage, or Fabric Lakehouse.
- It’s the foundation for Know Your Data: the `m365` tag publishes DLP/labels/retention, but without Unified Audit you can’t prove “user X sent prompt Y,” so auditors will reject the evidence package.
- Azure diagnostics for Foundry/OpenAI resources (wired up via `07-Enable-Diagnostics.ps1`) complement Unified Audit by capturing platform logs in Log Analytics; together they provide both Microsoft 365 and Azure telemetry for prompts, responses, and control-plane changes.

## If Unified Audit is an M365 control, why is it required for Foundry?
- The accelerator’s Know Your Data (Secure Interactions) policy stores every Foundry prompt/response inside the user’s Exchange mailbox so Purview can apply retention, DLP, and insider-risk rules. Exchange refuses to persist that evidence if Unified Audit is off.
- Without Unified Audit the Secure Interactions policy can’t capture prompts, which means there is no chain of custody tying Foundry chats to compliance controls—retention, DLP, Insider Risk, or eDiscovery have nothing to act on.
- Downstream evidence (`21-Export-Audit.ps1`, `17-Export-ComplianceInventory.ps1`, Management Activity exports) would simply miss the interactions, leaving auditors without proof that Foundry prompts were governed.
- Turning on Unified Audit therefore becomes the bridge that lets Purview treat Foundry prompts like any other audited workload even though the toggle lives in Exchange Online.

## Why does `07-Enable-Diagnostics.ps1` connect Foundry to Log Analytics?
- The script enables diagnostic settings on every Foundry/Azure AI resource listed in your spec and sends the logs to a Log Analytics workspace. That stream includes `AzureDiagnostics`, Cognitive Services telemetry, Content Safety events, and other platform signals Defender for Cloud consumes.
- Defender for AI analytics rely on those logs to correlate with Purview prompt evidence. Without diagnostics you only have the Microsoft 365 side of the story—no resource-level traces, no SOC hunting queries, and limited incident reconstruction.
- Log Analytics provides a persistent history you can query with KQL, forward to Sentinel, or package as evidence. When regulators ask for “show me every prompt this project processed,” you pair Unified Audit (KYD policy) with the Azure diagnostics captured here.
- Microsoft’s DSPM-for-AI Learn articles emphasize collection policies, Secure Interactions, and the Defender-for-Cloud “Enable data security for Azure AI” switch. They assume telemetry lands in a workspace; wiring diagnostics through this script satisfies that expectation automatically with no extra portal clicks.

## Why are there two `logAnalyticsWorkspaceId` fields in the spec?
- The top-level `logAnalyticsWorkspaceId` (near the subscription/resourceGroup fields) is the “general purpose” workspace. Purview scans, tagging diagnostics, and other scripts wire telemetry here if they need a workspace and you don’t override it elsewhere.
- `defenderForAI.logAnalyticsWorkspaceId` lives under the `defenderForAI` block because the Defender diagnostics script (`07-Enable-Diagnostics.ps1`) can push logs to a different workspace than the rest of the automation. Leave it blank to fall back to the top-level ID, or supply a dedicated Defender workspace if your security team requires isolation.
- Both fields exist so you can either reuse a single workspace or split Defender telemetry from the broader operations log stream without editing the scripts.

## Why does the spec have both `aiFoundry` and `foundry.resources` (and two Content Safety blocks)?
- `aiFoundry` is the single “anchor” Azure AI Foundry project that scripts such as `30-Foundry-RegisterResources.ps1` expect. It provides one canonical project name/resourceId even if you only manage a single workspace.
- `foundry.resources` is an array so you can tag/monitor multiple Cognitive Services or AI Foundry workloads. Each entry feeds `25-Tag-ResourcesFromSpec.ps1`, `31-Foundry-ConfigureContentSafety.ps1`, and similar automation. If you only have one project, you’ll see the same resource repeated just so the array isn’t empty.
- `foundry.contentSafety` contains the Content Safety configuration that should be applied to those Foundry-linked resources (endpoint, Key Vault secret, blocklists, severity threshold).
- The top-level `contentSafety` section is for standalone Content Safety deployments outside Foundry—for example, when you attach Content Safety to Azure OpenAI directly. Different scripts reference each block, so both remain even if some fields are empty.

## Why do I need to add every Foundry project to the spec if Purview already shows it?
- Purview discovers Azure AI Foundry accounts on its own once Defender for Cloud plans are enabled, so new workspaces appear in the DSPM blades even if you never rerun the automation.
- The scripts only touch resources listed in `spec.local.json` (`foundry.resources[]` plus the anchor `aiFoundry`). If a workspace is missing there, rerunning `run.ps1` will skip it entirely.
- Adding the resource name/ID unlocks the downstream automation:
	- `25-Tag-ResourcesFromSpec.ps1` applies the governance tags defined in the spec.
	- `30-Foundry-RegisterResources.ps1` registers the project so DSPM recommendations stay in sync with the rest of your estate.
	- `31-Foundry-ConfigureContentSafety.ps1` pushes the configured blocklists, allow lists, and severity threshold.
	- `07-Enable-Diagnostics.ps1` only enables diagnostics on the resource IDs it knows, so omitting the workspace means no Defender log stream.
- Bottom line: Purview can display any discovered Foundry account, but listing it in the spec is what ties it into tagging, Content Safety configuration, diagnostics routing, and subsequent posture validation when you rerun the accelerator.

## Do I need Azure diagnostics for Foundry in addition to Unified Audit?
- Yes—Unified Audit covers Microsoft 365 endpoints (Teams, SharePoint, Exchange, KYD evidence), while Azure diagnostics capture logs from the Foundry/OpenAI resources themselves (API calls, request/response payload metadata, Content Safety enforcement).
- `07-Enable-Diagnostics.ps1` enables Diagnostic Settings on each Foundry/Cognitive Services resource listed in the spec and ships them to the specified Log Analytics workspace. Those logs power Defender for AI detections and give you platform-level visibility that Unified Audit can’t provide.
- Together they close the gap: Unified Audit proves what users did inside Microsoft 365, while Azure diagnostics prove what the AI infrastructure processed or attempted.

## Why does a deleted Foundry account or project still show up in DSPM for AI?
- Microsoft Purview DSPM for AI retains historical telemetry and risk assessments so compliance teams can investigate past activity. Removing the Azure AI Foundry account/project (or deleting the subscription) stops **future** data collection, but previously captured evidence stays in the DSPM dashboard until retention policies purge it.
- There is no automatic cleanup tied to account deletion because DSPM is designed for audit scenarios—erasing the record would break investigations and regulatory traceability.
- If a name must be removed immediately, use the Purview compliance portal to adjust or purge retention: review **Data lifecycle management** policies, Communication Compliance/Insider Risk retention, or purge content under **Audit (Premium)** exports. This is a manual action; the accelerator does not issue deletions.
- As a best practice, confirm what still appears via **Data Risk Assessment** reports and review the retention policies assigned to those workloads so stakeholders know when the historical entries will naturally expire.

## Why doesn’t `30-Foundry-RegisterResources.ps1` touch Azure OpenAI accounts?

Confirming what’s happening: the only part of the accelerator that “registers a project” in Purview today is `30-Foundry-RegisterResources.ps1`, and that script only knows how to work with Azure AI Foundry projects (`…/accounts/<foundry>/projects/<project>` resource IDs). When you append an Azure OpenAI account (for example `/accounts/oai-cwydhg7zp`) to `foundry.resources[]`, the run still loops through the array, but this module deliberately ignores non-Foundry items because Purview already discovers plain Azure OpenAI accounts automatically. The end result matches what you see in the portal: the manual **Secure interactions for enterprise AI apps** toggle only surfaces for Foundry projects. As of today’s change, the script prints “Skipping non-Foundry resource” whenever it encounters an entry without the `/projects/` segment so the run log makes that behavior explicit.

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
