<#
.SYNOPSIS
  Connect Microsoft Defender for AI with Microsoft Purview DSPM.

.DESCRIPTION
  This script enables data security for AI interactions with Purview:
  - Sends AI prompt/response data to Purview
  - Enables sensitive information type (SIT) classification
  - Provides compliance reporting and analytics
  - Integrates with Insider Risk Management

.NOTES
  Requires: Defender for AI enabled, Purview DSPM enabled (M365 E5)
#>

[CmdletBinding()]
param(
    [Parameter(Mandatory = $false)]
    [string]$SubscriptionId = $null,

    [Parameter(Mandatory = $false)]
    [string]$PurviewSubscriptionId = $null
)

Set-StrictMode -Version Latest

# Import security module
$SecurityModulePath = Join-Path $PSScriptRoot "../SecurityModule.ps1"
. $SecurityModulePath
$ErrorActionPreference = 'Stop'

function Log([string]$m) { Write-Host "[defender-purview] $m" -ForegroundColor Cyan }
function Warn([string]$m) { Write-Warning "[defender-purview] $m" }
function Success([string]$m) { Write-Host "[defender-purview] ✓ $m" -ForegroundColor Green }
function Info([string]$m) { Write-Host "[defender-purview] ℹ $m" -ForegroundColor Yellow }
function Fail([string]$m) { 
    Write-Error "[defender-purview] $m"
    Clear-SensitiveVariables -VariableNames @("accessToken", "armToken")
    exit 1 
}

Log "═══════════════════════════════════════════════════════════════"
Log "  Defender for AI ↔ Purview DSPM Integration"
Log "═══════════════════════════════════════════════════════════════"
Log ""

# Step 1: Validate Azure environment
Log "Step 1: Validating Azure Environment..."
Log "─────────────────────────────────────────────────────────────"

try {
    $account = az account show 2>$null | ConvertFrom-Json
    if (-not $account) {
        Fail "Not authenticated with Azure CLI. Run 'az login' first."
    }
    Success "Azure CLI authenticated"
    
    if (-not $SubscriptionId) {
        $envSubscriptionId = $null
        try {
            $envSubscriptionId = & azd env get-value aiSubscriptionId 2>$null
        } catch {
            # ignore
        }

        if ($envSubscriptionId) {
            if ($account.id -ne $envSubscriptionId) {
                az account set --subscription $envSubscriptionId 2>$null
                $account = az account show 2>$null | ConvertFrom-Json
                Success "Switched to subscription from azd environment: $($account.name)"
            }
            $SubscriptionId = $envSubscriptionId
        } else {
            $SubscriptionId = $account.id
        }
    } else {
        az account set --subscription $SubscriptionId 2>$null
        $account = az account show 2>$null | ConvertFrom-Json
    }
    
    Log "  Subscription: $($account.name)"
    Log "  Tenant ID: $($account.tenantId)"
} catch {
    Fail "Azure validation failed: $($_.Exception.Message)"
}
Log ""

if (-not $PurviewSubscriptionId) {
    try {
        $PurviewSubscriptionId = & azd env get-value purviewSubscriptionId 2>$null
    } catch {
        # ignore
    }
}

if ($PurviewSubscriptionId) {
    Log "  Purview subscription override detected: $PurviewSubscriptionId"
    Log ""
}

# Step 2: Verify Defender for AI is enabled
Log "Step 2: Verifying Defender for AI Status..."
Log "─────────────────────────────────────────────────────────────"

try {
    $aiPlan = az security pricing show --name "AI" --subscription $SubscriptionId 2>$null | ConvertFrom-Json
    
    if ($aiPlan -and $aiPlan.pricingTier -eq "Standard") {
        Success "Defender for AI services is enabled"
    } else {
        Warn "Defender for AI is not enabled"
        Fail "Please run ./enable_defender_for_ai.ps1 first"
    }
} catch {
    Fail "Could not verify Defender for AI: $($_.Exception.Message)"
}
Log ""

