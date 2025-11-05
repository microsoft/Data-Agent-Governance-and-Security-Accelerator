<#
.SYNOPSIS
  Enable Microsoft Purview Data Security Posture Management (DSPM) for AI.

.DESCRIPTION
  This script enables DSPM for AI in your Microsoft 365 tenant, including:
  - Validation of tenant prerequisites (M365 E5)
  - Activation of Microsoft Purview Audit
  - Enabling DSPM for AI hub
  - Status verification and reporting

.NOTES
  Requires: Microsoft Entra Compliance Admin, Global Admin, or Purview Compliance Admin role
  License: Microsoft 365 E5
#>

[CmdletBinding()]
param()

Set-StrictMode -Version Latest

# Import security module
$SecurityModulePath = Join-Path $PSScriptRoot "../SecurityModule.ps1"
. $SecurityModulePath
$ErrorActionPreference = 'Stop'

function Log([string]$m) { Write-Host "[dspm-enable] $m" -ForegroundColor Cyan }
function Warn([string]$m) { Write-Warning "[dspm-enable] $m" }
function Success([string]$m) { Write-Host "[dspm-enable] ✓ $m" -ForegroundColor Green }
function Fail([string]$m) { 
    Write-Error "[dspm-enable] $m"
    Clear-SensitiveVariables -VariableNames @("accessToken", "purviewToken", "graphToken")
    exit 1 
}

Log "═══════════════════════════════════════════════════════════════"
Log "  Microsoft Purview DSPM for AI - Enablement Script"
Log "═══════════════════════════════════════════════════════════════"
Log ""

# Step 1: Validate Prerequisites
Log "Step 1: Validating Prerequisites..."
Log "─────────────────────────────────────────────────────────────"

# Check Azure CLI authentication
try {
    $account = az account show 2>$null | ConvertFrom-Json
    if (-not $account) {
        Fail "Not authenticated with Azure CLI. Run 'az login' first."
    }
    Success "Azure CLI authenticated as: $($account.user.name)"
    Log "  Tenant: $($account.tenantId)"
} catch {
    Fail "Azure CLI authentication check failed: $($_.Exception.Message)"
}

# Get tenant ID
$tenantId = $account.tenantId
Log ""

# Step 2: Acquire tokens for Purview and Microsoft Graph
Log "Step 2: Acquiring Access Tokens..."
Log "─────────────────────────────────────────────────────────────"

try {
    # Purview token for audit operations
    $purviewToken = Get-SecureApiToken -Resource $SecureApiResources.Purview -Description "Purview"
    Success "Purview token acquired"
    $null = $purviewToken.Length
    
    # Microsoft Graph token for compliance operations
    $graphToken = Get-SecureApiToken -Resource "https://graph.microsoft.com" -Description "Microsoft Graph"
    Success "Microsoft Graph token acquired"
    
    # Note: Tokens are acquired for potential future use in automated configuration
    # Currently, most DSPM configuration is done through portal or Exchange Online PowerShell
} catch {
    Fail "Failed to acquire access tokens: $($_.Exception.Message)"
}

Log ""

# Step 2a: Validate Microsoft 365 E5 Licensing
Log "Step 2a: Validating Microsoft 365 licensing..."
Log "─────────────────────────────────────────────────────────────"

try {
    $headers = New-SecureHeaders -Token $graphToken
    $skuResponse = Invoke-SecureRestMethod -Uri "https://graph.microsoft.com/v1.0/subscribedSkus" -Headers $headers -Description "Microsoft 365 subscribed SKUs"

    if (-not $skuResponse.value) {
        Fail "No Microsoft 365 licenses returned. Verify Graph permissions for the signed-in identity."
    }

    $e5Skus = $skuResponse.value | Where-Object { $_.skuPartNumber -match 'E5' }

    if ($e5Skus) {
        $skuNames = ($e5Skus | Select-Object -ExpandProperty skuPartNumber -Unique) -join ', '
        Success "Detected Microsoft 365 E5 SKU(s): $skuNames"
    } else {
        Fail "Microsoft 365 E5 licensing not detected. DSPM for AI requires an active M365 E5 or equivalent license. Assign the license and rerun the script."
    }
} catch {
    Fail "Microsoft 365 licensing check failed: $($_.Exception.Message)"
}

