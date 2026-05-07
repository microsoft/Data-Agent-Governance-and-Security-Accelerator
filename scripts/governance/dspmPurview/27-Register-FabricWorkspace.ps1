# Filename: 27-Register-FabricWorkspace.ps1
param([Parameter(Mandatory=$true)][string]$SpecPath)

$ErrorActionPreference = 'Stop'
$spec = Get-Content $SpecPath -Raw | ConvertFrom-Json
$ensureContextPath = Join-Path $PSScriptRoot "..\..\common\Ensure-AzContext.ps1"
. $ensureContextPath
@('Az.Accounts','Az.Resources') | Where-Object { -not (Get-Module $_) } | ForEach-Object { Import-Module $_ -ErrorAction Stop }
Ensure-AzContext -TenantId $spec.tenantId -SubscriptionId $spec.subscriptionId

if(-not $spec.purviewAccount){
  Write-Host "purviewAccount is not configured in spec. Skipping Fabric workspace registration." -ForegroundColor Yellow
  exit 0
}

$workspaces = @()
if($spec.fabric -and $spec.fabric.workspaces){
  $workspaces = @($spec.fabric.workspaces)
}
if($workspaces.Count -eq 0){
  Write-Host "No fabric.workspaces entries found. Skipping Fabric workspace registration." -ForegroundColor DarkGray
  exit 0
}

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

$scanAutomationMode = 'full'
if($spec.fabric){
  $configuredMode = Get-OptionalStringProperty -obj $spec.fabric -name 'scanAutomationMode'
  if(-not [string]::IsNullOrWhiteSpace($configuredMode)){
    $scanAutomationMode = $configuredMode.Trim().ToLowerInvariant()
  }
}
if($scanAutomationMode -notin @('full','runonly','disabled')){
  Write-Host "Unknown fabric.scanAutomationMode '$scanAutomationMode'. Falling back to 'full'." -ForegroundColor Yellow
  $scanAutomationMode = 'full'
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

function Get-PvToken {
  $token = Get-AccessTokenForResource -resourceUrl "https://purview.azure.net"
  if([string]::IsNullOrWhiteSpace($token)){
    $token = Get-AccessTokenForResource -resourceUrl "https://purview.azure.com"
  }
  return $token
}
function Get-FabricToken { Get-AccessTokenForResource -resourceUrl "https://api.fabric.microsoft.com" }
function Get-PowerBiToken { Get-AccessTokenForResource -resourceUrl "https://analysis.windows.net/powerbi/api" }

function PvInvoke([string]$method,[string]$path,[object]$body){
  $uri = "https://$($spec.purviewAccount).purview.azure.com$path"
  $pvToken = Get-PvToken
  if([string]::IsNullOrWhiteSpace($pvToken)){
    throw "Failed to acquire Purview access token. Run az login and verify Purview data-plane access."
  }
  $headers = @{ Authorization = "Bearer $pvToken"; "Content-Type" = "application/json" }
  $payload = if($body){ $body | ConvertTo-Json -Depth 20 } else { $null }
  Invoke-RestMethod -Method $method -Uri $uri -Headers $headers -Body $payload
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
    $powerBiToken = Get-PowerBiToken
    if([string]::IsNullOrWhiteSpace($powerBiToken)){ return $null }
    $headers = @{ Authorization = "Bearer $powerBiToken" }
    $groups = Invoke-RestMethod -Method Get -Uri "https://api.powerbi.com/v1.0/myorg/groups?%24top=5000" -Headers $headers
    $matches = @($groups.value | Where-Object { $_.name -eq $workspaceName })
    if($matches.Count -eq 1){ return [string]$matches[0].id }
    if($matches.Count -gt 1){
      Write-Host "Multiple Fabric workspaces matched '$workspaceName'. Provide workspaceId/workspaceUrl." -ForegroundColor Yellow
    }
  } catch {
    Write-Host "Unable to resolve workspace ID from name '$workspaceName': $($_.Exception.Message)" -ForegroundColor Yellow
  }
  return $null
}