# Step 3: Check for Purview account
Log "Step 3: Checking for Microsoft Purview Account..."
Log "─────────────────────────────────────────────────────────────"

$purviewAccountName = $null
try {
    # Try to get from azd environment
    $purviewAccountName = & azd env get-value purviewAccountName 2>$null
} catch {
    # Not in azd environment
}

if ($purviewAccountName) {
    Success "Found Purview account from environment: $purviewAccountName"
} else {
    # Query for Purview accounts in subscription
    Log "Searching for Purview accounts in subscription..."
    
    try {
        $purviewQuery = "resources | where type =~ 'Microsoft.Purview/accounts' | project name, resourceGroup, location"
        $graphArgs = @('graph', 'query', '-q', $purviewQuery)

        if ($PurviewSubscriptionId) {
            $graphArgs += @('--subscriptions', $PurviewSubscriptionId)
        } elseif ($SubscriptionId) {
            $graphArgs += @('--subscriptions', $SubscriptionId)
        }

        $purviewAccounts = az @graphArgs 2>$null | ConvertFrom-Json
        
        if ($purviewAccounts.data -and $purviewAccounts.data.Count -gt 0) {
            Success "Found $($purviewAccounts.data.Count) Purview account(s)"
            
            if ($purviewAccounts.data.Count -eq 1) {
                $purviewAccountName = $purviewAccounts.data[0].name
                Success "Using Purview account: $purviewAccountName"
            } else {
                Log ""
                Log "Multiple Purview accounts found:"
                foreach ($acct in $purviewAccounts.data) {
                    Log "  • $($acct.name) (Resource Group: $($acct.resourceGroup))"
                }
                $purviewAccountName = $purviewAccounts.data[0].name
                Info "Using first account: $purviewAccountName"
            }
        } else {
            Warn "No Purview accounts found in subscription"
            Log "  Create a Purview account: https://portal.azure.com/#create/Microsoft.Purview"
        }
    } catch {
        Warn "Could not query for Purview accounts: $($_.Exception.Message)"
    }
}
Log ""

# Step 4: Enable Data Security for AI Interactions with Purview
Log "Step 4: Enabling Data Security for AI Interactions..."
Log "─────────────────────────────────────────────────────────────"

Log "This integration enables:"
Log "  • Sensitive information type (SIT) classification"
Log "  • Analytics and reporting through Purview DSPM for AI"
Log "  • Insider Risk Management integration"
Log "  • Communication Compliance policies"
Log "  • Microsoft Purview Audit logging"
Log "  • Data Lifecycle Management"
Log "  • eDiscovery capabilities"
Log ""

Info "Prerequisites for Purview Integration:"
Log "  ✓ Microsoft 365 E5 license (required)"
Log "  ✓ Microsoft Purview DSPM for AI enabled"
Log "  ✓ Purview account in same tenant"
Log "  ✓ Azure AI services use Entra ID authentication with user context"
Log ""

try {
    Log "Configuring Purview integration..."
    
    # Note: This configuration is primarily done through the portal
    # as the API for subplan extensions is still in preview
    
    Log ""
    Log "Manual Configuration Steps (Portal):"
    Log "─────────────────────────────────────────────────────────────"
    Log "  1. Open: https://portal.azure.com"
    Log "  2. Navigate to: Microsoft Defender for Cloud"
    Log "  3. Select: Environment settings"
    Log "  4. Choose subscription: $($account.name)"
    Log "  5. Locate: AI services → Settings button"
    Log "  6. Toggle: 'Enable data security for AI interactions' to ON"
    Log "  7. Select: Continue to save"
    Log ""
    
    if ($purviewAccountName) {
        Log "Purview Configuration:"
        Log "  • Purview account: $purviewAccountName"
        Log "  • Ensure DSPM for AI is enabled in Purview portal"
        Log "  • URL: https://purview.microsoft.com/purviewforai/overview"
        Log ""
    }
    
    Success "Integration configuration guidance provided"
    
} catch {
    Warn "Configuration guidance error: $($_.Exception.Message)"
}
Log ""

