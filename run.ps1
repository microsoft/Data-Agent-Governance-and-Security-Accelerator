param(
  [string]   $SpecPath = "./spec.local.json",
  [string[]] $Tags     = @("dspm"),
  [switch]   $DryRun,
  [switch]   $ContinueOnError
)

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
  @{Order=  5; File="scripts/governance/00-New-DspmSpec.ps1";                 Tags=@("ops");                      NeedsSpec=$false; Parameters=[ordered]@{ OutFile = $SpecPath }}
  @{Order= 10; File="scripts/governance/01-Ensure-ResourceGroup.ps1";         Tags=@("foundation","dspm");        NeedsSpec=$true }
  @{Order= 20; File="scripts/governance/dspmPurview/02-Ensure-PurviewAccount.ps1"; Tags=@("foundation","dspm");  NeedsSpec=$true }
  @{Order= 30; File="scripts/exchangeOnline/10-Connect-Compliance.ps1";       Tags=@("m365");                       NeedsSpec=$false}
  @{Order= 40; File="scripts/exchangeOnline/11-Enable-UnifiedAudit.ps1";      Tags=@("m365");                       NeedsSpec=$false}
  @{Order= 50; File="scripts/governance/dspmPurview/12-Create-DlpPolicy.ps1"; Tags=@("m365");                       NeedsSpec=$true }
  @{Order= 60; File="scripts/governance/dspmPurview/13-Create-SensitivityLabel.ps1"; Tags=@("m365");               NeedsSpec=$true }
  @{Order= 70; File="scripts/governance/dspmPurview/14-Create-RetentionPolicy.ps1"; Tags=@("m365");               NeedsSpec=$true }
  @{Order= 80; File="scripts/governance/dspmPurview/03-Register-DataSource.ps1";    Tags=@("scans","dspm","foundry");   NeedsSpec=$true }
  @{Order= 90; File="scripts/governance/dspmPurview/04-Run-Scan.ps1";               Tags=@("scans","dspm","foundry");   NeedsSpec=$true }
  @{Order=100; File="scripts/governance/dspmPurview/20-Subscribe-ManagementActivity.ps1"; Tags=@("audit","dspm"); NeedsSpec=$true }
  @{Order=110; File="scripts/governance/dspmPurview/21-Export-Audit.ps1";     Tags=@("audit","dspm");             NeedsSpec=$true }
  @{Order=120; File="scripts/governance/dspmPurview/05-Assign-AzurePolicies.ps1";   Tags=@("policies","dspm","defender");NeedsSpec=$true}
  @{Order=130; File="scripts/defender/defenderForAI/06-Enable-DefenderPlans.ps1";   Tags=@("defender");                 NeedsSpec=$true }
  @{Order=140; File="scripts/defender/defenderForAI/07-Enable-Diagnostics.ps1";     Tags=@("defender","diagnostics","foundry"); NeedsSpec=$true }
  @{Order=150; File="scripts/governance/dspmPurview/25-Tag-ResourcesFromSpec.ps1";  Tags=@("tags","foundry","dspm");    NeedsSpec=$true }
  @{Order=160; File="scripts/governance/dspmPurview/26-Register-OneLake.ps1";       Tags=@("scans","foundry","dspm");   NeedsSpec=$true }
  @{Order=170; File="scripts/governance/dspmPurview/27-Register-FabricWorkspace.ps1";Tags=@("scans","foundry","dspm");  NeedsSpec=$true }
  @{Order=180; File="scripts/governance/dspmPurview/28-Trigger-OneLakeScan.ps1";    Tags=@("scans","foundry","dspm");   NeedsSpec=$true }
  @{Order=190; File="scripts/governance/dspmPurview/29-Trigger-FabricWorkspaceScan.ps1"; Tags=@("scans","foundry","dspm"); NeedsSpec=$true }
  @{Order=200; File="scripts/governance/dspmPurview/30-Foundry-RegisterResources.ps1"; Tags=@("foundry","ops");         NeedsSpec=$true }
  @{Order=210; File="scripts/governance/dspmPurview/31-Foundry-ConfigureContentSafety.ps1"; Tags=@("foundry","contentsafety","defender"); NeedsSpec=$true }
  @{Order=220; File="scripts/governance/dspmPurview/17-Export-ComplianceInventory.ps1"; Tags=@("ops","dspm");           NeedsSpec=$false}
  @{Order=230; File="scripts/governance/dspmPurview/34-Validate-Posture.ps1";       Tags=@("ops","dspm","defender");    NeedsSpec=$true }
  # Stubs (optional steps)
  @{Order=240; File="scripts/governance/dspmPurview/15-Create-SensitiveInfoType-Stub.ps1";    Tags=@("policies","dspm"); NeedsSpec=$false}
  @{Order=250; File="scripts/governance/dspmPurview/16-Create-TrainableClassifier-Stub.ps1";  Tags=@("policies","dspm"); NeedsSpec=$false}
  @{Order=260; File="scripts/governance/dspmPurview/22-Ship-AuditToStorage.ps1";              Tags=@("audit","ops");     NeedsSpec=$false}
  @{Order=270; File="scripts/governance/dspmPurview/23-Ship-AuditToFabricLakehouse-Stub.ps1"; Tags=@("audit","foundry"); NeedsSpec=$false}
  @{Order=280; File="scripts/governance/dspmPurview/24-Create-BudgetAlert-Stub.ps1";          Tags=@("ops");             NeedsSpec=$false}
)

# Filter by tags
$selected = $plan.Where({
  ($_.Tags | ForEach-Object { $expanded.Contains($_) }) -contains $true
}) | Sort-Object Order

if ($selected.Count -eq 0) {
  Write-Host "No steps matched tags: $($Tags -join ', ')" -ForegroundColor Yellow
  exit 0
}

Write-Host "Running steps for tags: $($Tags -join ', ')" -ForegroundColor Cyan

# PSScriptAnalyzerSuppressMessage("PSAvoidAssignmentToAutomaticVariable", "", "No automatic variables are assigned; parameters are tracked via local ordered hashtable")
foreach ($step in $selected) {
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