function Get-PurviewPrincipalId {
  try {
    $args = @('purview','account','show','--name',$spec.purviewAccount,'--query','identity.principalId','-o','tsv')
    if($spec.purviewResourceGroup){ $args += @('--resource-group', $spec.purviewResourceGroup) }
    if($spec.purviewSubscriptionId){ $args += @('--subscription', $spec.purviewSubscriptionId) }
    $principalId = az @args 2>$null
    if($principalId){ return $principalId.Trim() }
  } catch {
  }
  return $null
}

function Get-CollectionMap {
  $path = Get-ScopedTempArtifactPath -SpecPath $SpecPath -FileName 'fabric_purview_collections.json'
  if(-not (Test-Path -Path $path)){
    $legacyPath = Join-Path ([IO.Path]::GetTempPath()) 'fabric_purview_collections.json'
    if(Test-Path -Path $legacyPath){
      $path = $legacyPath
    }
  }
  if(-not (Test-Path -Path $path)){ return @() }
  try {
    $raw = Get-Content -Path $path -Raw
    if([string]::IsNullOrWhiteSpace($raw)){ return @() }
    $data = $raw | ConvertFrom-Json
    if($data -is [System.Array]){ return @($data) }
    return @($data)
  } catch {
    return @()
  }
}

function Get-MapStringProperty($obj, [string]$name){
  if(-not $obj){ return $null }
  $prop = $obj.PSObject.Properties[$name]
  if($null -eq $prop -or $null -eq $prop.Value){ return $null }
  return [string]$prop.Value
}

function Resolve-CollectionId([string]$workspaceName, $collectionMap){
  if([string]::IsNullOrWhiteSpace($workspaceName)){ return $null }
  $match = @(
    $collectionMap |
      Where-Object {
        $mappedWorkspaceName = Get-MapStringProperty -obj $_ -name 'workspaceName'
        -not [string]::IsNullOrWhiteSpace($mappedWorkspaceName) -and $mappedWorkspaceName -eq $workspaceName
      } |
      Select-Object -First 1
  )
  if($match.Count -gt 0){
    $cid = Get-MapStringProperty -obj $match[0] -name 'collectionId'
    if([string]::IsNullOrWhiteSpace($cid)){
      $cid = Get-MapStringProperty -obj $match[0] -name 'collectionName'
    }
    if(-not [string]::IsNullOrWhiteSpace($cid)){ return $cid }
  }
  return $workspaceName
}

function Get-ExistingPowerBiDatasource($existingDataSources, [string]$workspaceSpecificName){
  if(-not $existingDataSources -or -not $existingDataSources.value){ return $null }

  $workspaceSpecific = @($existingDataSources.value | Where-Object { (Get-OptionalStringProperty -obj $_ -name 'name') -eq $workspaceSpecificName })
  if($workspaceSpecific.Count -gt 0){
    return $workspaceSpecific[0]
  }

  return $null
}

function Get-AllDatasources {
  $all = @()
  $continuationToken = $null
  $iteration = 0

  do {
    $path = '/scan/datasources?api-version=2022-07-01-preview'
    if(-not [string]::IsNullOrWhiteSpace($continuationToken)){
      $encodedToken = [System.Uri]::EscapeDataString($continuationToken)
      $path = "$path&continuationToken=$encodedToken"
    }

    try {
      $page = PvInvoke 'GET' $path $null
    } catch {
      break
    }

    if($page -and $page.value){
      $all += @($page.value)
    }

    $continuationToken = Get-OptionalStringProperty -obj $page -name 'continuationToken'
    if([string]::IsNullOrWhiteSpace($continuationToken)){
      $nextLink = Get-OptionalStringProperty -obj $page -name 'nextLink'
      if(-not [string]::IsNullOrWhiteSpace($nextLink) -and $nextLink -match 'continuationToken=([^&]+)'){
        $continuationToken = [System.Uri]::UnescapeDataString($Matches[1])
      }
    }

    $iteration++
  } while(-not [string]::IsNullOrWhiteSpace($continuationToken) -and $iteration -lt 50)

  return @{ value = $all }
}

