[CmdletBinding()]
param(
  [string]$SpecPath
)

$ErrorActionPreference = 'Stop'

function Get-Default($value, $fallback) {
  if ($null -ne $value -and $value -ne '') { return $value }
  return $fallback
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
