<#
.SYNOPSIS
  Verify Microsoft Purview DSPM for AI configuration.

.DESCRIPTION
  This script validates the DSPM configuration and reports on:
  - Audit status
  - Policy creation and status
  - AI app data collection
  - Sensitive data detection
  - Configuration health summary

.NOTES
  Run this script after enabling DSPM and creating policies
#>

[CmdletBinding()]
param()

Set-StrictMode -Version Latest

# Import security module
$SecurityModulePath = Join-Path $PSScriptRoot "../SecurityModule.ps1"
. $SecurityModulePath
$ErrorActionPreference = 'Stop'

function Log([string]$m) { Write-Host "[dspm-verify] $m" -ForegroundColor Cyan }
function Warn([string]$m) { Write-Warning "[dspm-verify] $m" }
function Success([string]$m) { Write-Host "[dspm-verify] ✓ $m" -ForegroundColor Green }
function Info([string]$m) { Write-Host "[dspm-verify] ℹ $m" -ForegroundColor Yellow }
function Fail([string]$m) { 
    Write-Error "[dspm-verify] $m"
    exit 1 
}

Log "═══════════════════════════════════════════════════════════════"
Log "  Microsoft Purview DSPM for AI - Configuration Verification"
Log "═══════════════════════════════════════════════════════════════"
Log ""

$verificationResults = @{
    AzureAuth = $false
    ExchangeConnection = $false
    PoliciesConfigured = 0
    AuditEnabled = $false
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
        Log "  Subscription: $($account.name)"
        $verificationResults.AzureAuth = $true
    } else {
        Warn "Not authenticated with Azure CLI"
    }
} catch {
    Warn "Azure CLI check failed: $($_.Exception.Message)"
}
Log ""

# Step 2: Check Exchange Online Connection
Log "Step 2: Checking Exchange Online PowerShell..."
Log "─────────────────────────────────────────────────────────────"

try {
    $module = Get-Module -Name ExchangeOnlineManagement -ListAvailable
    if ($module) {
        Success "ExchangeOnlineManagement module installed"
        
        # Try to import if not already imported
        if (-not (Get-Module -Name ExchangeOnlineManagement)) {
            try {
                Import-Module ExchangeOnlineManagement -ErrorAction SilentlyContinue
            } catch {
                # Ignore import errors
            }
        }
        
        # Check if connected
        try {
            $testCmd = Get-Command Get-FeatureConfiguration -ErrorAction SilentlyContinue
            if ($testCmd) {
                Success "Connected to Security & Compliance PowerShell"
                $verificationResults.ExchangeConnection = $true
            } else {
                Info "Not connected to Security & Compliance PowerShell"
                Log "  To connect, run: Connect-IPPSSession"
            }
        } catch {
            Info "Could not verify connection to Security & Compliance PowerShell"
        }
    } else {
        Info "ExchangeOnlineManagement module not installed"
        Log "  To install: Install-Module -Name ExchangeOnlineManagement -Force"
    }
} catch {
    Warn "Exchange Online check failed: $($_.Exception.Message)"
}
Log ""

# Step 3: Verify DSPM Policies
Log "Step 3: Verifying DSPM Policies..."
Log "─────────────────────────────────────────────────────────────"

if ($verificationResults.ExchangeConnection) {
    try {
        # Get all DSPM/AI related policies
        $allPolicies = Get-FeatureConfiguration | Where-Object { 
            $_.Identity -like "*DSPM*" -or 
            $_.Identity -like "*AI*" -or 
            $_.Identity -like "*Collection policy*"
        }
        
        if ($allPolicies) {
            Success "Found $($allPolicies.Count) DSPM/AI policy/policies"
            Log ""
            
            foreach ($policy in $allPolicies) {
                Log "  Policy: $($policy.Identity)"
                Log "    Status: $($policy.ConfigurationStatus)"
                
                if ($policy.ConfigurationStatus -eq "Enabled" -or $policy.ConfigurationStatus -eq "On") {
                    Success "    ✓ Active"
                    $verificationResults.PoliciesConfigured++
                } else {
                    Warn "    ⚠ Not active"
                }
                
                # Parse scenario config if available
                if ($policy.ScenarioConfig) {
                    try {
                        $config = $policy.ScenarioConfig | ConvertFrom-Json
                        if ($config.IsIngestionEnabled) {
                            Log "    Ingestion: Enabled"
                        }
                        if ($config.Activities) {
                            Log "    Activities: $($config.Activities -join ', ')"
                        }
                    } catch {
                        # Ignore parsing errors
                    }
                }
                Log ""
            }
        } else {
            Warn "No DSPM/AI policies found"
            Log "  Expected policies:"
            Log "    • DSPM for AI - Collection policy for enterprise AI apps (KYD)"
            Log "    • Communication Compliance policies"
            Log "    • Insider Risk Management policies"
            Log ""
            Log "  Create policies with: ./create_dspm_policies.ps1"
        }
    } catch {
        Warn "Could not retrieve policy configurations: $($_.Exception.Message)"
    }
} else {
    Info "Skipping policy verification (not connected to Security & Compliance PowerShell)"
    Log "  Connect with: Connect-IPPSSession"
}
Log ""

# Step 4: Check Audit Status
Log "Step 4: Checking Microsoft Purview Audit Status..."
Log "─────────────────────────────────────────────────────────────"

