[CmdletBinding()]
param(
  [string]$SpecPath
)

$ErrorActionPreference = 'Stop'

function Get-Default($value, $fallback) {
  if ($null -ne $value -and $value -ne '') { return $value }
  return $fallback
}

function Install-RequiredAzModules {
  <#
    Ensures the Azure PowerShell modules required by the post-provisioning
    automation (Step 6 in DeploymentGuide.md) are installed and current.

    For each module:
      - Gets the highest version installed locally.
      - Queries PSGallery for the latest published version.
      - Skips when the installed version is already >= latest.
      - Otherwise installs/updates to the latest version (CurrentUser scope).

    Set DAGA_SKIP_AZ_MODULE_INSTALL=1 to opt out (e.g. air-gapped environments).
  #>
  if ($env:DAGA_SKIP_AZ_MODULE_INSTALL -eq '1') {
    Write-Host "Skipping Az module install (DAGA_SKIP_AZ_MODULE_INSTALL=1)." -ForegroundColor DarkGray
    return
  }

  $required = @(
    @{ Name = 'Az.Accounts';            MinimumVersion = '5.0.0' },
    @{ Name = 'Az.Resources';           MinimumVersion = $null },
    @{ Name = 'Az.Monitor';             MinimumVersion = $null },
    @{ Name = 'Az.OperationalInsights'; MinimumVersion = $null },
    @{ Name = 'Az.Purview';             MinimumVersion = $null },
    @{ Name = 'Az.Security';            MinimumVersion = $null },
    @{ Name = 'Az.Storage';             MinimumVersion = $null },
    @{ Name = 'Az.KeyVault';            MinimumVersion = $null }
  )

  # Make sure PSGallery is registered and trusted before any Find-/Install-Module call.
  try {
    $gallery = Get-PSRepository -Name PSGallery -ErrorAction SilentlyContinue
    if (-not $gallery) {
      Register-PSRepository -Default -ErrorAction Stop
      $gallery = Get-PSRepository -Name PSGallery -ErrorAction Stop
    }
    if ($gallery.InstallationPolicy -ne 'Trusted') {
      Set-PSRepository -Name PSGallery -InstallationPolicy Trusted -ErrorAction Stop
    }
  } catch {
    Write-Warning "Unable to configure PSGallery: $($_.Exception.Message)"
  }

  # Ensure PowerShellGet progress (Write-Progress emitted by Install-Module/Find-Module)
  # is visible. Some shells set $ProgressPreference to SilentlyContinue.
  $previousProgressPreference = $ProgressPreference
  $ProgressPreference = 'Continue'

  $progressActivity = 'Installing Azure PowerShell modules'
  $totalModules = $required.Count
  $moduleIndex = 0

  try {
    foreach ($module in $required) {
      $moduleIndex++
      $name = $module.Name
      $overallPercent = [int](($moduleIndex - 1) / $totalModules * 100)
      Write-Progress -Id 1 -Activity $progressActivity `
        -Status "[$moduleIndex/$totalModules] $name - checking..." `
        -PercentComplete $overallPercent

      $installed = Get-Module -ListAvailable -Name $name -ErrorAction SilentlyContinue |
                   Sort-Object Version -Descending | Select-Object -First 1

      $latest = $null
      try {
        $latest = Find-Module -Name $name -Repository PSGallery -ErrorAction Stop |
                  Select-Object -First 1
      } catch {
        Write-Warning "Unable to query latest version of '$name' from PSGallery: $($_.Exception.Message)"
      }

      $needsInstall = $false
      $reason = ''
      if (-not $installed) {
        $needsInstall = $true
        $reason = 'not installed'
      } elseif ($latest -and ([version]$installed.Version -lt [version]$latest.Version)) {
        $needsInstall = $true
        $reason = "$($installed.Version) -> $($latest.Version)"
      } elseif ($module.MinimumVersion -and ([version]$installed.Version -lt [version]$module.MinimumVersion)) {
        $needsInstall = $true
        $reason = "$($installed.Version) below minimum $($module.MinimumVersion)"
      }

      if (-not $needsInstall) {
        $pct = [int]($moduleIndex / $totalModules * 100)
        Write-Progress -Id 1 -Activity $progressActivity `
          -Status "[$moduleIndex/$totalModules] $name - up to date ($($installed.Version)) - $pct% complete" `
          -PercentComplete $pct
        Write-Host "[$name] already up to date ($($installed.Version)) [$moduleIndex/$totalModules - $pct%]" -ForegroundColor DarkGray
        continue
      }

      Write-Progress -Id 1 -Activity $progressActivity `
        -Status "[$moduleIndex/$totalModules] $name - installing ($reason)..." `
        -PercentComplete $overallPercent
      Write-Host "[$name] installing/updating ($reason) [$moduleIndex/$totalModules]..." -ForegroundColor Cyan

      $installArgs = @{
        Name         = $name
        Scope        = 'CurrentUser'
        Repository   = 'PSGallery'
        Force        = $true
        AllowClobber = $true
        AcceptLicense= $true
        Confirm      = $false
      }
      if ($latest) {
        $installArgs['RequiredVersion'] = $latest.Version
      } elseif ($module.MinimumVersion) {
        $installArgs['MinimumVersion'] = $module.MinimumVersion
      }

      try {
        Install-Module @installArgs
        $pct = [int]($moduleIndex / $totalModules * 100)
        Write-Progress -Id 1 -Activity $progressActivity `
          -Status "[$moduleIndex/$totalModules] $name - installed - $pct% complete" `
          -PercentComplete $pct
        Write-Host "[$name] installed [$moduleIndex/$totalModules - $pct%]" -ForegroundColor Green
      } catch {
        Write-Warning "Failed to install '$name': $($_.Exception.Message)"
      }
    }
  } finally {
    Write-Progress -Id 1 -Activity $progressActivity -Completed
    $ProgressPreference = $previousProgressPreference
  }
}

