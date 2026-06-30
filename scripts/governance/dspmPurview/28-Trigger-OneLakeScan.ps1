# Filename: 28-Trigger-OneLakeScan.ps1
param([Parameter(Mandatory=$true)][string]$SpecPath,[Parameter(Mandatory=$true)][string]$OneLakeName,[Parameter(Mandatory=$true)][string]$ScanName)
$spec = Get-Content $SpecPath -Raw | ConvertFrom-Json
$ensureContextPath = Join-Path $PSScriptRoot "..\..\common\Ensure-AzContext.ps1"
. $ensureContextPath
Import-Module Az.Accounts -ErrorAction Stop
Ensure-AzContext -TenantId $spec.tenantId -SubscriptionId $spec.subscriptionId
function Get-PvToken { (Get-AzAccessToken -ResourceUrl "https://purview.azure.net").Token }
function PvInvoke([string]$m,[string]$p,[object]$b){ $u="https://$($spec.purviewAccount).purview.azure.com$p"; $h=@{Authorization="Bearer $(Get-PvToken)";"Content-Type"="application/json"}; $j=if($b){$b|ConvertTo-Json -Depth 20}else{$null}; Invoke-RestMethod -Method $m -Uri $u -Headers $h -Body $j }
$p="/scan/datasources/$OneLakeName/scans/$ScanName?api-version=2024-05-01-preview"
$b=@{ properties=@{ scanRulesetType="System"; scanRulesetName="OneLake"; incrementalScanStartTime=(Get-Date).ToUniversalTime().ToString('o'); collection=@{ type='CollectionReference'; referenceName=$spec.purviewAccount } } }
PvInvoke 'PUT' $p $b | Out-Null
PvInvoke 'POST' "/scan/datasources/$OneLakeName/scans/$ScanName/run?api-version=2024-05-01-preview" $null | Out-Null
Write-Host "Triggered OneLake scan $ScanName" -ForegroundColor Green
