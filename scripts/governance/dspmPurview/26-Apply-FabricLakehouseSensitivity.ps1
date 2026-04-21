# Filename: 26-Apply-FabricLakehouseSensitivity.ps1
param([Parameter(Mandatory=$true)][string]$SpecPath)

$ErrorActionPreference = 'Stop'
$spec = Get-Content $SpecPath -Raw | ConvertFrom-Json

function Get-OptionalStringProperty($obj, [string]$name){
  if(-not $obj){ return $null }
  $prop = $obj.PSObject.Properties[$name]
  if($null -eq $prop -or $null -eq $prop.Value){ return $null }
  return [string]$prop.Value
}

function Get-FabricLakehouseLabelTargetPath([string]$SpecPath){
  $legacyPath = Join-Path ([IO.Path]::GetTempPath()) 'fabric_lakehouse_labels.json'
  if([string]::IsNullOrWhiteSpace($SpecPath)){
    return $legacyPath
  }

  try {
    $resolvedSpecPath = (Resolve-Path -LiteralPath $SpecPath -ErrorAction Stop).Path
  } catch {
    $resolvedSpecPath = [IO.Path]::GetFullPath($SpecPath)
  }

  $sha256 = [System.Security.Cryptography.SHA256]::Create()
  try {
    $hashBytes = $sha256.ComputeHash([System.Text.Encoding]::UTF8.GetBytes($resolvedSpecPath))
  } finally {
    if($sha256){ $sha256.Dispose() }
  }

  $specId = ([System.BitConverter]::ToString($hashBytes)).Replace('-', '').ToLowerInvariant()
  return Join-Path ([IO.Path]::GetTempPath()) ("fabric_lakehouse_labels_{0}.json" -f $specId)
}

function Get-AccessTokenForResource([string]$resourceUrl){
  try {
    $token = az account get-access-token --resource $resourceUrl --query accessToken -o tsv 2>$null
    if($LASTEXITCODE -eq 0 -and -not [string]::IsNullOrWhiteSpace($token)){
      return $token.Trim()
    }
  } catch {
  }

  try {
    return (Get-AzAccessToken -ResourceUrl $resourceUrl).Token
  } catch {
    return $null
  }
}

function Get-FabricToken {
  Get-AccessTokenForResource -resourceUrl "https://api.fabric.microsoft.com"
}

function Get-PowerBiToken {
  Get-AccessTokenForResource -resourceUrl "https://analysis.windows.net/powerbi/api"
}

function Invoke-FabricApi([string]$Method, [string]$Uri, [object]$Body){
  $token = Get-FabricToken
  if([string]::IsNullOrWhiteSpace($token)){
    throw "Failed to acquire Fabric access token. Run az login with a Fabric admin user."
  }
  $headers = @{ Authorization = "Bearer $token"; "Content-Type" = "application/json" }
  $payload = if($Body){ $Body | ConvertTo-Json -Depth 20 } else { $null }
  Invoke-RestMethod -Method $Method -Uri $Uri -Headers $headers -Body $payload
}

function Resolve-WorkspaceGuid($workspace, [string]$workspaceName){
  $workspaceId = Get-OptionalStringProperty -obj $workspace -name 'workspaceId'
  $workspaceUrl = Get-OptionalStringProperty -obj $workspace -name 'workspaceUrl'
  $resourceId = Get-OptionalStringProperty -obj $workspace -name 'resourceId'

  if($workspaceId -and $workspaceId -match '^[0-9a-fA-F-]{36}$'){ return $workspaceId }
  foreach($candidate in @($workspaceUrl, $resourceId)){
    if($candidate -and $candidate -match '/groups/([0-9a-fA-F-]{36})'){ return $Matches[1] }
    if($candidate -and $candidate -match '^[0-9a-fA-F-]{36}$'){ return $candidate }
  }

  if([string]::IsNullOrWhiteSpace($workspaceName)){ return $null }
  try {
    $pbiToken = Get-PowerBiToken
    if([string]::IsNullOrWhiteSpace($pbiToken)){ return $null }
    $headers = @{ Authorization = "Bearer $pbiToken" }
    $groups = Invoke-RestMethod -Method Get -Uri "https://api.powerbi.com/v1.0/myorg/groups?%24top=5000" -Headers $headers
    $matches = @($groups.value | Where-Object { $_.name -eq $workspaceName })
    if($matches.Count -eq 1){ return [string]$matches[0].id }
  } catch {
  }
  return $null
}

function Get-LakehouseItems([string]$workspaceGuid){
  $items = @()
  $continuationToken = $null
  do {
    $uri = "https://api.fabric.microsoft.com/v1/workspaces/$workspaceGuid/items?type=Lakehouse"
    if($continuationToken){
      $uri = "$uri&continuationToken=$([System.Uri]::EscapeDataString($continuationToken))"
    }
    $result = Invoke-FabricApi -Method 'GET' -Uri $uri -Body $null
    if($result.value){
      $items += @($result.value)
    }
    $continuationToken = $null
    $continuationProp = $null
    if($result){
      $continuationProp = $result.PSObject.Properties['continuationToken']
    }
    if($continuationProp -and -not [string]::IsNullOrWhiteSpace([string]$continuationProp.Value)){
      $continuationToken = [string]$continuationProp.Value
    }
  } while(-not [string]::IsNullOrWhiteSpace($continuationToken))
  return @($items)
}

