# Filename: 03-Register-DataSource.ps1
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
foreach($ds in $spec.dataSources){
  $path = "/scan/datasources/$($ds.name)?api-version=2024-05-01-preview"
  $body = @{ kind=$ds.type; properties=@{ resourceId=$ds.resourceId; collection=@{ type='CollectionReference'; referenceName=$spec.purviewAccount } } }
  PvInvoke 'PUT' $path $body | Out-Null
  Write-Host "Registered data source $($ds.name) [$($ds.type)]" -ForegroundColor Green
}
