# Filename: 29-Trigger-FabricWorkspaceScan.ps1
param([Parameter(Mandatory=$true)][string]$SpecPath)

$ErrorActionPreference = 'Stop'
$spec = Get-Content $SpecPath -Raw | ConvertFrom-Json
$ensureContextPath = Join-Path $PSScriptRoot "..\..\common\Ensure-AzContext.ps1"
. $ensureContextPath
Import-Module Az.Accounts -ErrorAction Stop
Ensure-AzContext -TenantId $spec.tenantId -SubscriptionId $spec.subscriptionId

function Get-OptionalStringProperty($obj, [string]$name){
  if(-not $obj){ return $null }
  $prop = $obj.PSObject.Properties[$name]
  if($null -eq $prop -or $null -eq $prop.Value){ return $null }
  return [string]$prop.Value
}

function Get-ScopedTempArtifactPath([string]$SpecPath, [string]$FileName){
  $legacyPath = Join-Path ([IO.Path]::GetTempPath()) $FileName
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
  $baseName = [IO.Path]::GetFileNameWithoutExtension($FileName)
  $extension = [IO.Path]::GetExtension($FileName)
  return Join-Path ([IO.Path]::GetTempPath()) ("{0}_{1}{2}" -f $baseName, $specId, $extension)
}

function Get-AccessTokenForResource([string]$resourceUrl){
  try {
    $token = az account get-access-token --resource $resourceUrl --query accessToken -o tsv 2>$null
    if($LASTEXITCODE -eq 0 -and -not [string]::IsNullOrWhiteSpace($token)){ return $token.Trim() }
  } catch {
  }
  try {
    return (Get-AzAccessToken -ResourceUrl $resourceUrl).Token
  } catch {
    return $null
  }
}

function Get-PurviewToken {
  $token = Get-AccessTokenForResource -resourceUrl 'https://purview.azure.net'
  if([string]::IsNullOrWhiteSpace($token)){
    $token = Get-AccessTokenForResource -resourceUrl 'https://purview.azure.com'
  }
  return $token
}

function Get-PowerBiToken {
  Get-AccessTokenForResource -resourceUrl 'https://analysis.windows.net/powerbi/api'
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
    $groups = Invoke-RestMethod -Method Get -Uri 'https://api.powerbi.com/v1.0/myorg/groups?%24top=5000' -Headers $headers
    $matches = @($groups.value | Where-Object { $_.name -eq $workspaceName })
    if($matches.Count -eq 1){ return [string]$matches[0].id }
  } catch {
  }
  return $null
}

function Resolve-CollectionIdFromMap([string]$workspaceName){
  if([string]::IsNullOrWhiteSpace($workspaceName)){ return $null }
  $mapPath = Get-ScopedTempArtifactPath -SpecPath $SpecPath -FileName 'fabric_purview_collections.json'
  if(-not (Test-Path -Path $mapPath)){
    $legacyPath = Join-Path ([IO.Path]::GetTempPath()) 'fabric_purview_collections.json'
    if(Test-Path -Path $legacyPath){
      $mapPath = $legacyPath
    }
  }
  if(-not (Test-Path -Path $mapPath)){ return $null }
  try {
    $raw = Get-Content -Path $mapPath -Raw
    if([string]::IsNullOrWhiteSpace($raw)){ return $null }
    $data = $raw | ConvertFrom-Json
    $arr = if($data -is [System.Array]) { @($data) } else { @($data) }
    $match = @($arr | Where-Object {
      $w = Get-OptionalStringProperty -obj $_ -name 'workspaceName'
      -not [string]::IsNullOrWhiteSpace($w) -and $w -eq $workspaceName
    } | Select-Object -First 1)
    if($match.Count -gt 0){
      $cid = Get-OptionalStringProperty -obj $match[0] -name 'collectionId'
      if(-not [string]::IsNullOrWhiteSpace($cid)){ return $cid }
    }
  } catch {
  }
  return $null
}

