param(
  [string]   $SpecPath = "./spec.local.json",
  [string[]] $Tags     = @("dspm"),
  [switch]   $DryRun,
  [switch]   $ContinueOnError,
  [switch]   $ConnectM365,
  [string]   $M365UserPrincipalName,
  [string]   $M365AppId,
  [string]   $M365Organization,
  [string]   $M365CertificateThumbprint,
  [string]   $M365CertificatePath,
  [string]   $M365CertificatePassword
)
if($M365UserPrincipalName){ $env:DAGA_M365_UPN = $M365UserPrincipalName } else { Remove-Item Env:DAGA_M365_UPN -ErrorAction SilentlyContinue }
if(-not $M365AppId -and $env:DAGA_M365_APP_ID){ $M365AppId = $env:DAGA_M365_APP_ID }
if(-not $M365Organization -and $env:DAGA_M365_ORGANIZATION){ $M365Organization = $env:DAGA_M365_ORGANIZATION }
if(-not $M365CertificateThumbprint -and $env:DAGA_M365_CERT_THUMBPRINT){ $M365CertificateThumbprint = $env:DAGA_M365_CERT_THUMBPRINT }
if(-not $M365CertificatePath -and $env:DAGA_M365_CERT_PATH){ $M365CertificatePath = $env:DAGA_M365_CERT_PATH }
if(-not $M365CertificatePassword -and $env:DAGA_M365_CERT_PASSWORD){ $M365CertificatePassword = $env:DAGA_M365_CERT_PASSWORD }
function Initialize-AutomationEnvironment {
  param([bool]$RequireExchange)

  try {
    if ((Get-ExecutionPolicy -Scope Process) -ne "Bypass") {
      Set-ExecutionPolicy -Scope Process -ExecutionPolicy Bypass -Force -ErrorAction Stop
      Write-Host "Execution policy set to Bypass for this session." -ForegroundColor DarkGray
    }
  } catch {
    Write-Warning "Unable to set process execution policy: $($_.Exception.Message)"
  }

  try {
    $scriptRoot = Split-Path -Parent $PSCommandPath
    $targets = Get-ChildItem -Path $scriptRoot -Filter *.ps1 -Recurse -ErrorAction SilentlyContinue
    if ($targets) {
      $targets | Unblock-File -ErrorAction SilentlyContinue
      Write-Host "Validated PowerShell scripts are unblocked." -ForegroundColor DarkGray
    }
  } catch {
    Write-Warning "Unable to unblock files automatically: $($_.Exception.Message)"
  }

  try {
    $gallery = Get-PSRepository -Name PSGallery -ErrorAction Stop
    if ($gallery.InstallationPolicy -ne "Trusted") {
      Set-PSRepository -Name PSGallery -InstallationPolicy Trusted -ErrorAction Stop
      Write-Host "Trusted PSGallery for module installs." -ForegroundColor DarkGray
    }
  } catch {
    Write-Warning "Unable to update PSGallery trust settings: $($_.Exception.Message)"
  }

  if (Get-Module -Name ExchangeOnlineManagement -ErrorAction SilentlyContinue) {
    Remove-Module -Name ExchangeOnlineManagement -Force -ErrorAction SilentlyContinue
  }

  $moduleSpecs = @(
    @{ Name = "Az.Accounts";            MinimumVersion = "5.0.0" },
    @{ Name = "Az.Resources";           MinimumVersion = $null },
    @{ Name = "Az.Monitor";             MinimumVersion = $null },
    @{ Name = "Az.OperationalInsights"; MinimumVersion = $null }
  )
  if ($RequireExchange) {
    $moduleSpecs += @{ Name = "ExchangeOnlineManagement"; MinimumVersion = $null }
  }

  foreach ($module in $moduleSpecs) {
    $installed = Get-Module -ListAvailable -Name $module.Name -ErrorAction SilentlyContinue | Sort-Object Version -Descending | Select-Object -First 1
    $needsInstall = -not $installed
    if (-not $needsInstall -and $module.MinimumVersion) {
      try {
        $needsInstall = ([version]$installed.Version -lt [version]$module.MinimumVersion)
      } catch {
        $needsInstall = $true
      }
    }
    if ($needsInstall) {
      $versionNote = if ($module.MinimumVersion) { " (>= $($module.MinimumVersion))" } else { "" }
      Write-Host "Installing PowerShell module '$($module.Name)'$versionNote..." -ForegroundColor Cyan
      if ($module.MinimumVersion) {
        Install-Module -Name $module.Name -Scope CurrentUser -Force -AllowClobber -AcceptLicense -Confirm:$false -MinimumVersion $module.MinimumVersion
      } else {
        Install-Module -Name $module.Name -Scope CurrentUser -Force -AllowClobber -AcceptLicense -Confirm:$false
      }
    }
  }

  Import-Module Az.Accounts -ErrorAction Stop | Out-Null
}

