# Filename: 25-Tag-ResourcesFromSpec.ps1
param([Parameter(Mandatory=$true)][string]$SpecPath)
$spec = Get-Content $SpecPath -Raw | ConvertFrom-Json
$ensureContextPath = Join-Path $PSScriptRoot "..\..\common\Ensure-AzContext.ps1"
. $ensureContextPath
Import-Module Az.Accounts, Az.Resources -ErrorAction Stop
Ensure-AzContext -TenantId $spec.tenantId -SubscriptionId $spec.subscriptionId
if ($spec.foundry -and $spec.foundry.resources) {
  foreach($r in $spec.foundry.resources){
    if(-not $r.resourceId){ Write-Host "Skipping entry with no resourceId" -ForegroundColor Yellow; continue }

    $desiredTags = @{}
    if($r.tags){
      if($r.tags -is [Collections.IDictionary]){ $desiredTags += $r.tags }
      else{ foreach($prop in $r.tags.PSObject.Properties){ $desiredTags[$prop.Name] = $prop.Value } }
    }
    if($desiredTags.Count -eq 0){ Write-Host "No spec tags defined for $($r.name); skipping" -ForegroundColor DarkGray; continue }
    $res = Get-AzResource -ResourceId $r.resourceId -ErrorAction SilentlyContinue
    if(-not $res){ Write-Warning "Resource not found, skipping tag update: $($r.resourceId)"; continue }
    if($res.ResourceType -and $res.ResourceType -match '/projects'){ Write-Host "Skipping tag update for project-level resource $($res.ResourceId); Azure tags only apply to the parent account." -ForegroundColor Yellow; continue }
    # Use Update-AzTag to avoid full resource deserialization issues
    Update-AzTag -ResourceId $res.ResourceId -Tag $desiredTags -Operation Merge | Out-Null
    Write-Host "Tagged $($res.Name)" -ForegroundColor Green
  }
} else {
  Write-Warning "Spec does not contain 'foundry.resources'. No resources tagged."
}
