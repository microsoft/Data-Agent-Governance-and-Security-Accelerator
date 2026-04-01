[CmdletBinding()]
param(
  [string]$SpecPath,
  [string[]]$Tags,
  [switch]$ConnectM365,
  [string]$M365UserPrincipalName
)

$previousStrictMode = $PSStrictModePreference
Set-StrictMode -Version Latest
$ErrorActionPreference = 'Stop'

function Get-Default($value, $fallback) {
  if ($null -ne $value -and $value -ne '') { return $value }
  return $fallback
}

function ConvertTo-TagArray {
  param([object]$tagInput)
  $items = @()
  if ($null -eq $tagInput) {
    return @('foundation', 'dspm', 'defender', 'foundry')
  }
  if ($tagInput -isnot [System.Collections.IEnumerable] -or $tagInput -is [string]) {
    $tagInput = @($tagInput)
  }
  foreach ($entry in $tagInput) {
    if ($null -eq $entry) { continue }
    if ($entry -is [System.Collections.IEnumerable] -and $entry -isnot [string]) {
      $items += (ConvertTo-TagArray -tagInput $entry)
      continue
    }
    $text = [string]$entry
    if ([string]::IsNullOrWhiteSpace($text)) { continue }
    $items += ($text -split '[,\s]+' | Where-Object { $_ })
  }
  if (-not $items) {
    return @('foundation', 'dspm', 'defender', 'foundry')
  }
  $deduped = $items | ForEach-Object { $_.Trim() } | Where-Object { $_ } | Select-Object -Unique
  return @($deduped)
}

function Add-TagSource {
  param(
    [System.Collections.Generic.List[object]]$Target,
    [object]$Source
  )
  if (-not $Target) { return }
  if ($null -eq $Source) { return }
  if ($Source -is [System.Collections.IEnumerable] -and $Source -isnot [string]) {
    foreach ($item in $Source) {
      Add-TagSource -Target $Target -Source $item
    }
    return
  }
  $Target.Add($Source) | Out-Null
}

function Restore-StrictMode {
  param([object]$PreviousValue)

  if ($null -eq $PreviousValue -or $PreviousValue -eq 'Off') {
    Set-StrictMode -Off
    return
  }

  if ($PreviousValue -is [System.Version]) {
    Set-StrictMode -Version $PreviousValue.ToString()
    return
  }

  Set-StrictMode -Version $PreviousValue
}

function Get-BicepParameterConfig {
  param([string]$ParamFile)
  $bag = @{}
  if (-not (Test-Path $ParamFile)) { return $bag }
  $bicepCmd = Get-Command bicep -ErrorAction SilentlyContinue
  if (-not $bicepCmd) {
    Write-Verbose "Bicep CLI not found; skipping parameter defaults from $ParamFile."
    return $bag
  }
  try {
    $json = & $bicepCmd.Source build-params $ParamFile --stdout 2>$null
    if (-not $json) { return $bag }
    $doc = $json | ConvertFrom-Json
    # Newer Bicep CLI wraps output as { parametersJson: "<json string>", ... }
    $paramJsonProp = $doc.PSObject.Properties['parametersJson']
    if ($paramJsonProp -and $paramJsonProp.Value) {
      $doc = $paramJsonProp.Value | ConvertFrom-Json
    }
    $parametersProp = $doc.PSObject.Properties['parameters']
    if ($parametersProp -and $parametersProp.Value) {
      foreach ($prop in $parametersProp.Value.PSObject.Properties) {
        $bag[$prop.Name] = $prop.Value
      }
    }
  } catch {
    $msg = $_.Exception.Message
    Write-Warning ("Unable to parse {0}: {1}" -f $ParamFile, $msg)
  }
  return $bag
}

function Get-ParamValue {
  param([string]$Name)
  if (-not $script:parameterBag) { return $null }
  if ($script:parameterBag.ContainsKey($Name)) {
    return $script:parameterBag[$Name].value
  }
  return $null
}

function Get-ParamString {
  param([string]$Name)
  $value = Get-ParamValue -Name $Name
  if ($null -eq $value) { return $null }
  return [string]$value
}

function Get-ParamBool {
  param([string]$Name)
  $value = Get-ParamValue -Name $Name
  if ($null -eq $value) { return $null }
  return [bool]$value
}

function Get-ParamArray {
  param([string]$Name)
  $value = Get-ParamValue -Name $Name
  if ($null -eq $value) { return $null }
  if ($value -is [System.Array]) { return $value }
  return @([string]$value)
}

