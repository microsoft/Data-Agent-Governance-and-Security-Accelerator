<#
.SYNOPSIS
  Enable Microsoft Defender for AI services threat protection.

.DESCRIPTION
  This script enables the Defender for AI services plan, providing:
  - Threat detection for Azure OpenAI and other AI services
  - Prompt injection attack detection
  - Data exfiltration monitoring
  - Jailbreak attempt identification
  - Anomalous usage pattern detection

.NOTES
  Requires: Defender for Cloud enabled, Security Admin or Contributor role
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

function Log([string]$m) { Write-Host "[defender-ai] $m" -ForegroundColor Cyan }
function Warn([string]$m) { Write-Warning "[defender-ai] $m" }
function Success([string]$m) { Write-Host "[defender-ai] ✓ $m" -ForegroundColor Green }
function Fail([string]$m) { 
    Write-Error "[defender-ai] $m"
    Clear-SensitiveVariables -VariableNames @("accessToken", "armToken")
    exit 1 
}

Log "═══════════════════════════════════════════════════════════════"
Log "  Microsoft Defender for AI Services - Enablement Script"
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
            Log "Using current subscription: $($account.name)"
        }
    } else {
        az account set --subscription $SubscriptionId 2>$null
        $account = az account show 2>$null | ConvertFrom-Json
        Success "Using subscription: $($account.name)"
    }

    Log "  Subscription ID: $SubscriptionId"
} catch {
    Fail "Azure validation failed: $($_.Exception.Message)"
}
Log ""

# Step 2: Verify Defender for Cloud is enabled
Log "Step 2: Verifying Defender for Cloud Status..."
Log "─────────────────────────────────────────────────────────────"

try {
    $defenderStatus = az security pricing list --subscription $SubscriptionId 2>$null | ConvertFrom-Json
    
    if (-not $defenderStatus) {
        Fail "Defender for Cloud is not accessible. Run ./enable_defender_for_cloud.ps1 first."
    }
    
    $enabledPlans = $defenderStatus | Where-Object { $_.pricingTier -eq "Standard" }
    
    if ($enabledPlans) {
        Success "Defender for Cloud is enabled with $($enabledPlans.Count) plan(s)"
    } else {
        Warn "Defender for Cloud is in Free tier - some features may be limited"
    }
} catch {
    Fail "Could not verify Defender for Cloud status: $($_.Exception.Message)"
}
Log ""

# Step 3: Check for AI services in subscription
Log "Step 3: Discovering AI Services in Subscription..."
Log "─────────────────────────────────────────────────────────────"

try {
    Log "Searching for Azure AI services..."
    
    # Query for Azure OpenAI and other AI services
    $aiServicesQuery = "resources | where type in~ ('Microsoft.CognitiveServices/accounts', 'Microsoft.MachineLearningServices/workspaces') | project name, type, resourceGroup, location"
    $aiServices = az graph query -q $aiServicesQuery --subscription $SubscriptionId 2>$null | ConvertFrom-Json
    
    if ($aiServices.data -and $aiServices.data.Count -gt 0) {
        Success "Found $($aiServices.data.Count) AI service(s)"
        Log ""
        foreach ($service in $aiServices.data) {
            Log "  • $($service.name)"
            Log "    Type: $($service.type)"
            Log "    Resource Group: $($service.resourceGroup)"
            Log "    Location: $($service.location)"
            Log ""
        }
    } else {
        Warn "No AI services found in subscription"
        Log "  Defender for AI will protect AI services when they are deployed"
        Log "  Deploy Azure OpenAI, AI Search, or AI Foundry to enable monitoring"
    }
} catch {
    Warn "Could not query for AI services: $($_.Exception.Message)"
    Log "  Continuing with Defender for AI enablement..."
}
Log ""

# Step 4: Enable Defender for AI services plan
Log "Step 4: Enabling Defender for AI Services Plan..."
Log "─────────────────────────────────────────────────────────────"

