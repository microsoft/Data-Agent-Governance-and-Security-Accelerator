# DSPM + Defender for AI Narrative Guide

Use this supplement when briefing sellers, technical specialists, or customer champions. Each section pairs the **what** and **why** for every automation step so teams can frame the value in plain language.

### Latest Microsoft Learn signals (Nov 2025)
- [Use Microsoft Purview to manage data security & compliance for Microsoft Foundry](https://learn.microsoft.com/en-us/purview/ai-azure-foundry) now calls out the **Secure data in Azure AI apps and agents** recommendation plus the **DSPM for AI – Capture interactions for enterprise AI apps** one-click policy. Reference these names whenever you describe the Know Your Data (Secure Interactions) automation.
- The same article reiterates that prompts/responses flow through Unified Audit and land in the user’s mailbox, and that capturing those events requires a [collection policy](https://learn.microsoft.com/en-us/purview/collection-policies-solution-overview). Step 3 below maps directly to that guidance.
- Defender for Cloud onboarding guidance now lists “Enable data security for Azure AI with Microsoft Purview” as the prerequisite switch. Tie Steps 5–8 back to this wording so customers can cross-check in the Azure portal.

---

## 1. Prep the Spec in PowerShell 7
- **What happens**: From a local PowerShell 7 (`pwsh`) session we copy `spec.dspm.template.json` to `spec.local.json`, fill in tenant/subscription/resource IDs, and (optionally) rerun `pwsh ./scripts/governance/00-New-DspmSpec.ps1` whenever the schema changes so automation and documentation stay in sync.
- **Why it matters**: The spec is the contract every script consumes. Working locally in PowerShell 7 avoids Windows PowerShell module conflicts and ensures the same file drives governance across Purview, Defender, and Azure AI workloads.

---

- **What happens**: We run `pwsh ./run.ps1 -Tags m365 -SpecPath ./spec.local.json` (or the individual Exchange Online scripts) from the same local PowerShell 7 shell to confirm Unified Audit is on, flip the DSPM for AI switches, and log exactly which prerequisites passed.
- **Why it matters**: Audit is the compliance safety net. Running these steps locally—with MFA-capable PowerShell 7—guarantees the Exchange Online modules load, the operator can finish interactive sign-in, and the DSPM for AI toggles are verified before touching AI resources.

---

- **What happens**: `create_dspm_policies.ps1` (or the `m365` tag) loads the Exchange Online PowerShell module, connects to the compliance endpoint, and creates the "Secure interactions from enterprise apps" policy—the same one-click policy Learn lists as **DSPM for AI - Capture interactions for enterprise AI apps**.
- **Why it matters**: DSPM does not store prompts on its own. Microsoft explicitly says captured prompts/responses live in the user's mailbox so they inherit retention, eDiscovery, and Communication Compliance. The Exchange Online cmdlets are the bridge that turns on that capture and satisfy the [collection policy requirement](https://learn.microsoft.com/en-us/purview/collection-policies-solution-overview).

---

## 4. Portal Policies (Communication Compliance & Insider Risk)
- **What happens**: The script prints a checklist, then admins finish the two remaining policies in the Purview portal.
- **Why it matters**: These policies are still UI-only in preview. Calling them out prevents a false sense of "automation done" and keeps security/compliance owners in the loop.

---

- **What happens**: `connect_dspm_to_ai_foundry.ps1` enumerates Azure AI Foundry workspaces/projects, records IDs, and tells admins how to toggle the integration inside Azure AI Foundry (the Learn doc now labels this recommendation **Secure data in Azure AI apps and agents**).
- **Why it matters**: This is the handshake between runtime AI projects and governance. Without it, DSPM sees zero interactions and the customer assumes the feature "doesn't work."

---

## 6. Verify DSPM Configuration
- **What happens**: `verify_dspm_configuration.ps1` replays the critical checks (KYD policy, audit flag, compliance connectivity) and summarizes the state.
- **Why it matters**: Customers learn exactly what succeeded, what is pending, and where to look in the Purview portal. This is the "trust but verify" moment for security owners.

---

## 7. Defender for Cloud CSPM + Defender for AI Plans
- **What happens**: `enable_defender_for_cloud.ps1` and `enable_defender_for_ai.ps1` register providers and switch on the AI plan, reporting back which AI services are now protected.
- **Why it matters**: Defender for Cloud is where threat protection and posture scoring show up. Turning on the AI plan is the ticket to user prompt evidence, risk analytics, and correlation across data security and threat detection.

---
## 8. User Prompt Evidence & Purview Integration
- **What happens**: The scripts attempt the preview APIs; if unavailable, they log the portal path to enable user prompt evidence and the Purview integration toggle—matching Learn’s "Enable data security for Azure AI with Microsoft Purview" prerequisite in Defender for Cloud.
- **Why it matters**: These previews light up the correlated dashboards in Defender and Purview. Without them, customers cannot trace malicious prompts back to the human that sent them.

---

## 9. Post-Run Summary & Logs
- **What happens**: `invoke-governance-automation.ps1` prints `[governance-run]` success/failure lines and saves the full transcript under `logs/governance/`.
- **Why it matters**: Operators leave the session with a snapshot they can paste into a ticket, email, or meeting notes. It is proof of work and a diagnostic starting point if something failed.

---

## 10. Storyboard for Sellers
Use this three-sentence elevator pitch when positioning the solution:
1. **"We wire your AI estate into Purview so every prompt lives inside the same trusted compliance boundary as email and Teams."**
2. **"We turn on Defender for AI so threats, data security, and user-level evidence sit in one dashboard your SOC already uses."**
3. **"We leave you with a run log, a manual checklist, and Microsoft Learn links so your admins can finish any previews Microsoft still keeps in the portal."**

Highlight that each automation step corresponds to Microsoft guidance�"nothing proprietary or black-box�"and that the scripts exist to remove toil while respecting the customer's approval gates.