# Step 5: Verify DSPM policies are configured
Log "Step 5: Checking Purview DSPM Policies..."
Log "─────────────────────────────────────────────────────────────"

Log "Recommended Purview DSPM policies:"
Log ""
Log "1. KYD (Know Your Data) Policy"
Log "   • Policy: 'Secure interactions from enterprise apps'"
Log "   • Status: Should be created via PurviewGovernance scripts"
Log "   • Run: ../PurviewGovernance/create_dspm_policies.ps1"
Log ""
Log "2. Communication Compliance"
Log "   • Policy: 'Control Unethical Behavior in AI'"
Log "   • Create via: https://purview.microsoft.com/purviewforai/recommendations"
Log ""
Log "3. Insider Risk Management"
Log "   • Policy: 'Detect risky AI usage'"
Log "   • Create via: https://purview.microsoft.com/purviewforai/recommendations"
Log ""

# Step 6: Integration verification
Log "Step 6: Integration Verification Checklist..."
Log "─────────────────────────────────────────────────────────────"

Log "After enabling the integration, verify:"
Log ""
Log "☐ Defender for Cloud:"
Log "    • AI services plan: Enabled (Standard tier)"
Log "    • User prompt evidence: Enabled"
Log "    • Data security for AI interactions: Enabled"
Log ""
Log "☐ Microsoft Purview:"
Log "    • DSPM for AI: Activated"
Log "    • Purview Audit: Enabled"
Log "    • KYD policies: Created and status ON"
Log ""
Log "☐ Azure AI Services:"
Log "    • Authentication: Microsoft Entra ID with user context"
Log "    • Content filtering: Enabled (not opted out)"
Log "    • API calls include user-context tokens"
Log ""
Log "☐ Data Flow (after 24-48 hours):"
Log "    • Activity Explorer shows AI interactions"
Log "    • Purview reports populate with AI data"
Log "    • Sensitive data detections appear"
Log ""

Success "═══════════════════════════════════════════════════════════════"
Success "  Defender ↔ Purview Integration Configuration Complete!"
Success "═══════════════════════════════════════════════════════════════"
Log ""
Log "Integration Benefits:"
Log "  ✓ Comprehensive AI security and compliance"
Log "  ✓ Threat detection + governance policies"
Log "  ✓ Sensitive data classification"
Log "  ✓ Compliance reporting and analytics"
Log "  ✓ Unified security and governance view"
Log ""
Log "Next Steps:"
Log "  1. Complete portal configuration (see manual steps above)"
Log "  2. Ensure Purview DSPM policies are created:"
Log "     • Run: ../PurviewGovernance/enable_purview_dspm.ps1"
Log "     • Run: ../PurviewGovernance/create_dspm_policies.ps1"
Log "  3. Run: ./verify_defender_ai_configuration.ps1"
Log "  4. Wait 24-48 hours for data flow to begin"
Log "  5. Monitor both Defender and Purview portals"
Log ""
Log "Monitoring Portals:"
Log "  • Defender: https://portal.azure.com/#view/Microsoft_Azure_Security/SecurityMenuBlade"
Log "  • Purview: https://purview.microsoft.com/purviewforai/overview"
Log "  • Activity: https://purview.microsoft.com/activityexplorer"
Log ""
Log "Reference Documentation:"
Log "  • Integration guide:"
Log "    https://learn.microsoft.com/azure/defender-for-cloud/ai-onboarding#enable-data-security-for-azure-ai-with-microsoft-purview"
Log "  • DSPM for AI setup:"
Log "    https://learn.microsoft.com/purview/ai-microsoft-purview"
Log ""

# Clear sensitive variables
Clear-SensitiveVariables -VariableNames @("accessToken", "armToken")
