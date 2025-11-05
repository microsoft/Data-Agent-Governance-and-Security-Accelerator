<#
.SYNOPSIS
  Verify Microsoft Defender for AI configuration.

.DESCRIPTION
  This script validates the complete Defender for AI setup:
  - Defender for Cloud status
  - AI services plan enablement
  - User prompt evidence configuration
  - Purview integration status
  - Overall configuration health

.NOTES
  Run after all enablement scripts complete
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

function Log([string]$m) { Write-Host "[verify-defender] $m" -ForegroundColor Cyan }
function Warn([string]$m) { Write-Warning "[verify-defender] $m" }
function Success([string]$m) { Write-Host "[verify-defender] ✓ $m" -ForegroundColor Green }
function Info([string]$m) { Write-Host "[verify-defender] ℹ $m" -ForegroundColor Yellow }
function Fail([string]$m) { Write-Error "[verify-defender] $m" }

Log "═══════════════════════════════════════════════════════════════"
Log "  Microsoft Defender for AI - Configuration Verification"
Log "═══════════════════════════════════════════════════════════════"
Log ""

$verificationResults = @{
    AzureAuth = $false
    DefenderForCloud = $false
    AIServicesPlan = $false
    PromptEvidence = "Unknown"
    PurviewIntegration = "Unknown"
    AIServicesCount = 0
    OverallHealth = "Unknown"
}

# Step 1: Verify Azure Authentication
Log "Step 1: Verifying Azure Authentication..."
Log "─────────────────────────────────────────────────────────────"

try {
    $account = az account show 2>$null | ConvertFrom-Json
    if ($account) {
        Success "Azure CLI authenticated"
        Log "  User: $($account.user.name)"
        Log "  Tenant: $($account.tenantId)"

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
        Log "  Subscription ID: $SubscriptionId"
        $verificationResults.AzureAuth = $true
    } else {
        Warn "Not authenticated with Azure CLI"
    }
} catch {
    Warn "Azure CLI check failed: $($_.Exception.Message)"
}
Log ""

# Step 2: Check Defender for Cloud Status
Log "Step 2: Checking Defender for Cloud Status..."
Log "─────────────────────────────────────────────────────────────"

try {
    $defenderPlans = az security pricing list --subscription $SubscriptionId 2>$null | ConvertFrom-Json
    
    if ($defenderPlans) {
        Success "Defender for Cloud is accessible"
        $verificationResults.DefenderForCloud = $true
        
        $enabledPlans = $defenderPlans | Where-Object { $_.pricingTier -eq "Standard" }
        
        if ($enabledPlans -and $enabledPlans.Count -gt 0) {
            Success "Found $($enabledPlans.Count) enabled Defender plan(s)"
            Log ""
            foreach ($plan in $enabledPlans) {
                Log "  ✓ $($plan.name): Enabled"
            }
        } else {
            Warn "No Defender plans enabled (Free tier only)"
            Log "  Run: ./enable_defender_for_cloud.ps1"
        }
    } else {
        Warn "Could not access Defender for Cloud"
    }
} catch {
    Warn "Defender for Cloud check failed: $($_.Exception.Message)"
}
Log ""

# Step 3: Verify AI Services Plan
Log "Step 3: Verifying Defender for AI Services Plan..."
Log "─────────────────────────────────────────────────────────────"

try {
    $aiPlan = az security pricing show --name "AI" --subscription $SubscriptionId 2>$null | ConvertFrom-Json
    
    if ($aiPlan) {
        if ($aiPlan.pricingTier -eq "Standard") {
            Success "Defender for AI services plan is ENABLED"
            $verificationResults.AIServicesPlan = $true
            
            Log "  Plan: $($aiPlan.name)"
            Log "  Tier: $($aiPlan.pricingTier)"
            Log ""
            Log "  Protected Services:"
            Log "    ✓ Azure OpenAI Service"
            Log "    ✓ Azure AI Search"
            Log "    ✓ Azure Cognitive Services"
            Log "    ✓ Azure Machine Learning"
        } else {
            Warn "AI services plan is in Free tier"
            Log "  Current tier: $($aiPlan.pricingTier)"
            Log "  Run: ./enable_defender_for_ai.ps1"
        }
    } else {
        Warn "AI services plan not found"
    }
} catch {
    Warn "AI services plan check failed: $($_.Exception.Message)"
}
Log ""

# Step 4: Check for AI Services in Subscription
Log "Step 4: Discovering AI Services..."
Log "─────────────────────────────────────────────────────────────"

