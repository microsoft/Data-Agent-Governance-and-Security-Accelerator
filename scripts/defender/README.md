# Defender for AI Automation Guide

The scripts under `scripts/defender/defenderForAI` enable Microsoft Defender for Cloud plans that protect Azure AI services, wire diagnostics to Log Analytics, and prepare the environment for integration with Purview DSPM. They rely on the shared spec contract (copy `spec.dspm.template.json` to your local file such as `spec.local.json`), so the subscription, resource group, Log Analytics workspace, and resource names are defined in one place.

---

## Prerequisites

- Azure CLI authenticated to the subscription called out in the spec (`parameters.subscriptionId`).
- Permissions: Security Administrator or Contributor on the Defender subscription, plus access to write diagnostic settings.
- A Log Analytics workspace and Key Vault defined in the spec.
- Defender for Cloud must be registered in the tenant (the scripts check and register the provider if needed).

---

## Script overview

| Script | Purpose | Tags |
|--------|---------|------|
| `defenderForAI/06-Enable-DefenderPlans.ps1` | Enables the Defender for Cloud plans listed in the spec (Cognitive Services, Storage, Containers, etc.) and confirms pricing tier. | `defender`, `dspm` |
| `defenderForAI/07-Enable-Diagnostics.ps1` | Routes diagnostic categories (Audit, RequestResponse, AllMetrics) for each AI service to the Log Analytics workspace defined in the spec. | `defender`, `diagnostics`, `foundry` |

Both scripts support `-SpecPath` and optional `-Tags` parameters so they can run outside of `run.ps1` if you prefer.

---

## Typical execution flow

1. Run the DSPM prerequisites (Purview account, unified audit) as described in `scripts/governance/README.md`.
2. Enable Defender plans:
   ```powershell
   pwsh ./scripts/defender/defenderForAI/06-Enable-DefenderPlans.ps1 -SpecPath ./spec.local.json
   ```
3. Configure diagnostics for protected resources:
   ```powershell
   pwsh ./scripts/defender/defenderForAI/07-Enable-Diagnostics.ps1 -SpecPath ./spec.local.json
   ```
4. Review Microsoft Defender for Cloud -> Environment settings -> AI services to confirm plans show as **On** and diagnostics point to the correct workspace.

---

## Integration checkpoints

- If the script warns that certain preview toggles (for example "Enable data security for AI interactions") must be enabled manually, follow the steps in the portal and rerun the validation script (`scripts/governance/dspmPurview/34-Validate-Posture.ps1`).
- Make sure Purview has access to the Log Analytics workspace if you intend to ship diagnostics into compliance dashboards.

---

## Troubleshooting

| Symptom | Likely cause | Resolution |
|---------|--------------|------------|
| "pricingTier cannot be found" warning | Defender graph API changed response shape | The script already normalizes the response; this warning is informational if the API returns a preview payload. |
| Diagnostics fail for a resource | Resource provider does not support the requested categories in that region | Remove or adjust the category in the spec and rerun `07-Enable-Diagnostics.ps1`. |
| Portal still shows plan Off after successful script | Defender plan requires up to 15 minutes to become active | Wait and refresh; confirm the subscription ID in the spec matches the subscription selected in the portal. |

---

## After action

- Use Defender for Cloud recommendations and alerts to validate threat detections are flowing.
- Pair these scripts with the DSPM modules that export audit data so security alerts can be correlated with user prompts and sensitive information types.
- Update the spec if you add new Azure AI resources; rerun the scripts to ensure they inherit the same protection baseline.

These Defender modules provide the security telemetry half of the story captured in the root README and complement the governance steps in `scripts/governance/README.md`.