function Get-DatasourceCollectionId([string]$endpoint, $headers, [string]$datasourceName){
  if([string]::IsNullOrWhiteSpace($datasourceName)){ return $null }
  $uri = "$endpoint/scan/datasources/${datasourceName}?api-version=2022-07-01-preview"
  try {
    $ds = Invoke-RestMethod -Method Get -Uri $uri -Headers $headers
    if(-not $ds){ return $null }
    $properties = $ds.PSObject.Properties['properties']
    if($null -eq $properties -or $null -eq $properties.Value){ return $null }
    $collection = $properties.Value.PSObject.Properties['collection']
    if($null -eq $collection -or $null -eq $collection.Value){ return $null }

    $referenceName = Get-OptionalStringProperty -obj $collection.Value -name 'referenceName'
    if(-not [string]::IsNullOrWhiteSpace($referenceName)){ return $referenceName }

    $name = Get-OptionalStringProperty -obj $collection.Value -name 'name'
    if(-not [string]::IsNullOrWhiteSpace($name)){ return $name }
  } catch {
  }
  return $null
}

function Resolve-DatasourceNameFromMap([string]$workspaceName, [string]$workspaceGuid){
  $mapPath = Get-ScopedTempArtifactPath -SpecPath $SpecPath -FileName 'fabric_datasource_map.json'
  if(-not (Test-Path -Path $mapPath)){
    $legacyPath = Join-Path ([IO.Path]::GetTempPath()) 'fabric_datasource_map.json'
    if(Test-Path -Path $legacyPath){
      $mapPath = $legacyPath
    }
  }
  if(-not (Test-Path -Path $mapPath)){ return $null }
  try {
    $raw = Get-Content -Path $mapPath -Raw
    if([string]::IsNullOrWhiteSpace($raw)){ return $null }
    $data = $raw | ConvertFrom-Json
    $arr = if($data -is [System.Array]) { @($data) } else { @($data) }

    $byGuid = @($arr | Where-Object {
      (Get-OptionalStringProperty -obj $_ -name 'workspaceId') -eq $workspaceGuid
    } | Select-Object -First 1)
    if($byGuid.Count -gt 0){
      $name = Get-OptionalStringProperty -obj $byGuid[0] -name 'datasourceName'
      if(-not [string]::IsNullOrWhiteSpace($name)){ return $name }
    }

    $byName = @($arr | Where-Object {
      (Get-OptionalStringProperty -obj $_ -name 'workspaceName') -eq $workspaceName
    } | Select-Object -First 1)
    if($byName.Count -gt 0){
      $name = Get-OptionalStringProperty -obj $byName[0] -name 'datasourceName'
      if(-not [string]::IsNullOrWhiteSpace($name)){ return $name }
    }
  } catch {
  }

  return $null
}

function Get-ExistingPowerBiDatasources([string]$endpoint, $headers){
  $uri = "$endpoint/scan/datasources?api-version=2022-07-01-preview"
  try {
    $result = Invoke-RestMethod -Method Get -Uri $uri -Headers $headers
    if($result -and $result.value){ return @($result.value) }
  } catch {
  }
  return @()
}

function Get-DatasourceWorkspaceId($datasource){
  if(-not $datasource){ return $null }
  $propertiesProp = $datasource.PSObject.Properties['properties']
  if($null -eq $propertiesProp -or $null -eq $propertiesProp.Value){ return $null }
  $workspaceProp = $propertiesProp.Value.PSObject.Properties['workspace']
  if($null -eq $workspaceProp -or $null -eq $workspaceProp.Value){ return $null }
  return Get-OptionalStringProperty -obj $workspaceProp.Value -name 'id'
}

function Resolve-FallbackDatasourceName([string]$endpoint, $headers, [string]$workspaceGuid){
  $all = Get-ExistingPowerBiDatasources -endpoint $endpoint -headers $headers
  if($all.Count -eq 0){ return $null }

  $byWorkspace = @($all | Where-Object {
    (Get-OptionalStringProperty -obj $_ -name 'kind') -eq 'PowerBI' -and
    (Get-DatasourceWorkspaceId -datasource $_) -eq $workspaceGuid
  } | Select-Object -First 1)
  if($byWorkspace.Count -gt 0){
    $name = Get-OptionalStringProperty -obj $byWorkspace[0] -name 'name'
    if(-not [string]::IsNullOrWhiteSpace($name)){ return $name }
  }

  return $null
}

