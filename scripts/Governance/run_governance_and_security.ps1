<#
.SYNOPSIS
  Orchestrate Purview Governance and Defender for AI scripts.

.DESCRIPTION
  This script runs all governance and security automation in the correct order:
  1. Purview DSPM for AI (governance, policies, monitoring)
  2. Microsoft Defender for AI (threat detection, security)
  
  Use this as a standalone orchestrator OR rely on azure.yaml postprovision hooks.

.PARAMETER SkipPurview
  Skip Purview DSPM scripts (run Defender only)

.PARAMETER SkipDefender
  Skip Defender scripts (run Purview only)

.EXAMPLE
  ./run_governance_and_security.ps1
  
.EXAMPLE
  ./run_governance_and_security.ps1 -SkipPurview
  
.EXAMPLE
  ./run_governance_and_security.ps1 -SkipDefender
#>

[CmdletBinding()]
param(
    [Parameter(Mandatory = $false)]
    [switch]$SkipPurview,
    
    [Parameter(Mandatory = $false)]
    [switch]$SkipDefender
)

Set-StrictMode -Version Latest
$ErrorActionPreference = 'Stop'

function Log([string]$m) { Write-Host "[orchestrator] $m" -ForegroundColor Cyan }
function Success([string]$m) { Write-Host "[orchestrator] ✓ $m" -ForegroundColor Green }
function Warn([string]$m) { Write-Warning "[orchestrator] $m" }
function Fail([string]$m) { Write-Error "[orchestrator] $m" }

$startTime = Get-Date

Log "═══════════════════════════════════════════════════════════════"
Log "  AI Governance & Security Automation Orchestrator"
Log "═══════════════════════════════════════════════════════════════"
Log ""
Log "Start Time: $($startTime.ToString('yyyy-MM-dd HH:mm:ss'))"
Log ""

# Script root
$scriptRoot = $PSScriptRoot
$purviewPath = Join-Path $scriptRoot "PurviewGovernance"
$defenderPath = Join-Path $scriptRoot "DefenderScripts"

# Execution tracking
$executedScripts = @()
$failedScripts = @()
$totalScripts = 0

# Function to run script safely
function Invoke-GovernanceScript {
    param(
        [string]$ScriptPath,
        [string]$Description
    )
    
    $totalScripts++
    $scriptName = Split-Path $ScriptPath -Leaf
    
    Log ""
    Log "───────────────────────────────────────────────────────────────"
    Log "Running: $scriptName"
    Log "Purpose: $Description"
    Log "───────────────────────────────────────────────────────────────"
    
    if (-not (Test-Path $ScriptPath)) {
        Warn "Script not found: $ScriptPath"
        $failedScripts += @{
            Name = $scriptName
            Error = "File not found"
        }
        return $false
    }
    
    try {
        & $ScriptPath
        
        if ($LASTEXITCODE -eq 0 -or $null -eq $LASTEXITCODE) {
            Success "Completed: $scriptName"
            $executedScripts += $scriptName
            return $true
        } else {
            Warn "Script returned exit code: $LASTEXITCODE"
            $failedScripts += @{
                Name = $scriptName
                Error = "Exit code $LASTEXITCODE"
            }
            return $false
        }
    } catch {
        Warn "Script failed: $($_.Exception.Message)"
        $failedScripts += @{
            Name = $scriptName
            Error = $_.Exception.Message
        }
        return $false
    }
}

# Phase 1: Purview DSPM for AI
if (-not $SkipPurview) {
    Log ""
    Log "═══════════════════════════════════════════════════════════════"
    Log "  PHASE 1: Microsoft Purview DSPM for AI"
    Log "═══════════════════════════════════════════════════════════════"
    Log ""
    Log "This phase establishes governance foundation:"
    Log "  • Data Security Posture Management (DSPM)"
    Log "  • Know Your Data (KYD) policies"
    Log "  • AI Foundry project discovery and tagging"
    Log "  • Configuration health validation"
    Log ""
    
    $purviewScripts = @(
        @{
            Path = Join-Path $purviewPath "enable_purview_dspm.ps1"
            Description = "Enable Purview DSPM for AI and validate tenant"
        },
        @{
            Path = Join-Path $purviewPath "create_dspm_policies.ps1"
            Description = "Create Know Your Data (KYD) compliance policies"
        },
        @{
            Path = Join-Path $purviewPath "connect_dspm_to_ai_foundry.ps1"
            Description = "Discover and tag AI Foundry projects for monitoring"
        },
        @{
            Path = Join-Path $purviewPath "verify_dspm_configuration.ps1"
            Description = "Validate complete DSPM configuration health"
        }
    )
    
    foreach ($script in $purviewScripts) {
        $success = Invoke-GovernanceScript -ScriptPath $script.Path -Description $script.Description
        
        if (-not $success) {
            Warn "Purview script failed, but continuing with remaining scripts..."
        }
    }
    
    Success "Phase 1 Complete: Purview DSPM"
} else {
    Log ""
    Log "Skipping Purview DSPM scripts (-SkipPurview specified)"
}