function Test-HasFabricLakehouseSensitivityLabels {
  param([string]$Path)

  if([string]::IsNullOrWhiteSpace($Path) -or -not (Test-Path -Path $Path)){
    return $false
  }

  try {
    $spec = Get-Content $Path -Raw | ConvertFrom-Json
    if(-not $spec.fabric -or -not $spec.fabric.workspaces){ return $false }

    foreach($workspace in @($spec.fabric.workspaces)){
      $lakehousesProp = $workspace.PSObject.Properties['lakehouses']
      if($null -eq $lakehousesProp -or $null -eq $lakehousesProp.Value){ continue }
      foreach($lakehouse in @($lakehousesProp.Value)){
        $labelProp = $lakehouse.PSObject.Properties['sensitivityLabel']
        if($labelProp -and -not [string]::IsNullOrWhiteSpace([string]$labelProp.Value)){
          return $true
        }
      }
    }
  } catch {
    Write-Warning "Unable to inspect Fabric lakehouse labels from spec '$Path': $($_.Exception.Message)"
  }

  return $false
}

Initialize-AutomationEnvironment -RequireExchange:$ConnectM365
$planEntry = {
  param([int]$Order,[string]$File,[string[]]$Tags,[bool]$NeedsSpec,[hashtable]$Parameters)
  [pscustomobject]@{
    Order      = $Order
    File       = $File
    Tags       = $Tags
    NeedsSpec  = $NeedsSpec
    Parameters = $Parameters
  }
}
$exoCmds = @('Get-AdminAuditLogConfig','Set-AdminAuditLogConfig','Get-DlpCompliancePolicy','New-DlpCompliancePolicy','Get-DlpComplianceRule','New-DlpComplianceRule','Get-Label','New-Label','Get-LabelPolicy','New-LabelPolicy','New-RetentionCompliancePolicy','New-RetentionComplianceRule','Set-Label')
$exoSessionEstablished = $false
$ErrorActionPreference = "Stop"

# --- Tag aliases (feature flags)
$aliases = @{
  "dspm"      = @("foundation","policies","scans","audit")
  "defender"  = @("defender","diagnostics","policies")
  "foundry"   = @("foundry","diagnostics","tags","contentsafety")
  "all"       = @("foundation","compliance","policies","scans","audit","defender","diagnostics","foundry","networking","ops","tags","contentsafety")
}

# Expand high-level tags to concrete tags
$expanded = New-Object System.Collections.Generic.HashSet[string]
foreach ($t in $Tags) {
  if ($aliases.ContainsKey($t)) { $aliases[$t] | ForEach-Object { $expanded.Add($_) | Out-Null } }
  else                           { $expanded.Add($t) | Out-Null }
}

