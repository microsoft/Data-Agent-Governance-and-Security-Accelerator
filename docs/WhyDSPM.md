# Why DSPM for AI? — Value Proposition Guide

This guide explains **what each automation step does** and **why it matters** for your organization. Use it to understand the business value of the accelerator and communicate it to stakeholders, security teams, and compliance officers.

---

## Understanding the Two Governance Paths

> **Critical Distinction:** This accelerator supports two *different* AI governance scenarios with *different* underlying mechanisms. Choose the path that matches your workload.

| Scenario | What's Governed | How It Works | Tags to Run |
|----------|-----------------|--------------|-------------|
| **M365 Copilot & 3rd-Party AI Apps** | Microsoft 365 Copilot, ChatGPT, other browser-based AI | Purview DSPM captures prompts/responses and routes them to **user mailboxes** for retention, eDiscovery, and DLP | `m365` |
| **Azure AI Foundry & Custom Agents** | Azure OpenAI, Cognitive Services, custom agentic solutions | Defender for AI monitors via **diagnostic telemetry** to Log Analytics; Purview registers data sources for classification | `defender`, `foundry` |

### Key Differences

| Aspect | M365 Copilot Path | Azure AI Foundry Path |
|--------|-------------------|----------------------|
| **Where prompts are stored** | User mailboxes (Exchange Online) | Log Analytics workspace (diagnostic logs) |
| **Retention mechanism** | M365 retention policies | Log Analytics retention settings |
| **eDiscovery** | Yes (via Purview eDiscovery) | No (requires custom export) |
| **DLP enforcement** | Yes (Purview DLP policies) | No (Content Safety blocklists instead) |
| **Threat detection** | Purview Insider Risk + Defender | Defender for AI only |
| **Licensing required** | M365 E5 or E5 Compliance | Azure subscription |

### Choose Your Path

- **"I want to govern M365 Copilot and browser-based AI apps"** → Run `m365` tag from a desktop with MFA
- **"I want to protect Azure AI Foundry projects only"** → Run `defender,foundry` tags (no M365 license needed)
- **"I want both"** → Run all tags, understanding that governance mechanisms differ per workload

---

## The Bottom Line

**What this accelerator does for you:**

| If you're protecting... | The accelerator... |
|------------------------|-------------------|
| **M365 Copilot / 3rd-party AI** | Wires your AI interactions into Purview so prompts live inside the same compliance boundary as email and Teams—subject to retention, eDiscovery, and DLP |
| **Azure AI Foundry** | Enables Defender for AI threat detection, streams diagnostics to Log Analytics, and applies Content Safety guardrails—but prompts do NOT flow to mailboxes |
| **Both** | Configures both paths, giving you unified visibility in Defender for Cloud while maintaining the distinct governance mechanisms |

Every automation step corresponds to official Microsoft guidance—nothing proprietary or black-box. The scripts exist to remove toil while respecting your organization's approval gates.

---

## Official Microsoft Learn References

These links validate the automation steps below:

- [Use Microsoft Purview to manage data security & compliance for Microsoft Foundry](https://learn.microsoft.com/en-us/purview/ai-azure-foundry) — Documents the **Secure data in Azure AI apps and agents** recommendation and the **DSPM for AI – Capture interactions for enterprise AI apps** policy
- [Collection policies overview](https://learn.microsoft.com/en-us/purview/collection-policies-solution-overview) — Explains why capturing prompts/responses requires explicit policy configuration (M365 path only)
- [Defender for AI documentation](https://learn.microsoft.com/en-us/azure/defender-for-cloud/ai-threat-protection) — Threat protection for Azure AI services
- Defender for Cloud guidance lists **"Enable data security for Azure AI with Microsoft Purview"** as a prerequisite switch

---

## Step-by-Step Value Breakdown

### Step 1: Prepare the Configuration Spec

| What Happens | Why It Matters |
|--------------|----------------|
| Copy `spec.dspm.template.json` to `spec.local.json` and populate with your tenant, subscription, and resource IDs. Optionally regenerate the template when the schema changes. | **The spec is your single source of truth.** Every script consumes it, ensuring consistent governance across Purview, Defender, and Azure AI workloads. One file drives everything. |

---

## M365 Copilot Path (Steps 2-4)

> **These steps apply to M365 Copilot and 3rd-party AI apps.** Skip to Step 5 if you're only protecting Azure AI Foundry.

### Step 2: Enable Unified Audit and M365 Prerequisites

| What Happens | Why It Matters |
|--------------|----------------|
| Run `./run.ps1 -Tags m365` to confirm Unified Audit is enabled, activate DSPM for AI switches, and log which prerequisites passed. | **Audit is the M365 compliance safety net.** Without it, Copilot interactions won't be captured. This step guarantees the M365 foundation is solid. |

---

### Step 3: Create the Secure Interactions Policy

| What Happens | Why It Matters |
|--------------|----------------|
| The automation creates the "Secure interactions from enterprise apps" policy—the same one-click policy Microsoft Learn calls **DSPM for AI - Capture interactions for enterprise AI apps**. | **This is M365-specific.** Microsoft routes M365 Copilot prompts/responses to user mailboxes so they inherit your existing retention, eDiscovery, and Communication Compliance controls. Azure AI Foundry prompts do NOT flow through this path. |

---

### Step 4: Complete Portal-Only M365 Policies

| What Happens | Why It Matters |
|--------------|----------------|
| The script prints a checklist of policies that must be finished in the Purview portal (Communication Compliance, Insider Risk). | **Some M365 features are still UI-only.** Calling them out prevents a false sense of "automation complete" and keeps compliance owners in the loop. |

---

## Azure AI Foundry Path (Steps 5-8)

> **These steps apply to Azure AI Foundry and custom AI solutions.** They use Defender for AI and diagnostics, NOT mailbox-based capture.

### Step 5: Register Foundry Resources with Purview

| What Happens | Why It Matters |
|--------------|----------------|
| The automation enumerates your Azure AI Foundry workspaces and projects, registers them as Purview data sources, and enables the **Secure data in Azure AI apps and agents** toggle. | **This connects Foundry to governance—but differently than M365.** Purview can classify data in Foundry resources, but prompts are NOT routed to mailboxes. Telemetry flows to Defender and Log Analytics instead. |

---

### Step 6: Verify Configuration

| What Happens | Why It Matters |
|--------------|----------------|
| A verification script checks Foundry registration, Defender plan status, and diagnostic settings, then summarizes the state. | **Trust but verify.** You see exactly what succeeded and what's pending. This is the validation checkpoint before declaring success. |

---

### Step 7: Enable Defender for Cloud + Defender for AI

| What Happens | Why It Matters |
|--------------|----------------|
| The automation registers providers and enables the Defender for AI plan, reporting which AI services are now protected. | **Defender is where Foundry threat protection lives.** It detects prompt injection, jailbreaks, and data exfiltration—but through diagnostic telemetry, not mailbox monitoring. |

---

### Step 8: Enable User Prompt Evidence & Purview Integration

| What Happens | Why It Matters |
|--------------|----------------|
| Scripts attempt preview APIs; if unavailable, they log the portal path to enable user prompt evidence and the Purview integration toggle in Defender for Cloud. | **This connects Defender to Purview for Foundry workloads.** Without it, you can detect a malicious prompt but can't correlate it with Purview's data classification. Note: This is different from the M365 mailbox-based capture. |

---

## Both Paths (Step 9)

### Step 9: Review Logs and Evidence

| What Happens | Why It Matters |
|--------------|----------------|
| The orchestrator prints success/failure lines and saves full transcripts under `logs/governance/`. | **Proof of work.** You leave the session with a snapshot you can attach to a change ticket, email to auditors, or use as a diagnostic starting point if something fails later. |

---

## Summary: What You Get Per Path

| Capability | M365 Copilot Path | Azure AI Foundry Path |
|------------|-------------------|----------------------|
| **Prompt/response capture** | Yes - To user mailboxes | No - Diagnostic logs only |
| **Retention policies** | Yes - M365 retention | Partial - Log Analytics retention (configure separately) |
| **eDiscovery** | Yes - Purview eDiscovery | No - Requires custom export from Log Analytics |
| **DLP enforcement** | Yes - Purview DLP policies | No - Use Content Safety blocklists instead |
| **Sensitivity labels** | Yes - Applied to captured content | Partial - Applied to Foundry data sources (classification only) |
| **Threat detection** | Yes - Insider Risk + Defender | Yes - Defender for AI |
| **Prompt injection detection** | Partial - Via Communication Compliance | Yes - Defender for AI native capability |
| **Required licensing** | M365 E5 or E5 Compliance | Azure subscription (PAYG) |

---

## Who Should Care?

| Stakeholder | M365 Copilot Path | Azure AI Foundry Path |
|-------------|-------------------|----------------------|
| **CISO / Security Leadership** | AI interactions governed by same controls as email—no shadow AI visibility gaps | Threat detection and posture management via Defender for Cloud |
| **Compliance Officers** | Prompts subject to retention, eDiscovery, and DLP—audit-ready from day one | Diagnostic logs available for export; no built-in eDiscovery |
| **SOC / Security Operations** | Insider Risk and Communication Compliance alerts | Defender for AI alerts in the same console they already use |
| **AI/ML Platform Teams** | N/A (M365 managed by IT) | Governance automated—focus on building, not configuring compliance |
| **IT Operations** | One spec file, one run—deterministic M365 policy deployment | One spec file, one run—Defender + diagnostics configured |

---

## Common Objections Addressed

| Objection | Response |
|-----------|----------|
| "We don't know what AI apps our users are accessing" | **M365 path:** DSPM for AI discovers AI interactions across M365 Copilot and third-party AI apps accessed via browser. **Foundry path:** You define which Foundry projects to monitor in your spec. |
| "We only use Azure AI Foundry, not Copilot" | Perfect—run `defender,foundry` tags only. No M365 license required. You get threat detection and diagnostics without the M365 overhead. |
| "Adding governance will slow down our AI initiatives" | The automation runs in minutes and doesn't block AI workloads—it observes and protects |
| "We already have DLP—why do we need this?" | **M365 path:** Traditional DLP doesn't see AI prompts. DSPM extends your existing policies to cover AI-specific data flows. **Foundry path:** Use Content Safety blocklists instead of DLP. |
| "This seems complex" | The accelerator reduces 50+ portal clicks to a single `azd up` command with a config file |
| "Do Foundry prompts go to user mailboxes?" | **No.** Only M365 Copilot/3rd-party AI interactions route to mailboxes. Foundry telemetry goes to Log Analytics via diagnostics. |

---

## Next Steps

1. **Review the [README](../README.md)** for deployment options
2. **Follow the [Deployment Guide](./DeploymentGuide.md)** for step-by-step setup
3. **Check the [Troubleshooting Guide](./TroubleshootingGuide.md)** if you hit issues
4. **Review [Cost Guidance](./CostGuidance.md)** to understand billing implications