function Get-DatasourceWorkspaceIdByName([string]$endpoint, $headers, [string]$datasourceName){
  if([string]::IsNullOrWhiteSpace($datasourceName)){ return $null }
  $all = Get-ExistingPowerBiDatasources -endpoint $endpoint -headers $headers
  if($all.Count -eq 0){ return $null }

  $match = @($all | Where-Object {
    (Get-OptionalStringProperty -obj $_ -name 'name') -eq $datasourceName
  } | Select-Object -First 1)
  if($match.Count -eq 0){ return $null }

  return Get-DatasourceWorkspaceId -datasource $match[0]
}

function Get-ExistingScanByName([string]$endpoint, $headers, [string]$datasourceName, [string]$scanName){
  if([string]::IsNullOrWhiteSpace($datasourceName) -or [string]::IsNullOrWhiteSpace($scanName)){ return $null }
  $uri = "$endpoint/scan/datasources/${datasourceName}/scans?api-version=2022-07-01-preview"
  try {
    $result = Invoke-RestMethod -Method Get -Uri $uri -Headers $headers
    if($result -and $result.value){
      $match = @($result.value | Where-Object {
        (Get-OptionalStringProperty -obj $_ -name 'name') -eq $scanName
      } | Select-Object -First 1)
      if($match.Count -gt 0){ return $match[0] }
    }
  } catch {
  }
  return $null
}

function Test-DatasourceExists([string]$endpoint, $headers, [string]$datasourceName){
  if([string]::IsNullOrWhiteSpace($datasourceName)){ return $false }
  $uri = "$endpoint/scan/datasources/${datasourceName}?api-version=2022-07-01-preview"
  try {
    $ds = Invoke-RestMethod -Method Get -Uri $uri -Headers $headers
    return ($null -ne $ds)
  } catch {
    return $false
  }
}

function Get-HttpErrorDetails($exception){
  $statusCode = $null
  $body = $null

  if($null -eq $exception){
    return [pscustomobject]@{ StatusCode = $null; Body = $null }
  }

  $response = $exception.Response
  if($null -eq $response){
    return [pscustomobject]@{ StatusCode = $null; Body = $null }
  }

  try {
    if($response.PSObject.Properties['StatusCode']){
      $rawCode = $response.StatusCode
      if($rawCode -is [int]){ $statusCode = $rawCode }
      else { $statusCode = [int]$rawCode }
    }
  } catch {
  }

  try {
    if($response -is [System.Net.Http.HttpResponseMessage]){
      if($response.Content){
        $body = $response.Content.ReadAsStringAsync().GetAwaiter().GetResult()
      }
    } elseif($response.PSObject.Methods.Name -contains 'GetResponseStream'){
      $stream = $response.GetResponseStream()
      if($stream){
        $reader = New-Object System.IO.StreamReader($stream)
        $body = $reader.ReadToEnd()
      }
    }
  } catch {
  }

  return [pscustomobject]@{ StatusCode = $statusCode; Body = $body }
}

if(-not $spec.purviewAccount){
  Write-Host 'purviewAccount is not configured in spec. Skipping Fabric workspace scans.' -ForegroundColor Yellow
  exit 0
}

$fabric = $null
$fabricProp = $spec.PSObject.Properties['fabric']
if($fabricProp -and $fabricProp.Value){
  $fabric = $fabricProp.Value
}

$workspaces = @()
if($fabric){
  $workspacesProp = $fabric.PSObject.Properties['workspaces']
  if($workspacesProp -and $workspacesProp.Value){
    $workspaces = @($workspacesProp.Value)
  }
}
if($workspaces.Count -eq 0){
  Write-Host 'No fabric.workspaces entries found. Skipping Fabric workspace scans.' -ForegroundColor DarkGray
  exit 0
}

