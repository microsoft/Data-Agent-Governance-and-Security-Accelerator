# Data Agent Governance and Security Accelerator

Light up Microsoft Purview Data Security Posture Management (DSPM) for AI to safeguard Microsoft 365 Copilot, Azure AI Foundry, Microsoft Fabric, and custom agentic solutions. Deploy end-to-end governance controls, automate registration and scanning, wire telemetry into Defender for AI, and export auditable evidence for regulators.

<div align="center">

[**SOLUTION OVERVIEW**](#solution-overview) | [**QUICK DEPLOY**](#quick-deploy) | [**BUSINESS SCENARIO**](#business-scenario) | [**SUPPORTING DOCUMENTATION**](#supporting-documentation)

</div>

---

## User story

Organizations deploying AI across Microsoft 365 Copilot, Azure AI Foundry, and custom agents face a common challenge: **how do you govern AI interactions at scale while maintaining compliance?**

A data protection team is tasked with securing AI workloads across the enterprise. They need to:

- **Discover** where AI interactions occur - which apps, which data sources, which users
- **Classify** sensitive data flowing through AI prompts and responses
- **Protect** data with policies that prevent sensitive information from leaking through AI systems
- **Monitor** AI interactions through audit logs and compliance dashboards
- **Demonstrate** compliance to regulators with exportable evidence

Without automation, this requires weeks of manual configuration across multiple portals: Purview, Defender for Cloud, Azure Policy, Exchange Online, and more. Each AI project means repeating the same steps.

**This accelerator solves that problem.** Capture your governance requirements in a single spec file, run `azd up`, and produce verifiable evidence that DSPM for AI and Defender for AI are enforcing policies, logging activity, and keeping every AI workflow compliant.

---

## ![](./docs/images/readme/solution-overview.png) Solution overview

This accelerator orchestrates Azure and Microsoft 365 governance artifacts through PowerShell and Azure Developer CLI hooks:

- Automates Purview DSPM for AI onboarding (resource groups, Purview account checks, data-source registration, scans, DLP/label/retention policies, audit exports)
- Governs Azure AI Foundry projects with Azure Policy, Defender for Cloud, Content Safety blocklists, diagnostics, and tagging
- Ships telemetry to Log Analytics and exports compliance evidence for downstream analytics or regulators
- Provides repeatable CI/Desktop experiences through spec-controlled tags and azd post-provision hooks

### Solution architecture

![Data Agent governance architecture](./docs/doc-images/architectureDAGSA.png)

### Key features

<details open>
<summary>Click to view the core capabilities provided by this accelerator</summary>

| Feature | Description |
| ------- | ----------- |
| **Spec-driven DSPM for AI enablement** | Copy `spec.dspm.template.json`, populate tenant data, and let the scripts create Purview accounts, data sources, scans, KYD/DLP/retention policies, and audit exports without portal clicks. |
| **Cross-cloud posture telemetry** | Stream diagnostics to Log Analytics, ensure Secure Interactions/KYD capture prompts and responses, and collect compliance inventory snapshots for auditors. |
| **CI + desktop friendly automation** | Run `azd up` to replay deterministic checklists in devcontainers, Codespaces, or local shells. |
| **Extensible evidence exports** | Reuse the audit export, compliance inventory, and tagging scripts as building blocks for bespoke regulator packages or SIEM pipelines. |
| **Microsoft Foundry control plane governance** | *(Coming soon - not yet available)* Apply Azure Policies, Defender for AI plans, diagnostics, tagging, and Content Safety guardrails to every Foundry project listed in the spec. This capability is on the roadmap. |

</details>

### How to customize

- [Author and extend the spec contract](./spec.dspm.template.json) for each tenant/subscription
- [Review the value proposition](./docs/WhyDSPM.md) to communicate benefits to stakeholders
- [Understand cost implications](./docs/CostGuidance.md) before enabling paid features
- Extend stub scripts (for example `15-Create-SensitiveInfoType-Stub.ps1`) with organization-specific controls

### Additional resources

- [Architecture Overview](./docs/ArchitectureOverview.md) - Technical architecture and class diagram
- [Deployment Guide](./docs/DeploymentGuide.md) - Comprehensive step-by-step instructions
- [Alternative Deployment Paths](./docs/AlternativeDeploymentPaths.md) - CI/CD, run.ps1 tags, M365 desktop deployment
- [Troubleshooting Guide](./docs/TroubleshootingGuide.md)

---

## ![](./docs/images/readme/quick-deploy.png) Quick deploy

Deploy this solution to your Azure subscription using the Azure Developer CLI.

> **Note:** This solution accelerator requires Azure Developer CLI (azd) version 1.9.0 or higher. Please ensure you have the latest version installed before proceeding with deployment. [Download azd here](https://learn.microsoft.com/en-us/azure/developer/azure-developer-cli/install-azd).

[Click here to launch the deployment guide](./docs/DeploymentGuide.md)

| [![Open in GitHub Codespaces](https://github.com/codespaces/badge.svg)](https://codespaces.new/microsoft/Data-Agent-Governance-and-Security-Accelerator) | [![Open in Dev Containers](https://img.shields.io/static/v1?style=for-the-badge&label=Dev%20Containers&message=Open&color=blue&logo=visualstudiocode)](https://vscode.dev/redirect?url=vscode://ms-vscode-remote.remote-containers/cloneInVolume?url=https://github.com/microsoft/Data-Agent-Governance-and-Security-Accelerator) |
| --- | --- |

> **Important:** Check Azure resource availability. To ensure the required services are available in your subscription and region, review the [Prerequisites and costs](#prerequisites-and-costs) section before deploying.

### How to install or deploy

**1. Sign in to Azure:**
```powershell
az login
azd auth login
Connect-AzAccount -Tenant <tenantId> -Subscription <subscriptionId>
Set-AzContext -Subscription <subscriptionId>
```

**2. Prepare the spec file:**
```powershell
Copy-Item ./spec.dspm.template.json ./spec.local.json
```
Edit `spec.local.json` with your tenant ID, subscription ID, Purview account details, and AI Foundry project information.

**3. Deploy:**
```powershell
azd up
```

**4. Complete manual steps** (see below)

> **Need alternative deployment options?** See [Alternative Deployment Paths](./docs/AlternativeDeploymentPaths.md) for run.ps1 tags, M365 desktop deployment, CI/CD integration, and GitHub Actions workflows.

### Post-deployment manual steps

After automation completes, you **MUST** manually enable two settings that cannot be automated via API:

**1. Purview DSPM - Secure interactions for enterprise AI apps:**
1. Sign in to [https://web.purview.azure.com](https://web.purview.azure.com)
2. Navigate: **Data Security Posture Management for AI** > **Recommendations** > **Secure interactions for enterprise AI apps**
3. Click **Enable**

**2. Defender for Cloud - Enable data security for AI interactions:**
1. Sign in to the [Azure portal](https://portal.azure.com)
2. Navigate: **Microsoft Defender for Cloud** > **Environment settings** > Select your subscription
3. Under **Defender plans**, locate **AI Services** > Click **Settings**
4. Toggle **Enable data security for AI interactions** to **On** > Click **Save**

**Why this matters:** Without these manual toggles, AI interaction data (prompts/responses) will NOT be captured by Purview DSPM or Defender for AI for threat detection and compliance analysis.

### Prerequisites and costs

To deploy this solution accelerator, ensure you have access to an [Azure subscription](https://azure.microsoft.com/free/) with the necessary permissions to create resource groups, resources, and assign roles.

**Required permissions:**
- Contributor role at the subscription level
- Role Based Access Control Administrator on the subscription and/or resource group level
- Microsoft 365 E5 (or E5 Compliance) license for the operator enabling Secure Interactions

**Required tooling:**
- Azure CLI 2.58.0+
- Azure Developer CLI (azd) 1.9.0+
- PowerShell 7.x with Az modules

| Service | Purpose | Pricing |
| ------- | ------- | ------- |
| [Microsoft Purview](https://azure.microsoft.com/pricing/details/purview/) | DSPM for AI scans, Secure Interactions, Know Your Data | [Usage based](https://azure.microsoft.com/pricing/details/purview/) |
| [Azure AI Foundry / Cognitive Services](https://azure.microsoft.com/pricing/details/ai-studio/) | AI project hosting, diagnostics, Content Safety | [Usage based](https://azure.microsoft.com/pricing/details/ai-studio/) |
| [Microsoft Defender for Cloud](https://azure.microsoft.com/pricing/details/defender-for-cloud/) | Defender for AI plans, alerts, diagnostics | [Per resource type](https://azure.microsoft.com/pricing/details/defender-for-cloud/) |
| [Log Analytics](https://azure.microsoft.com/pricing/details/monitor/) | Central log collection for diagnostics | [Pay-as-you-go](https://azure.microsoft.com/pricing/details/monitor/) |

Use the [Azure pricing calculator](https://azure.microsoft.com/pricing/calculator) to estimate costs. See [Cost Guidance](./docs/CostGuidance.md) for optimization tips.

> **Important:** To avoid unnecessary costs, remember to take down your deployment if it's no longer in use by running `azd down` or deleting the resource group in the Portal.

---

## ![](./docs/images/readme/business-scenario.png) Business scenario

![DSPM for all services](./docs/doc-images/DSPM-for-all-services-steps.png)

A data protection program is tasked with lighting up Microsoft Purview Data Security Posture Management for AI and Microsoft Defender for AI across Microsoft 365 Copilot, Azure AI Foundry, Fabric, and bespoke agentic solutions.

They must:
- Discover and classify the source data that feeds every agent
- Apply Purview labels, DLP, and retention policies plus Defender guardrails
- Continuously track and audit Generative AI apps and agents for regulators

With this accelerator, the team captures those requirements in a spec file, executes `azd up`, and produces verifiable evidence that DSPM for AI and Defender for AI are enforcing policies, logging activity, and keeping every AI workflow compliant.

### Business value

<details>
<summary>Click to expand the value delivered by this solution</summary>

| Value | Description |
| ----- | ----------- |
| **Unified AI governance** | Enforce Purview DSPM for AI, labels, DLP, retention, audit, and Azure Policy from one declarative spec. |
| **Operational efficiency** | Shorten deployment time from days to minutes via azd hooks and repeatable PowerShell plans. |
| **Evidence on demand** | Export audit logs and compliance inventory snapshots to satisfy regulators or internal risk teams. |
| **Secure innovation** | Light up Defender for AI, diagnostics, and Content Safety controls around every Foundry project so new AI agents inherit enterprise guardrails. |

</details>

### DSPM for AI and Defender for AI - Features mapping

| Environment Component | Secured Asset | Product | Key Features |
| --------------------- | ------------- | ------- | ------------ |
| **Azure AI Foundry** | AI interactions (prompts & responses), workspaces, connections | Microsoft Purview **DSPM for AI** | Discovery of AI interactions; sensitivity classification & labeling; DLP on prompts/responses; audit & eDiscovery |
| **Azure OpenAI / Azure ML** | Model endpoints, prompt flow apps, deployments | **Defender for AI** | AI-specific threat detection and posture hardening; misconfiguration findings; attack-path analysis |
| **Microsoft Fabric OneLake** | Tables/files (Delta/Parquet), Lakehouse/Warehouse data | Microsoft Purview + **DSPM for AI** | Sensitivity labels; DLP for structured data; label coverage reports; activity monitoring |
| **Cross-estate AI** | Prompt/response interaction data across Copilot, agents, AI apps | Microsoft Purview **DSPM for AI** | Unified view of AI interactions; policy enforcement; natural-language risk exploration |

---

## ![](./docs/images/readme/supporting-documentation.png) Supporting documentation

| Document | Description |
| -------- | ----------- |
| [Architecture Overview](./docs/ArchitectureOverview.md) | Technical architecture and class diagram |
| [Deployment Guide](./docs/DeploymentGuide.md) | Comprehensive step-by-step deployment instructions |
| [Alternative Deployment Paths](./docs/AlternativeDeploymentPaths.md) | CI/CD integration, run.ps1 tags, M365 desktop deployment, GitHub Actions |
| [Troubleshooting Guide](./docs/TroubleshootingGuide.md) | Common issues and solutions |
| [Why DSPM for AI?](./docs/WhyDSPM.md) | Value proposition and stakeholder communication |
| [Cost Guidance](./docs/CostGuidance.md) | Billing models and optimization tips |
| [Spec File Reference](./docs/spec-local-reference.md) | Field-by-field documentation for spec.local.json |
| [Script Reference](./scripts/governance/README.md) | Repository structure and script descriptions |

### Security guidelines

- Store secrets in Azure Key Vault and pass references through the spec file instead of embedding secrets directly
- Use managed identities or service principals for automation runs; rotate credentials regularly
- Enable Microsoft Defender for Cloud across Cognitive Services, Storage, and Container workloads
- Ensure GitHub secret scanning is enabled if you fork this repo; avoid committing `spec.local.json`



---

## Provide feedback

Have questions, find a bug, or want to request a feature? [Submit a new issue](https://github.com/microsoft/Data-Agent-Governance-and-Security-Accelerator/issues) on this repo and we'll connect.

---

## Responsible AI Transparency FAQ

Please refer to [TRANSPARENCY_FAQ.md](./TRANSPARENCY_FAQ.md) for responsible AI transparency details of this solution accelerator.

---

## Data Collection

The software may collect information about you and your use of the software and send it to Microsoft. Microsoft may use this information to provide services and improve our products and services. You may turn off the telemetry as described in the repository. There are also some features in the software that may enable you and Microsoft to collect data from users of your applications.

To opt out of telemetry:
1. Set the environment variable `AZURE_DEV_COLLECT_TELEMETRY` to `no` before deploying
2. Set the `enableTelemetry` parameter in `main.bicepparam` to `false` before deploying

---

## Disclaimers

To the extent that the Software includes components or code used in or derived from Microsoft products or services, including without limitation Microsoft Azure Services (collectively, "Microsoft Products and Services"), you must also comply with the Product Terms applicable to such Microsoft Products and Services. You acknowledge and agree that the license governing the Software does not grant you a license or other right to use Microsoft Products and Services. Nothing in the license or this ReadMe file will serve to supersede, amend, terminate or modify any terms in the Product Terms for any Microsoft Products and Services.

You must also comply with all domestic and international export laws and regulations that apply to the Software, which include restrictions on destinations, end users, and end use. For further information on export restrictions, visit [https://aka.ms/exporting](https://aka.ms/exporting).

You acknowledge that the Software and Microsoft Products and Services (1) are not designed, intended or made available as a medical device(s), and (2) are not designed or intended to be a substitute for professional medical advice, diagnosis, treatment, or judgment and should not be used to replace or as a substitute for professional medical advice, diagnosis, treatment, or judgment.

You acknowledge the Software is not subject to SOC 1 and SOC 2 compliance audits. No Microsoft technology, nor any of its component technologies, including the Software, is intended or made available as a substitute for the professional advice, opinion, or judgement of a certified financial services professional. Do not use the Software to replace, substitute, or provide professional financial advice or judgment.

BY ACCESSING OR USING THE SOFTWARE, YOU ACKNOWLEDGE THAT THE SOFTWARE IS NOT DESIGNED OR INTENDED TO SUPPORT ANY USE IN WHICH A SERVICE INTERRUPTION, DEFECT, ERROR, OR OTHER FAILURE OF THE SOFTWARE COULD RESULT IN THE DEATH OR SERIOUS BODILY INJURY OF ANY PERSON OR IN PHYSICAL OR ENVIRONMENTAL DAMAGE (COLLECTIVELY, "HIGH-RISK USE"), AND THAT YOU WILL ENSURE THAT, IN THE EVENT OF ANY INTERRUPTION, DEFECT, ERROR, OR OTHER FAILURE OF THE SOFTWARE, THE SAFETY OF PEOPLE, PROPERTY, AND THE ENVIRONMENT ARE NOT REDUCED BELOW A LEVEL THAT IS REASONABLY, APPROPRIATE, AND LEGAL, WHETHER IN GENERAL OR IN A SPECIFIC INDUSTRY. BY ACCESSING THE SOFTWARE, YOU FURTHER ACKNOWLEDGE THAT YOUR HIGH-RISK USE OF THE SOFTWARE IS AT YOUR OWN RISK.

---

## Trademarks

This project may contain trademarks or logos for projects, products, or services. Authorized use of Microsoft trademarks or logos is subject to and must follow [Microsoft's Trademark & Brand Guidelines](https://www.microsoft.com/en-us/legal/intellectualproperty/trademarks/usage/general). Use of Microsoft trademarks or logos in modified versions of this project must not cause confusion or imply Microsoft sponsorship. Any use of third-party trademarks or logos are subject to those third-party's policies.


