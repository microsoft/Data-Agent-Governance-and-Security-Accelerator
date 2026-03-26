# Post-Provisioning Validation

Use this guide after `azd up`, `azd provision`, or a direct `run.ps1` execution to confirm that the accelerator applied the expected governance, security, and compliance settings.

This guide is organized by portal so an operator can quickly verify what changed in Azure, Microsoft Purview, Microsoft 365 compliance, and Fabric.

---

## Quick Verification Checklist

| Area | Where to check | Expected result |
| ---- | -------------- | --------------- |
| Defender for Cloud AI Services plan | Azure Portal -> Microsoft Defender for Cloud -> Environment settings -> Defender plans | `AI Services` is On for the target subscription |
| Diagnostic settings | Azure Portal -> Azure AI Services / Foundry resource -> Diagnostic settings | Diagnostic settings exist and target the expected Log Analytics workspace |
| Log Analytics ingestion | Azure Portal -> Log Analytics workspace -> Logs | Recent diagnostics exist for configured Cognitive Services resources |
| DSPM for AI secure interactions | Microsoft Purview portal -> Data Security Posture Management for AI -> Recommendations | `Secure interactions for enterprise AI apps` shows Enabled |
| Purview registered sources and scans | Microsoft Purview portal -> Data Map -> Sources / Monitoring | Expected Foundry and Fabric sources exist and scans show Completed or Completed with exceptions reviewed |
| Unified audit | Exchange Online PowerShell or Microsoft Purview audit | Unified audit ingestion is enabled |
| DLP policy | Microsoft Purview compliance portal -> Data loss prevention -> Policies | Configured DLP policy exists and is On |
| Sensitivity labels | Microsoft Purview compliance portal -> Information protection -> Labels | Expected labels and publishing policies exist |
| Fabric workspace scope (if configured) | `https://app.fabric.microsoft.com` | Existing workspaces and lakehouses referenced in the spec are reachable and match the intended targets |
| Fabric sensitivity labels | Fabric item header or item settings | Expected labels are visible on the pre-existing Fabric items targeted by the spec |
| Evidence exports | Repo folders `audit_export/` and `compliance_inventory/` | Expected export artifacts exist if those scripts were run |

---

## 1. Validate Azure Resource Configuration

### Defender for Cloud AI Services Plan

1. Go to Azure Portal -> Microsoft Defender for Cloud.
2. Open Environment settings.
3. Select the subscription from `subscriptionId`.
4. Open Defender plans.
5. Verify `AI Services` is On.
6. If your organization uses prompt evidence, open Settings for AI Services and confirm the desired prompt evidence setting.