function Import-AzdLoginContext {
  param([string]$SubscriptionId)

  if (-not (Get-Command az -ErrorAction SilentlyContinue)) {
    throw "Azure CLI (az) is not installed inside the container."
  }

  $accountJson = az account show --output json 2>$null
  if (-not $accountJson) {
    throw "Azure CLI is not logged in. Run 'azd auth login' before provisioning."
  }
  $account = $accountJson | ConvertFrom-Json

  if (-not $SubscriptionId) { $SubscriptionId = $account.id }

  $rmToken = az account get-access-token --resource https://management.azure.com/ --output json | ConvertFrom-Json
  $graphToken = az account get-access-token --resource https://graph.microsoft.com/ --output json | ConvertFrom-Json

  Import-Module Az.Accounts -ErrorAction Stop | Out-Null

  $connectParams = @{
    AccessToken    = $rmToken.accessToken
    AccountId      = $account.user.name
    Tenant         = $account.tenantId
    SubscriptionId = $SubscriptionId
  }
  if ($graphToken -and $graphToken.accessToken) {
    $connectParams["GraphAccessToken"] = $graphToken.accessToken
  }

  Connect-AzAccount @connectParams | Out-Null
  Select-AzSubscription -SubscriptionId $SubscriptionId | Out-Null
}

$repoRoot = (Get-Item $PSScriptRoot).Parent.FullName
$paramFilePath = Join-Path $repoRoot "infra/main.bicepparam"
$script:parameterBag = Get-BicepParameterConfig -ParamFile $paramFilePath

$specPath = Get-Default -value $SpecPath -fallback (Get-Default -value $env:DAGA_SPEC_PATH -fallback (Get-Default -value (Get-ParamString 'dagaSpecPath') -fallback "./spec.local.json"))
if (-not (Test-Path -Path $specPath)) {
  throw "Spec file '$specPath' not found. Set DAGA_SPEC_PATH or pass -SpecPath to the hook."
}

$paramTags = Get-ParamArray 'dagaTags'
$combinedTags = New-Object 'System.Collections.Generic.List[object]'
Add-TagSource -Target $combinedTags -Source $Tags
$envTags = Get-Default -value $env:DAGA_POSTPROVISION_TAGS -fallback $null
if (-not [string]::IsNullOrWhiteSpace($envTags)) { Add-TagSource -Target $combinedTags -Source $envTags }
Add-TagSource -Target $combinedTags -Source $paramTags
$tagArray = ConvertTo-TagArray -tagInput ($combinedTags.ToArray())
$connectM365 = $ConnectM365.IsPresent
if (-not $connectM365 -and $env:DAGA_POSTPROVISION_CONNECT_M365) {
  [bool]::TryParse($env:DAGA_POSTPROVISION_CONNECT_M365, [ref]$connectM365) | Out-Null
}
if (-not $connectM365) {
  $paramConnect = Get-ParamBool 'dagaConnectM365'
  if ($null -ne $paramConnect) { $connectM365 = $paramConnect }
}
$m365Upn = Get-Default -value $M365UserPrincipalName -fallback (Get-Default -value $env:DAGA_POSTPROVISION_M365_UPN -fallback (Get-ParamString 'dagaM365UserPrincipalName'))
$m365AppId = Get-Default -value $env:DAGA_POSTPROVISION_M365_APP_ID -fallback (Get-ParamString 'dagaM365AppId')
$m365Organization = Get-Default -value $env:DAGA_POSTPROVISION_M365_ORGANIZATION -fallback (Get-ParamString 'dagaM365Organization')
$m365CertThumb = Get-Default -value $env:DAGA_POSTPROVISION_M365_CERT_THUMBPRINT -fallback (Get-ParamString 'dagaM365CertificateThumbprint')
$m365CertPath = Get-Default -value $env:DAGA_POSTPROVISION_M365_CERT_PATH -fallback (Get-ParamString 'dagaM365CertificatePath')
$m365CertPassword = Get-Default -value $env:DAGA_POSTPROVISION_M365_CERT_PASSWORD -fallback (Get-ParamString 'dagaM365CertificatePassword')

# Import the azd CLI context so downstream scripts find an authenticated Az session.
Import-AzdLoginContext -SubscriptionId $env:AZURE_SUBSCRIPTION_ID

$runScript = Join-Path $repoRoot "run.ps1"
if (-not (Test-Path $runScript)) {
  throw "Unable to locate run.ps1 (expected at $runScript)."
}

$runParams = [ordered]@{
  Tags     = $tagArray
  SpecPath = $specPath
}

if ($connectM365) {
  $runParams['ConnectM365'] = $true
  if ($m365Upn) { $runParams['M365UserPrincipalName'] = $m365Upn }
  if ($m365AppId) { $runParams['M365AppId'] = $m365AppId }
  if ($m365Organization) { $runParams['M365Organization'] = $m365Organization }
  if ($m365CertThumb) { $runParams['M365CertificateThumbprint'] = $m365CertThumb }
  if ($m365CertPath) { $runParams['M365CertificatePath'] = $m365CertPath }
  if ($m365CertPassword) { $runParams['M365CertificatePassword'] = $m365CertPassword }
}

$previewParts = @()
foreach ($entry in $runParams.GetEnumerator()) {
  $key = $entry.Key
  $value = $entry.Value
  if ($key -eq 'ConnectM365' -and $value) {
    $previewParts += "-$key"
    continue
  }
  if ($value -is [System.Array]) {
    $previewParts += "-$key $([string]::Join(',', $value))"
  } else {
    $previewParts += "-$key $value"
  }
}

Write-Host "Invoking run.ps1 $($previewParts -join ' ')" -ForegroundColor Cyan
Restore-StrictMode -PreviousValue $previousStrictMode
& $runScript @runParams
