# Filename: 00-New-DspmSpec.ps1
param(
  [Parameter()][string]$OutFile = "./spec.dspm.template.json",
  [switch]$Force
)

if ((Test-Path -Path $OutFile -PathType Leaf) -and -not $Force) {
  Write-Host "Spec '$OutFile' already exists. Skipping scaffold (pass -Force to overwrite)." -ForegroundColor Yellow
  return
}

$repoRoot = Resolve-Path (Join-Path $PSScriptRoot "..\..")
$templatePath = Join-Path $repoRoot "spec.dspm.template.json"
if (-not (Test-Path -Path $templatePath -PathType Leaf)) {
  throw "Template '$templatePath' not found."
}

$template = Get-Content -Path $templatePath -Raw | ConvertFrom-Json

try {
  $accountJson = az account show --output json 2>$null
  if ($accountJson) {
    $azContext = $accountJson | ConvertFrom-Json
    if ($azContext.tenantId) { $template.tenantId = $azContext.tenantId }
    if ($azContext.id) {
      $template.subscriptionId = $azContext.id
      if ($template.aiSubscriptionId -ne $null) { $template.aiSubscriptionId = $azContext.id }
    }
  }
} catch {
}

if ($env:AZURE_TENANT_ID) { $template.tenantId = $env:AZURE_TENANT_ID }
if ($env:AZURE_SUBSCRIPTION_ID) {
  $template.subscriptionId = $env:AZURE_SUBSCRIPTION_ID
  if ($template.aiSubscriptionId -ne $null) { $template.aiSubscriptionId = $env:AZURE_SUBSCRIPTION_ID }
  if ($template.purviewSubscriptionId -ne $null -and [string]::IsNullOrWhiteSpace([string]$template.purviewSubscriptionId)) { $template.purviewSubscriptionId = $env:AZURE_SUBSCRIPTION_ID }
}
if ($env:AZURE_RESOURCE_GROUP) { $template.resourceGroup = $env:AZURE_RESOURCE_GROUP }
elseif ($env:AZURE_RESOURCE_GROUP_NAME) { $template.resourceGroup = $env:AZURE_RESOURCE_GROUP_NAME }
if ($env:AZURE_LOCATION) { $template.location = $env:AZURE_LOCATION }

if ($template.subscriptionId -and $template.purviewSubscriptionId -ne $null -and [string]::IsNullOrWhiteSpace([string]$template.purviewSubscriptionId)) {
  $template.purviewSubscriptionId = $template.subscriptionId
}
if ($template.resourceGroup -and $template.purviewResourceGroup -ne $null -and [string]::IsNullOrWhiteSpace([string]$template.purviewResourceGroup)) {
  $template.purviewResourceGroup = $template.resourceGroup
}

$destinationDir = Split-Path -Parent $OutFile
if ($destinationDir -and -not (Test-Path -Path $destinationDir)) {
  New-Item -ItemType Directory -Path $destinationDir -Force | Out-Null
}

$template | ConvertTo-Json -Depth 20 | Out-File -FilePath $OutFile -Encoding UTF8 -Force
Write-Host "Scaffolded spec at $OutFile from spec.dspm.template.json" -ForegroundColor Green