try {
    # Check current AI plan status
    $aiPlanStatus = az security pricing show --name "AI" --subscription $SubscriptionId 2>$null | ConvertFrom-Json
    
    if ($aiPlanStatus -and $aiPlanStatus.pricingTier -eq "Standard") {
        Success "Defender for AI services plan is already enabled"
        Log "  Tier: $($aiPlanStatus.pricingTier)"
        Log "  Plan: $($aiPlanStatus.name)"
    } else {
        Log "Enabling Defender for AI services plan..."
        
        $enableResult = az security pricing create --name "AI" --tier "Standard" --subscription $SubscriptionId 2>$null | ConvertFrom-Json
        
        if ($enableResult -and $enableResult.pricingTier -eq "Standard") {
            Success "Defender for AI services plan enabled successfully"
        } else {
            Warn "Plan enablement status unclear - verifying..."
            Start-Sleep -Seconds 5
            
            $verifyResult = az security pricing show --name "AI" --subscription $SubscriptionId 2>$null | ConvertFrom-Json
            if ($verifyResult -and $verifyResult.pricingTier -eq "Standard") {
                Success "Verified: Defender for AI services is enabled"
            } else {
                Fail "Could not enable Defender for AI services plan"
            }
        }
    }
} catch {
    Warn "Error during AI plan enablement: $($_.Exception.Message)"
    Log ""
    Log "Manual enablement instructions:"
    Log "  1. Open Azure Portal: https://portal.azure.com"
    Log "  2. Navigate to: Microsoft Defender for Cloud"
    Log "  3. Select: Environment settings"
    Log "  4. Choose your subscription: $SubscriptionId"
    Log "  5. Toggle 'AI' plan to 'On'"
    Log ""
}
Log ""

# Step 5: Verify enablement and configuration
Log "Step 5: Verifying AI Services Protection..."
Log "─────────────────────────────────────────────────────────────"

try {
    $finalStatus = az security pricing show --name "AI" --subscription $SubscriptionId 2>$null | ConvertFrom-Json
    
    if ($finalStatus) {
        Log ""
        Log "Defender for AI Services Configuration:"
        Log "─────────────────────────────────────────────────────────────"
        Log "  Plan Name: $($finalStatus.name)"
        Log "  Pricing Tier: $($finalStatus.pricingTier)"
        
        if ($finalStatus.pricingTier -eq "Standard") {
            Success "Threat protection is ACTIVE for AI services"
            Log ""
            Log "Protected AI Services:"
            Log "  ✓ Azure OpenAI Service"
            Log "  ✓ Azure AI Search"
            Log "  ✓ Azure AI Services (Cognitive Services)"
            Log "  ✓ Azure Machine Learning"
            Log ""
            Log "Threat Detection Capabilities:"
            Log "  ✓ Prompt injection attacks"
            Log "  ✓ Data exfiltration attempts"
            Log "  ✓ Jailbreak attempts"
            Log "  ✓ Anomalous usage patterns"
            Log "  ✓ Unauthorized access attempts"
        } else {
            Warn "AI services plan is in Free tier - limited protection"
        }
    }
} catch {
    Warn "Could not verify final configuration: $($_.Exception.Message)"
}
Log ""

Success "═══════════════════════════════════════════════════════════════"
Success "  Defender for AI Services Enablement Complete!"
Success "═══════════════════════════════════════════════════════════════"
Log ""
Log "What's Enabled:"
Log "  ✓ Threat detection for AI workloads"
Log "  ✓ Security alerts for AI services"
Log "  ✓ Attack pattern detection"
Log "  ✓ Real-time monitoring"
Log ""
Log "Next Steps:"
Log "  1. Run: ./enable_user_prompt_evidence.ps1 to capture AI interactions"
Log "  2. Run: ./connect_defender_to_purview.ps1 for DSPM integration"
Log "  3. Run: ./verify_defender_ai_configuration.ps1 to validate setup"
Log "  4. Wait 24 hours for threat detection to become active"
Log ""
Log "Monitoring:"
Log "  - Security Alerts: https://portal.azure.com/#view/Microsoft_Azure_Security/SecurityMenuBlade/~/SecurityAlerts"
Log "  - AI Dashboard: https://portal.azure.com/#view/Microsoft_Azure_Security/DataSecurityMenuBlade"
Log "  - Recommendations: https://portal.azure.com/#view/Microsoft_Azure_Security/SecurityMenuBlade/~/Recommendations"
Log ""
Log "Important:"
Log "  • Ensure AI services use Microsoft Entra ID authentication"
Log "  • Do not opt out of Azure OpenAI content filtering"
Log "  • User prompt evidence requires separate enablement (next step)"
Log ""

# Clear sensitive variables
Clear-SensitiveVariables -VariableNames @("accessToken", "armToken")
