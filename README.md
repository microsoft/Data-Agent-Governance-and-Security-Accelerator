# AI Governance and Security Accelerator

This accelerator knits together Microsoft 365, Microsoft Purview, Microsoft Defender for Cloud, Azure AI Foundry, and ChatGPT Enterprise so AI solutions inherit the same governance and security posture as the rest of the enterprise. All automation is spec driven: copy the shared template (`spec.dspm.template.json`) to an environment-specific file (for example `spec.local.json`) that feeds the atomic PowerShell modules provisioning resources, enabling compliance controls, and lighting up monitoring across tenants.

- **Purview DSPM for AI** discovers, classifies, and protects data used by AI workloads in Microsoft 365, Fabric, OneLake, and connected Azure services.
- **Defender for AI** enables threat detection (prompt injection, jailbreak, exfiltration) and routes evidence into SIEM or Purview.
- **Azure AI Foundry + ChatGPT Enterprise** gain Content Safety policies, audit trails, and resource tagging so every prompt, response, and deployment can be governed.

---

## How the story comes together

1. **Author the spec** – capture tenant, subscriptions, Purview account, Azure AI assets, data sources, and compliance intent in your local copy (for example `spec.local.json`).
2. **Run atomic modules** – invoke only the scripts you need (or call `run.ps1` with tags) to ensure prerequisites, enable compliance services, create policies, and register data sources.
3. **Validate posture** – use the verification modules to confirm Defender plans, audit ingestion, and Purview policy status, then hand the spec to ops for day-two governance.

---

## Capabilities at a glance

- **Purview Data Security Posture Management (DSPM) for AI**: register storage, SQL, OneLake, and Fabric workspaces, trigger Purview DSPM for AI scans, and apply sensitivity labels, DLP policies, and retention rules so AI workloads (Azure AI Foundry and ChatGPT Enterprise) inherit Microsoft Purview’s DSPM controls.
- **Security posture**: assign Azure Policies, enable Defender for Cloud plans, and ship diagnostics to Log Analytics for continuous monitoring of AI endpoints.
- **Compliance evidence**: subscribe to the Management Activity API, export audit logs, and push transcripts into storage or Fabric for downstream analytics.
- **Application guardrails**: configure Content Safety blocklists, tag Azure resources with compliance metadata, and lay the groundwork for AI prompt filtering in ChatGPT Enterprise.


## DSPM for AI & Defender for AI — Features and Benefits Mapping

| **Environment Component** | **Secured Asset (What It Protects)** | **Product** | **Required / Optional** | **Key Features** | **Business Benefits** |
|---|---|---|---|---|---|
| **Azure AI Foundry** | AI interactions (prompts & responses), workspaces, connections to data sources | Microsoft Purview **DSPM for AI** | **Required** | Centralized discovery of AI interactions; sensitivity classification & labeling; DLP on prompts/responses; audit & eDiscovery integration | Prevents sensitive-data leakage via AI; enforces consistent data handling; accelerates investigations and compliance reporting |
| **Azure OpenAI / Azure ML (AI runtime)** | Model endpoints, prompt flow apps, deployments, keys/secrets linkage | **Defender for AI** | **Required** | AI-specific threat detection and posture hardening; misconfiguration findings; attack-path/context analysis for AI components | Reduces breach risk and configuration drift; shortens time-to-detect and time-to-remediate for AI workloads |
| **Microsoft Fabric OneLake** | Tables/files (Delta/Parquet), Lakehouse/Warehouse data, Domains | Microsoft Purview (Info Protection + DLP) & **DSPM for AI** | **Required** | Sensitivity labels; **DLP for structured data in OneLake**; label coverage goals & reports; activity monitoring | Enforces least-privilege & prevents oversharing; provides measurable posture improvements and evidence for audits |
| **Fabric Workspaces & Items** | Workspaces, Dataflows, Datasets, Notebooks, Pipelines | Fabric native RBAC + Microsoft Purview integrations | **Required** | Workspace/item security; default label per domain; end-to-end auditability with Purview; federated governance between **OneLake Catalog** and Purview Unified Catalog | Consistent guardrails for self-service analytics; clear ownership; end-to-end traceability for regulated data operations |
| **Fabric AI Experiences (e.g., Copilot in Fabric)** | AI-generated insights & Q&A over governed data | Microsoft Purview **DSPM for AI** | **Optional** (becomes **Required** for regulated use) | Oversharing prevention in AI experiences; policy evaluation before/around AI actions; audit of interaction data | Safe, governed self-service AI analytics without exposing sensitive data; audit-ready usage trails |
| **Cross‑estate AI Interactions (enterprise AI apps & agents)** | Prompt/response interaction data spanning Copilot, custom agents, and registered AI apps | Microsoft Purview **DSPM for AI** | **Required** | Unified view of where AI interactions occur; policy enforcement across multiple AI entry points; natural-language risk exploration | Single control plane for AI data risks; consistent compliance across heterogeneous AI surfaces |