# Phase 2: Microsoft Defender for AI
if (-not $SkipDefender) {
    Log ""
    Log "═══════════════════════════════════════════════════════════════"
    Log "  PHASE 2: Microsoft Defender for AI"
    Log "═══════════════════════════════════════════════════════════════"
    Log ""
    Log "This phase establishes security monitoring:"
    Log "  • Defender for Cloud (CSPM foundation)"
    Log "  • AI services threat detection"
    Log "  • User prompt evidence collection"
    Log "  • Integration with Purview governance"
    Log ""
    
    $defenderScripts = @(
        @{
            Path = Join-Path $defenderPath "enable_defender_for_cloud.ps1"
            Description = "Enable Defender for Cloud CSPM"
        },
        @{
            Path = Join-Path $defenderPath "enable_defender_for_ai.ps1"
            Description = "Enable AI services plan and threat detection"
        },
        @{
            Path = Join-Path $defenderPath "enable_user_prompt_evidence.ps1"
            Description = "Enable user prompt and response collection"
        },
        @{
            Path = Join-Path $defenderPath "connect_defender_to_purview.ps1"
            Description = "Integrate Defender with Purview DSPM"
        },
        @{
            Path = Join-Path $defenderPath "verify_defender_ai_configuration.ps1"
            Description = "Validate complete Defender for AI setup"
        }
    )
    
    foreach ($script in $defenderScripts) {
        $success = Invoke-GovernanceScript -ScriptPath $script.Path -Description $script.Description
        
        if (-not $success) {
            Warn "Defender script failed, but continuing with remaining scripts..."
        }
    }
    
    Success "Phase 2 Complete: Defender for AI"
} else {
    Log ""
    Log "Skipping Defender for AI scripts (-SkipDefender specified)"
}

# Final Summary
$endTime = Get-Date
$duration = $endTime - $startTime

Log ""
Log "═══════════════════════════════════════════════════════════════"
Log "  Orchestration Complete!"
Log "═══════════════════════════════════════════════════════════════"
Log ""
Log "Execution Summary:"
Log "  Start Time:        $($startTime.ToString('yyyy-MM-dd HH:mm:ss'))"
Log "  End Time:          $($endTime.ToString('yyyy-MM-dd HH:mm:ss'))"
Log "  Duration:          $($duration.ToString('hh\:mm\:ss'))"
Log "  Total Scripts:     $totalScripts"
Log "  Successful:        $($executedScripts.Count)"
Log "  Failed:            $($failedScripts.Count)"
Log ""

if ($executedScripts.Count -gt 0) {
    Success "Successfully executed scripts:"
    foreach ($script in $executedScripts) {
        Log "  ✓ $script"
    }
    Log ""
}

if ($failedScripts.Count -gt 0) {
    Warn "Failed scripts:"
    foreach ($script in $failedScripts) {
        Log "  ✗ $($script.Name): $($script.Error)"
    }
    Log ""
    Log "Review logs above for detailed error information"
    Log ""
}

Log "Next Steps:"
Log "  1. Review any failed scripts and retry if needed"
Log "  2. Allow 24-48 hours for full data collection"
Log "  3. Monitor Defender for Cloud alerts"
Log "  4. Check Purview DSPM portal for governance insights"
Log ""

Log "Monitoring Portals:"
Log "  • Defender: https://portal.azure.com/#view/Microsoft_Azure_Security/SecurityMenuBlade"
Log "  • Purview:  https://purview.microsoft.com/purviewforai/overview"
Log ""

Success "═══════════════════════════════════════════════════════════════"

# Exit with appropriate code
if ($failedScripts.Count -gt 0) {
    exit 1
} else {
    exit 0
}
