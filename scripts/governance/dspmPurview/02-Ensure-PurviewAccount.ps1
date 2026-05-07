# Filename: 02-Ensure-PurviewAccount.ps1
param([Parameter(Mandatory=$true)][string]$SpecPath)
$spec = Get-Content $SpecPath -Raw | ConvertFrom-Json
$ensureContextPath = Join-Path $PSScriptRoot "..\..\common\Ensure-AzContext.ps1"
. $ensureContextPath
Import-Module Az.Accounts, Az.Purview -ErrorAction Stop
$purviewSubId = if ($spec.purviewSubscriptionId) { $spec.purviewSubscriptionId } else { $spec.subscriptionId }
$purviewRg    = if ($spec.purviewResourceGroup) { $spec.purviewResourceGroup } else { $spec.resourceGroup }
Ensure-AzContext -TenantId $spec.tenantId -SubscriptionId $purviewSubId
try {
	$pv = Get-AzPurviewAccount -Name $spec.purviewAccount -ResourceGroupName $purviewRg -ErrorAction Stop
	Write-Host "Purview account '$($spec.purviewAccount)' verified in subscription $purviewSubId" -ForegroundColor DarkGray
} catch {
	throw "Purview account '$($spec.purviewAccount)' was not found in subscription '$purviewSubId' / resource group '$purviewRg'. Provision it first or update purviewSubscriptionId/purviewResourceGroup in the spec."
}