---

## Quick start

1. **Clone and install tooling** (PowerShell 7, Azure CLI) in your preferred shell.
2. **Review the spec template** – the repo includes `spec.dspm.template.json` (generated by `scripts/governance/00-New-DspmSpec.ps1`). Update it if the schema changes:
  ```powershell
  pwsh ./scripts/governance/00-New-DspmSpec.ps1 -OutFile ./spec.dspm.template.json
  ```
3. **Fill in parameters** – copy `spec.dspm.template.json` to `spec.local.json`, populate tenant and resource IDs, and keep the local file untracked (see below).
4. **Execute the modules** (examples shown; run from the repo root):
   ```powershell
  # Azure foundation and Purview
  pwsh ./scripts/governance/01-Ensure-ResourceGroup.ps1 -SpecPath ./spec.local.json
  pwsh ./scripts/governance/dspmPurview/02-Ensure-PurviewAccount.ps1 -SpecPath ./spec.local.json

  # Exchange Online / Compliance (run from a desktop session capable of MFA)
  ./run.ps1 -Tags m365 -SpecPath ./spec.local.json   # from PowerShell; use "pwsh ./run.ps1" if invoking from bash/zsh

  # Policies, scans, and governance
  pwsh ./scripts/governance/dspmPurview/03-Register-DataSource.ps1 -SpecPath ./spec.local.json
  pwsh ./scripts/governance/dspmPurview/04-Run-Scan.ps1 -SpecPath ./spec.local.json

  # AI security posture
  pwsh ./scripts/defender/defenderForAI/06-Enable-DefenderPlans.ps1 -SpecPath ./spec.local.json
  pwsh ./scripts/defender/defenderForAI/07-Enable-Diagnostics.ps1 -SpecPath ./spec.local.json

  # Foundry and Content Safety
  pwsh ./scripts/governance/dspmPurview/30-Foundry-RegisterResources.ps1 -SpecPath ./spec.local.json
  pwsh ./scripts/governance/dspmPurview/31-Foundry-ConfigureContentSafety.ps1 -SpecPath ./spec.local.json

  # Optional orchestrator (filters by tag)
  ./run.ps1 -Tags m365 -SpecPath ./spec.local.json   # from PowerShell; use "pwsh ./run.ps1" if invoking from bash/zsh
  ./run.ps1 -Tags dspm,defender,foundry -SpecPath ./spec.local.json

    ```

5. **Review dashboards** in Purview and Defender, then export evidence with `17-Export-ComplianceInventory.ps1`, `21-Export-Audit.ps1`, and `34-Validate-Posture.ps1`.

## Running inside GitHub Codespaces

- **Why split the execution?** Modules in `scripts/exchangeOnline` call `Connect-IPPSSession`, which opens an interactive Security & Compliance sign-in window. Codespaces containers are headless, so the prompt never renders and those scripts hang. Running the `m365` tag from a local workstation avoids the problem because the browser-based MFA flow launches normally on your desktop.
- **Step 1 – Local workstation:** Open PowerShell 7, install `ExchangeOnlineManagement` if needed, sign in with `Connect-IPPSSession`, then execute `./run.ps1 -Tags m365 -SpecPath ./spec.local.json` (from PowerShell use `./run.ps1 ...`; from bash/zsh use `pwsh ./run.ps1 ...`). This completes audit enablement, DLP, sensitivity labels, and retention policies.
- **Step 2 – Codespaces container:** From the authenticated Codespaces PowerShell session, run `./run.ps1 -Tags dspm defender foundry -SpecPath ./spec.local.json`. These tags cover Azure resource provisioning, Defender plans, diagnostics, and Purview DSPM tasks that only rely on Az modules.
- **Optional automation:** If you configure certificate-based auth for Exchange Online, you can export the app settings into the container and run `-Tags m365` there; otherwise treat it as a prerequisite before running remaining tags in Codespaces.

## Spec management

