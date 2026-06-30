# Filename: 05-Assign-AzurePolicies.ps1
param([Parameter(Mandatory=$true)][string]$SpecPath)
$ErrorActionPreference='Stop'
$spec = Get-Content $SpecPath -Raw | ConvertFrom-Json
$ensureContextPath = Join-Path $PSScriptRoot "..\..\common\Ensure-AzContext.ps1"
. $ensureContextPath
Import-Module Az.Accounts, Az.Resources -ErrorAction Stop
Ensure-AzContext -TenantId $spec.tenantId -SubscriptionId $spec.subscriptionId
$hasAzurePolicies = $spec.PSObject.Properties.Name -contains 'azurePolicies'
if(-not $hasAzurePolicies){ Write-Host "No azurePolicies in spec. Skipping policy assignments." -ForegroundColor Yellow; exit 0 }
$policies = $spec.azurePolicies
if(-not $policies -or -not $policies.Count){ Write-Host "azurePolicies array empty. Nothing to assign." -ForegroundColor Yellow; exit 0 }
function Resolve-DefId([string]$display,[string]$id){ if($id){return $id}; (Get-AzPolicyDefinition -Builtin | Where-Object {$_.Properties.DisplayName -eq $display} | Select-Object -First 1).PolicyDefinitionId }
foreach($p in $policies){
  if($p.enabled -eq $false){ Write-Host "Policy $($p.name) disabled in spec, skipping" -ForegroundColor DarkGray; continue }
  $scope = if($p.scope -eq 'subscription') { "/subscriptions/$($spec.subscriptionId)" } else { "/subscriptions/$($spec.subscriptionId)/resourceGroups/$($spec.resourceGroup)" }
  $defId = Resolve-DefId $p.displayName $p.definitionId
  if(Get-AzPolicyAssignment -Scope $scope -ErrorAction SilentlyContinue | Where-Object Name -eq $p.name){ Write-Host "Policy $($p.name) exists" -ForegroundColor DarkGray; continue }
  New-AzPolicyAssignment -Name $p.name -DisplayName $p.displayName -PolicyDefinitionId $defId -Scope $scope -PolicyParameterObject $p.parameters | Out-Null
  Write-Host "Assigned policy $($p.displayName) at $scope" -ForegroundColor Green
}