function Get-ExistingPowerBiDatasourceForWorkspace($existingDataSources, [string]$workspaceGuid){
  if(-not $existingDataSources -or -not $existingDataSources.value){ return $null }
  if([string]::IsNullOrWhiteSpace($workspaceGuid)){ return $null }

  $matches = @($existingDataSources.value | Where-Object {
    (Get-OptionalStringProperty -obj $_ -name 'kind') -eq 'PowerBI' -and
    (Get-DatasourceWorkspaceId -datasource $_) -eq $workspaceGuid
  })

  if($matches.Count -gt 0){
    return $matches[0]
  }

  return $null
}

function Get-DatasourceWorkspaceId($datasource){
  if(-not $datasource){ return $null }
  $properties = $datasource.PSObject.Properties['properties']
  if($null -eq $properties -or $null -eq $properties.Value){ return $null }
  $workspace = $properties.Value.PSObject.Properties['workspace']
  if($null -eq $workspace -or $null -eq $workspace.Value){ return $null }
  return Get-OptionalStringProperty -obj $workspace.Value -name 'id'
}

function Remove-DatasourceIfExists([string]$datasourceName){
  if([string]::IsNullOrWhiteSpace($datasourceName)){ return }
  try {
    PvInvoke 'DELETE' "/scan/datasources/${datasourceName}?api-version=2022-07-01-preview" $null | Out-Null
    Write-Host "Deleted mismatched datasource '$datasourceName' so it can be recreated with correct workspace binding." -ForegroundColor DarkGray
  } catch {
    Write-Host "Could not delete datasource '$datasourceName': $($_.Exception.Message)" -ForegroundColor Yellow
  }
}

function Test-DatasourceExists([string]$datasourceName){
  if([string]::IsNullOrWhiteSpace($datasourceName)){ return $false }
  try {
    $result = PvInvoke 'GET' "/scan/datasources/${datasourceName}?api-version=2022-07-01-preview" $null
    return ($null -ne $result)
  } catch {
    return $false
  }
}

function Register-WorkspaceDatasourceResult([string]$workspaceName, [string]$workspaceGuid, [string]$datasourceName, [ref]$registeredDataSourcesRef, [ref]$registeredDataSourceMapRef){
  if([string]::IsNullOrWhiteSpace($datasourceName)){ return }
  $registeredDataSourcesRef.Value += "FABRIC_DATASOURCE_NAME=$datasourceName"
  $registeredDataSourceMapRef.Value += [pscustomobject]@{ workspaceName = $workspaceName; workspaceId = $workspaceGuid; datasourceName = $datasourceName }
}

function Resolve-ExistingDatasourceNameForWorkspace([string]$workspaceGuid, [string]$preferredName){
  $all = Get-AllDatasources

  $workspaceMatch = Get-ExistingPowerBiDatasourceForWorkspace -existingDataSources $all -workspaceGuid $workspaceGuid
  if($workspaceMatch){
    $workspaceName = Get-OptionalStringProperty -obj $workspaceMatch -name 'name'
    if(-not [string]::IsNullOrWhiteSpace($workspaceName)){
      return $workspaceName
    }
  }

  if(-not [string]::IsNullOrWhiteSpace($preferredName)){
    $nameMatch = Get-ExistingPowerBiDatasource -existingDataSources $all -workspaceSpecificName $preferredName
    if($nameMatch){
      $name = Get-OptionalStringProperty -obj $nameMatch -name 'name'
      if(-not [string]::IsNullOrWhiteSpace($name)){
        return $name
      }
    }
  }

  return $null
}

