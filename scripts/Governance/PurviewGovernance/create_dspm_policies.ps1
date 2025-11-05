<#
.SYNOPSIS
  Create Microsoft Purview DSPM for AI one-click policies.

.DESCRIPTION
  This script creates the recommended DSPM for AI policies including:
  - KYD (Know Your Data) policy: "Secure interactions from enterprise apps"
  - Communication Compliance policy: "Control Unethical Behavior in AI"
  - Insider Risk Management policy: "Detect risky AI usage"

.NOTES
  Requires: Exchange Online Management module and appropriate admin permissions
  Must be connected to Security & Compliance PowerShell (Connect-IPPSSession)
#>

[CmdletBinding()]
param(
    [Parameter(Mandatory = $false)]
    [switch]$DisableIngestion,
    
    [Parameter(Mandatory = $false)]
    [switch]$SkipKYDPolicy,
    
    [Parameter(Mandatory = $false)]
    [switch]$Force
)

Set-StrictMode -Version Latest

# Import security module
$SecurityModulePath = Join-Path $PSScriptRoot "../SecurityModule.ps1"
. $SecurityModulePath
$ErrorActionPreference = 'Stop'

function Log([string]$m) { Write-Host "[dspm-policies] $m" -ForegroundColor Cyan }
function Warn([string]$m) { Write-Warning "[dspm-policies] $m" }
function Success([string]$m) { Write-Host "[dspm-policies] ✓ $m" -ForegroundColor Green }
function Fail([string]$m) { 
    Write-Error "[dspm-policies] $m"
    exit 1 
}

Log "═══════════════════════════════════════════════════════════════"
Log "  Microsoft Purview DSPM for AI - Policy Creation"
Log "═══════════════════════════════════════════════════════════════"
Log ""

# Step 1: Check Exchange Online Connection
Log "Step 1: Checking Exchange Online PowerShell Connection..."
Log "─────────────────────────────────────────────────────────────"

try {
    # Check if ExchangeOnlineManagement module is available
    $module = Get-Module -Name ExchangeOnlineManagement -ListAvailable
    if (-not $module) {
        Fail "ExchangeOnlineManagement module not found. Install it with: Install-Module -Name ExchangeOnlineManagement -Force"
    }
    Success "ExchangeOnlineManagement module found"
    
    # Import the module if not already imported
    if (-not (Get-Module -Name ExchangeOnlineManagement)) {
        Import-Module ExchangeOnlineManagement -ErrorAction Stop
        Success "ExchangeOnlineManagement module imported"
    }
    
    # Check if connected to Security & Compliance PowerShell
    try {
        $testConnection = Get-Command Get-FeatureConfiguration -ErrorAction SilentlyContinue
        if (-not $testConnection) {
            Log "Not connected to Security & Compliance PowerShell"
            Log "Attempting to connect..."
            Connect-IPPSSession -ErrorAction Stop
            Success "Connected to Security & Compliance PowerShell"
        } else {
            Success "Already connected to Security & Compliance PowerShell"
        }
    } catch {
        Fail "Failed to connect to Security & Compliance PowerShell. Please run: Connect-IPPSSession"
    }
} catch {
    Fail "Exchange Online PowerShell setup failed: $($_.Exception.Message)"
}
Log ""

