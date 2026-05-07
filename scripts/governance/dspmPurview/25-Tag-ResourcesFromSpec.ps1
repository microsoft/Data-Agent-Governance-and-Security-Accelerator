# Filename: 25-Tag-ResourcesFromSpec.ps1
param([Parameter(Mandatory=$true)][string]$SpecPath)
$spec = Get-Content $SpecPath -Raw | ConvertFrom-Json
$ensureContextPath = Join-Path $PSScriptRoot "..\..\common\Ensure-AzContext.ps1"
. $ensureContextPath
Import-Module Az.Accounts, Az.Resources -ErrorAction Stop
Ensure-AzContext -TenantId $spec.tenantId -SubscriptionId $spec.subscriptionId

function Test-IsTransientTaggingError([string]$message){
  if([string]::IsNullOrWhiteSpace($message)){ return $false }
  return (
    $message -match 'ServiceUnavailable' -or
    $message -match 'temporar' -or
    $message -match 'TooManyRequests' -or
    $message -match 'timed out' -or
    $message -match 'resource content to evaluate the request'
  )
}

function Invoke-TagMergeWithRetry([string]$resourceId, [hashtable]$tagSet){
  $maxAttempts = 5
  $delaySeconds = 3

  for($attempt = 1; $attempt -le $maxAttempts; $attempt++){
    try {
      Update-AzTag -ResourceId $resourceId -Tag $tagSet -Operation Merge -ErrorAction Stop | Out-Null
      return $true
    } catch {
      $message = $_.Exception.Message
      $isLastAttempt = $attempt -ge $maxAttempts
      if($isLastAttempt -or -not (Test-IsTransientTaggingError -message $message)){
        throw
      }

      Write-Warning "Transient tag update failure on '$resourceId' (attempt $attempt/$maxAttempts): $message"
      Start-Sleep -Seconds $delaySeconds
      $delaySeconds = [Math]::Min($delaySeconds * 2, 30)
    }
  }

  return $false
}

if ($spec.foundry -and $spec.foundry.resources) {
  foreach($r in $spec.foundry.resources){
    try {
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
    $merged = @{}
    if($res.Tags -is [Collections.IDictionary]){
      foreach($key in $res.Tags.Keys){ $merged[$key] = $res.Tags[$key] }
    }
    foreach($key in $desiredTags.Keys){ $merged[$key] = $desiredTags[$key] }
    Invoke-TagMergeWithRetry -resourceId $res.ResourceId -tagSet $merged | Out-Null
    Write-Host "Tagged $($res.Name)" -ForegroundColor Green
    } catch {
      Write-Warning "Failed to tag resource '$($r.resourceId)'. Skipping. $($_.Exception.Message)"
      continue
    }
  }
} else {
  Write-Warning "Spec does not contain 'foundry.resources'. No resources tagged."
}