function Resolve-ExistingDatasourceNameForWorkspaceWithRetry([string]$workspaceGuid, [string]$preferredName, [int]$attempts, [int]$sleepSeconds){
  if($attempts -lt 1){ $attempts = 1 }
  if($sleepSeconds -lt 0){ $sleepSeconds = 0 }

  for($i = 1; $i -le $attempts; $i++){
    $resolved = Resolve-ExistingDatasourceNameForWorkspace -workspaceGuid $workspaceGuid -preferredName $preferredName
    if(-not [string]::IsNullOrWhiteSpace($resolved)){
      return $resolved
    }

    if($i -lt $attempts -and $sleepSeconds -gt 0){
      Start-Sleep -Seconds $sleepSeconds
    }
  }

  return $null
}

function Resolve-SharedPowerBiDatasourceName {
  $all = Get-AllDatasources
  if(-not $all -or -not $all.value){ return $null }

  $pbi = @($all.value | Where-Object { (Get-OptionalStringProperty -obj $_ -name 'kind') -eq 'PowerBI' })
  if($pbi.Count -eq 1){
    return Get-OptionalStringProperty -obj $pbi[0] -name 'name'
  }

  return $null
}

$purviewPrincipalId = Get-PurviewPrincipalId
if(-not $purviewPrincipalId){
  Write-Host "Could not resolve Purview managed identity principalId. Scan may fail if workspace access is missing." -ForegroundColor Yellow
}

$collectionMap = Get-CollectionMap

$registeredDataSources = @()
$registeredDataSourceMap = @()

