# Filename: 30-Foundry-RegisterResources.ps1
param([Parameter(Mandatory=$true)][string]$SpecPath)
$ErrorActionPreference='Stop'
$spec = Get-Content $SpecPath -Raw | ConvertFrom-Json
$ensureContextPath = Join-Path $PSScriptRoot "..\..\common\Ensure-AzContext.ps1"
. $ensureContextPath
Import-Module Az.Accounts, Az.Resources -ErrorAction Stop
Ensure-AzContext -TenantId $spec.tenantId -SubscriptionId $spec.subscriptionId
if(-not $spec.foundry -or -not $spec.foundry.resources){ Write-Host "No foundry.resources"; exit 0 }
foreach($r in $spec.foundry.resources){
  if(-not $r.resourceId -or $r.resourceId -notmatch '/projects/'){ Write-Host "Skipping non-Foundry resource: $($r.name)" -ForegroundColor Yellow; continue }
  $res = Get-AzResource -ResourceId $r.resourceId -ErrorAction SilentlyContinue
  if(-not $res){
    Write-Warning "Resource not found, skipping: $($r.resourceId)"
    continue
  }
  Write-Host "Found resource: $($res.ResourceId)" -ForegroundColor Cyan
  if($r.tags){
    $merged = @{}
    if($res.Tags -is [Collections.IDictionary]){ $merged += $res.Tags }
    if($r.tags -is [Collections.IDictionary]){ $merged += $r.tags }
    Set-AzResource -ResourceId $res.ResourceId -Tag $merged -Force | Out-Null
    Write-Host "Applied tags to $($res.Name)" -ForegroundColor Green
  }
}
