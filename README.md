# Data Agent Governance and Security Accelerator

Light up Microsoft Purview Data Security Posture Management (DSPM) for AI to safeguard Microsoft 365 Copilot, Azure AI Foundry, Microsoft Fabric, and custom agentic solutions from a single, spec-driven toolkit. Deploy end-to-end governance controls, automate registration and scanning, wire telemetry into Defender for AI, and export auditable evidence for regulators.

<div align="center">

[**SOLUTION OVERVIEW**](#solution-overview) \| [**QUICK DEPLOY**](#quick-deploy) \| [**PREREQUISITES**](#prerequisites-and-costs) \| [**BUSINESS SCENARIO**](#business-scenario) \| [**SUPPORTING DOCUMENTATION**](#supporting-documentation)

</div>

> **Note:** You own risk evaluation for every AI workload you deploy with this accelerator. Validate regulatory, privacy, and security requirements before moving to production.

---

## Getting Started - Choose Your Path

**New to this accelerator?**  
→ Start with the [Deployment Guide](./docs/DeploymentGuide.md) for comprehensive step-by-step instructions

**Already familiar with the solution?**  
→ Use [Quick Deploy](#quick-deploy) below for reference commands

**Want to secure Azure AI Foundry only?**  
→ Jump to [Foundry-Only Configuration](#foundry-only-configuration) for minimal setup

**Need to understand which tags to run?**  
→ See [Common Deployment Scenarios](#common-deployment-scenarios) for scenario-based guidance

### First Time Setup Checklist

Follow these steps in order for your first successful run:

- [ ] **1. Install tooling** - Azure CLI 2.58+, azd 1.9+, PowerShell 7.x, Az modules
- [ ] **2. Gather resource info** - Tenant ID, Subscription ID, Purview account name, AI Foundry project details
- [ ] **3. Clone repo** - `git clone https://github.com/microsoft/Data-Agent-Governance-and-Security-Accelerator.git`
- [ ] **4. Create spec file** - `Copy-Item ./spec.dspm.template.json ./spec.local.json`
- [ ] **5. Configure spec** - Replace placeholder values with your actual resource IDs and settings
- [ ] **6. Sign in** - Run `az login`, `azd auth login`, `Connect-AzAccount`, `Set-AzContext` in same terminal
- [ ] **7. Run automation** - Execute `azd up` or `./run.ps1 -Tags <your-tags> -SpecPath ./spec.local.json`
- [ ] **8. Complete manual steps** - Enable Purview DSPM and Defender for AI toggles in portals
- [ ] **9. Verify** - Check dashboards in Purview and Defender for Cloud to confirm configuration

---

## Solution overview
This accelerator orchestrates Azure and Microsoft 365 governance artifacts through PowerShell and azd hooks:

- Automates Purview DSPM for AI onboarding (resource groups, Purview account checks, data-source registration, scans, DLP/label/retention policies, audit exports).
- Governs Azure AI Foundry projects with Azure Policy, Defender for Cloud, Content Safety blocklists, diagnostics, and tagging.
- Ships telemetry to Log Analytics and exports compliance evidence for downstream analytics or regulators.
- Provides repeatable CI/Desktop experiences through spec-controlled tags and azd post-provision hooks.

### Solution architecture

![Data Agent governance architecture](./docs/doc-images/architectureDAGSA.png)

### What is DSPM for AI?

**Microsoft Purview Data Security Posture Management (DSPM) for AI** is a set of capabilities that help organizations:

- **Discover** where AI interactions occur across M365 Copilot, Azure AI Foundry, and third-party AI apps
- **Classify** sensitive data flowing through AI prompts and responses using sensitivity labels
- **Protect** data with DLP policies that prevent sensitive information from being shared with AI systems
- **Monitor** AI interactions through audit logs and compliance dashboards
- **Govern** retention and eDiscovery for AI-generated content

**Microsoft Defender for AI** complements DSPM by providing:

- **Threat detection** for AI-specific attacks (prompt injection, jailbreaks, data exfiltration)
- **Posture hardening** recommendations for AI resources
- **Attack path analysis** showing how AI components connect to sensitive data

This accelerator automates the configuration of both services so you don't have to manually toggle settings across multiple portals.

### How to customize
- [Author and extend the spec contract](./spec.dspm.template.json) for each tenant/subscription.
- [Review the value proposition](./docs/WhyDSPM.md) to communicate benefits to stakeholders.
- [Understand cost implications](./docs/CostGuidance.md) before enabling paid features.
- Extend stub scripts (for example `15-Create-SensitiveInfoType-Stub.ps1`) with organization-specific controls.

### Additional resources
- [Architecture Overview](./docs/ArchitectureOverview.md) - Technical architecture and class diagram
- [Deployment Guide](./docs/DeploymentGuide.md)
- [Troubleshooting Guide](./docs/TroubleshootingGuide.md)
- [Why DSPM for AI?](./docs/WhyDSPM.md) - Value proposition and stakeholder guide
- [Cost Guidance](./docs/CostGuidance.md) - Billing models and cost optimization

---

## Key features
<details open>
<summary>Click to view the core capabilities provided by this accelerator</summary>

- **Spec-driven DSPM for AI enablement** – Copy `spec.dspm.template.json`, populate tenant data, and let the scripts create Purview accounts, data sources, scans, KYD/DLP/retention policies, and audit exports without portal clicks.
- **Microsoft Foundry control plane governance** – ** Roadmap item ** Apply Azure Policies, Defender for AI plans, diagnostics, tagging, and Content Safety guardrails to every Foundry project listed in the spec.
- **Cross-cloud posture telemetry** – Stream diagnostics to Log Analytics, ensure Secure Interactions/KYD capture prompts and responses, and collect compliance inventory snapshots for auditors.
- **CI + desktop friendly automation** – Run `azd up` or `./run.ps1` with tags (foundation, dspm, defender, foundry, m365) to replay deterministic checklists in devcontainers, Codespaces, or local shells.
- **Extensible evidence exports** – Reuse the audit export, compliance inventory, and tagging scripts as building blocks for bespoke regulator packages or SIEM pipelines.

</details>

---

## Quick deploy
> **Azure Developer CLI requirement:** Install azd **1.9.0 or later** and Azure CLI **2.58.0 or later** before deploying.

### Execution paths (choose one)

**Option A - azd orchestrated** (recommended for CI/Codespaces):
```powershell
azd up  # Triggers hooks/postprovision.ps1 → run.ps1 automatically
```

**Option B - Direct run.ps1** (recommended for desktop/manual runs):
```powershell
pwsh ./run.ps1 -Tags foundation,dspm,defender,foundry -SpecPath ./spec.local.json
```

> Both execute the same automation. `azd up` adds token import logic for container environments where Azure CLI context needs to be propagated to Az PowerShell modules.

### Steps

1. **Sign in to Azure** - Run these commands in the same terminal you'll use for deployment:
   ```powershell
   az login
   azd auth login
   Connect-AzAccount -Tenant <tenantId> -Subscription <subscriptionId>
   Set-AzContext -Subscription <subscriptionId>
   Get-AzContext  # Verify tenant/subscription match your spec
   ```

2. **Prepare the spec** - Copy `spec.dspm.template.json` to `spec.local.json` and populate required fields:
   
   **Minimum required fields:**
   - `tenantId`, `subscriptionId` (top level)
   - `purview.resourceGroupName`, `purview.accountName` (for `foundation` tag)
   - `aiFoundry.subscriptionId`, `aiFoundry.resourceGroupName` (for `foundry` tag)
   - `defenderForAI.enableDefenderForCloudPlans[]` (for `defender` tag)
   
   **Optional fields** (automation skips if missing):
   - `activityExport.*` (skip audit exports)
   - `foundry.contentSafety.*` (skip Content Safety config)
   - `fabric.*` (Fabric features not yet implemented)
   - `dlpPolicy`, `labels`, `retentionPolicies` (only needed for `m365` tag)

3. **Optional:** Adjust `infra/main.bicepparam` (tags, spec path, Microsoft 365 auth options).

4. **Execute `azd up`** or run `./run.ps1` directly (see execution paths above).

5. **Microsoft 365 steps** (desktop only) - From a workstation with MFA capability:
   ```powershell
   ./run.ps1 -Tags m365 -ConnectM365 -M365UserPrincipalName <upn> -SpecPath ./spec.local.json
   ```
   This publishes Secure Interactions, DLP, labels, and retention policies.

| [![Open in GitHub Codespaces](https://github.com/codespaces/badge.svg)](https://codespaces.new/microsoft/Data-Agent-Governance-and-Security-Accelerator) | [![Open in Dev Containers](https://img.shields.io/static/v1?style=for-the-badge&label=Dev%20Containers&message=Open&color=blue&logo=visualstudiocode)](https://vscode.dev/redirect?url=vscode://ms-vscode-remote.remote-containers/cloneInVolume?url=https://github.com/microsoft/Data-Agent-Governance-and-Security-Accelerator) | [![Open in Visual Studio Code Web](https://img.shields.io/static/v1?style=for-the-badge&label=Visual%20Studio%20Code%20(Web)&message=Open&color=blue&logo=visualstudiocode&logoColor=white)](https://insiders.vscode.dev/azure/?vscode-azure-exp=foundry&agentPayload=eyJiYXNlVXJsIjogImh0dHBzOi8vZ2l0aHViLmNvbS9taWNyb3NvZnQvRGF0YS1BZ2VudC1Hb3Zlcm5hbmNlLWFuZC1TZWN1cml0eS1BY2NlbGVyYXRvciIsICJpbmRleFVybCI6ICIvcmVmczo6aGVhZHMvbWFpbi9pbmZyYS92c2NvZGVfd2ViIiwgY2xhaW1zIjogeyJ3b3JrZmxvdyI6ICJjbG9uZSJ9fQ==) |
| --- | --- | --- |

### CRITICAL POST-DEPLOYMENT STEPS

After automation completes, you **MUST** manually enable two settings that cannot be automated via API:

**1. Purview DSPM - Secure interactions for enterprise AI apps:**
1. Sign in to [https://web.purview.azure.com](https://web.purview.azure.com)
2. Navigate: **Data Security Posture Management for AI** → **Recommendations** → **Secure interactions for enterprise AI apps**
3. Click **Enable**

**2. Defender for Cloud - Enable data security for AI interactions:**
1. Sign in to the [Azure portal](https://portal.azure.com)
2. Navigate: **Microsoft Defender for Cloud** → **Environment settings** → Select your subscription
3. Under **Defender plans**, locate **AI Services** → Click **Settings**
4. Toggle **Enable data security for AI interactions** to **On** → Click **Save**

**Why this matters:** Without these manual toggles, AI interaction data (prompts/responses) will NOT be captured by Purview DSPM or Defender for AI for threat detection and compliance analysis.

See [Required Manual Checkpoints](#required-manual-checkpoints) for complete post-deployment checklist.

> **Need help?** Review the [Troubleshooting Guide](./docs/TroubleshootingGuide.md) for solutions to common azd and Purview authentication issues.

---

## Common Deployment Scenarios

| I want to... | Run these tags | Prerequisites | Key spec sections |
|-------------|----------------|---------------|-------------------|
| **Secure Azure AI Foundry only** | `defender,foundry` | Azure Contributor on subscription with Foundry projects | `aiFoundry.*`, `foundry.resources[]`, `defenderForAI.enableDefenderForCloudPlans` |
| **Full Purview DSPM for AI (no M365)** | `foundation,dspm,defender,foundry` | Azure Contributor + Purview Data Source Admin | All Azure sections (skip `dlpPolicy`, `labels`, `retentionPolicies`) |
| **Enable M365 Copilot governance** | `m365` (run separately from desktop) | Desktop + MFA + Exchange Online admin + E5 license | `dlpPolicy`, `labels`, `retentionPolicies` |
| **Everything** | `all` OR `foundation,dspm,defender,foundry,m365` | All of the above (may require multiple operators) | All spec sections |
| **Re-run audit exports only** | `audit` | Audit Reader role in Purview + populated `activityExport` | `activityExport.*` |

---

## Foundry-Only Configuration

To configure governance for only Azure AI Foundry projects without full Purview DSPM or M365 setup:

### Prerequisites
- Azure Contributor RBAC on the subscription containing your Foundry projects
- PowerShell 7.x and Az modules installed
- Azure Developer CLI (azd) 1.9.0+ and Azure CLI 2.58.0+

### Spec preparation
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
# Sign in (all required for automation to work)
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

## How to install or deploy
Follow the [Deployment Guide](./docs/DeploymentGuide.md) for detailed prerequisites, sign-in commands, spec preparation, `azd up` guidance, and manual Purview toggles. The guide also covers how to rerun atomic scripts or integrate the plan into GitHub Actions using `run.ps1` tags.

---

## Prerequisites and costs

> **IMPORTANT - Multiple Operator Accounts Required for Full Deployment**
>
> Running `-Tags all` requires coordinating **multiple privileged identities**. A single user can complete the deployment if they hold all roles, but the `m365` tag requires interactive MFA from a desktop (not containers/Codespaces).
>
> | Tag(s) | Required Identity | Why |
> |--------|-------------------|-----|
> | `foundation`, `dspm`, `defender`, `foundry` | **Azure Contributor** + **Purview Data Source Admin** | Creates Azure resources, registers data sources in Purview catalog |
> | `m365` | **Compliance Administrator** with **MFA-capable workstation** | Interactive Exchange Online auth to enable Unified Audit and create KYD policies |
> | Audit exports (`audit` tag or scripts 20-21) | **Audit Reader** OR **Compliance Admin** in Purview | Management Activity API access for compliance evidence |
>
> **Single-user scenario:** If one person holds all roles, run `foundation,dspm,defender,foundry` from any environment, then switch to a desktop to run `m365` separately.
>
> **Team scenario:** Azure admin runs automation tags from containers/CI; compliance admin runs `m365` from their workstation independently.

### Core requirements
- Contributor RBAC on the subscription(s) hosting Purview, Defender, and Azure AI resources.
- Microsoft 365 E5 (or E5 Compliance) license for the operator enabling Secure Interactions and Unified Audit.
- Exchange Online + Security & Compliance PowerShell access (MFA-capable workstation) for the `m365` tag.
- Audit Reader or Compliance Administrator role in Purview to call the Management Activity API.
- PowerShell 7.x and Az modules installed locally or inside your devcontainer.

| Service | Purpose | Pricing |
| --- | --- | --- |
| [Microsoft Purview](https://azure.microsoft.com/pricing/details/purview/) | DSPM for AI scans, Secure Interactions, Know Your Data | Usage based |
| [Azure AI Foundry / Cognitive Services](https://azure.microsoft.com/pricing/details/ai-studio/) | AI project hosting, diagnostics, Content Safety | Usage based |
| [Microsoft Defender for Cloud](https://azure.microsoft.com/pricing/details/defender-for-cloud/) | Defender for AI plans, alerts, diagnostics | Per resource type |
| [Log Analytics](https://azure.microsoft.com/pricing/details/monitor/) | Central log collection for diagnostics | Pay-as-you-go |
| [Azure OpenAI / GPT capacity](https://azure.microsoft.com/pricing/details/cognitive-services/openai-service/) | Optional Content Safety or Foundry workloads | Usage based |

Use the [Azure pricing calculator](https://azure.microsoft.com/pricing/calculator) and the guidance in [Cost Guidance](./docs/CostGuidance.md) to estimate and monitor spend. Remember to run `azd down` or delete the resource group when finished.

---

## Business scenario
A data protection program is tasked with lighting up Microsoft Purview Data Security Posture Management for AI and Microsoft Defender for AI across Microsoft 365 Copilot, Azure AI Foundry, Fabric, and bespoke agentic solutions. They must discover and classify the source data that feeds every agent, apply Purview labels/DLP/retention policies plus Defender guardrails, and continuously track and audit Generative AI apps and agents for regulators. With this accelerator, the team captures those requirements in a spec, executes `azd up` or `run.ps1`, and produces verifiable evidence that DSPM for AI and Defender for AI are enforcing policies, logging activity, and keeping every agented workflow compliant.

---

## Business value
<details>
<summary>Click to expand the value delivered by this solution</summary>

- **Unified AI governance** – Enforce Purview DSPM for AI, labels, DLP, retention, audit, and Azure Policy from one declarative spec.
- **Operational efficiency** – Shorten deployment time from days to minutes via azd hooks and repeatable PowerShell plans.
- **Evidence on demand** – Export audit logs and compliance inventory snapshots to satisfy regulators or internal risk teams.
- **Secure innovation** – Light up Defender for AI, diagnostics, and Content Safety controls around every Foundry project so new AI agents inherit enterprise guardrails.

</details>

---

## Supporting documentation
- [Architecture Overview](./docs/ArchitectureOverview.md) - Technical architecture and class diagram
- [Deployment Guide](./docs/DeploymentGuide.md)
- [Troubleshooting Guide](./docs/TroubleshootingGuide.md)
- [Why DSPM for AI?](./docs/WhyDSPM.md) - Value proposition and stakeholder communication
- [Cost Guidance](./docs/CostGuidance.md) - Billing models and optimization tips
- [Repository structure and script descriptions](./scripts/governance/README.md)

---

## Security guidelines
- Store secrets in Azure Key Vault and pass references through the spec file instead of embedding secrets directly.
- Use managed identities or service principals for automation runs; rotate credentials regularly.
- Enable Microsoft Defender for Cloud across Cognitive Services, Storage, and Container workloads when enabling Defender for AI.
- Ensure GitHub secret scanning is enabled if you fork this repo; avoid committing `spec.local.json`.

---

## Provide feedback
Have a question or feature request? [Open an issue](https://github.com/microsoft/Data-Agent-Governance-and-Security-Accelerator/issues) and include the failing script name, error text, and environment details.

---

## Disclaimers
This repository contains example assets that rely on Microsoft products and services such as Azure, Purview, and Microsoft 365. You must comply with all applicable [Microsoft Product Terms](https://www.microsoft.com/licensing/terms/) and export regulations when deploying the solution. The accelerator is not certified for high-risk or safety-critical systems; evaluate and mitigate risks before production use.

## Interaction callouts
- **Secure interactions (KYD)**: M365 sends Foundry prompts/responses to Purview DSPM via Unified Audit, landing in user mailboxes for retention/eDiscovery.
- **Purview ↔ Defender for AI**: DSPM recommendations illuminate Defender posture; Defender for AI sends detections back to Purview activity explorer.
- **Foundry ↔ Log Analytics**: `07-Enable-Diagnostics.ps1` streams diagnostic logs from Cognitive Services/Foundry to Log Analytics, powering Defender analytics and SOC hunting.
- **Fabric/OneLake ↔ Purview**: Registration/scans keep Fabric datasets classified so downstream Foundry agents respect sensitivity labels.
- **Evidence exports**: Purview audit exports (Management Activity) and compliance inventory dumps feed Log Analytics or storage for regulators.




## Prerequisites

Before DSPM can provide insights and risk analytics, you must opt in to analytics processing for Insider Risk Management (IRM) and Data Loss Prevention (DLP). This is a prerequisite for DSPM to start scanning and correlating data security signals. Once enabled, DSPM automatically begins scanning your data estate for sensitive data and risky activities.
- **Microsoft 365 E5** (or **E5 compliance**) license assigned to an operator with **Compliance Administrator** and **Purview Data Source Administrator rights** ([Microsoft Learn](https://learn.microsoft.com/en-us/purview/ai-microsoft-purview-considerations#prerequisites-for-data-security-posture-management-for-ai)).
- **PowerShell 7 required** – run every script (including `run.ps1`) from pwsh 7.x to avoid Windows PowerShell module loader conflicts.
- **Az module installed** – install or update the Az rollup before running anything:

  ```powershell
  pwsh
  Install-Module Az -Scope CurrentUser -Force
  Install-Module Az.Security -Scope CurrentUser -Force    # defender steps
  ```


- **Exchange Online Management module** installed on a workstation capable of satisfying MFA for audit enablement steps ([Connect to Exchange Online PowerShell](https://learn.microsoft.com/en-us/powershell/exchange/connect-to-exchange-online-powershell)).
- The **operator** running the Microsoft 365 tag (`run.ps1 -Tags m365`) must hold **Unified Audit** roles (Compliance Administrator, Organization Management, or Audit Admin). Without those permissions Exchange will report "completed successfully but no settings modified" when toggling `Set-AdminAuditLogConfig`, so the scripts emit a warning and you must enable unified audit in the Purview/M365 Compliance portal instead.
- Run the Exchange Online steps (`run.ps1 -Tags m365`) from that workstation; containerized environments without a browser should execute the remaining tags (`dspm`, `defender`, `foundry`) separately. If you're staying on the desktop, you can combine everything in one go ([Modern auth with MFA guidance](https://learn.microsoft.com/en-us/powershell/exchange/connect-to-exo-powershell#connect-to-exchange-online-powershell-using-modern-authentication-with-or-without-mfa)):
  ```powershell
  ./run.ps1 -Tags m365,dspm,defender,foundry -SpecPath ./spec.local.json
  # or, from bash/zsh: pwsh ./run.ps1 -Tags m365,dspm,defender,foundry -SpecPath ./spec.local.json
  ```
- Expect **multiple authentication prompts** during a full run. Each tag connects to different control planes (Exchange Online, Azure, Defender, Content Safety), so distinct operator accounts or privileged groups may need to approve access. This is intentional so governance stakeholders remain in the loop.
- Azure RBAC permissions: **Contributor** on the subscription that hosts Purview, AI Foundry, and Defender resources.

---




## azd & CI automation

### Required sign-in steps before `azd up`
The post-provision hook inherits whatever identities are active in your shell. Run the following commands (in this order) every time you open a fresh terminal or switch tenants/subscriptions so Azure CLI, azd, and Az PowerShell all target the IDs defined in your spec:

1. `az login` – establishes the Azure CLI session tied to your operator account.
2. `azd auth login` – optional but recommended so `azd up` can reuse the same identity (workload identity/service principal flows are fine here).
3. `Connect-AzAccount -Tenant <tenantId> -Subscription <subscriptionId>` – PowerShell-side login that the scripts consume; match the IDs at the top of `spec.local.json`.
4. `Set-AzContext -Subscription <subscriptionId>` – pins the default context so child PowerShell processes do not prompt again.
5. `Get-AzContext` – verify the tenant/subscription shown above aligns with your spec before running `azd up` or `./run.ps1`.

Skipping any of these steps usually results in browser prompts (because the hook can’t import CLI tokens) or failures when Purview scripts call `Connect-AzAccount`. Logging in up front keeps the automation non-interactive.

### Devcontainer / `azd` post-provision flow
- `azure.yaml` plus the empty `infra/main.bicep` let you run `azd up` (or `azd provision`) purely to trigger the post-provision hook – no infrastructure needs to be deployed.
- The hook (`hooks/postprovision.ps1`) reuses the current `azd auth login` context by grabbing Azure CLI tokens and importing them into Az PowerShell before it invokes `run.ps1`.
- Customize the hook with environment variables:
  - `DAGA_SPEC_PATH` – spec file to pass to `run.ps1` (defaults to `./spec.local.json`).
  - `DAGA_POSTPROVISION_TAGS` – comma-separated tags (default `foundation,dspm,defender,foundry`).
  - `DAGA_POSTPROVISION_CONNECT_M365`/`DAGA_POSTPROVISION_M365_UPN` – enable Microsoft 365 steps when you have desktop/MFA access inside the container.
- Typical workflow inside the devcontainer:
  1. `azd auth login` (or `az login`) to seed the CLI context.
  2. Populate `spec.local.json`.
  3. Run `azd up` – you will see the Bicep deployment no-op, followed by the hook printing the `run.ps1` invocation.
- If you prefer declarative configuration, edit `infra/main.bicepparam`: each `daga*` parameter mirrors a hook input (spec path, tags, whether to run Microsoft 365 steps, app-only auth settings). `azd` compiles the file during provisioning, and the hook reads those values via the Bicep CLI before executing `run.ps1`.
- Environment variables always win over the parameter file, so you can temporarily override behavior without editing source:
  - `DAGA_SPEC_PATH`
  - `DAGA_POSTPROVISION_TAGS`
  - `DAGA_POSTPROVISION_CONNECT_M365`
  - `DAGA_POSTPROVISION_M365_UPN`
  - `DAGA_POSTPROVISION_M365_APP_ID`
  - `DAGA_POSTPROVISION_M365_ORGANIZATION`
  - `DAGA_POSTPROVISION_M365_CERT_THUMBPRINT`
  - `DAGA_POSTPROVISION_M365_CERT_PATH`
  - `DAGA_POSTPROVISION_M365_CERT_PASSWORD`

### GitHub Actions (federated SPN)
- The workflow in `.github/workflows/daga-automation-oidc.yml` runs `./run.ps1 -Tags all -ConnectM365` on `ubuntu-latest` with OIDC-based Azure login (`azure/login@v2`).
- Required repository secrets:
  1. `AZURE_FEDERATED_CLIENT_ID`, `AZURE_FEDERATED_TENANT_ID`, `AZURE_FEDERATED_SUBSCRIPTION_ID` – values from the federated SPN you create in Entra ID.
  2. `DAGA_SPEC_JSON` – entire `spec.local.json` contents (stored as JSON in the secret; the workflow writes it to `spec.ci.json`).
  3. Microsoft 365 app-only auth values: `DAGA_M365_APP_ID`, `DAGA_M365_ORGANIZATION`, plus either
     - `DAGA_M365_CERT_PFX` + `DAGA_M365_CERT_PASSWORD` (Base64-encoded PFX and its password), or
     - `DAGA_M365_CERT_THUMBPRINT` if you preload a certificate into the hosted agent (self-hosted scenario).
- The workflow installs the Az/Defender/Exchange modules, logs into Azure via workload identity federation, materializes the M365 certificate, and then executes `run.ps1` so every script runs in the same order as the orchestrator.

### Non-interactive Microsoft 365 auth
- `run.ps1` now supports both interactive and app-only connections when `-ConnectM365` is supplied:
  - Pass `-M365UserPrincipalName <upn>` for the traditional interactive desktop flow.
  - Or pass `-M365AppId`, `-M365Organization`, and either `-M365CertificateThumbprint` **or** `-M365CertificatePath` + `-M365CertificatePassword` for certificate-based automation.
- The same values can be provided via environment variables (`DAGA_M365_APP_ID`, `DAGA_M365_ORGANIZATION`, `DAGA_M365_CERT_THUMBPRINT`, `DAGA_M365_CERT_PATH`, `DAGA_M365_CERT_PASSWORD`) so CI systems keep secrets out of command-line logs.
## Local Quick start

1. **Install the tooling** – open PowerShell 7 and install/refresh the Az bits you need:
   ```powershell
   Install-Module Az -Scope CurrentUser -Repository PSGallery -Force -AllowClobber
   Install-Module Az.Security -Scope CurrentUser -Force
   ```
2. **Sign in to Azure** – authenticate in the same shell that will run the scripts:
   ```powershell
   Connect-AzAccount -Tenant '<tenant-guid>' -Subscription '<subscription-guid>'
   ```
   For automation, use a service principal or managed identity instead (device-code auth is disabled here):
   ```powershell
   Connect-AzAccount -ServicePrincipal -Tenant '<tenant-guid>' -ApplicationId '<appId>' -Credential (Get-Credential)
   ```
3. **Prepare the spec** – this is an optional step and should only be run in a new clone before running scripts. As the solution grows additional parameters may be added, or refactored. Regenerate the public template when the schema changes, then clone it to your local copy:
   ```powershell
   pwsh ./scripts/governance/00-New-DspmSpec.ps1 -OutFile ./spec.dspm.template.json
   Copy-Item ./spec.dspm.template.json ./spec.local.json
   ```
   Populate tenant/subscription IDs, Purview settings, Foundry resources, Content Safety endpoints, etc., and keep the local file untracked.
4. **Execute the modules** – from the repo root, run the individual scripts you need (or orchestrate them via tags as in the examples). A typical first run looks like:
   - **Foundation (Purview landing zone):**
     ```powershell
     pwsh ./scripts/governance/01-Ensure-ResourceGroup.ps1 -SpecPath ./spec.local.json
     pwsh ./scripts/governance/dspmPurview/02-Ensure-PurviewAccount.ps1 -SpecPath ./spec.local.json
     ```
   - **Microsoft 365 compliance  (desktop + MFA):**
     ```powershell
     ./run.ps1 -Tags m365 -SpecPath ./spec.local.json
     # bash/zsh: pwsh ./run.ps1 -Tags m365 -SpecPath ./spec.local.json
     ```
     Connects to Exchange Online, ensures Unified Audit, and publishes KYD/DLP/label/retention settings.
   - **Purview registrations and scans:**
     ```powershell
     pwsh ./scripts/governance/dspmPurview/03-Register-DataSource.ps1 -SpecPath ./spec.local.json
     pwsh ./scripts/governance/dspmPurview/04-Run-Scan.ps1 -SpecPath ./spec.local.json
     ```
   - **Defender for AI posture:** - additional manual step necessary
     ```powershell
     pwsh ./scripts/defender/defenderForAI/06-Enable-DefenderPlans.ps1 -SpecPath ./spec.local.json
     pwsh ./scripts/defender/defenderForAI/07-Enable-Diagnostics.ps1 -SpecPath ./spec.local.json
     ```
   - **Foundry registration + Content Safety:** - need content safety endpoint in the parameter file
     ```powershell
     pwsh ./scripts/governance/dspmPurview/30-Foundry-RegisterResources.ps1 -SpecPath ./spec.local.json
     pwsh ./scripts/governance/dspmPurview/31-Foundry-ConfigureContentSafety.ps1 -SpecPath ./spec.local.json
     ```
   - **Optional orchestrator:** bundle the same steps with tags instead of individual scripts:
     ```powershell
     ./run.ps1 -Tags m365 -SpecPath ./spec.local.json
     ./run.ps1 -Tags dspm,defender,foundry -SpecPath ./spec.local.json
     ./run.ps1 -Tags all -SpecPath ./spec.local.json
     ```
     Mix tags however you like (for example `-Tags foundation,dspm`).
5. **Review dashboards & export evidence** – once telemetry and policies show up, capture artifacts:
   ```powershell
   pwsh ./scripts/governance/dspmPurview/17-Export-ComplianceInventory.ps1 -SpecPath ./spec.local.json
   pwsh ./scripts/governance/dspmPurview/21-Export-Audit.ps1 -SpecPath ./spec.local.json
   ```
### Defender for Cloud plan choices

Populate `defenderForAI.enableDefenderForCloudPlans` (in `spec.dspm.template.json` or your local copy) with every Defender for Cloud plan you want the automation to enable before Defender for AI configuration/activation scripts run. Common values include:

- `CognitiveServices` (displayed as **AI Services** in the Defender for Cloud portal) – protection for Azure AI Foundry, Azure OpenAI, and other Cognitive Services resources that handle prompts, responses, or model orchestration. **Note:** enabling the "Enable data security for AI interactions" feature for AI Services in Defender still requires a manual step in the Purview portal (see the manual checkpoints section below). 
- `Storage` – coverage for Storage accounts holding prompt transcripts, audit exports, embeddings, or fine-tuning payloads.
- `Containers` – Defender for Containers for AKS/Fabric scenarios where containerized agents run inference pipelines.
- `KeyVaults` – detection around vaults storing model keys, Content Safety secrets, or managed identities.
- `AppServices` and `Api` – surface exploits or drift on App Service / API Management front ends used by prompt flow apps.
- `ContainerRegistry` – protect custom model images prior to deployment.
- `KubernetesService` and `VirtualMachines` – telemetry from GPU clusters or VM pools hosting self-managed inference.
- `ResourceManager` (a.k.a. `Arm`) – watch for control-plane changes that might weaken AI guardrails.
- `SqlServers`, `SqlServersOnVirtualMachines`, `OpenSourceRelationalDatabases`, `CosmosDbs` – when AI workloads persist chat history, embeddings, or feature stores in those data services.
- `ContainerApp` and `Dns` – helpful when exposing AI agents through Container Apps or public endpoints.

Add or remove plan strings as needed; the `06-Enable-DefenderPlans.ps1` module iterates the array and skips any plan already turned on in the subscription.

**Know Your Data capture (KYD):** run `./run.ps1 -Tags m365 -SpecPath ./spec.local.json` from a local PowerShell 7 session whenever you need to (re)enable Unified Audit, create the Secure interactions/KYD policy, or publish the DLP/label/retention settings baked into your spec. The script loads the Exchange Online Management module, prompts for MFA in your default browser, and creates the policy that stores prompts/responses in each user's mailbox so the data inherits retention, eDiscovery, and Communication Compliance. See [Why DSPM for AI?](./docs/WhyDSPM.md) (Steps 2–3) and the Microsoft Learn article on [turning auditing on or off](https://learn.microsoft.com/en-us/purview/audit-log-enable-disable) for the operator walkthrough.

**Why the registration script matters:** `30-Foundry-RegisterResources.ps1` leverages the `aiFoundry` and `foundry.resources[]` sections in `spec.local.json`, validates each resource, and writes the metadata Purview’s DSPM blades use to associate Azure AI Foundry projects with your broader AI estate. Without that registration pass, Defender for Cloud may still discover the workspace, but Purview cannot correlate the DSPM recommendation state or surface “Secure interactions for enterprise AI apps” for that project, which is why rerunning the script keeps recommendations aligned with the rest of your environment.

**Content Safety script behavior:** if `foundry.contentSafety` is missing, the script logs "No foundry.contentSafety" and skips configuration so the rest of the tag run continues. When an endpoint is present but the Key Vault secret info is omitted or local auth is disabled, the script automatically requests an Entra ID access token for `https://cognitiveservices.azure.com` (works with system-assigned managed identities) and uses it to call the Content Safety REST APIs. Supplying a Key Vault secret still works when you prefer key-based auth. In either mode, every Foundry project listed under `foundry.resources` inherits the blocklists/items defined in the spec.

---

## Capabilities at a glance

- **Purview Data Security Posture Management (DSPM) for AI**: register storage, SQL, OneLake, and Fabric workspaces, trigger Purview DSPM for AI scans, and apply sensitivity labels, DLP policies, and retention rules so AI workloads (Azure AI Foundry and ChatGPT Enterprise) inherit Microsoft Purview’s DSPM controls.
- **Security posture**: assign Azure Policies, enable Defender for Cloud plans, and ship diagnostics to Log Analytics for continuous monitoring of AI endpoints.
- **Compliance evidence**: subscribe to the Management Activity API, export audit logs, and push transcripts into storage or Fabric for downstream analytics.
- **Application guardrails**: configure Content Safety blocklists, tag Azure resources with compliance metadata, and lay the groundwork for AI prompt filtering in ChatGPT Enterprise.

## DSPM for AI & Defender for AI — Features and Benefits Mapping

| **Environment Component**                                      | **Secured Asset (What It Protects)**                                                     | **Product**                                                 | **Key Features**                                                                                                                                                      | **Business Benefits**                                                                                                          |
| -------------------------------------------------------------- | ---------------------------------------------------------------------------------------- | ----------------------------------------------------------- | --------------------------------------------------------------------------------------------------------------------------------------------------------------------- | ------------------------------------------------------------------------------------------------------------------------------ |
| **Azure AI Foundry**                                           | AI interactions (prompts & responses), workspaces, connections to data sources           | Microsoft Purview **DSPM for AI**                           | Centralized discovery of AI interactions; sensitivity classification & labeling; DLP on prompts/responses; audit & eDiscovery integration                             | Prevents sensitive-data leakage via AI; enforces consistent data handling; accelerates investigations and compliance reporting |
| **Azure OpenAI / Azure ML (AI runtime)**                       | Model endpoints, prompt flow apps, deployments, keys/secrets linkage                     | **Defender for AI**                                         | AI-specific threat detection and posture hardening; misconfiguration findings; attack-path/context analysis for AI components                                         | Reduces breach risk and configuration drift; shortens time-to-detect and time-to-remediate for AI workloads                    |
| **Microsoft Fabric OneLake**                                   | Tables/files (Delta/Parquet), Lakehouse/Warehouse data, Domains                          | Microsoft Purview (Info Protection + DLP) & **DSPM for AI** | Sensitivity labels; **DLP for structured data in OneLake**; label coverage goals & reports; activity monitoring                                                       | Enforces least-privilege & prevents oversharing; provides measurable posture improvements and evidence for audits              |
| **Fabric Workspaces & Items**                                  | Workspaces, Dataflows, Datasets, Notebooks, Pipelines                                    | Fabric native RBAC + Microsoft Purview integrations         | Workspace/item security; default label per domain; end-to-end auditability with Purview; federated governance between **OneLake Catalog** and Purview Unified Catalog | Consistent guardrails for self-service analytics; clear ownership; end-to-end traceability for regulated data operations       |
| **Fabric AI Experiences (e.g., Copilot in Fabric)**            | AI-generated insights & Q&A over governed data                                           | Microsoft Purview **DSPM for AI**                           | Oversharing prevention in AI experiences; policy evaluation before/around AI actions; audit of interaction data                                                       | Safe, governed self-service AI analytics without exposing sensitive data; audit-ready usage trails                             |
| **Cross‑estate AI Interactions (enterprise AI apps & agents)** | Prompt/response interaction data spanning Copilot, custom agents, and registered AI apps | Microsoft Purview **DSPM for AI**                           | Unified view of where AI interactions occur; policy enforcement across multiple AI entry points; natural-language risk exploration                                    | Single control plane for AI data risks; consistent compliance across heterogeneous AI surfaces                                 |

---


### DSPM for Microsoft Foundry Steps

The following diagram illustrates the end-to-end automation flow for securing Azure AI Foundry with Purview DSPM and Defender for AI:

![DSPM for Foundry Steps](./docs/doc-images/DSPM-for-Foundry-Steps.png)


Manual steps exist where Microsoft has not yet exposed APIs or where MFA-capable desktop sessions are mandatory (Exchange Online, Purview preview toggles). Keep this diagram handy when planning customer demos so you can assign owners before the run.

### DSPM for M365 Copilot, Microsoft Foundry, custom AI solutions and ChatGPT Enterprise

![DSPM for all services](./docs/doc-images/DSPM-for-all-services-steps.png)

### Required manual checkpoints

1. **Secure interactions / KYD policy (Purview portal)**
  - Navigate to **https://web.purview.azure.com** → **Data Security Posture Management for AI** → **Recommendations** → **Secure interactions for enterprise AI apps**. Be sure it is enabled

2. **Defender for Cloud - Enable data security for AI interactions**
  - Sign in to the [Azure portal](https://portal.azure.com)
  - Navigate to **Microsoft Defender for Cloud** → **Environment settings** → Select your subscription
  - Under **Defender plans**, locate **AI Services** (or **Cognitive Services**)
  - Click **Settings** → Toggle **Enable data security for AI interactions** to **On**
  - Click **Save**
  - **Why this matters:** This setting cannot be automated via API yet. Without it, Defender for AI will not capture AI interaction telemetry for threat detection and posture analysis.

3. **Exchange Online desktop session for `m365` tag (desktop required, not containers/Codespaces)**
  - Open PowerShell 7 on a workstation with browser-based MFA, install/update the Exchange Online Management module, and run `./run.ps1 -Tags m365 -ConnectM365 -M365UserPrincipalName <upn>`.
  - Approve the MFA prompts, confirm Unified Audit reports "Enabled," and verify the Secure interactions (KYD) policy appears under **Data lifecycle management** in the Purview portal.
4. **Communication Compliance / Insider Risk previews**
  - In the Microsoft Purview compliance portal, browse to **Communication Compliance** and **Insider Risk Management** to enable any required preview policies or monitoring templates (for example sensitive keywords, channel monitoring, or policy templates tied to AI prompts).
  - Document approvals with screenshots or exports; these features remain portal-only.
5. **Post-run review and evidence capture**
  - Check Defender for Cloud, Purview DSPM dashboards, and Azure Policy compliance to ensure new registrations/scans are reflected.
  - Run `17-Export-ComplianceInventory.ps1` / `21-Export-Audit.ps1` only after confirming telemetry is flowing, then upload the artifacts to your evidence repository (SharePoint, Fabric, or storage account) for audit traceability.
  - If Fabric scans are enabled later, confirm in the Purview portal that the scan job completed successfully; rerun manually when changes occur.

Use this checklist with your stakeholders to understand which steps require human interaction and which ones the automation handles.

### Tag reference

| Tag                                                                         | What it runs / why it exists                                                                                                                                                                                                                                                                                  | Example command |
| --------------------------------------------------------------------------- | ------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------- | ---------------- |
| `foundation`                                                                | Baseline Purview/DSPM bootstrap: `01-Ensure-ResourceGroup.ps1`, `02-Ensure-PurviewAccount.ps1`, data-source registration + first scans. Delivers the landing zone Purview needs before policies or scans proceed.                                                                                             | `./run.ps1 -Tags foundation -SpecPath ./spec.local.json` |
| `m365`                                                                      | Exchange Online / Compliance Center steps that require interactive auth: connect session, enable Unified Audit, create the Know Your Data (Secure interactions) policy, and publish the DLP/label/retention settings from your spec. Run from a desktop with MFA access (see [Why DSPM?](./docs/WhyDSPM.md)). | `./run.ps1 -Tags m365 -SpecPath ./spec.local.json` |
| `dspm`                                                                      | Broader Purview governance tasks beyond the bootstrap: scan registration, audit subscriptions/exports (`20-21`), Azure policy assignments, tagging, posture validation. Combine with `foundation` for the full Purview story.                                                                                 | `./run.ps1 -Tags foundation,dspm -SpecPath ./spec.local.json` |
| `defender`                                                                  | Defender for AI enablement scripts (`06-Enable-DefenderPlans.ps1`, `07-Enable-Diagnostics.ps1`) plus content-safety wiring. Requires the AI subscription/resource group fields in the spec.                                                                                                                   | `./run.ps1 -Tags defender -SpecPath ./spec.local.json` |
| `foundry`                                                                   | Azure AI Foundry integration: resource registration, tagging, diagnostics, content safety, OneLake/Fabric registration (when enabled). Works off `aiFoundry` and `foundry.resources` blocks in the spec.                                                                                                      | `./run.ps1 -Tags foundry -SpecPath ./spec.local.json` |
| `scans`, `audit`, `policies`, `diagnostics`, `ops`, `tags`, `contentsafety` | Finer-grained switches used internally by the plan. You usually won’t call them directly unless you want to rerun a single atomic step (e.g., `-Tags audit` to replay the audit export scripts).                                                                                                         | `./run.ps1 -Tags audit -SpecPath ./spec.local.json` |
| `all`                                                                       | Convenience alias that expands to every tag listed above (runs everything end-to-end).                                                                                                                                                                                                                        | `./run.ps1 -Tags all -SpecPath ./spec.local.json` |

Use whichever combination suits your workflow (for example, `-Tags m365` from a workstation, then `-Tags dspm,defender,foundry` from Cloud Shell). Documenting the tags keeps the intent clear until we refactor or rename them.

## Run plan breakdown

`run.ps1` drives a fixed plan (see `$plan` in the script) so every atomic step of DSPM for AI and the Foundry control plane happens in a deterministic order. The table below expands each step, explaining both *what* the script does and *why* it matters.

| Order | Script | What happens | Why it matters for DSPM / Foundry |
| ----- | ------ | ------------- | --------------------------------- |
| 5 | `00-New-DspmSpec.ps1` | Generates or refreshes the spec contract (`spec.dspm.template.json`) and, by default, writes it to `-SpecPath`. | Keeps every run tied to a declared configuration so compliance/policy intent stays versioned and auditable. |
| 10 | `01-Ensure-ResourceGroup.ps1` | Confirms or creates the landing-zone resource group for Purview, Defender, diagnostics, and Foundry resources. | Guarantees there is a governed container before policies, RBAC, and diagnostics are layered on top. |
| 20 | `02-Ensure-PurviewAccount.ps1` | Ensures the Purview account exists and is configured per spec. | DSPM analytics, scans, and Secure interactions all depend on a healthy Purview account. |
| 30 | `10-Connect-Compliance.ps1` | Establishes the Exchange Online/Security & Compliance sessions. | Required to publish KYD, DLP, and retention artifacts that capture Foundry prompts/responses. |
| 40 | `11-Enable-UnifiedAudit.ps1` | Turns on Unified Audit (or verifies it). | Without Unified Audit the KYD policy cannot store interactions, so Purview/Defender lose lineage for Foundry chats. |
| 50 | `12-Create-DlpPolicy.ps1` | Creates or updates DLP/KYD policies from the spec. | Enforces the “Secure interactions for enterprise AI apps” control and routes Foundry prompts into governed mailboxes. |
| 60 | `13-Create-SensitivityLabel.ps1` | Publishes sensitivity labels referenced elsewhere in the spec. | Ensures scans and Foundry outputs inherit the right classification vocabulary. |
| 70 | `14-Create-RetentionPolicy.ps1` | Creates retention policies/rules for AI interaction data. | Keeps Foundry transcripts, audit exports, and downstream evidence governed for the required duration. |
| 80 | `03-Register-DataSource.ps1` | Registers data sources (storage, SQL, OneLake, Fabric) in Purview. | Gives DSPM observability across the data estate, including stores that power Foundry projects. |
| 90 | `04-Run-Scan.ps1` | Triggers Purview scans based on the registered sources. | Produces the sensitive-data findings that DSPM uses to prioritize recommendations tied to Foundry workloads. |
| 100 | `20-Subscribe-ManagementActivity.ps1` | Sets up Management Activity / audit exports. | Ships Purview audit telemetry so prompts, scans, and alerts can be reconstructed outside the tenant. |
| 110 | `21-Export-Audit.ps1` | Executes the actual audit export to storage/Fabric. | Creates external evidence proving Foundry prompts and policy actions were recorded. |
| 120 | `05-Assign-AzurePolicies.ps1` | Applies Azure Policy assignments from the spec. | Enforces guardrails (diagnostics, tags, encryption) on Purview and Foundry resources at scale. |
| 130 | `06-Enable-DefenderPlans.ps1` | Enables Defender for Cloud plans tied to AI/Fabric resources. | Lights up Defender for AI detections so Foundry projects inherit threat protection. |
| 140 | `07-Enable-Diagnostics.ps1` | Configures diagnostic settings/log pipelines. | Streams AI endpoint and Purview telemetry to Log Analytics/LA workspaces for SOC monitoring. |
| 150 | `25-Tag-ResourcesFromSpec.ps1` | Applies governance tags described in the spec. | Builds lineage between Azure resources and Purview/Foundry controls, making DSPM reports actionable. |
| 200 | `30-Foundry-RegisterResources.ps1` | Registers Foundry workspaces/projects in Purview DSPM. | Allows Purview DSPM to correlate “Secure interactions” recommendations with actual Foundry projects. |
| 210 | `31-Foundry-ConfigureContentSafety.ps1` | Deploys Content Safety blocklists/settings to Foundry projects. | Enforces the same prompt filtering across Foundry control plane artifacts that DLP provides in M365. |
| 220 | `17-Export-ComplianceInventory.ps1` | Captures compliance inventory outputs. | Produces a bundle of “day zero” evidence for auditors (labels, policies, scans) tied to Foundry. |
| 280 | `24-Create-BudgetAlert-Stub.ps1` | Placeholder for budget alerts. | Allows you to wire cost controls into the same run once your organization finalizes thresholds. |

> Fabric/OneLake scripts (`26-29`) remain commented out in the plan. Once those resources are onboarded, re-enable them so Fabric data surfaces alongside Foundry telemetry in DSPM.

## Spec management

- The repo tracks a sanitized contract in `spec.dspm.template.json`. Update it when the schema evolves so customers always have an authoritative sample.
- Create your working copy via `Copy-Item ./spec.dspm.template.json ./spec.local.json` (or the equivalent). This file is listed in `.gitignore` so it stays on your machine.
- Pass `-SpecPath ./spec.local.json` (or any other filename you choose) when running modules. `run.ps1` defaults to `./spec.local.json` and prints a friendly error if the file is missing.
- For multiple environments, create additional local files such as `spec.dev.json` and point `run.ps1 -SpecPath` to the one you need. Keep secrets in Key Vault rather than the spec.
- Fabric + OneLake placeholders live under `fabric.oneLakeRoots[]` and `fabric.workspaces[]`. Scripts `26-29` in `run.ps1` are commented out until they can gracefully ignore empty arrays, so populate these blocks now and uncomment the lines when you are ready to register/scan Fabric resources.
- Need to postpone an Azure Policy assignment? Set `"enabled": false` on that entry in `azurePolicies`. The assignment script logs the skip and leaves the declaration in place for later.
- Want a field-by-field explanation? See `docs/spec-local-reference.md` for the table that maps each spec parameter to the scripts that consume it.
- Know Your Data evidence flow is fully spec-driven: the `dlpPolicy`, `labels`, and `retentionPolicies` blocks define what the `m365` tag publishes, while `activityExport` controls the Management Activity/Audit offload that keeps KYD prompts and alerting in sync. See [Why DSPM for AI?](./docs/WhyDSPM.md) to understand the business value of each step.

---

## Component guides

- `scripts/governance/README.md` – Microsoft Purview DSPM automation cookbook (policies, scans, audit exports, Foundry integrations).
- `scripts/defender/README.md` – Defender for AI enablement and diagnostics.
- [Why DSPM for AI?](./docs/WhyDSPM.md) – Value proposition and stakeholder communication.
- [Cost Guidance](./docs/CostGuidance.md) – Billing models and optimization tips.

---

## Architecture overview



---

## Script families

| Folder                           | Purpose                                                                                         | Highlights                                                                                                           |
| -------------------------------- | ----------------------------------------------------------------------------------------------- | -------------------------------------------------------------------------------------------------------------------- |
| `scripts/governance`             | Spec management, Purview account bootstrap, policy creation, audit exports, Foundry integration | `00-New-DspmSpec.ps1`, `02-Ensure-PurviewAccount.ps1`, `12-Create-DlpPolicy.ps1`, `30-Foundry-RegisterResources.ps1` |
| `scripts/defender/defenderForAI` | Enable Defender for Cloud AI plans, diagnostics, and integrations                               | `06-Enable-DefenderPlans.ps1`, `07-Enable-Diagnostics.ps1`                                                           |
| `scripts/exchangeOnline`         | Security and Compliance PowerShell prerequisites (behind the `m365` tag)                        | `10-Connect-Compliance.ps1`, `11-Enable-UnifiedAudit.ps1`                                                            |

Each script is idempotent and checks for prerequisites before applying changes. Combine them in CI, during `azd up`, or as one-off remediation tools.

---

## Post provisioning

**Manual Purview action (until API support ships):** after `30-Foundry-RegisterResources.ps1` and `31-Foundry-ConfigureContentSafety.ps1` finish, sign into the Purview portal and navigate to **Data Security Posture > Recommendations > Secure interactions for enterprise AI apps** (a.k.a. **Capture interactions for enterprise AI apps**). Enable the recommendation once and Purview automatically applies it to every Azure AI Foundry account/project as those resources appear. The "Enable Data Security for AI Interactions" switch cannot be set via API yet, so this manual step is required to collect Foundry chat interactions (see [Use Microsoft Purview to manage data security & compliance for Microsoft Foundry](https://learn.microsoft.com/en-us/purview/ai-azure-foundry#getting-started-recommended-steps)).

---

## Next steps

1. Populate `spec.dspm.template.json` as the customer-facing contract and keep per-environment copies such as `spec.local.json` out of source control (store secrets in Key Vault).
2. Wire the atomic modules into your CI/CD or Azure Developer CLI pipeline by calling `run.ps1` with the appropriate tags.
3. Extend the stubs (`15-Create-SensitiveInfoType-Stub.ps1`, `23-Ship-AuditToFabricLakehouse-Stub.ps1`, `32-Foundry-GenerateBindings-Stub.ps1`) to meet organization-specific requirements.

With the spec as the contract, the accelerator keeps Microsoft 365 compliance, Defender telemetry, and Azure AI workloads aligned so AI apps stay governed from prompt to production.