- The repo tracks a sanitized contract in `spec.dspm.template.json`. Update it when the schema evolves so customers always have an authoritative sample.
- Create your working copy via `Copy-Item ./spec.dspm.template.json ./spec.local.json` (or the equivalent). This file is listed in `.gitignore` so it stays on your machine.
- Pass `-SpecPath ./spec.local.json` (or any other filename you choose) when running modules. `run.ps1` defaults to `./spec.local.json` and prints a friendly error if the file is missing.
- For multiple environments, create additional local files such as `spec.dev.json` and point `run.ps1 -SpecPath` to the one you need. Keep secrets in Key Vault rather than the spec.

---

## Component guides

- `scripts/governance/README.md` – Microsoft Purview DSPM automation cookbook (policies, scans, audit exports, Foundry integrations).
- `scripts/defender/README.md` – Defender for AI enablement and diagnostics.
- `docs/dspm-sales-narrative.md` – business outcome framing for stakeholders.
- `docs/payGo.md` – optional PAYG cost considerations.

---

## Architecture overview

```
M365 Compliance Boundary
  ├─ Microsoft Purview DSPM for AI
  │    ├─ Know Your Data policies (DLP, sensitivity, retention)
  │    ├─ Audit ingestion + Management Activity exports
  │    └─ Compliance role assignments
  └─ ChatGPT Enterprise + Teams, Exchange, SharePoint workloads
          │ governed via Purview policies and audit
          ▼
Azure Landing Zone
  ├─ Purview account + Log Analytics workspace
  ├─ Azure AI Foundry projects (tagged, content safety enabled)
  ├─ Azure OpenAI, Cognitive Services, Fabric, OneLake
  └─ Defender for Cloud plans + diagnostics
          │ telemetry and governance metadata flow
          ▼
Operations & Monitoring
  ├─ Spec-driven automation (PowerShell modules)
  ├─ Audit exports to Storage or Fabric Lakehouse
  └─ Posture validation scripts for day-two operations
```

---

## Script families

| Folder | Purpose | Highlights |
|--------|---------|------------|
| `scripts/governance` | Spec management, Purview account bootstrap, policy creation, audit exports, Foundry integration | `00-New-DspmSpec.ps1`, `02-Ensure-PurviewAccount.ps1`, `12-Create-DlpPolicy.ps1`, `30-Foundry-RegisterResources.ps1` |
| `scripts/defender/defenderForAI` | Enable Defender for Cloud AI plans, diagnostics, and integrations | `06-Enable-DefenderPlans.ps1`, `07-Enable-Diagnostics.ps1` |
| `scripts/exchangeOnline` | Security and Compliance PowerShell prerequisites (behind the `m365` tag) | `10-Connect-Compliance.ps1`, `11-Enable-UnifiedAudit.ps1` |

Each script is idempotent and checks for prerequisites before applying changes. Combine them in CI, during `azd up`, or as one-off remediation tools.

---

## Prerequisites

- PowerShell 7 and Azure CLI authenticated to the target subscriptions.
- Microsoft 365 E5 (or E5 compliance) license assigned to an operator with Compliance Administrator and Purview Data Source Administrator rights.
- Exchange Online Management module installed on a workstation capable of satisfying MFA for audit enablement steps.
- Run the Exchange Online steps (`run.ps1 -Tags m365`) from that workstation; containerized environments without a browser should execute the remaining tags (`dspm`, `defender`, `foundry`) separately. If you're staying on the desktop, you can combine everything in one go:
  ```powershell
  ./run.ps1 -Tags m365,dspm,defender,foundry -SpecPath ./spec.local.json
  # or, from bash/zsh: pwsh ./run.ps1 -Tags m365,dspm,defender,foundry -SpecPath ./spec.local.json
  ```
- Azure RBAC permissions: Contributor on the subscription that hosts Purview, AI Foundry, and Defender resources.

---

## Next steps

1. Populate `spec.dspm.template.json` as the customer-facing contract and keep per-environment copies such as `spec.local.json` out of source control (store secrets in Key Vault).
2. Wire the atomic modules into your CI/CD or Azure Developer CLI pipeline by calling `run.ps1` with the appropriate tags.
3. Extend the stubs (`15-Create-SensitiveInfoType-Stub.ps1`, `23-Ship-AuditToFabricLakehouse-Stub.ps1`, `32-Foundry-GenerateBindings-Stub.ps1`) to meet organization-specific requirements.

With the spec as the contract, the accelerator keeps Microsoft 365 compliance, Defender telemetry, and Azure AI workloads aligned so AI apps stay governed from prompt to production.
