<#
.SYNOPSIS
  Enable Microsoft Defender for Cloud on Azure subscription.

.DESCRIPTION
  This script enables Microsoft Defender for Cloud, providing:
  - Cloud Security Posture Management (CSPM)
  - Threat protection capabilities
  - Security recommendations
  - Foundation for AI services protection

.NOTES
  Requires: Security Admin or Contributor role on Azure subscription
#>


# Filename: 06-Enable-DefenderPlans.ps1
param([Parameter(Mandatory=$true)][string]$SpecPath)
$ErrorActionPreference='Stop'
$spec = Get-Content $SpecPath -Raw | ConvertFrom-Json
$ensureContextPath = Join-Path $PSScriptRoot "..\common\Ensure-AzContext.ps1"
. $ensureContextPath
Import-Module Az.Accounts, Az.Security -ErrorAction Stop
Ensure-AzContext -TenantId $spec.tenantId -SubscriptionId $spec.subscriptionId
$plans = $spec.defenderForAI.enableDefenderForCloudPlans
if(!$plans){ Write-Host "No Defender plans in spec" -ForegroundColor DarkGray; exit 0 }
$planMap = @{
  "CognitiveServices" = "AI"
  "Storage" = "StorageAccounts"
  "Containers" = "Containers"
  "VirtualMachines" = "VirtualMachines"
  "SqlServers" = "SqlServers"
  "KeyVaults" = "KeyVaults"
}
foreach($p in $plans){
  $resolved = if($planMap.ContainsKey($p)){ $planMap[$p] } else { $p }
  try{
    Set-AzSecurityPricing -Name $resolved -PricingTier "Standard" | Out-Null
    Write-Host "Enabled Defender plan: $resolved (requested '$p')" -ForegroundColor Green
  }catch{
    Write-Warning "Failed to enable plan '$p' (resolved '$resolved'): $($_.Exception.Message)"
  }
}
