# Filename: 07-Enable-Diagnostics.ps1
param([Parameter(Mandatory=$true)][string]$SpecPath)
$ErrorActionPreference='Stop'
$spec = Get-Content $SpecPath -Raw | ConvertFrom-Json
$ensureContextPath = Join-Path $PSScriptRoot "..\..\common\Ensure-AzContext.ps1"
. $ensureContextPath
Import-Module Az.Accounts, Az.Monitor, Az.Resources, Az.OperationalInsights -ErrorAction Stop
Ensure-AzContext -TenantId $spec.tenantId -SubscriptionId $spec.subscriptionId
$law = $spec.defenderForAI.logAnalyticsWorkspaceId
if(!$law){ Write-Host "No Log Analytics workspace configured" -ForegroundColor DarkGray; exit 0 }
$cats = if($spec.defenderForAI.diagnosticCategories){$spec.defenderForAI.diagnosticCategories}else{@("AllLogs","AllMetrics")}
$logCategories = @()
$metricCategories = @()
foreach($cat in $cats){
  if($cat -match "Metric") { $metricCategories += $cat }
  else { $logCategories += $cat }
}
if(-not $logCategories){ $logCategories = @("AllLogs") }
if(-not $metricCategories){ $metricCategories = @("AllMetrics") }

function Resolve-RequestedCategories {
  param(
    [string[]]$Requested,
    [string[]]$Available,
    [string]$AllToken,
    [string]$TypeName,
    [string]$ResourceLabel
  )

  if(-not $Available -or $Available.Count -eq 0){ return @() }
  if($Requested -contains $AllToken){ return @($Available) }
  $resolved = @($Requested | Where-Object { $Available -contains $_ })
  $missing = @($Requested | Where-Object { $Available -notcontains $_ })
  if($missing.Count -gt 0){
    Write-Host "Skipping unsupported $TypeName categories on ${ResourceLabel}: $($missing -join ', ')" -ForegroundColor Yellow
  }
  return $resolved
}

function Resolve-WorkspaceResourceId([string]$workspaceId, $specObj){
  if(-not $workspaceId){ throw "Log Analytics workspace identifier is empty." }
  if($workspaceId -match '^/'){ return $workspaceId }
  $subscriptions = @()
  if($specObj.subscriptionId){ $subscriptions += $specObj.subscriptionId }
  if($specObj.aiSubscriptionId -and ($subscriptions -notcontains $specObj.aiSubscriptionId)){
    $subscriptions += $specObj.aiSubscriptionId
  }
  if(-not $subscriptions){
    $subscriptions = @((Get-AzContext).Subscription.Id)
  }
  $originalContext = Get-AzContext
  foreach($sub in $subscriptions){
    try{
      Select-AzSubscription -SubscriptionId $sub | Out-Null
    } catch {
      continue
    }
    $workspace = Get-AzOperationalInsightsWorkspace -ErrorAction SilentlyContinue | Where-Object {
      $_.CustomerId -eq $workspaceId -or $_.Name -eq $workspaceId -or $_.ResourceId -eq $workspaceId
    }
    if($workspace){
      if($originalContext -and $originalContext.Subscription.Id -ne $sub){
        Select-AzSubscription -SubscriptionId $originalContext.Subscription.Id | Out-Null
      }
      return $workspace.ResourceId
    }
  }
  if($originalContext){ Select-AzSubscription -SubscriptionId $originalContext.Subscription.Id | Out-Null }
  throw "Workspace '$workspaceId' not found. Provide the full resource ID (/subscriptions/.../workspaces/<name>)."
}

function Get-DiagnosticScopeId([string]$resourceId){
  if($resourceId -match "/providers/Microsoft\.CognitiveServices/accounts/[^/]+/projects/[^/]+$"){
    return ($resourceId -replace "/projects/[^/]+$", "")
  }
  return $resourceId
}

$workspaceResourceId = Resolve-WorkspaceResourceId -workspaceId $law -specObj $spec

foreach($r in $spec.foundry.resources){
  if(!$r.diagnostics){ continue }
  $res = Get-AzResource -ResourceId $r.resourceId -ErrorAction SilentlyContinue
  if(-not $res){
    Write-Warning "Resource not found, skipping: $($r.resourceId)"
    continue
  }
  $diagResourceId = Get-DiagnosticScopeId -resourceId $r.resourceId
  $scopeName = if($diagResourceId -eq $r.resourceId){ $res.Name } else { (Split-Path -Path $diagResourceId -Leaf) }
  $name = "$scopeName-diag"
  if(Get-AzDiagnosticSetting -ResourceId $diagResourceId -ErrorAction SilentlyContinue | Where-Object Name -eq $name){ Write-Host "Diagnostics exists on $scopeName" -ForegroundColor DarkGray; continue }
  if($diagResourceId -ne $r.resourceId){
    Write-Host "Diagnostics not supported at project scope; using parent $diagResourceId" -ForegroundColor Yellow
  }
  $availableCats = Get-AzDiagnosticSettingCategory -ResourceId $diagResourceId -ErrorAction SilentlyContinue
  $availableLogs = @($availableCats | Where-Object { $_.CategoryType -eq 'Logs' } | Select-Object -ExpandProperty Name)
  $availableMetrics = @($availableCats | Where-Object { $_.CategoryType -eq 'Metrics' } | Select-Object -ExpandProperty Name)

  $resolvedLogs = Resolve-RequestedCategories -Requested $logCategories -Available $availableLogs -AllToken 'AllLogs' -TypeName 'log' -ResourceLabel $scopeName
  $resolvedMetrics = Resolve-RequestedCategories -Requested $metricCategories -Available $availableMetrics -AllToken 'AllMetrics' -TypeName 'metric' -ResourceLabel $scopeName

  if((-not $resolvedLogs -or $resolvedLogs.Count -eq 0) -and (-not $resolvedMetrics -or $resolvedMetrics.Count -eq 0)){
    Write-Host "No supported diagnostic categories for $scopeName. Skipping." -ForegroundColor Yellow
    continue
  }

  $logSettings = foreach($log in $resolvedLogs){ New-AzDiagnosticSettingLogSettingsObject -Enabled $true -Category $log }
  $metricSettings = foreach($metric in $resolvedMetrics){ New-AzDiagnosticSettingMetricSettingsObject -Enabled $true -Category $metric }
  New-AzDiagnosticSetting -Name $name -ResourceId $diagResourceId -WorkspaceId $workspaceResourceId -Log $logSettings -Metric $metricSettings | Out-Null
  Write-Host "Enabled diagnostics for $scopeName" -ForegroundColor Green
}
