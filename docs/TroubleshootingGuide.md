# Troubleshooting Guide

Use this guide to resolve common issues when running the Data Agent Governance and Security Accelerator.

---

## Quick Fixes for New Users

| Symptom | Quick Fix |
|---------|-----------|
| \"Connect-AzAccount\" prompts for login during azd up | Run `az login`, `azd auth login`, `Connect-AzAccount`, and `Set-AzContext` in same terminal before `azd up` |
| \"spec.local.json not found\" | Run `Copy-Item ./spec.dspm.template.json ./spec.local.json` and populate values |
| \"Cannot find property 'tenantId'\" | Your spec.local.json has invalid JSON syntax - validate with `Get-Content ./spec.local.json | ConvertFrom-Json` |
| Scripts skip with \"No X configured\" | The corresponding spec section is empty/missing - this is OK if you don't need that feature |
| \"Authorization denied\" on audit exports | You need Audit Reader or Compliance Administrator role in Purview |
| Exchange Online commands fail | Run `m365` tag from desktop with MFA, not from containers/Codespaces |

---

## Detailed Troubleshooting

### 1. Post-provision hook re-prompts for login
- **Symptoms:** `Connect-AzAccount` opens a browser during `azd up` or fails with `InteractiveBrowserCredential` errors.
- **Fix:** Ensure you ran `az login`, `azd auth login`, `Connect-AzAccount -Tenant ... -Subscription ...`, and `Set-AzContext` in the same terminal before invoking `azd up`. The hook only reuses existing contexts.

## 2. Management Activity API returns 401
- **Symptoms:** `20-Subscribe-ManagementActivity.ps1` or `21-Export-Audit.ps1` fails with `Authorization has been denied for this request`.
- **Fix:**
  1. Assign the operator to the **Audit Reader** or **Compliance Administrator** role under Microsoft Purview permissions.
  2. Confirm the user has an Exchange Online / Microsoft 365 E5 license and that auditing is enabled (`Get-AdminAuditLogConfig`).
  3. Run `Disconnect-AzAccount`, `az logout`, and sign in again so new tokens include the `ActivityFeed.Read` role.

## 3. Missing spec blocks (activityExport, azurePolicies)
- **Symptoms:** Scripts complain that `contentTypes` or `azurePolicies` cannot be found.
- **Fix:**
  - Update to the latest main branch (scripts now skip gracefully when those blocks are missing), or
  - Reintroduce the section into `spec.local.json` using `spec.dspm.template.json` as a reference.

## 4. Content Safety endpoint skipped
- **Symptoms:** `31-Foundry-ConfigureContentSafety.ps1` logs `foundry.contentSafety.endpoint not provided`.
- **Fix:** Provide the Content Safety endpoint and either a Key Vault secret reference or confirm Entra ID access works for the AI subscription. This message is informational; populate the block only when you are ready to configure Content Safety.

## 5. `azd up` fails after changes to README or docs
- **Symptoms:** `postprovision.ps1` fails with backtick or markdown tokens in the error message.
- **Fix:** Ensure PowerShell scripts do not contain stray Markdown fences (````` ```). Run `git status` to confirm only README/docs changed.

## 6. Defender for AI diagnostics not flowing
- **Symptoms:** No logs appear in Log Analytics after running `07-Enable-Diagnostics.ps1`.
- **Fix:**
  - Verify the `defenderForAI.logAnalyticsWorkspaceId` value in the spec points to an existing workspace with the correct permissions.
  - Confirm the Defender plan (`enableDefenderForCloudPlans`) includes `CognitiveServices` and that Defender for Cloud is enabled in the subscription.

If your issue is not listed here, open a new issue in the repository with the failing script name, the exact error text, and the relevant snippet from `spec.local.json` (redacting secrets).

---

## 7. Spec file JSON syntax errors
- **Symptoms:** `ConvertFrom-Json: Invalid JSON primitive` or scripts fail immediately with parsing errors.
- **Fix:**
  1. Validate your spec: `Get-Content ./spec.local.json | ConvertFrom-Json`
  2. Common issues: trailing commas, missing quotes around values, unescaped characters in paths
  3. Use VS Code with JSON extension for syntax highlighting and error detection

## 8. \"Module not found\" errors
- **Symptoms:** `The term 'Get-AzContext' is not recognized` or similar module errors.
- **Fix:**
  ```powershell
  # Install required modules
  Install-Module Az -Scope CurrentUser -Force -AllowClobber
  Install-Module Az.Security -Scope CurrentUser -Force
  Install-Module ExchangeOnlineManagement -Scope CurrentUser -Force  # for m365 tag
  
  # Verify installation
  Get-Module Az -ListAvailable
  ```

## 9. Wrong subscription/tenant context
- **Symptoms:** Scripts create resources in wrong subscription or fail with \"resource not found\".
- **Fix:**
  ```powershell
  # Check current context
  Get-AzContext
  
  # Switch to correct subscription
  Set-AzContext -Subscription \"<subscription-id-from-spec>\"
  
  # Verify tenant matches
  (Get-AzContext).Tenant.Id  # Should match tenantId in spec
  ```

