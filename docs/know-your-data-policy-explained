### What is KYD Policy in Purview?

KYD (Know Your Data) is a foundational capability in Microsoft Purview that:

Discovers and classifies sensitive data across Microsoft 365 and connected sources.
Uses sensitive information types, classifiers, and labels to identify regulated or confidential content.
Enables risk-based policies for AI interactions (e.g., Copilot prompts and outputs) by applying data governance rules.


In DSPM for AI, KYD ensures that Copilot interactions respect sensitivity labels and compliance policies. For example:

If a document is labeled “Highly Confidential,” KYD ensures prompts referencing that document are flagged or restricted.


KYD policies integrate with:

Microsoft Purview Information Protection (for sensitivity labels).
DLP and Insider Risk Management (for enforcement).
Audit and Communication Compliance (for monitoring).

### How KYD Policy Works with Azure Foundry Accounts

KYD (Know Your Data) in Microsoft Purview is about discovering and classifying sensitive data across your environment, including AI interactions.
When you use Azure AI Foundry to build or deploy AI apps and agents, Purview can extend KYD principles to those apps:

It classifies sensitive data accessed or processed by Foundry-based AI agents.
It applies sensitivity labels and compliance rules to prompts, responses, and any data used at runtime.

KYD policies in DSPM for AI include recommendations like:

Secure interactions from enterprise apps (preview) – ensures prompts and outputs respect sensitivity labels.
Detect risky AI usage – flags oversharing or unethical behavior in AI interactions.

### Do You Need KYD Enabled to Use DSPM in Purview?
Yes, KYD is a core component of DSPM for AI:

DSPM for AI uses KYD to identify sensitive data in AI prompts and outputs.
Without KYD, DSPM cannot classify or apply sensitivity-based controls to AI interactions.
To enable DSPM for AI fully, you must:

Activate Microsoft Purview Audit (for logging interactions).
Enable KYD policy (e.g., “Secure interactions from enterprise apps”).
Optionally enable other compliance policies like Insider Risk and Communication Compliance.

### Integration with Azure Foundry

Foundry projects and agents can integrate with Purview natively:

Admins can turn on Purview integration in the Azure portal for Foundry subscriptions.
This requires enabling Microsoft Defender for Cloud and Purview data security for Azure AI.


Once enabled:

DSPM for AI can capture prompts and responses from Foundry agents.
KYD classification applies to data processed by those agents.


Prerequisites:

Active Azure subscription.
Foundry project with agents registered in the Foundry Control Plane.
Appropriate RBAC roles (e.g., Cognitive Services Security Integration Administrator).

### Automation

KYD policies can be scripted using PowerShell (e.g., New-DlpComplianceRule) for Purview.
Azure Foundry compliance guardrails can be enforced via Azure Policy and deployed through CI/CD pipelines.
Combining both gives you end-to-end governance: resource-level controls (Azure Policy) + data-level controls (KYD in Purview).

https://learn.microsoft.com/en-us/purview/developer/configurepurview