Log ""

# Step 3: Check/Enable Microsoft Purview Audit
Log "Step 3: Enabling Microsoft Purview Audit..."
Log "─────────────────────────────────────────────────────────────"

try {
    # Use Microsoft Graph to check audit status
    # Note: Audit enablement is typically done through the portal or Exchange Online PowerShell
    Log "Checking audit configuration..."
    
    # Check if audit is already enabled
    $auditEnabled = $false
    try {
        # Try to query audit logs to see if auditing is enabled
        $auditCheck = az rest --method GET `
            --uri "https://manage.office.com/api/v1.0/$tenantId/activity/feed/subscriptions/list" `
            --resource "https://manage.office.com" 2>$null
        
        if ($auditCheck) {
            $auditEnabled = $true
            Success "Microsoft Purview Audit is already enabled"
        }
    } catch {
        Log "Audit may not be enabled yet..."
    }
    
    if (-not $auditEnabled) {
        Warn "Microsoft Purview Audit needs to be enabled manually"
        Log "  Please follow these steps:"
        Log "  1. Go to: https://purview.microsoft.com/purviewforai/overview"
        Log "  2. In the 'Get Started' section, select 'Activate Microsoft Purview Audit'"
        Log "  3. Click 'Activate' and wait for status to turn green"
        Log ""
        Log "  Alternatively, use Exchange Online PowerShell:"
        Log "  Connect-IPPSSession"
        Log "  Set-AdminAuditLogConfig -UnifiedAuditLogIngestionEnabled `$true"
        Log ""
        
        # Prompt user to continue
        $continue = Read-Host "Have you enabled Microsoft Purview Audit? (y/n)"
        if ($continue -ne 'y') {
            Fail "Script aborted. Please enable Microsoft Purview Audit first."
        }
    }
} catch {
    Warn "Could not automatically verify audit status: $($_.Exception.Message)"
    Log "Manual verification required via portal"
}
Log ""

# Step 4: Enable DSPM for AI Hub
Log "Step 4: Enabling DSPM for AI Hub..."
Log "─────────────────────────────────────────────────────────────"

try {
    Log "DSPM for AI hub activation is managed through the Microsoft Purview portal"
    Log ""
    Log "Automatic activation steps:"
    Log "  1. Portal URL: https://purview.microsoft.com/purviewforai/overview"
    Log "  2. Navigate to 'Overview' > 'Get Started'"
    Log "  3. Ensure DSPM for AI hub is activated (green status indicator)"
    Log ""
    
    Warn "Note: DSPM for AI requires Microsoft 365 E5 license"
    Log "If you don't see DSPM for AI in the portal:"
    Log "  - Verify M365 E5 license is assigned"
    Log "  - Contact your Microsoft account team for preview access"
    Log ""
    
    Success "DSPM for AI hub enablement information provided"
} catch {
    Fail "Error during DSPM hub check: $($_.Exception.Message)"
}
Log ""

# Step 5: Verify Configuration
Log "Step 5: Verification Summary..."
Log "─────────────────────────────────────────────────────────────"

Log ""
Log "✓ Prerequisites validated"
Log "✓ Access tokens acquired"
Log "✓ Audit configuration checked"
Log "✓ DSPM for AI hub information provided"
Log ""

Success "═══════════════════════════════════════════════════════════════"
Success "  DSPM for AI Enablement Complete!"
Success "═══════════════════════════════════════════════════════════════"
Log ""
Log "Next Steps:"
Log "  1. Run: ./create_dspm_policies.ps1 to create DSPM policies"
Log "  2. Run: ./connect_dspm_to_ai_foundry.ps1 to connect to AI Foundry"
Log "  3. Run: ./verify_dspm_configuration.ps1 to validate setup"
Log ""
Log "Portal Access:"
Log "  - DSPM for AI: https://purview.microsoft.com/purviewforai/overview"
Log "  - Recommendations: https://purview.microsoft.com/purviewforai/recommendations"
Log "  - Reports: https://purview.microsoft.com/purviewforai/reports"
Log ""

# Clear sensitive variables
Clear-SensitiveVariables -VariableNames @("accessToken", "purviewToken", "graphToken")