## 10. Purview account not found
- **Symptoms:** `02-Ensure-PurviewAccount.ps1` fails with \"resource not found\".
- **Fix:**
  - Verify `purviewAccount`, `purviewResourceGroup`, and `purviewSubscriptionId` in spec match exactly (case-sensitive)
  - Confirm the Purview account exists: Azure Portal → Microsoft Purview accounts
  - Ensure you have at least Reader access to the Purview resource
## 11. Fabric sensitivity labels require M365 connectivity
- **Symptoms:** `azd up` fails with *"Step '…26-Ensure-FabricWorkspaceSensitivity.ps1' requires Microsoft 365 connectivity. Re-run with -ConnectM365 plus either -M365UserPrincipalName or app-only parameters."*
- **Fix:**
  - Ensure `dagaConnectM365 = true` in `infra/main.bicepparam` (this is the default). The post-provision hook automatically detects the M365 UPN from the Azure CLI login context (`az account show`), so you do **not** need to hardcode `dagaM365UserPrincipalName`. Just run `az login` and `azd auth login` before `azd up`.
  - If auto-detection does not work (e.g., service principal login), provide the UPN explicitly via one of these methods:
    - Set `dagaM365UserPrincipalName` in `infra/main.bicepparam`
    - Set the environment variable `DAGA_POSTPROVISION_M365_UPN`
    - Run directly: `pwsh ./run.ps1 -Tags foundation,dspm,defender,foundry -SpecPath ./spec.local.json -ConnectM365 -M365UserPrincipalName <upn>`

## 12. Fabric sensitivity label name not found
- **Symptoms:** `26-Ensure-FabricWorkspaceSensitivity.ps1` logs *"WARNING: Missing Fabric sensitivity labels"* with label names that could not be resolved.
- **Fix:**
  1. Open the [Microsoft Purview compliance portal](https://compliance.microsoft.com) → **Information protection** → **Labels**.
  2. Note the **exact display name** of the desired label (e.g., `General` not `General usage`). Parent/child labels use backslash format: `Confidential\All Employees`.
  3. Update `sensitivityLabel` values in `spec.local.json` to match the exact display name, then rerun.

## 13. 403 Forbidden when applying Fabric sensitivity labels
- **Symptoms:** `26-Apply-FabricLakehouseSensitivity.ps1` logs *"Failed to apply label to lakehouse … 403 (Forbidden)"*.
- **Fix:**
  - Ensure the operator account has **Contributor** or **Member** access on the Fabric workspace.
  - Verify the account has an **Information Protection P1 or P2** license (required to set sensitivity labels via API).
  - In the Purview compliance portal, confirm the label's publish policy includes the operator account or a group it belongs to.

## 14. Fabric datasource registration 409 conflict
- **Symptoms:** `27-Register-FabricWorkspace.ps1` logs *"409 (Conflict)"* errors and falls back to a shared PowerBI datasource.
- **Fix:** This is expected when a workspace-scoped datasource already exists or conflicts with tenant-level registrations.
  1. The script falls back to a shared datasource automatically. No immediate action is required.
  2. After deployment, open the Purview portal, navigate to the shared datasource, and create a **workspace-scoped scan definition** manually to avoid unscoped tenant-wide scans.
  3. Set `fabric.scanAutomationMode` to `runOnly` in `spec.local.json` so subsequent runs trigger the scan without overwriting it.
---

## How to Verify Successful Configuration

After running the accelerator, validate that services are correctly configured:

### Check DSPM for AI is enabled
1. Sign in to [Microsoft Purview portal](https://web.purview.azure.com)
2. Navigate to **Data Security Posture Management for AI**
3. Verify **Secure interactions for enterprise AI apps** shows as **Enabled**
4. Check **Recommendations** tab for any outstanding items

### Check Defender for AI is enabled
1. Sign in to [Azure Portal](https://portal.azure.com)
2. Navigate to **Microsoft Defender for Cloud** → **Environment settings**
3. Select your subscription → **Defender plans**
4. Verify **AI Services** shows as **On**
5. Click **Settings** → Confirm **Enable data security for AI interactions** is **On**

### Check diagnostics are flowing
1. Navigate to **Log Analytics workspace** specified in spec
2. Run query: `AzureDiagnostics | where ResourceProvider == "MICROSOFT.COGNITIVESERVICES" | take 10`
3. If results appear, diagnostics are configured correctly (may take 15-30 minutes after initial setup)

### Check DLP/Labels are published (m365 tag)
1. Sign in to [Microsoft Purview compliance portal](https://compliance.microsoft.com)
2. Navigate to **Data loss prevention** → **Policies**
3. Verify your DLP policy appears and shows **On** status
4. Navigate to **Information protection** → **Labels** to verify sensitivity labels

---

## Getting Help

If you're still stuck:

1. **Check existing issues:** [GitHub Issues](https://github.com/microsoft/Data-Agent-Governance-and-Security-Accelerator/issues)
2. **Open a new issue** with:
   - Script name that failed
   - Exact error message
   - Relevant `spec.local.json` snippet (redact secrets!)
   - PowerShell version (`$PSVersionTable`)
   - Az module version (`Get-Module Az -ListAvailable`)
3. **Community discussions:** Use GitHub Discussions for questions and best practices