function Get-AzCliContext {
  if (-not (Get-Command az -ErrorAction SilentlyContinue)) {
    return $null
  }
  try {
    $accountJson = az account show --output json 2>$null
    if (-not $accountJson) { return $null }
    return ($accountJson | ConvertFrom-Json)
  } catch {
    return $null
  }
}

Install-RequiredAzModules

$repoRoot = (Get-Item $PSScriptRoot).Parent.FullName
$specPath = Get-Default -value $SpecPath -fallback (Get-Default -value $env:DAGA_SPEC_PATH -fallback "./spec.local.json")
if (-not [System.IO.Path]::IsPathRooted($specPath)) {
  $specPath = Join-Path $repoRoot $specPath
}

if (Test-Path -Path $specPath) {
  Write-Host "Spec already exists at $specPath" -ForegroundColor DarkGray
  return
}

$azContext = Get-AzCliContext
$tenantId = Get-Default -value $env:AZURE_TENANT_ID -fallback (Get-Default -value ($azContext.tenantId) -fallback "")
$subscriptionId = Get-Default -value $env:AZURE_SUBSCRIPTION_ID -fallback (Get-Default -value ($azContext.id) -fallback "")
$resourceGroup = Get-Default -value $env:AZURE_RESOURCE_GROUP -fallback (Get-Default -value $env:AZURE_RESOURCE_GROUP_NAME -fallback "")
$location = Get-Default -value $env:AZURE_LOCATION -fallback ""

$templatePath = Join-Path $repoRoot "spec.dspm.template.json"
if (-not (Test-Path -Path $templatePath)) {
  throw "Template '$templatePath' not found. Cannot scaffold spec."
}

$spec = Get-Content $templatePath -Raw | ConvertFrom-Json
if ($tenantId) { $spec.tenantId = $tenantId }
if ($subscriptionId) {
  $spec.subscriptionId = $subscriptionId
  if ($null -ne ($spec.aiSubscriptionId)) { $spec.aiSubscriptionId = $subscriptionId }
  if ($null -ne ($spec.purviewSubscriptionId) -and [string]::IsNullOrWhiteSpace([string]$spec.purviewSubscriptionId)) { $spec.purviewSubscriptionId = $subscriptionId }
}
if ($resourceGroup) { $spec.resourceGroup = $resourceGroup }
if ($location) { $spec.location = $location }
if ($spec.resourceGroup -and $null -ne ($spec.purviewResourceGroup) -and [string]::IsNullOrWhiteSpace([string]$spec.purviewResourceGroup)) { $spec.purviewResourceGroup = $spec.resourceGroup }

$specDir = Split-Path -Parent $specPath
if (-not (Test-Path -Path $specDir)) {
  New-Item -ItemType Directory -Path $specDir -Force | Out-Null
}

$spec | ConvertTo-Json -Depth 20 | Out-File -FilePath $specPath -Encoding UTF8 -Force
Write-Host "Created spec from template at $specPath" -ForegroundColor Green
