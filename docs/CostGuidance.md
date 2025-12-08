# Cost Guidance

This guide explains the billing models and cost considerations for services enabled by this accelerator.

---

## Understanding Pay-As-You-Go (PAYG)

Several Microsoft services used by this accelerator support **Pay-As-You-Go** billing:

### What is PAYG?

Instead of purchasing prepaid licenses or capacity upfront, PAYG lets your organization link an Azure subscription and pay based on actual usage (messages processed, storage consumed, API calls made, etc.).

**Think of it as:** Your Azure subscription acts like a credit card—charges accrue monthly based on consumption.

### Why PAYG Exists

| Benefit | Description |
|---------|-------------|
| **Flexibility** | Scale up or down without committing to fixed license counts |
| **Cost Efficiency** | Ideal for pilots, unpredictable workloads, or seasonal usage |
| **No Upfront Commitment** | Start small and grow based on actual needs |

---

## Services with PAYG Options

### Microsoft Purview DSPM

| Feature | Billing Model | Notes |
|---------|---------------|-------|
| DSPM for AI scanning | Included with E5/E5 Compliance | No additional PAYG cost for basic features |
| Advanced analytics | PAYG available | Large data estates may benefit from PAYG for extended scanning |
| Data Map capacity | Capacity units | Based on assets cataloged and scanned |

### Defender for Cloud

| Feature | Billing Model | Notes |
|---------|---------------|-------|
| Defender for AI (Cognitive Services) | Per-resource/month | Charged per protected AI resource |
| Defender CSPM | Per-resource/month | Posture management for cloud resources |
| Log Analytics ingestion | Per-GB | Diagnostic logs consume Log Analytics quota |

### Azure AI Services

| Feature | Billing Model | Notes |
|---------|---------------|-------|
| Content Safety API | Per-1000 calls | Charged when blocklist evaluation runs |
| Azure OpenAI | Per-token | Model inference costs (not governance-related) |

---

## Cost Optimization Tips

### 1. Right-Size Your Deployment

| Scenario | Recommendation |
|----------|----------------|
| **Pilot/POC** | Use `defender,foundry` tags only—skip full DSPM scanning |
| **Production** | Enable all relevant tags but review diagnostic log volume |
| **Cost-Sensitive** | Disable optional features in spec (e.g., skip `activityExport` if not needed) |

### 2. Monitor Log Analytics Ingestion

Diagnostic logs from AI resources can generate significant volume. To control costs:

```powershell
# Check current ingestion in Log Analytics
az monitor log-analytics workspace show --resource-group <rg> --workspace-name <workspace> --query "sku"
```

Consider:
- Setting daily caps on Log Analytics workspaces
- Filtering diagnostic categories in the spec (`defenderForAI.diagnosticCategories`)
- Using Azure Cost Management alerts

### 3. Use Budget Alerts

The accelerator includes a stub script for budget alerts:

```powershell
# Review and customize for your needs
./scripts/governance/dspmPurview/24-Create-BudgetAlert-Stub.ps1
```

### 4. Review Defender Plans

Not all Defender plans may be necessary for your scenario:

```json
{
  "defenderForAI": {
    "enableDefenderForCloudPlans": [
      "CognitiveServices"  // Required for AI protection
      // "Storage" - Only if scanning storage accounts
      // "KeyVaults" - Only if monitoring Key Vault access
    ]
  }
}
```

---

## Licensing Requirements

### Microsoft 365

| Feature | License Required |
|---------|------------------|
| DSPM for AI (basic) | M365 E5 or E5 Compliance |
| Unified Audit Log | M365 E3+ (E5 for advanced) |
| DLP policies | M365 E5 or E5 Compliance |
| Sensitivity labels | M365 E3+ (E5 for auto-labeling) |
| Retention policies | M365 E5 or E5 Compliance |
| Communication Compliance | M365 E5 Compliance add-on |

### Azure

| Feature | License Required |
|---------|------------------|
| Microsoft Purview (governance) | Azure subscription + Purview account |
| Defender for Cloud | Azure subscription (plans are per-resource) |
| Log Analytics | Azure subscription (per-GB ingestion) |
| Azure AI Foundry | Azure subscription + AI resource quota |

---

## Estimating Costs

### Small Deployment (1-5 AI resources)

| Service | Estimated Monthly Cost |
|---------|------------------------|
| Defender for AI | $15-50 |
| Log Analytics (1-5 GB/day) | $50-250 |
| Content Safety API | $0-50 |
| **Total** | **~$65-350/month** |

### Medium Deployment (10-50 AI resources)

| Service | Estimated Monthly Cost |
|---------|------------------------|
| Defender for AI | $150-500 |
| Log Analytics (10-50 GB/day) | $250-1,250 |
| Content Safety API | $50-200 |
| **Total** | **~$450-1,950/month** |

> **Note:** These are rough estimates. Actual costs depend on usage patterns, data volume, and regional pricing. Use the [Azure Pricing Calculator](https://azure.microsoft.com/pricing/calculator/) for accurate estimates.

---

## Related Resources

- [Azure Pricing Calculator](https://azure.microsoft.com/pricing/calculator/)
- [Microsoft Purview pricing](https://azure.microsoft.com/pricing/details/purview/)
- [Defender for Cloud pricing](https://azure.microsoft.com/pricing/details/defender-for-cloud/)
- [Log Analytics pricing](https://azure.microsoft.com/pricing/details/monitor/)
- [M365 E5 Compliance overview](https://www.microsoft.com/security/business/compliance/e5-compliance)