try {
    $aiServicesQuery = "resources | where type in~ ('Microsoft.CognitiveServices/accounts', 'Microsoft.MachineLearningServices/workspaces') | project name, type, resourceGroup, location"
    $aiServices = az graph query -q $aiServicesQuery --subscription $SubscriptionId 2>$null | ConvertFrom-Json
    
    if ($aiServices.data -and $aiServices.data.Count -gt 0) {
        Success "Found $($aiServices.data.Count) AI service(s)"
        $verificationResults.AIServicesCount = $aiServices.data.Count
        
        Log ""
        foreach ($service in $aiServices.data) {
            Log "  • $($service.name)"
            Log "    Type: $($service.type)"
            Log "    Location: $($service.location)"
        }
    } else {
        Info "No AI services found in subscription"
        Log "  Deploy AI services to begin monitoring"
    }
} catch {
    Warn "AI services discovery failed: $($_.Exception.Message)"
}
Log ""

# Step 5: Check User Prompt Evidence Configuration
Log "Step 5: Checking User Prompt Evidence Configuration..."
Log "─────────────────────────────────────────────────────────────"

try {
    # Check via API if possible
    $apiVersion = "2024-01-01"
    $uri = "https://management.azure.com/subscriptions/$SubscriptionId/providers/Microsoft.Security/pricings/AI?api-version=$apiVersion"
    
    $aiConfig = az rest --method GET --uri $uri 2>$null | ConvertFrom-Json
    
    if ($aiConfig -and $aiConfig.properties) {
        if ($aiConfig.properties.PSObject.Properties.Name -contains 'extensions') {
            $promptEvidence = $aiConfig.properties.extensions | Where-Object { $_.name -eq "UserPromptEvidence" }
            
            if ($promptEvidence) {
                if ($promptEvidence.isEnabled -eq "True") {
                    Success "User prompt evidence is ENABLED"
                    $verificationResults.PromptEvidence = "Enabled"
                } else {
                    Warn "User prompt evidence is disabled"
                    $verificationResults.PromptEvidence = "Disabled"
                }
            } else {
                Info "User prompt evidence configuration not found"
                $verificationResults.PromptEvidence = "Not Configured"
            }
        } else {
            Info "Cannot determine prompt evidence status via API"
            $verificationResults.PromptEvidence = "Manual Check Required"
        }
    }
    
    Log ""
    Log "Manual Verification:"
    Log "  1. Portal: https://portal.azure.com/#view/Microsoft_Azure_Security/SecurityMenuBlade"
    Log "  2. Navigate: Environment settings → Your subscription"
    Log "  3. Check: AI services → Settings → User prompt evidence"
    
} catch {
    Info "Could not check prompt evidence status: $($_.Exception.Message)"
    $verificationResults.PromptEvidence = "Check Manually"
}
Log ""

# Step 6: Check Purview Integration
Log "Step 6: Checking Purview Integration..."
Log "─────────────────────────────────────────────────────────────"

try {
    # Check for Purview account
    $purviewQuery = "resources | where type =~ 'Microsoft.Purview/accounts' | project name, resourceGroup"
    $purviewAccounts = az graph query -q $purviewQuery --subscription $SubscriptionId 2>$null | ConvertFrom-Json
    
    if ($purviewAccounts.data -and $purviewAccounts.data.Count -gt 0) {
        Success "Found Purview account(s): $($purviewAccounts.data.Count)"
        
        foreach ($acct in $purviewAccounts.data) {
            Log "  • $($acct.name)"
        }
        
        Log ""
        Info "Verify Purview DSPM Integration:"
        Log "  1. Check: Defender AI settings → 'Data security for AI interactions'"
        Log "  2. Verify: Purview DSPM for AI is enabled"
        Log "  3. Portal: https://purview.microsoft.com/purviewforai/overview"
        
        $verificationResults.PurviewIntegration = "Available"
    } else {
        Info "No Purview accounts found"
        Log "  Purview integration requires a Purview account and M365 E5"
        $verificationResults.PurviewIntegration = "Not Available"
    }
} catch {
    Warn "Purview check failed: $($_.Exception.Message)"
    $verificationResults.PurviewIntegration = "Unknown"
}
Log ""

# Step 7: Configuration Health Summary
Log "Step 7: Configuration Health Summary..."
Log "─────────────────────────────────────────────────────────────"

# Calculate overall health
$healthScore = 0
$maxScore = 5

if ($verificationResults.AzureAuth) { $healthScore++ }
if ($verificationResults.DefenderForCloud) { $healthScore++ }
if ($verificationResults.AIServicesPlan) { $healthScore++ }
if ($verificationResults.PromptEvidence -eq "Enabled") { $healthScore++ }
if ($verificationResults.PurviewIntegration -eq "Configured") { $healthScore++ }