$scanAutomationMode = 'full'
if($fabric){
  $configuredMode = Get-OptionalStringProperty -obj $fabric -name 'scanAutomationMode'
  if(-not [string]::IsNullOrWhiteSpace($configuredMode)){
    $scanAutomationMode = $configuredMode.Trim().ToLowerInvariant()
  }
}
if($scanAutomationMode -notin @('full','runonly','disabled')){
  Write-Host "Unknown fabric.scanAutomationMode '$scanAutomationMode'. Falling back to 'full'." -ForegroundColor Yellow
  $scanAutomationMode = 'full'
}
if($scanAutomationMode -eq 'disabled'){
  Write-Host "Fabric scan automation mode is 'disabled'. Skipping Fabric scan trigger step." -ForegroundColor DarkGray
  exit 0
}

$hasAzCli = $null -ne (Get-Command az -ErrorAction SilentlyContinue)
$hasAzAccounts = $null -ne (Get-Command Get-AzAccessToken -ErrorAction SilentlyContinue)
if(-not $hasAzCli -and -not $hasAzAccounts){
  throw "Fabric workspace scans require Azure authentication tooling. Install Azure CLI or Az.Accounts and authenticate before running this script."
}

$purviewToken = Get-PurviewToken
if([string]::IsNullOrWhiteSpace($purviewToken)){
  Write-Host 'Failed to acquire Purview access token. Skipping scan trigger step.' -ForegroundColor Yellow
  exit 0
}

$endpoint = "https://$($spec.purviewAccount).purview.azure.com"
$headers = @{ Authorization = "Bearer $purviewToken"; 'Content-Type' = 'application/json' }

$datasourceNameFromEnv = $null
$dsEnvPath = Get-ScopedTempArtifactPath -SpecPath $SpecPath -FileName 'fabric_datasource.env'
if(-not (Test-Path $dsEnvPath)){
  $legacyEnvPath = Join-Path ([IO.Path]::GetTempPath()) 'fabric_datasource.env'
  if(Test-Path $legacyEnvPath){
    $dsEnvPath = $legacyEnvPath
  }
}
if(Test-Path $dsEnvPath){
  Get-Content $dsEnvPath | ForEach-Object {
    if($_ -match '^FABRIC_DATASOURCE_NAME=(.*)$'){
      $candidate = $Matches[1].Trim()
      if(-not [string]::IsNullOrWhiteSpace($candidate) -and -not $datasourceNameFromEnv){
        $datasourceNameFromEnv = $candidate
      }
    }
  }
}