# --- Plan: ordered steps with tags & spec requirements
$plan = @(
  & $planEntry -Order  5 -File "scripts/governance/00-New-DspmSpec.ps1" -Tags @("ops") -NeedsSpec:$false -Parameters ([ordered]@{ OutFile = $SpecPath })
  & $planEntry -Order 10 -File "scripts/governance/01-Ensure-ResourceGroup.ps1" -Tags @("foundation","dspm") -NeedsSpec:$true -Parameters $null
  & $planEntry -Order 20 -File "scripts/governance/dspmPurview/02-Ensure-PurviewAccount.ps1" -Tags @("foundation","dspm") -NeedsSpec:$true -Parameters $null
  & $planEntry -Order 30 -File "scripts/exchangeOnline/10-Connect-Compliance.ps1" -Tags @("m365") -NeedsSpec:$false -Parameters $null
  & $planEntry -Order 40 -File "scripts/exchangeOnline/11-Enable-UnifiedAudit.ps1" -Tags @("m365") -NeedsSpec:$false -Parameters $null
  & $planEntry -Order 50 -File "scripts/governance/dspmPurview/12-Create-DlpPolicy.ps1" -Tags @("m365") -NeedsSpec:$true -Parameters $null
  & $planEntry -Order 60 -File "scripts/governance/dspmPurview/13-Create-SensitivityLabel.ps1" -Tags @("m365") -NeedsSpec:$true -Parameters $null
  & $planEntry -Order 70 -File "scripts/governance/dspmPurview/14-Create-RetentionPolicy.ps1" -Tags @("m365") -NeedsSpec:$true -Parameters $null
  & $planEntry -Order 80 -File "scripts/governance/dspmPurview/03-Register-DataSource.ps1" -Tags @("scans","dspm","foundry") -NeedsSpec:$true -Parameters $null
  & $planEntry -Order 90 -File "scripts/governance/dspmPurview/04-Run-Scan.ps1" -Tags @("scans","dspm","foundry") -NeedsSpec:$true -Parameters $null
  & $planEntry -Order 100 -File "scripts/governance/dspmPurview/20-Subscribe-ManagementActivity.ps1" -Tags @("audit","dspm") -NeedsSpec:$true -Parameters $null
  & $planEntry -Order 110 -File "scripts/governance/dspmPurview/21-Export-Audit.ps1" -Tags @("audit","dspm") -NeedsSpec:$true -Parameters $null
  & $planEntry -Order 120 -File "scripts/governance/dspmPurview/05-Assign-AzurePolicies.ps1" -Tags @("policies","dspm","defender") -NeedsSpec:$true -Parameters $null
  & $planEntry -Order 130 -File "scripts/defender/06-Enable-DefenderPlans.ps1" -Tags @("defender") -NeedsSpec:$true -Parameters $null
  & $planEntry -Order 140 -File "scripts/defender/07-Enable-Diagnostics.ps1" -Tags @("defender","diagnostics","foundry") -NeedsSpec:$true -Parameters $null
  & $planEntry -Order 150 -File "scripts/governance/dspmPurview/25-Tag-ResourcesFromSpec.ps1" -Tags @("tags","foundry","dspm") -NeedsSpec:$true -Parameters $null
  & $planEntry -Order 160 -File "scripts/governance/dspmPurview/26-Ensure-FabricWorkspaceSensitivity.ps1" -Tags @("scans","foundry","dspm") -NeedsSpec:$true -Parameters $null
  & $planEntry -Order 162 -File "scripts/governance/dspmPurview/26-Apply-FabricLakehouseSensitivity.ps1" -Tags @("scans","foundry","dspm") -NeedsSpec:$true -Parameters $null
  & $planEntry -Order 165 -File "scripts/governance/dspmPurview/28-Ensure-PurviewCollectionsForFabricWorkspaces.ps1" -Tags @("scans","foundry","dspm") -NeedsSpec:$true -Parameters $null
  & $planEntry -Order 170 -File "scripts/governance/dspmPurview/27-Register-FabricWorkspace.ps1" -Tags @("scans","foundry","dspm") -NeedsSpec:$true -Parameters $null
  & $planEntry -Order 190 -File "scripts/governance/dspmPurview/29-Trigger-FabricWorkspaceScan.ps1" -Tags @("scans","foundry","dspm") -NeedsSpec:$true -Parameters $null
  & $planEntry -Order 200 -File "scripts/governance/dspmPurview/30-Foundry-RegisterResources.ps1" -Tags @("foundry","ops") -NeedsSpec:$true -Parameters $null
  & $planEntry -Order 210 -File "scripts/governance/dspmPurview/31-Foundry-ConfigureContentSafety.ps1" -Tags @("foundry","contentsafety","defender") -NeedsSpec:$true -Parameters $null
  & $planEntry -Order 220 -File "scripts/governance/dspmPurview/17-Export-ComplianceInventory.ps1" -Tags @("ops") -NeedsSpec:$false -Parameters $null
  & $planEntry -Order 280 -File "scripts/governance/dspmPurview/24-Create-BudgetAlert-Stub.ps1" -Tags @("ops") -NeedsSpec:$false -Parameters $null
)

# Filter by tags
$selected = @(
  $plan.Where({
    ($_.Tags | ForEach-Object { $expanded.Contains($_) }) -contains $true
  }) | Sort-Object Order
)

if ($selected.Length -eq 0) {
  Write-Host "No steps matched tags: $($Tags -join ', ')" -ForegroundColor Yellow
  exit 0
}

Write-Host "Running steps for tags: $($Tags -join ', ')" -ForegroundColor Cyan

$fabricLabelsConfigured = Test-HasFabricLakehouseSensitivityLabels -Path $SpecPath