try {
    if ($verificationResults.AzureAuth) {
        $tenantId = $account.tenantId
        
        # Try to check audit status
        Log "Attempting to verify audit configuration..."
        
        try {
            # This is a simplified check - actual audit verification requires specific permissions
            $auditCheck = az rest --method GET `
                --uri "https://manage.office.com/api/v1.0/$tenantId/activity/feed/subscriptions/list" `
                --resource "https://manage.office.com" 2>$null
            
            if ($auditCheck) {
                Success "Microsoft Purview Audit appears to be enabled"
                $verificationResults.AuditEnabled = $true
            }
        } catch {
            Info "Could not automatically verify audit status"
            Log "  Manual verification required:"
            Log "    1. Go to: https://purview.microsoft.com/purviewforai/overview"
            Log "    2. Check 'Get Started' section for audit status"
            Log "    3. Status should show as 'enabled' (green)"
        }
    }
} catch {
    Info "Audit status check not available: $($_.Exception.Message)"
}
Log ""

# Step 5: Portal Links and Manual Checks
Log "Step 5: Manual Verification Checklist..."
Log "─────────────────────────────────────────────────────────────"

Log "Please verify the following in the Microsoft Purview portal:"
Log ""
Log "1. DSPM for AI Overview"
Log "   URL: https://purview.microsoft.com/purviewforai/overview"
Log "   Check:"
Log "     ☐ Microsoft Purview Audit is activated (green status)"
Log "     ☐ Get started checklist shows completed items"
Log ""
Log "2. Policies Status"
Log "   URL: https://purview.microsoft.com/purviewforai/policies"
Log "   Check:"
Log "     ☐ 'Secure interactions from enterprise apps' status = ON"
Log "     ☐ 'Control Unethical Behavior in AI' status = ON"
Log "     ☐ 'Detect risky AI usage' status = ON"
Log ""
Log "3. Activity Explorer (after 24-48 hours)"
Log "   URL: https://purview.microsoft.com/activityexplorer"
Log "   Check:"
Log "     ☐ AI interactions are appearing"
Log "     ☐ Enterprise AI apps category shows data"
Log "     ☐ Sensitive information types detected (if applicable)"
Log ""
Log "4. Reports (after 24-48 hours)"
Log "   URL: https://purview.microsoft.com/purviewforai/reports"
Log "   Check:"
Log "     ☐ AI activity reports show data"
Log "     ☐ Sensitive data reports populated"
Log "     ☐ User activity trends visible"
Log ""

# Step 6: Configuration Health Summary
Log "Step 6: Configuration Health Summary..."
Log "─────────────────────────────────────────────────────────────"

# Determine overall health
$healthScore = 0
if ($verificationResults.AzureAuth) { $healthScore++ }
if ($verificationResults.ExchangeConnection) { $healthScore++ }
if ($verificationResults.PoliciesConfigured -gt 0) { $healthScore += 2 }
if ($verificationResults.AuditEnabled) { $healthScore++ }

if ($healthScore -ge 4) {
    $verificationResults.OverallHealth = "Healthy"
} elseif ($healthScore -ge 2) {
    $verificationResults.OverallHealth = "Partial"
} else {
    $verificationResults.OverallHealth = "Needs Attention"
}

Log ""
Log "Configuration Health: $($verificationResults.OverallHealth)"
Log "─────────────────────────────────────────────────────────────"
Log "  Azure Authentication:        $(if($verificationResults.AzureAuth){'✓ Connected'}else{'✗ Not Connected'})"
Log "  Exchange Connection:         $(if($verificationResults.ExchangeConnection){'✓ Connected'}else{'✗ Not Connected'})"
Log "  DSPM Policies Configured:    $($verificationResults.PoliciesConfigured) policy/policies"
Log "  Microsoft Purview Audit:     $(if($verificationResults.AuditEnabled){'✓ Enabled'}else{'⚠ Verify Manually'})"
Log ""

if ($verificationResults.OverallHealth -eq "Healthy") {
    Success "═══════════════════════════════════════════════════════════════"
    Success "  DSPM Configuration Verified - Healthy!"
    Success "═══════════════════════════════════════════════════════════════"
} elseif ($verificationResults.OverallHealth -eq "Partial") {
    Warn "═══════════════════════════════════════════════════════════════"
    Warn "  DSPM Configuration Partially Complete"
    Warn "═══════════════════════════════════════════════════════════════"
    Log ""
    Log "Recommended Actions:"
    if (-not $verificationResults.ExchangeConnection) {
        Log "  • Connect to Security & Compliance PowerShell: Connect-IPPSSession"
    }
    if ($verificationResults.PoliciesConfigured -eq 0) {
        Log "  • Create DSPM policies: ./create_dspm_policies.ps1"
    }
} else {
    Warn "═══════════════════════════════════════════════════════════════"
    Warn "  DSPM Configuration Needs Attention"
    Warn "═══════════════════════════════════════════════════════════════"
    Log ""
    Log "Required Actions:"
    if (-not $verificationResults.AzureAuth) {
        Log "  • Authenticate with Azure CLI: az login"
    }
    Log "  • Run enablement script: ./enable_purview_dspm.ps1"
    Log "  • Create policies: ./create_dspm_policies.ps1"
}

Log ""
Log "Additional Resources:"
Log "  - DSPM Documentation: https://learn.microsoft.com/purview/ai-microsoft-purview"
Log "  - Configuration Guide: https://learn.microsoft.com/purview/developer/configurepurview"
Log "  - API Integration: https://learn.microsoft.com/purview/developer/secure-ai-with-purview"
Log ""

Log "Note: Allow 24-48 hours after configuration for data to appear in reports"
Log ""