Learn more:
- [Enable threat protection for AI services](https://learn.microsoft.com/azure/defender-for-cloud/ai-onboarding)
- [AI security recommendations](https://learn.microsoft.com/azure/defender-for-cloud/recommendations-reference-ai)

### Diagnostic Settings and Log Analytics

1. In Azure Portal, open each Foundry or Azure AI resource listed under `foundry.resources[]`.
2. Open Diagnostic settings.
3. Verify at least one diagnostic setting is present and targets the Log Analytics workspace from `logAnalyticsWorkspaceId` or `defenderForAI.logAnalyticsWorkspaceId`.
4. Open the Log Analytics workspace and run a query such as:

```kusto
AzureDiagnostics
| where ResourceProvider == "MICROSOFT.COGNITIVESERVICES"
| take 10
```

5. Expect recent records to appear after diagnostic traffic has had time to flow.

---

## 2. Validate Microsoft Purview Configuration

### DSPM for AI Secure Interactions

1. Go to the Microsoft Purview portal.
2. Open Data Security Posture Management for AI.
3. Open Recommendations.
4. Verify `Secure interactions for enterprise AI apps` is enabled.
5. If your spec includes `aiFoundry` or `foundry.resources[]`, verify the expected Microsoft Foundry project names appear in the relevant DSPM for AI views after registration and ingestion have completed.
6. If you just enabled it, allow time for reporting and downstream experiences to populate.

Learn more:
- [Use Microsoft Purview to manage data security and compliance for Microsoft Foundry](https://learn.microsoft.com/purview/ai-azure-foundry)
- [Considerations for DSPM for AI one-click policies](https://learn.microsoft.com/purview/dspm-for-ai-considerations#one-click-policies-from-data-security-posture-management-for-ai)

### Data Map Sources and Scans

1. In the Microsoft Purview portal, open Data Map -> Sources.
2. Verify expected Foundry and Fabric-related sources are registered.
3. Open each source and review its scans.
4. Confirm the most recent run status is Completed, or review and accept any Completed with exceptions state before proceeding.
5. If needed, open Data Map -> Monitoring to inspect recent scan runs in more detail.

Learn more:
- [Scan data sources in Data Map](https://learn.microsoft.com/purview/data-map-scan-data-sources)
- [View a scan in Data Map](https://learn.microsoft.com/purview/data-map-scan-data-sources#view-a-scan)
- [Monitor Data Map population in Microsoft Purview](https://learn.microsoft.com/purview/data-map-scan-run-monitor-population)

### Foundry Visibility in Purview

1. If your spec includes `aiFoundry` or `foundry.resources[]`, confirm the primary Foundry project and any additional configured entries appear in the intended Purview scope.
2. Treat this as the Foundry validation point for this accelerator, since the value here is that the governed Microsoft Foundry projects are discoverable in Purview DSPM for AI.
3. If an expected project name is missing, rerun the `foundry` tag or the specific registration script.

---

## 3. Validate Microsoft 365 Compliance Configuration

Run these checks when you executed the `m365` path or enabled DLP, labels, retention, or audit settings.

### Unified Audit

1. Connect to Exchange Online PowerShell.
2. Run:

```powershell
Get-AdminAuditLogConfig | Format-List UnifiedAuditLogIngestionEnabled
```

3. Confirm `UnifiedAuditLogIngestionEnabled` is `True`.

Learn more:
- [Search the audit log](https://learn.microsoft.com/purview/audit-search#before-you-search-the-audit-log)
- [Turn auditing on or off](https://learn.microsoft.com/purview/audit-log-enable-disable)

### DLP Policies and Sensitivity Labels

1. Go to the Microsoft Purview compliance portal.
2. Open Data loss prevention -> Policies and confirm the configured DLP policy exists and is On.
3. Open Information protection -> Labels and confirm the expected labels exist.
4. If your spec includes publishing configuration, verify the labels are published to the intended user scope.

Learn more:
- [Learn about sensitivity labels](https://learn.microsoft.com/purview/sensitivity-labels)
- [Create and configure sensitivity labels and their policies](https://learn.microsoft.com/microsoft-365/compliance/create-sensitivity-labels)

---

## 4. Validate Microsoft Fabric Configuration

Run these checks when your spec includes a `fabric` section.

The accelerator does not create Fabric workspaces or lakehouses. It assumes they already exist and then uses them as governance targets for label application, workspace registration, and scan automation.

### Sensitivity Labels on Fabric Items

Run this section only for pre-existing Fabric items that you intentionally listed in the spec.

1. Open each configured lakehouse.
2. Review the item header or settings.
3. Confirm the expected sensitivity label is shown.
4. If labels are missing, verify both tenant prerequisites and label publication.

Important notes:
- This accelerator applies labels to Fabric items but does not enable Fabric tenant sensitivity-label support for you.
- The referenced Purview labels must already exist and be published to the relevant users.
- The operator must have sufficient rights to apply labels.

Learn more:
- [Enable sensitivity labels in Fabric and Power BI](https://learn.microsoft.com/fabric/enterprise/powerbi/service-security-enable-data-sensitivity-labels)
- [Apply sensitivity labels to Fabric items](https://learn.microsoft.com/fabric/fundamentals/apply-sensitivity-labels)
- [Information protection in Microsoft Fabric](https://learn.microsoft.com/fabric/governance/information-protection)

### Fabric Scan Automation

1. Review `fabric.scanAutomationMode` in the spec.
2. If set to `runOnly`, confirm the named Purview scan already exists.
3. If set to `full`, confirm automation created or updated the scan definition and then triggered it.
4. If set to `disabled`, confirm that no scan execution was expected.

---

## 5. Validate Exported Evidence

If you ran evidence export scripts, confirm the generated artifacts are present.

1. Check `compliance_inventory/` for compliance inventory exports.
2. Check `audit_export/` for audit output.
3. If expected files are missing, rerun the relevant export scripts after confirming role assignments and audit prerequisites.

---

## 6. Rerun Post-Provision Steps

Use these commands when you need to rerun the post-provision automation after fixing configuration or permissions.

```powershell
azd hooks run postprovision
```

```powershell
pwsh ./run.ps1 -Tags foundation,dspm,defender,foundry -SpecPath ./spec.local.json
```

```powershell
pwsh ./run.ps1 -Tags m365 -ConnectM365 -M365UserPrincipalName <upn> -SpecPath ./spec.local.json
```

---

## Related Repo Guidance

- [Deployment Guide](./DeploymentGuide.md)
- [Troubleshooting Guide](./TroubleshootingGuide.md)
- [Spec File Reference](./spec-local-reference.md)
- [Alternative Deployment Paths](./AlternativeDeploymentPaths.md)