$workspaces = @()
$fabric = $null
$fabricProp = $spec.PSObject.Properties['fabric']
if($fabricProp -and $fabricProp.Value){
  $fabric = $fabricProp.Value
}
if($fabric){
  $workspacesProp = $fabric.PSObject.Properties['workspaces']
  if($workspacesProp -and $workspacesProp.Value){
    $workspaces = @($workspacesProp.Value)
  }
}
if($workspaces.Count -eq 0){
  Write-Host "No fabric.workspaces entries found. Skipping lakehouse label apply step." -ForegroundColor DarkGray
  exit 0
}

$targetPath = Get-FabricLakehouseLabelTargetPath -SpecPath $SpecPath
if(-not (Test-Path -Path $targetPath)){
  $legacyTargetPath = Join-Path ([IO.Path]::GetTempPath()) 'fabric_lakehouse_labels.json'
  if(Test-Path -Path $legacyTargetPath){
    $targetPath = $legacyTargetPath
  } else {
    Write-Host "Validated label target file not found at '$targetPath' or legacy path '$legacyTargetPath'. Run 26-Ensure-FabricWorkspaceSensitivity.ps1 first." -ForegroundColor Yellow
    exit 0
  }
}

$targets = @()
try {
  $raw = Get-Content -Path $targetPath -Raw
  if(-not [string]::IsNullOrWhiteSpace($raw)){
    $parsed = $raw | ConvertFrom-Json
    if($parsed -is [System.Array]){ $targets = @($parsed) } else { $targets = @($parsed) }
  }
} catch {
  Write-Host "Unable to parse label target file '$targetPath': $($_.Exception.Message)" -ForegroundColor Yellow
  exit 0
}

$validTargets = @($targets | Where-Object {
  (Get-OptionalStringProperty -obj $_ -name 'validationStatus') -eq 'VALID' -and
  -not [string]::IsNullOrWhiteSpace((Get-OptionalStringProperty -obj $_ -name 'resolvedLabelId')) -and
  -not [string]::IsNullOrWhiteSpace((Get-OptionalStringProperty -obj $_ -name 'lakehouseName'))
})

if($validTargets.Count -eq 0){
  Write-Host "No VALID lakehouse label targets with resolved label IDs. Skipping apply step." -ForegroundColor DarkGray
  exit 0
}

$workspaceGuidCache = @{}
$workspaceItemsCache = @{}
$itemsToApply = @()
$seenApplyKeys = @{}

foreach($target in $validTargets){
  $workspaceName = Get-OptionalStringProperty -obj $target -name 'workspaceName'
  $targetWorkspaceId = Get-OptionalStringProperty -obj $target -name 'workspaceId'
  $lakehouseName = Get-OptionalStringProperty -obj $target -name 'lakehouseName'
  $labelId = Get-OptionalStringProperty -obj $target -name 'resolvedLabelId'
  if(([string]::IsNullOrWhiteSpace($workspaceName) -and [string]::IsNullOrWhiteSpace($targetWorkspaceId)) -or [string]::IsNullOrWhiteSpace($lakehouseName)){ continue }

  $workspaceCacheKey = if(-not [string]::IsNullOrWhiteSpace($targetWorkspaceId)) { $targetWorkspaceId } else { $workspaceName }

  if(-not $workspaceGuidCache.ContainsKey($workspaceCacheKey)){
    if(-not [string]::IsNullOrWhiteSpace($targetWorkspaceId)){
      $workspaceGuidCache[$workspaceCacheKey] = $targetWorkspaceId
    } else {
      $workspaceConfig = @($workspaces | Where-Object { (Get-OptionalStringProperty -obj $_ -name 'name') -eq $workspaceName } | Select-Object -First 1)
      if($workspaceConfig.Count -eq 0){
        $workspaceGuidCache[$workspaceCacheKey] = $null
      } else {
        $workspaceGuidCache[$workspaceCacheKey] = Resolve-WorkspaceGuid -workspace $workspaceConfig[0] -workspaceName $workspaceName
      }
    }
  }

  $workspaceGuid = $workspaceGuidCache[$workspaceCacheKey]
  if([string]::IsNullOrWhiteSpace($workspaceGuid)){
    $workspaceLogName = if(-not [string]::IsNullOrWhiteSpace($workspaceName)) { $workspaceName } else { $targetWorkspaceId }
    Write-Host "Skipping apply for workspace '$workspaceLogName' (workspace GUID could not be resolved)." -ForegroundColor Yellow
    continue
  }

  if(-not $workspaceItemsCache.ContainsKey($workspaceGuid)){
    try {
      $workspaceItemsCache[$workspaceGuid] = Get-LakehouseItems -workspaceGuid $workspaceGuid
    } catch {
      Write-Host "Unable to list lakehouses in workspace '$workspaceName' ($workspaceGuid): $($_.Exception.Message)" -ForegroundColor Yellow
      $workspaceItemsCache[$workspaceGuid] = @()
    }
  }

  $lakehouseItems = @($workspaceItemsCache[$workspaceGuid])
  $matches = @($lakehouseItems | Where-Object {
    (Get-OptionalStringProperty -obj $_ -name 'displayName') -eq $lakehouseName -or
    (Get-OptionalStringProperty -obj $_ -name 'name') -eq $lakehouseName
  })
  if($matches.Count -eq 0){
    Write-Host "Lakehouse '$lakehouseName' not found in workspace '$workspaceName'. Skipping." -ForegroundColor Yellow
    continue
  }
  if($matches.Count -gt 1){
    Write-Host "Multiple lakehouses named '$lakehouseName' found in workspace '$workspaceName'. Skipping ambiguous target." -ForegroundColor Yellow
    continue
  }

  $lakehouseId = Get-OptionalStringProperty -obj $matches[0] -name 'id'
  if([string]::IsNullOrWhiteSpace($lakehouseId)){
    Write-Host "Lakehouse '$lakehouseName' in workspace '$workspaceName' has no ID. Skipping." -ForegroundColor Yellow
    continue
  }

  $applyKey = ("{0}|{1}|{2}" -f $workspaceGuid, $lakehouseId, $labelId).ToLowerInvariant()
  if($seenApplyKeys.ContainsKey($applyKey)){
    $workspaceDisplay = if(-not [string]::IsNullOrWhiteSpace($workspaceName)) { $workspaceName } else { $workspaceGuid }
    Write-Host "Duplicate label-apply target for workspace '$workspaceDisplay' lakehouse '$lakehouseName' label '$labelId' detected. Ignoring duplicate and continuing." -ForegroundColor DarkGray
    continue
  }
  $seenApplyKeys[$applyKey] = $true

  $itemsToApply += [pscustomobject]@{
    workspaceName = $workspaceName
    workspaceId = $workspaceGuid
    lakehouseName = $lakehouseName
    lakehouseId = $lakehouseId
    labelId = $labelId
  }
}

