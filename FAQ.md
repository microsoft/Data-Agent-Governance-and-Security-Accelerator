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

## Can I run everything from azd, GitHub Actions, or another automation platform?
- **azd hooks / GitHub Actions / Azure Automation** work for Azure resource tasks (Purview account, Defender plans, policies). Use a service principal with `Contributor` or `Security Admin` rights.
- **Exchange Online & Compliance Center** tasks (audit enablement, DLP creation) still require interactive or certificate-based authentication tied to a high-privilege M365 role. They usually run from a workstation or secure automation account capable of satisfying MFA.

## What do I need to do before running `run.ps1` in a fresh shell or container?
1. **Install the Az PowerShell modules** (once per environment):
	```powershell
	Install-Module Az -Scope CurrentUser -Repository PSGallery -Force -AllowClobber
	```
2. **Authenticate to Azure** before invoking the orchestrator. In containerized or SSH sessions without a GUI, use device code auth:
	```powershell
	Connect-AzAccount -Tenant '<tenant-guid>' -UseDeviceAuthentication
	```
	Follow the browser prompt to complete sign-in. If you prefer unattended execution, use a service principal instead (`Connect-AzAccount -ServicePrincipal ...`).
3. **Run the orchestrator** from the repo root once the session is authenticated:
	```powershell
	./run.ps1 -Tags dspm defender -SpecPath ./spec.local.json   # from bash/zsh use: pwsh ./run.ps1 -Tags ...
	```
