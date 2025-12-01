# AI Governance Value Narrative

Use this story when a customer asks, "What business value do we unlock by running the accelerator?" The narrative ties every automation step to measurable outcomes anchored in current Microsoft Learn guidance (Nov 2025).

## Headline value
1. **Capture every Foundry prompt inside the compliance boundary you already trust.** Purview DSPM for AI plus Unified Audit (per [Use Microsoft Purview to manage data security & compliance for Microsoft Foundry](https://learn.microsoft.com/en-us/purview/ai-azure-foundry)) stores chats/responses in the user mailbox so retention, eDiscovery, Insider Risk, Communication Compliance, and Data Lifecycle Management all see the same evidence trail.
2. **Prevent data loss before it hits an LLM.** Endpoint/M365 DLP policies (published via the `m365` tag) block or warn when users paste sensitive data into Foundry prompts or third-party LLM UIs, while Content Safety/Defender for AI detect jailbreak attempts and exfiltration patterns. AI builders can innovate without accidentally spraying source code or regulated data into model memory.
3. **Prove data safeguards for regulators in hours, not quarters.** Spec-driven run logs show exactly when you enabled "Secure data in Azure AI apps and agents," turned on Defender for AI plans, wired diagnostics, and exported evidence packages (`17-Export-ComplianceInventory.ps1`, `21-Export-Audit.ps1`). Auditors see a repeatable control, not tribal knowledge.
4. **Accelerate safe AI adoption without slowing product teams.** Tags, diagnostics, and Content Safety settings are deployed per project via automation, so AI teams keep iterating while security teams inherit alerts, recommendations, and insider-risk signals automatically.

## Value storyline
1. **Codify intent** – The spec is a signed contract between security, compliance, and the AI team. Every field (Foundry project, Content Safety profile, retention window) maps to a script, so there is no ambiguity when auditors ask "who approved what?"
2. **Turn on capture** – The `m365` tag publishes the Know Your Data collection policy Microsoft calls **DSPM for AI - Capture interactions for enterprise AI apps**, plus DLP/label/retention rules that stop sensitive uploads to LLMs and keep AI chats under retention.
3. **Register & scan** – `foundation,dspm` tags register data sources and kick off scans so DSPM dashboards light up with sensitive data locations, risk heat maps, and recommendation tracking for the new Foundry estate.
4. **Harden runtime surfaces** – `defender,foundry` tags enable Defender for AI plans, diagnostics, governance tags, and the "Secure data in Azure AI apps and agents" recommendation callouts. SOC teams now get posture drift alerts plus AI-specific detections (prompt injection, jailbreak, exfiltration).
5. **Extend DLP to endpoints & third-party LLMs** – Endpoint DLP (on boarded devices) can warn or block when users try to paste secrets into any generative AI site; the same policies publish through the spec so security doesn’t hand-edit rules.
6. **Package evidence** – Exports and compliance inventory snapshots are created on-demand. Customers leave every engagement with artifacts they can attach to change tickets, regulator responses, or ISO attestations.

## Talking points by persona
- **CISO / Compliance Officer** – "We can now demonstrate end-to-end control: prompts enter Purview via Unified Audit, data classification applies, Endpoint/M365 DLP stops sensitive uploads to LLMs, and every Foundry project inherits retention without manual rework."
- **Security Operations** – "Defender for AI telemetry streams into the existing Log Analytics workspace; no new SIEM connector, no blind spots. Prompt evidence links directly to the user principal, and Content Safety alerts show when someone tries to exfiltrate data via an AI agent."
- **AI Product Owner** – "Spec-driven onboarding means standing up a new Foundry project is as simple as adding resource IDs to `spec.local.json` and rerunning the relevant tags. Governance keeps pace with delivery, and policy owners can approve changes via the spec instead of slowing releases."
- **Privacy / Legal** – "Retention, DLP, and Insider Risk policies extend to AI interactions automatically, so we can prove no customer data ended up in model training sets or third-party chat logs."

## Proof hooks
- **Metrics to capture**: time to enable Secure Interactions, number of Foundry projects onboarded per run, number of sensitive prompts blocked or flagged via Content Safety/DLP, audit export freshness, count of endpoint DLP warnings on AI domains.
- **Artifacts to share**: run log (`logs/governance/*.log`), Purview DSPM recommendation screenshot, Defender for AI plan status, exported audit/compliance inventory zip files.
- **Next step CTA**: schedule a Day Zero run where customer operators follow the quick-start in README.md, then review evidence together within 24 hours.