# PSScriptAnalyzerSuppressMessage("PSAvoidAssignmentToAutomaticVariable", "", "No automatic variables are assigned; parameters are tracked via local ordered hashtable")
foreach ($step in $selected) {
  if ($step.File -eq "scripts/governance/dspmPurview/26-Apply-FabricLakehouseSensitivity.ps1" -and -not $fabricLabelsConfigured) {
    Write-Host "Skipping Fabric lakehouse label apply step because no lakehouse sensitivity labels are configured in spec." -ForegroundColor DarkGray
    continue
  }

  $stepParams = [ordered]@{}
  if ($step.NeedsSpec) {
    if (-not (Test-Path -Path $SpecPath)) {
      $templatePath = "./spec.dspm.template.json"
      if ($SpecPath -eq "./spec.local.json" -and (Test-Path -Path $templatePath)) {
        throw "Spec file '$SpecPath' not found. Copy '$templatePath' to '$SpecPath' and populate environment values, or pass -SpecPath explicitly."
      }
      throw "Spec file '$SpecPath' not found. Provide a valid spec via -SpecPath."
    }
    $stepParams['SpecPath'] = $SpecPath
  }
  if ($step.Parameters) {
    foreach ($entry in $step.Parameters.GetEnumerator()) {
      $stepParams[$entry.Key] = $entry.Value
    }
  }

  $requiresM365 = $step.Tags -contains "m365"
  if(-not $requiresM365 -and $step.File -eq "scripts/governance/dspmPurview/26-Ensure-FabricWorkspaceSensitivity.ps1" -and $fabricLabelsConfigured){
    $requiresM365 = $true
  }
  if ($requiresM365) {
    if ($step.File -eq "scripts/governance/dspmPurview/26-Ensure-FabricWorkspaceSensitivity.ps1" -and $fabricLabelsConfigured) {
      Write-Host "Fabric labels detected; Exchange Online label permissions are required, otherwise labels will not be applied." -ForegroundColor Cyan
    }

    if (-not $ConnectM365) {
      throw "Step '$($step.File)' requires Microsoft 365 connectivity. Re-run with -ConnectM365 plus either -M365UserPrincipalName or app-only parameters."
    }
    if (-not $exoSessionEstablished) {
      $useInteractiveM365 = -not [string]::IsNullOrWhiteSpace($M365UserPrincipalName)
      if ($useInteractiveM365) {
        Write-Host "Connecting to Exchange Online for compliance cmdlets..." -ForegroundColor Cyan
        Connect-ExchangeOnline -UserPrincipalName $M365UserPrincipalName -ShowBanner:$false -CommandName $exoCmds | Out-Null
        Write-Host "Connecting to Security & Compliance PowerShell..." -ForegroundColor Cyan
        Connect-IPPSSession -UserPrincipalName $M365UserPrincipalName -ShowBanner:$false | Out-Null
      } else {
        if (-not $M365AppId -or -not $M365Organization) {
          throw "Provide either -M365UserPrincipalName for interactive auth or -M365AppId/-M365Organization plus certificate details for app-only connections."
        }
        $appExchangeParams = @{ AppId = $M365AppId; Organization = $M365Organization; ShowBanner = $false }
        if ($M365CertificateThumbprint) {
          $appExchangeParams['CertificateThumbprint'] = $M365CertificateThumbprint
        } elseif ($M365CertificatePath) {
          if (-not $M365CertificatePassword) {
            throw "M365 certificate password is required when CertificateFilePath is provided."
          }
          $appExchangeParams['CertificateFilePath'] = $M365CertificatePath
          $appExchangeParams['CertificatePassword'] = (ConvertTo-SecureString $M365CertificatePassword -AsPlainText -Force)
        } else {
          throw "Supply either M365CertificateThumbprint or M365CertificatePath for app-only authentication."
        }
        Write-Host "Connecting to Exchange Online via app-only authentication..." -ForegroundColor Cyan
        Connect-ExchangeOnline @appExchangeParams -CommandName $exoCmds | Out-Null
        Write-Host "Connecting to Security & Compliance PowerShell via app-only authentication..." -ForegroundColor Cyan
        $appIPPSParams = @{}
        foreach ($key in $appExchangeParams.Keys) {
          if ($key -ne 'ShowBanner') { $appIPPSParams[$key] = $appExchangeParams[$key] }
        }
        Connect-IPPSSession @appIPPSParams | Out-Null
      }
      $exoSessionEstablished = $true
    }
  }

  $displayArgs = if ($stepParams.Count -gt 0) { ($stepParams.GetEnumerator() | ForEach-Object { "-{0} {1}" -f $_.Key, $_.Value }) } else { @() }
  $cmdDisplay = ".\{0} {1}" -f $step.File, ($displayArgs -join ' ')
  if ($DryRun) {
    Write-Host "[DRYRUN] $cmdDisplay" -ForegroundColor DarkGray
    continue
  }

  Write-Host "==> $cmdDisplay" -ForegroundColor Green
  try {
    if ($stepParams.Count -gt 0) {
      & ".\$($step.File)" @stepParams
    } else {
      & ".\$($step.File)"
    }
  } catch {
    Write-Host "ERROR in $($step.File): $($_.Exception.Message)" -ForegroundColor Red
    if (-not $ContinueOnError) { throw }
  }
}