foreach($workspace in $workspaces){
  $workspaceName = Get-OptionalStringProperty -obj $workspace -name 'name'
  $workspaceGuid = Resolve-WorkspaceGuid -workspace $workspace -workspaceName $workspaceName
  if([string]::IsNullOrWhiteSpace($workspaceName) -and $workspaceGuid){ $workspaceName = $workspaceGuid }

  if([string]::IsNullOrWhiteSpace($workspaceGuid)){
    Write-Host "Skipping Fabric workspace scan entry; unable to resolve workspace ID for '$workspaceName'." -ForegroundColor Yellow
    continue
  }

  $scanName = Get-OptionalStringProperty -obj $workspace -name 'scanName'
  if(-not [string]::IsNullOrWhiteSpace($scanName) -and -not [string]::IsNullOrWhiteSpace($workspaceName)){
    $scanName = $scanName.Replace('[name]', $workspaceName)
  }
  if([string]::IsNullOrWhiteSpace($scanName)){ $scanName = "scan-workspace-$workspaceGuid" }

  $datasourceName = Get-OptionalStringProperty -obj $workspace -name 'dataSourceName'
  if([string]::IsNullOrWhiteSpace($datasourceName)){
    $mappedDatasourceName = Resolve-DatasourceNameFromMap -workspaceName $workspaceName -workspaceGuid $workspaceGuid
    if(-not [string]::IsNullOrWhiteSpace($mappedDatasourceName)){
      $datasourceName = $mappedDatasourceName
    }
  }
  if([string]::IsNullOrWhiteSpace($datasourceName) -and -not [string]::IsNullOrWhiteSpace($datasourceNameFromEnv)){
    $envWorkspaceGuid = $null
    if($datasourceNameFromEnv -match '^Fabric-Workspace-([0-9a-fA-F-]{36})$'){
      $envWorkspaceGuid = $Matches[1]
    }

    if(-not [string]::IsNullOrWhiteSpace($envWorkspaceGuid) -and $envWorkspaceGuid -eq $workspaceGuid){
      $datasourceName = $datasourceNameFromEnv
    } elseif($workspaces.Count -eq 1 -and [string]::IsNullOrWhiteSpace($envWorkspaceGuid)){
      $datasourceName = $datasourceNameFromEnv
    } else {
      Write-Host "Ignoring shared FABRIC_DATASOURCE_NAME '$datasourceNameFromEnv' for workspace '$workspaceName' because it targets a different workspace." -ForegroundColor DarkGray
    }
  }
  if([string]::IsNullOrWhiteSpace($datasourceName)){ $datasourceName = "Fabric-Workspace-$workspaceGuid" }

  if(-not (Test-DatasourceExists -endpoint $endpoint -headers $headers -datasourceName $datasourceName)){
    $fallbackDatasourceName = Resolve-FallbackDatasourceName -endpoint $endpoint -headers $headers -workspaceGuid $workspaceGuid
    if(-not [string]::IsNullOrWhiteSpace($fallbackDatasourceName) -and $fallbackDatasourceName -ne $datasourceName){
      Write-Host "Datasource '$datasourceName' was not found for workspace '$workspaceName'. Falling back to existing datasource '$fallbackDatasourceName'." -ForegroundColor Yellow
      $datasourceName = $fallbackDatasourceName
    }
  }

  if(-not (Test-DatasourceExists -endpoint $endpoint -headers $headers -datasourceName $datasourceName)){
    Write-Host "No usable Purview PowerBI datasource found for workspace '$workspaceName'. Skipping scan trigger for this workspace." -ForegroundColor Yellow
    continue
  }

  $datasourceWorkspaceId = Get-DatasourceWorkspaceIdByName -endpoint $endpoint -headers $headers -datasourceName $datasourceName
  if(-not [string]::IsNullOrWhiteSpace($datasourceWorkspaceId) -and $datasourceWorkspaceId -ne $workspaceGuid){
    Write-Host "Datasource '$datasourceName' is bound to workspace '$datasourceWorkspaceId' but expected '$workspaceGuid'. Skipping scan trigger for '$workspaceName'." -ForegroundColor Yellow
    continue
  }

  $collectionId = Resolve-CollectionIdFromMap -workspaceName $workspaceName
  $existingScan = Get-ExistingScanByName -endpoint $endpoint -headers $headers -datasourceName $datasourceName -scanName $scanName
  $skipCreateUpdate = $false

  if($scanAutomationMode -eq 'runonly'){
    if($existingScan){
      $skipCreateUpdate = $true
      Write-Host "fabric.scanAutomationMode=runOnly; preserving existing scan definition '$scanName' and triggering run only." -ForegroundColor DarkGray
    } else {
      Write-Host "fabric.scanAutomationMode=runOnly but scan '$scanName' does not exist. Create it once in Purview portal, then rerun automation." -ForegroundColor Yellow
      continue
    }
  }

  if([string]::IsNullOrWhiteSpace($datasourceWorkspaceId)){
    if($existingScan){
      $existingCollectionId = $null
      if($existingScan.properties -and $existingScan.properties.collection){
        $existingCollectionId = Get-OptionalStringProperty -obj $existingScan.properties.collection -name 'referenceName'
      }
      if(-not [string]::IsNullOrWhiteSpace($collectionId) -and $existingCollectionId -ne $collectionId){
        Write-Host "Existing scan '$scanName' on shared datasource '$datasourceName' is mapped to collection '$existingCollectionId' but expected '$collectionId'. Skipping run for '$workspaceName'." -ForegroundColor Yellow
        continue
      }
      if(-not $skipCreateUpdate){
        $skipCreateUpdate = $true
        Write-Host "Datasource '$datasourceName' is shared (no workspace binding). Preserving existing scan definition '$scanName' to avoid losing scoped settings; triggering run only." -ForegroundColor Yellow
      }
    } else {
      Write-Host "Datasource '$datasourceName' is shared and scan '$scanName' does not exist. Skipping automatic creation to avoid unscoped tenant-wide scans; create scoped scan once in portal." -ForegroundColor Yellow
      continue
    }
  }

  $payload = [ordered]@{
    properties = [ordered]@{
      includePersonalWorkspaces = $false
      scanScope = [ordered]@{
        type = 'PowerBIScanScope'
        workspaces = @(
          [ordered]@{ id = $workspaceGuid }
        )
      }
    }
    kind = 'PowerBIMsi'
  }

  if(-not [string]::IsNullOrWhiteSpace($collectionId)){
    Write-Host "Collection map resolved '$collectionId' for workspace '$workspaceName'; scan will use datasource-bound collection." -ForegroundColor DarkGray
  }

  $datasourceCollectionId = Get-DatasourceCollectionId -endpoint $endpoint -headers $headers -datasourceName $datasourceName
  if(-not [string]::IsNullOrWhiteSpace($collectionId)){
    $payload.properties.collection = [ordered]@{ referenceName = $collectionId; type = 'CollectionReference' }
    Write-Host "Using mapped workspace collection '$collectionId' for workspace '$workspaceName'." -ForegroundColor DarkGray
  } elseif(-not [string]::IsNullOrWhiteSpace($datasourceCollectionId)){
    $payload.properties.collection = [ordered]@{ referenceName = $datasourceCollectionId; type = 'CollectionReference' }
    Write-Host "Using datasource-bound collection '$datasourceCollectionId' for workspace '$workspaceName'." -ForegroundColor DarkGray
  }

  $createUrl = "$endpoint/scan/datasources/${datasourceName}/scans/${scanName}?api-version=2022-07-01-preview"
  $runUrl = "$endpoint/scan/datasources/${datasourceName}/scans/${scanName}/run?api-version=2022-07-01-preview"
  $bodyJson = $payload | ConvertTo-Json -Depth 12

  if(-not $skipCreateUpdate){
    $createCode = $null
    $createBody = $null
    try {
      $resp = Invoke-WebRequest -Uri $createUrl -Method Put -Headers $headers -Body $bodyJson
      $createCode = [int]$resp.StatusCode
      $createBody = $resp.Content
    } catch {
      $details = Get-HttpErrorDetails -exception $_.Exception
      $createCode = $details.StatusCode
      $createBody = $details.Body
      if($null -eq $createCode){
        Write-Host "Failed to create/update Fabric scan '$scanName' for '$workspaceName': $($_.Exception.Message)" -ForegroundColor Yellow
        continue
      }
    }

    if($createCode -lt 200 -or $createCode -ge 300){
      Write-Host "Failed to create/update Fabric scan '$scanName' for '$workspaceName' (HTTP $createCode)." -ForegroundColor Yellow
      if($createBody){ Write-Host $createBody -ForegroundColor Yellow }
      continue
    }
  }

  $runCode = $null
  $runBody = $null
  try {
    $runResp = Invoke-WebRequest -Uri $runUrl -Method Post -Headers $headers -Body '{}'
    $runCode = [int]$runResp.StatusCode
    $runBody = $runResp.Content
  } catch {
    $details = Get-HttpErrorDetails -exception $_.Exception
    $runCode = $details.StatusCode
    $runBody = $details.Body
    if($null -eq $runCode){
      Write-Host "Failed to run Fabric scan '$scanName' for '$workspaceName': $($_.Exception.Message)" -ForegroundColor Yellow
      continue
    }
  }

  if($runCode -ne 200 -and $runCode -ne 202){
    if($runBody -match 'ScanHistory_ActiveRunExist' -or $runBody -match 'already.*running'){
      Write-Host "Fabric scan '$scanName' for '$workspaceName' is already active." -ForegroundColor DarkGray
      continue
    }
    Write-Host "Failed to trigger Fabric scan '$scanName' for '$workspaceName' (HTTP $runCode)." -ForegroundColor Yellow
    if($runBody){ Write-Host $runBody -ForegroundColor Yellow }
    continue
  }

  Write-Host "Triggered Fabric workspace scan '$scanName' for '$workspaceName'" -ForegroundColor Green
}