foreach($workspace in $workspaces){
  $workspaceName = Get-OptionalStringProperty -obj $workspace -name 'name'
  $workspaceGuid = Resolve-WorkspaceGuid -workspace $workspace -workspaceName $workspaceName
  if([string]::IsNullOrWhiteSpace($workspaceName) -and $workspaceGuid){
    $workspaceName = $workspaceGuid
  }

  if([string]::IsNullOrWhiteSpace($workspaceName) -or [string]::IsNullOrWhiteSpace($workspaceGuid)){
    Write-Host "Skipping Fabric workspace entry; provide workspace name and resolvable workspaceId/workspaceUrl." -ForegroundColor Yellow
    continue
  }

  if($scanAutomationMode -eq 'runonly'){
    $sharedName = Resolve-SharedPowerBiDatasourceName
    if(-not [string]::IsNullOrWhiteSpace($sharedName)){
      Write-Host "fabric.scanAutomationMode=runOnly; reusing shared datasource '$sharedName' for workspace '$workspaceName'." -ForegroundColor DarkGray
      Register-WorkspaceDatasourceResult -workspaceName $workspaceName -workspaceGuid $workspaceGuid -datasourceName $sharedName -registeredDataSourcesRef ([ref]$registeredDataSources) -registeredDataSourceMapRef ([ref]$registeredDataSourceMap)
      continue
    }
  }

  if($purviewPrincipalId){
    try {
      $fabricToken = Get-FabricToken
      if([string]::IsNullOrWhiteSpace($fabricToken)){
        throw "Failed to acquire Fabric access token."
      }
      $fabricHeaders = @{ Authorization = "Bearer $fabricToken"; "Content-Type" = "application/json" }
      $roleBody = @{ principal = @{ id = $purviewPrincipalId; type = 'ServicePrincipal' }; role = 'Contributor' } | ConvertTo-Json -Depth 5
      Invoke-RestMethod -Method Post -Uri "https://api.fabric.microsoft.com/v1/workspaces/$workspaceGuid/roleAssignments" -Headers $fabricHeaders -Body $roleBody | Out-Null
      Write-Host "Granted Purview MI Contributor on Fabric workspace $workspaceName" -ForegroundColor Green
    } catch {
      $msg = $_.Exception.Message
      if($msg -match 'already|409'){
        Write-Host "Purview MI already has access to workspace $workspaceName" -ForegroundColor DarkGray
      } else {
        Write-Host "Could not grant Purview MI workspace access for ${workspaceName}: $msg" -ForegroundColor Yellow
      }
    }
  }

  $datasourceName = Get-OptionalStringProperty -obj $workspace -name 'dataSourceName'
  if([string]::IsNullOrWhiteSpace($datasourceName)){
    $datasourceName = "Fabric-Workspace-$workspaceGuid"
  }

  $collectionId = Resolve-CollectionId -workspaceName $workspaceName -collectionMap $collectionMap
  if([string]::IsNullOrWhiteSpace([string]$collectionId)){
    $collectionId = $spec.purviewAccount
  }
  if([string]::IsNullOrWhiteSpace([string]$collectionId)){
    throw "Unable to resolve a Purview collection for Fabric datasource registration. Ensure purviewAccount is configured."
  }

  $path = "/scan/datasources/${datasourceName}?api-version=2022-07-01-preview"

  $existingDs = Get-AllDatasources

  $existingWorkspaceMatch = Get-ExistingPowerBiDatasourceForWorkspace -existingDataSources $existingDs -workspaceGuid $workspaceGuid
  if($existingWorkspaceMatch){
    $existingWorkspaceName = Get-OptionalStringProperty -obj $existingWorkspaceMatch -name 'name'
    if(-not [string]::IsNullOrWhiteSpace($existingWorkspaceName)){
      Write-Host "Found existing PowerBI datasource '$existingWorkspaceName' already bound to workspace '$workspaceName'. Reusing it." -ForegroundColor DarkGray
      Register-WorkspaceDatasourceResult -workspaceName $workspaceName -workspaceGuid $workspaceGuid -datasourceName $existingWorkspaceName -registeredDataSourcesRef ([ref]$registeredDataSources) -registeredDataSourceMapRef ([ref]$registeredDataSourceMap)
      continue
    }
  }

  $existingMatch = Get-ExistingPowerBiDatasource -existingDataSources $existingDs -workspaceSpecificName $datasourceName
  if($existingMatch){
    $existingName = Get-OptionalStringProperty -obj $existingMatch -name 'name'
    if(-not [string]::IsNullOrWhiteSpace($existingName)){
      $existingWorkspaceId = Get-DatasourceWorkspaceId -datasource $existingMatch
      if([string]::IsNullOrWhiteSpace($existingWorkspaceId)){
        Write-Host "Existing datasource '$existingName' has no workspace id metadata. It is not safe for scoped workspace scans; recreating as workspace-specific datasource." -ForegroundColor Yellow
        Remove-DatasourceIfExists -datasourceName $existingName
      }

      if(-not [string]::IsNullOrWhiteSpace($existingWorkspaceId) -and $existingWorkspaceId -eq $workspaceGuid){
        Write-Host "Found existing workspace-specific datasource '$existingName' for workspace '$workspaceName'." -ForegroundColor DarkGray
        Register-WorkspaceDatasourceResult -workspaceName $workspaceName -workspaceGuid $workspaceGuid -datasourceName $existingName -registeredDataSourcesRef ([ref]$registeredDataSources) -registeredDataSourceMapRef ([ref]$registeredDataSourceMap)
        continue
      }

      Write-Host "Existing datasource '$existingName' is bound to workspace '$existingWorkspaceId', expected '$workspaceGuid'. Recreating." -ForegroundColor Yellow
      Remove-DatasourceIfExists -datasourceName $existingName
    }
  }

  Write-Host "Using workspace-specific datasource '$datasourceName' for workspace '$workspaceName'." -ForegroundColor DarkGray

  try {
    $body = @{
      name = $datasourceName
      kind = 'PowerBI'
      properties = @{
        tenant = $spec.tenantId
        collection = @{ type = 'CollectionReference'; referenceName = $collectionId }
        workspace = @{ id = $workspaceGuid; name = $workspaceName }
        resourceGroup = $spec.resourceGroup
        subscriptionId = $spec.subscriptionId
      }
    }
    PvInvoke 'PUT' $path $body | Out-Null
    Write-Host "Registered Purview datasource $datasourceName for Fabric workspace $workspaceName" -ForegroundColor Green
    Register-WorkspaceDatasourceResult -workspaceName $workspaceName -workspaceGuid $workspaceGuid -datasourceName $datasourceName -registeredDataSourcesRef ([ref]$registeredDataSources) -registeredDataSourceMapRef ([ref]$registeredDataSourceMap)
  } catch {
    $firstError = $_.Exception.Message
    if($firstError -match '409|Conflict|already'){
      if(Test-DatasourceExists -datasourceName $datasourceName){
        Write-Host "Datasource '$datasourceName' already exists (409) for workspace '$workspaceName'. Reusing existing datasource." -ForegroundColor DarkGray
        Register-WorkspaceDatasourceResult -workspaceName $workspaceName -workspaceGuid $workspaceGuid -datasourceName $datasourceName -registeredDataSourcesRef ([ref]$registeredDataSources) -registeredDataSourceMapRef ([ref]$registeredDataSourceMap)
        continue
      }

      $resolvedName = Resolve-ExistingDatasourceNameForWorkspaceWithRetry -workspaceGuid $workspaceGuid -preferredName $datasourceName -attempts 4 -sleepSeconds 3
      if(-not [string]::IsNullOrWhiteSpace($resolvedName)){
        Write-Host "Datasource conflict for '$workspaceName' resolved by reusing existing datasource '$resolvedName'." -ForegroundColor DarkGray
        Register-WorkspaceDatasourceResult -workspaceName $workspaceName -workspaceGuid $workspaceGuid -datasourceName $resolvedName -registeredDataSourcesRef ([ref]$registeredDataSources) -registeredDataSourceMapRef ([ref]$registeredDataSourceMap)
        continue
      }

      Write-Host "Datasource '$datasourceName' returned 409 for workspace '$workspaceName' but was not found on lookup. Attempting clean recreate." -ForegroundColor Yellow
      Remove-DatasourceIfExists -datasourceName $datasourceName
      try {
        PvInvoke 'PUT' $path $body | Out-Null
        Write-Host "Registered Purview datasource $datasourceName for Fabric workspace $workspaceName after conflict recovery" -ForegroundColor Green
        Register-WorkspaceDatasourceResult -workspaceName $workspaceName -workspaceGuid $workspaceGuid -datasourceName $datasourceName -registeredDataSourcesRef ([ref]$registeredDataSources) -registeredDataSourceMapRef ([ref]$registeredDataSourceMap)
        continue
      } catch {
        $firstError = $_.Exception.Message
        $alternateDatasourceName = "$datasourceName-alt"
        $alternatePath = "/scan/datasources/${alternateDatasourceName}?api-version=2022-07-01-preview"
        $body.name = $alternateDatasourceName
        Write-Host "Retrying with alternate datasource name '$alternateDatasourceName' for workspace '$workspaceName'." -ForegroundColor Yellow
        try {
          PvInvoke 'PUT' $alternatePath $body | Out-Null
          Write-Host "Registered alternate Purview datasource $alternateDatasourceName for Fabric workspace $workspaceName" -ForegroundColor Green
          Register-WorkspaceDatasourceResult -workspaceName $workspaceName -workspaceGuid $workspaceGuid -datasourceName $alternateDatasourceName -registeredDataSourcesRef ([ref]$registeredDataSources) -registeredDataSourceMapRef ([ref]$registeredDataSourceMap)
          continue
        } catch {
          $firstError = $_.Exception.Message
          if($firstError -match '409|Conflict|already'){
            $resolvedName = Resolve-ExistingDatasourceNameForWorkspaceWithRetry -workspaceGuid $workspaceGuid -preferredName $alternateDatasourceName -attempts 4 -sleepSeconds 3
            if(-not [string]::IsNullOrWhiteSpace($resolvedName)){
              Write-Host "Alternate datasource conflict for '$workspaceName' resolved by reusing existing datasource '$resolvedName'." -ForegroundColor DarkGray
              Register-WorkspaceDatasourceResult -workspaceName $workspaceName -workspaceGuid $workspaceGuid -datasourceName $resolvedName -registeredDataSourcesRef ([ref]$registeredDataSources) -registeredDataSourceMapRef ([ref]$registeredDataSourceMap)
              continue
            }

          }
        }
      }
    }
    Write-Host "Workspace-specific datasource registration failed for ${workspaceName}: $firstError" -ForegroundColor Yellow
    Write-Host "Trying simplified datasource registration payload for ${workspaceName}..." -ForegroundColor Yellow

    try {
      $simpleBody = @{
        name = $datasourceName
        kind = 'PowerBI'
        properties = @{
          tenant = $spec.tenantId
          collection = @{ type = 'CollectionReference'; referenceName = $collectionId }
        }
      }
      PvInvoke 'PUT' $path $simpleBody | Out-Null
      Write-Host "Registered simplified Purview datasource $datasourceName for Fabric workspace $workspaceName" -ForegroundColor Green
      Register-WorkspaceDatasourceResult -workspaceName $workspaceName -workspaceGuid $workspaceGuid -datasourceName $datasourceName -registeredDataSourcesRef ([ref]$registeredDataSources) -registeredDataSourceMapRef ([ref]$registeredDataSourceMap)
    } catch {
      $fallbackError = $_.Exception.Message
      if($fallbackError -match '409|Conflict|already'){
        if(Test-DatasourceExists -datasourceName $datasourceName){
          Write-Host "Datasource '$datasourceName' already exists (409) after fallback for workspace '$workspaceName'. Reusing existing datasource." -ForegroundColor DarkGray
          Register-WorkspaceDatasourceResult -workspaceName $workspaceName -workspaceGuid $workspaceGuid -datasourceName $datasourceName -registeredDataSourcesRef ([ref]$registeredDataSources) -registeredDataSourceMapRef ([ref]$registeredDataSourceMap)
          continue
        }

        $resolvedName = Resolve-ExistingDatasourceNameForWorkspaceWithRetry -workspaceGuid $workspaceGuid -preferredName $datasourceName -attempts 4 -sleepSeconds 3
        if(-not [string]::IsNullOrWhiteSpace($resolvedName)){
          Write-Host "Fallback conflict for '$workspaceName' resolved by reusing existing datasource '$resolvedName'." -ForegroundColor DarkGray
          Register-WorkspaceDatasourceResult -workspaceName $workspaceName -workspaceGuid $workspaceGuid -datasourceName $resolvedName -registeredDataSourcesRef ([ref]$registeredDataSources) -registeredDataSourceMapRef ([ref]$registeredDataSourceMap)
          continue
        }

        Write-Host "Datasource '$datasourceName' still not found after fallback 409 for workspace '$workspaceName'." -ForegroundColor Yellow
      }

      Write-Host "Failed to register workspace-specific Fabric datasource '$datasourceName' for workspace '${workspaceName}' after fallback: $fallbackError" -ForegroundColor Yellow

      $sharedName = Resolve-SharedPowerBiDatasourceName
      if(-not [string]::IsNullOrWhiteSpace($sharedName)){
        Write-Host "Falling back to shared PowerBI datasource '$sharedName' for workspace '$workspaceName'. Workspace scoping must be preserved at scan-definition level." -ForegroundColor Yellow
        Register-WorkspaceDatasourceResult -workspaceName $workspaceName -workspaceGuid $workspaceGuid -datasourceName $sharedName -registeredDataSourcesRef ([ref]$registeredDataSources) -registeredDataSourceMapRef ([ref]$registeredDataSourceMap)
      }
    }
  }
}

if($registeredDataSources.Count -gt 0){
  $outPath = Get-ScopedTempArtifactPath -SpecPath $SpecPath -FileName 'fabric_datasource.env'
  Set-Content -Path $outPath -Value ($registeredDataSources -join [Environment]::NewLine) -Encoding UTF8
}

if($registeredDataSourceMap.Count -gt 0){
  $mapPath = Get-ScopedTempArtifactPath -SpecPath $SpecPath -FileName 'fabric_datasource_map.json'
  $registeredDataSourceMap | ConvertTo-Json -Depth 10 | Set-Content -Path $mapPath -Encoding UTF8
  Write-Host "Saved Fabric datasource map to $mapPath" -ForegroundColor DarkGray
}