# Step 2: Create KYD Policy - Secure interactions from enterprise apps
if (-not $SkipKYDPolicy) {
    Log "Step 2: Creating KYD Policy - 'Secure interactions from enterprise apps'..."
    Log "─────────────────────────────────────────────────────────────"
    
    $policyName = "DSPM for AI - Collection policy for enterprise AI apps"
    
    try {
        # Check if policy already exists
        $existingPolicy = $null
        try {
            $existingPolicy = Get-FeatureConfiguration -Identity $policyName -ErrorAction SilentlyContinue
        } catch {
            # Policy doesn't exist, which is fine
        }
        
        if ($existingPolicy -and -not $Force) {
            Warn "KYD policy '$policyName' already exists"
            Log "  Status: $($existingPolicy.ConfigurationStatus)"
            Log "  Use -Force to recreate the policy"
        } else {
            if ($existingPolicy -and $Force) {
                Log "Removing existing policy (Force mode)..."
                Remove-FeatureConfiguration -Identity $policyName -Confirm:$false
                Success "Existing policy removed"
            }
            
            # Create new policy
            $ingestionEnabled = -not $DisableIngestion.IsPresent
            Log "Creating new KYD policy..."
            Log "  Ingestion Enabled: $ingestionEnabled"
            Log "  Activities: UploadText, DownloadText"
            Log "  Enforcement: Entra"
            Log "  Sensitive Types: All"
            
            $scenarioConfig = @{
                Activities = @("UploadText", "DownloadText")
                EnforcementPlanes = @("Entra")
                SensitiveTypeIds = @("All")
                IsIngestionEnabled = $ingestionEnabled
            } | ConvertTo-Json -Compress
            
            New-FeatureConfiguration -Identity $policyName -ScenarioConfig $scenarioConfig -ErrorAction Stop
            Success "KYD policy created successfully"
            
            # Verify creation
            Start-Sleep -Seconds 5
            $verifyPolicy = Get-FeatureConfiguration -Identity $policyName -ErrorAction SilentlyContinue
            if ($verifyPolicy) {
                Success "Policy verified: $($verifyPolicy.ConfigurationStatus)"
            }
        }
    } catch {
        Fail "Failed to create KYD policy: $($_.Exception.Message)"
    }
} else {
    Log "Step 2: Skipping KYD Policy Creation (SkipKYDPolicy flag set)"
}
Log ""

# Step 3: Information about Portal-based Policies
Log "Step 3: Additional DSPM Policies (Portal-based)..."
Log "─────────────────────────────────────────────────────────────"

Log "The following policies should be created via the Microsoft Purview portal:"
Log ""
Log "1. Communication Compliance Policy - 'Control Unethical Behavior in AI'"
Log "   • Purpose: Detects sensitive information in AI prompts/responses"
Log "   • Covers: All users and groups"
Log "   • Portal: https://purview.microsoft.com/purviewforai/recommendations"
Log ""
Log "2. Insider Risk Management Policy - 'Detect risky AI usage'"
Log "   • Purpose: Identifies risky AI usage patterns"
Log "   • Covers: All users and groups"
Log "   • Portal: https://purview.microsoft.com/purviewforai/recommendations"
Log ""

Warn "To create these policies:"
Log "  1. Navigate to: https://purview.microsoft.com/purviewforai/recommendations"
Log "  2. Find each policy in the recommendations list"
Log "  3. Click 'Create policy' for each"
Log "  4. Monitor status on the Policies page"
Log ""

# Step 4: Policy Configuration Summary
Log "Step 4: Policy Configuration Summary..."
Log "─────────────────────────────────────────────────────────────"

try {
    # List all feature configurations
    Log "Retrieving current policy configurations..."
    $allPolicies = Get-FeatureConfiguration | Where-Object { $_.Identity -like "*DSPM*" -or $_.Identity -like "*AI*" }
    
    if ($allPolicies) {
        Log ""
        Log "Current DSPM/AI Policies:"
        Log "─────────────────────────────────────────────────────────────"
        foreach ($policy in $allPolicies) {
            Log "  • $($policy.Identity)"
            Log "    Status: $($policy.ConfigurationStatus)"
        }
    } else {
        Warn "No DSPM/AI policies found"
    }
} catch {
    Warn "Could not retrieve policy configurations: $($_.Exception.Message)"
}
Log ""

Success "═══════════════════════════════════════════════════════════════"
Success "  DSPM Policy Creation Complete!"
Success "═══════════════════════════════════════════════════════════════"
Log ""
Log "Created Policies:"
if (-not $SkipKYDPolicy) {
    Log "  ✓ KYD Policy - Secure interactions from enterprise apps"
}
Log "  ℹ Communication Compliance - Create via portal"
Log "  ℹ Insider Risk Management - Create via portal"
Log ""
Log "Next Steps:"
Log "  1. Complete portal-based policy creation (see above)"
Log "  2. Run: ./connect_dspm_to_ai_foundry.ps1 to connect to AI Foundry"
Log "  3. Run: ./verify_dspm_configuration.ps1 to validate setup"
Log "  4. Wait 24 hours for data collection to begin"
Log ""
Log "Monitoring:"
Log "  - Policies: https://purview.microsoft.com/purviewforai/policies"
Log "  - Reports: https://purview.microsoft.com/purviewforai/reports"
Log "  - Activity Explorer: https://purview.microsoft.com/activityexplorer"
Log ""
