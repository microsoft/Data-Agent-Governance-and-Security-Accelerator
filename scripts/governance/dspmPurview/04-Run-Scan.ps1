# Filename: 04-Run-Scan.ps1
param([Parameter(Mandatory=$true)][string]$SpecPath)
$spec = Get-Content $SpecPath -Raw | ConvertFrom-Json
$ensureContextPath = Join-Path $PSScriptRoot "..\..\common\Ensure-AzContext.ps1"
. $ensureContextPath
Import-Module Az.Accounts -ErrorAction Stop
Ensure-AzContext -TenantId $spec.tenantId -SubscriptionId $spec.subscriptionId
function Get-PvToken { (Get-AzAccessToken -ResourceUrl "https://purview.azure.net").Token }
function PvInvoke([string]$m,[string]$p,[object]$b) {
  $u = "https://$($spec.purviewAccount).purview.azure.com$p"
  $h = @{ Authorization="Bearer $(Get-PvToken)"; "Content-Type"="application/json" }
  $j = if($b){$b|ConvertTo-Json -Depth 20}else{$null}
  Invoke-RestMethod -Method $m -Uri $u -Headers $h -Body $j
}
function Get-OptionalStringProperty($obj, [string]$name){
  if(-not $obj){ return $null }
  $prop = $obj.PSObject.Properties[$name]
  if($null -eq $prop -or $null -eq $prop.Value){ return $null }
  return [string]$prop.Value
}
foreach($s in $spec.scans){
  $dataSourceName = Get-OptionalStringProperty -obj $s -name 'dataSource'
  if([string]::IsNullOrWhiteSpace($dataSourceName)){
    $dataSourceName = Get-OptionalStringProperty -obj $s -name 'dataSourceName'
  }

  $scanName = Get-OptionalStringProperty -obj $s -name 'name'
  if([string]::IsNullOrWhiteSpace($scanName)){
    $scanName = Get-OptionalStringProperty -obj $s -name 'scanName'
  }

  if([string]::IsNullOrWhiteSpace($dataSourceName) -or [string]::IsNullOrWhiteSpace($scanName)){
    Write-Host "Skipping scan entry with missing data source or scan name." -ForegroundColor Yellow
    continue
  }

  $p = "/scan/datasources/$dataSourceName/scans/$scanName?api-version=2024-05-01-preview"
  $b = @{ properties=@{ scanRulesetType=$s.rulesetType; scanRulesetName=$s.rulesetName; incrementalScanStartTime=(Get-Date).ToUniversalTime().ToString('o'); collection=@{ type='CollectionReference'; referenceName=$spec.purviewAccount } } }
  PvInvoke 'PUT' $p $b | Out-Null
  PvInvoke 'POST' "/scan/datasources/$dataSourceName/scans/$scanName/run?api-version=2024-05-01-preview" $null | Out-Null
  Write-Host "Triggered scan $scanName on $dataSourceName" -ForegroundColor Green
}