if ($healthScore -ge 4) {
    $verificationResults.OverallHealth = "Healthy"
} elseif ($healthScore -ge 2) {
    $verificationResults.OverallHealth = "Partial"
} else {
    $verificationResults.OverallHealth = "Needs Attention"
}

Log ""
Log "Configuration Health: $($verificationResults.OverallHealth) ($healthScore/$maxScore)"
Log "─────────────────────────────────────────────────────────────"
Log "  Azure Authentication:         $(if($verificationResults.AzureAuth){'✓ Connected'}else{'✗ Not Connected'})"
Log "  Defender for Cloud:           $(if($verificationResults.DefenderForCloud){'✓ Enabled'}else{'✗ Not Enabled'})"
Log "  AI Services Plan:             $(if($verificationResults.AIServicesPlan){'✓ Enabled'}else{'✗ Not Enabled'})"
Log "  User Prompt Evidence:         $($verificationResults.PromptEvidence)"
Log "  Purview Integration:          $($verificationResults.PurviewIntegration)"
Log "  AI Services Deployed:         $($verificationResults.AIServicesCount)"
Log ""

# Step 8: Recommendations
Log "Step 8: Recommendations..."
Log "─────────────────────────────────────────────────────────────"

if ($verificationResults.OverallHealth -eq "Healthy") {
    Success "Configuration is healthy!"
    Log ""
    Log "Next Actions:"
    Log "  ✓ Monitor security alerts for AI services"
    Log "  ✓ Review recommendations in Defender for Cloud"
    Log "  ✓ Test AI services to ensure evidence collection"
    Log "  ✓ Check Purview DSPM after 24-48 hours"
} else {
    Log ""
    Log "Recommended Actions:"
    
    if (-not $verificationResults.DefenderForCloud) {
        Log "  • Enable Defender for Cloud: ./enable_defender_for_cloud.ps1"
    }
    
    if (-not $verificationResults.AIServicesPlan) {
        Log "  • Enable AI services plan: ./enable_defender_for_ai.ps1"
    }
    
    if ($verificationResults.PromptEvidence -ne "Enabled") {
        Log "  • Enable prompt evidence: ./enable_user_prompt_evidence.ps1"
    }
    
    if ($verificationResults.PurviewIntegration -ne "Configured") {
        Log "  • Configure Purview integration: ./connect_defender_to_purview.ps1"
    }
    
    if ($verificationResults.AIServicesCount -eq 0) {
        Log "  • Deploy AI services to begin monitoring"
    }
}
Log ""

# Step 9: Monitoring Links
Log "Step 9: Monitoring and Management Links..."
Log "─────────────────────────────────────────────────────────────"

Log ""
Log "Defender for Cloud:"
Log "  • Dashboard: https://portal.azure.com/#view/Microsoft_Azure_Security/SecurityMenuBlade"
Log "  • Security Alerts: https://portal.azure.com/#view/Microsoft_Azure_Security/SecurityMenuBlade/~/SecurityAlerts"
Log "  • Recommendations: https://portal.azure.com/#view/Microsoft_Azure_Security/SecurityMenuBlade/~/Recommendations"
Log "  • Environment Settings: https://portal.azure.com/#view/Microsoft_Azure_Security/SecurityMenuBlade/~/EnvironmentSettings"
Log ""

if ($verificationResults.PurviewIntegration -ne "Not Available") {
    Log "Microsoft Purview:"
    Log "  • DSPM for AI: https://purview.microsoft.com/purviewforai/overview"
    Log "  • Activity Explorer: https://purview.microsoft.com/activityexplorer"
    Log "  • Reports: https://purview.microsoft.com/purviewforai/reports"
    Log ""
}

Log "What to Monitor:"
Log "  • Security alerts for AI services (prompt injection, data exfiltration)"
Log "  • Anomalous usage patterns in AI resources"
Log "  • User prompt evidence in alert details"
Log "  • Compliance status in Purview (if integrated)"
Log "  • Recommendations for AI security posture"
Log ""

Success "═══════════════════════════════════════════════════════════════"
Success "  Configuration Verification Complete!"
Success "═══════════════════════════════════════════════════════════════"
Log ""
Log "Summary: $($verificationResults.OverallHealth) configuration"
Log ""
Log "Note: Allow 24-48 hours for full data collection and alert generation"
Log ""

# Clear sensitive variables
Clear-SensitiveVariables -VariableNames @("accessToken", "armToken")