if($itemsToApply.Count -eq 0){
  Write-Host "No lakehouse items resolved for label application. Skipping apply step." -ForegroundColor DarkGray
  exit 0
}

$applyResults = @()
$groups = $itemsToApply | Group-Object labelId
foreach($group in $groups){
  $labelId = [string]$group.Name
  $requestBody = @{
    items = @($group.Group | ForEach-Object { @{ id = $_.lakehouseId; type = 'Lakehouse' } })
    labelId = $labelId
    assignmentMethod = 'Standard'
  }

  try {
    $response = Invoke-FabricApi -Method 'POST' -Uri 'https://api.fabric.microsoft.com/v1/admin/items/bulkSetLabels' -Body $requestBody
    $statusItems = @()
    if($response.itemsChangeLabelStatus){ $statusItems = @($response.itemsChangeLabelStatus) }
    foreach($entry in $group.Group){
      $status = 'Unknown'
      $statusMatch = @($statusItems | Where-Object { (Get-OptionalStringProperty -obj $_ -name 'id') -eq $entry.lakehouseId } | Select-Object -First 1)
      if($statusMatch.Count -gt 0){
        $statusValue = Get-OptionalStringProperty -obj $statusMatch[0] -name 'status'
        if(-not [string]::IsNullOrWhiteSpace($statusValue)){ $status = $statusValue }
      }

      $applyResults += [pscustomobject]@{
        workspaceName = $entry.workspaceName
        lakehouseName = $entry.lakehouseName
        lakehouseId = $entry.lakehouseId
        labelId = $entry.labelId
        status = $status
      }

      if($status -eq 'Succeeded'){
        Write-Host "Applied label '$($entry.labelId)' to lakehouse '$($entry.lakehouseName)' in workspace '$($entry.workspaceName)'." -ForegroundColor Green
      } else {
        Write-Host "Label apply returned status '$status' for lakehouse '$($entry.lakehouseName)' in workspace '$($entry.workspaceName)'." -ForegroundColor Yellow
      }
    }
  } catch {
    $errorMessage = $_.Exception.Message
    foreach($entry in $group.Group){
      $applyResults += [pscustomobject]@{
        workspaceName = $entry.workspaceName
        lakehouseName = $entry.lakehouseName
        lakehouseId = $entry.lakehouseId
        labelId = $entry.labelId
        status = 'Failed'
        error = $errorMessage
      }
      Write-Host "Failed to apply label to lakehouse '$($entry.lakehouseName)' in workspace '$($entry.workspaceName)': $errorMessage" -ForegroundColor Yellow
    }
  }
}

$resultPath = Join-Path ([IO.Path]::GetTempPath()) 'fabric_lakehouse_label_apply_results.json'
$applyResults | ConvertTo-Json -Depth 10 | Set-Content -Path $resultPath -Encoding UTF8
Write-Host "Saved Fabric lakehouse label apply results to $resultPath" -ForegroundColor DarkGray