<#
.SYNOPSIS
  Enable Microsoft Defender for Cloud on Azure subscription.

.DESCRIPTION
  This script enables Microsoft Defender for Cloud, providing:
  - Cloud Security Posture Management (CSPM)
  - Threat protection capabilities
  - Security recommendations
  - Foundation for AI services protection

.NOTES
  Requires: Security Admin or Contributor role on Azure subscription
#>

[CmdletBinding()]
param(
    [Parameter(Mandatory = $false)]
    [string]$SubscriptionId = $null
)

Set-StrictMode -Version Latest

# Import security module
$SecurityModulePath = Join-Path $PSScriptRoot "../SecurityModule.ps1"
. $SecurityModulePath
$ErrorActionPreference = 'Stop'

function Log([string]$m) { Write-Host "[defender-cloud] $m" -ForegroundColor Cyan }
function Warn([string]$m) { Write-Warning "[defender-cloud] $m" }
function Success([string]$m) { Write-Host "[defender-cloud] ✓ $m" -ForegroundColor Green }
function Fail([string]$m) { 
    Write-Error "[defender-cloud] $m"
    Clear-SensitiveVariables -VariableNames @("accessToken", "armToken")
    exit 1 
}

Log "═══════════════════════════════════════════════════════════════"
Log "  Microsoft Defender for Cloud - Enablement Script"
Log "═══════════════════════════════════════════════════════════════"
Log ""

# Step 1: Validate Azure CLI and subscription
Log "Step 1: Validating Azure Environment..."
Log "─────────────────────────────────────────────────────────────"

try {
    $account = az account show 2>$null | ConvertFrom-Json
    if (-not $account) {
        Fail "Not authenticated with Azure CLI. Run 'az login' first."
    }
    Success "Azure CLI authenticated as: $($account.user.name)"

    if (-not $SubscriptionId) {
        $envSubscriptionId = $null
        try {
            $envSubscriptionId = & azd env get-value aiSubscriptionId 2>$null
        } catch {
            # ignore missing value
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
            Log "Using current subscription: $($account.name)"
        }
    } else {
        az account set --subscription $SubscriptionId 2>$null
        $account = az account show 2>$null | ConvertFrom-Json
        Success "Switched to subscription: $($account.name)"
    }

    Log "  Subscription ID: $SubscriptionId"
    Log "  Tenant ID: $($account.tenantId)"
} catch {
    Fail "Azure CLI validation failed: $($_.Exception.Message)"
}
Log ""

# Step 2: Check current Defender for Cloud status
Log "Step 2: Checking Defender for Cloud Status..."
Log "─────────────────────────────────────────────────────────────"

try {
    # Check if Defender for Cloud is already enabled
    Log "Querying Defender for Cloud registration..."
    
    $defenderStatus = az security pricing list --subscription $SubscriptionId 2>$null | ConvertFrom-Json
    
    if ($defenderStatus) {
        Success "Defender for Cloud is accessible"
        
        # Check if any plans are enabled
        $enabledPlans = $defenderStatus | Where-Object { $_.pricingTier -eq "Standard" }
        
        if ($enabledPlans) {
            Success "Found $($enabledPlans.Count) enabled Defender plan(s)"
            foreach ($plan in $enabledPlans) {
                Log "  • $($plan.name): $($plan.pricingTier)"
            }
        } else {
            Log "No Defender plans are currently enabled (Free tier)"
        }
    } else {
        Log "Defender for Cloud not yet configured"
    }
} catch {
    Warn "Could not check Defender status: $($_.Exception.Message)"
}
Log ""

# Step 3: Enable Defender for Cloud (if not already enabled)
Log "Step 3: Enabling Defender for Cloud..."
Log "─────────────────────────────────────────────────────────────"

try {
    # Register Microsoft.Security provider if needed
    Log "Ensuring Microsoft.Security provider is registered..."
    
    $securityProvider = az provider show --namespace Microsoft.Security 2>$null | ConvertFrom-Json
    
    if ($securityProvider.registrationState -ne "Registered") {
        Log "Registering Microsoft.Security provider..."
        az provider register --namespace Microsoft.Security --wait 2>$null
        Success "Microsoft.Security provider registered"
    } else {
        Success "Microsoft.Security provider already registered"
    }
    
    # Enable Defender CSPM (foundational plan)
    Log "Configuring Defender CSPM (Cloud Security Posture Management)..."
    
    $cspmResult = az security pricing create --name "CloudPosture" --tier "Standard" --subscription $SubscriptionId 2>$null
    
    if ($cspmResult) {
        Success "Defender CSPM enabled"
    } else {
        Log "CSPM configuration completed"
    }
    
    Log ""
    Log "Defender for Cloud foundational setup complete!"
    Log "Additional plans (AI, Containers, Databases) can be enabled separately."
    
} catch {
    Warn "Error during Defender for Cloud enablement: $($_.Exception.Message)"
    Log "Note: You may need to enable Defender for Cloud manually via portal:"
    Log "  https://portal.azure.com/#view/Microsoft_Azure_Security/SecurityMenuBlade/~/GettingStarted"
}
Log ""

# Step 4: Verify enablement
Log "Step 4: Verifying Defender for Cloud Configuration..."
Log "─────────────────────────────────────────────────────────────"

try {
    Log "Checking Defender for Cloud status..."
    
    $finalStatus = az security pricing list --subscription $SubscriptionId 2>$null | ConvertFrom-Json
    
    if ($finalStatus) {
        Log ""
        Log "Current Defender Plans:"
        Log "─────────────────────────────────────────────────────────────"
        
        $standardPlans = @()
        $freePlans = @()
        
        foreach ($plan in $finalStatus) {
            if ($plan.pricingTier -eq "Standard") {
                $standardPlans += $plan
                Log "  ✓ $($plan.name): Enabled"
            } else {
                $freePlans += $plan
            }
        }
        
        Log ""
        Log "Summary:"
        Log "  • Enabled plans: $($standardPlans.Count)"
        Log "  • Free tier plans: $($freePlans.Count)"
        
        if ($standardPlans.Count -gt 0) {
            Success "Defender for Cloud is active with $($standardPlans.Count) enabled plan(s)"
        } else {
            Warn "No Defender plans are currently enabled"
            Log "Run ./enable_defender_for_ai.ps1 to enable AI services protection"
        }
    }
} catch {
    Warn "Could not verify final status: $($_.Exception.Message)"
}
Log ""

Success "═══════════════════════════════════════════════════════════════"
Success "  Defender for Cloud Enablement Complete!"
Success "═══════════════════════════════════════════════════════════════"
Log ""
Log "Next Steps:"
Log "  1. Run: ./enable_defender_for_ai.ps1 to enable AI threat protection"
Log "  2. Run: ./enable_user_prompt_evidence.ps1 for AI evidence collection"
Log "  3. Run: ./connect_defender_to_purview.ps1 for DSPM integration"
Log "  4. Run: ./verify_defender_ai_configuration.ps1 to validate setup"
Log ""
Log "Portal Access:"
Log "  - Defender for Cloud: https://portal.azure.com/#view/Microsoft_Azure_Security/SecurityMenuBlade"
Log "  - Security Alerts: https://portal.azure.com/#view/Microsoft_Azure_Security/SecurityMenuBlade/~/SecurityAlerts"
Log "  - Recommendations: https://portal.azure.com/#view/Microsoft_Azure_Security/SecurityMenuBlade/~/Recommendations"
Log ""

# Clear sensitive variables
Clear-SensitiveVariables -VariableNames @("accessToken", "armToken")
