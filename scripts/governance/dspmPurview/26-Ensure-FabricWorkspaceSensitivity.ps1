# Filename: 26-Ensure-FabricWorkspaceSensitivity.ps1
param([Parameter(Mandatory=$true)][string]$SpecPath)

$ErrorActionPreference = 'Stop'
$spec = Get-Content $SpecPath -Raw | ConvertFrom-Json

function Get-OptionalStringProperty($obj, [string]$name){
	if(-not $obj){ return $null }
	$prop = $obj.PSObject.Properties[$name]
	if($null -eq $prop){ return $null }
	if($null -eq $prop.Value){ return $null }
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

function Resolve-WorkspaceGuidFromSpec($workspace){
	$workspaceId = Get-OptionalStringProperty -obj $workspace -name 'workspaceId'
	$workspaceUrl = Get-OptionalStringProperty -obj $workspace -name 'workspaceUrl'
	$resourceId = Get-OptionalStringProperty -obj $workspace -name 'resourceId'

	if($workspaceId -and $workspaceId -match '^[0-9a-fA-F-]{36}$'){ return $workspaceId }
	foreach($candidate in @($workspaceUrl, $resourceId)){
		if($candidate -and $candidate -match '/groups/([0-9a-fA-F-]{36})'){ return $Matches[1] }
		if($candidate -and $candidate -match '^[0-9a-fA-F-]{36}$'){ return $candidate }
	}

	return $null
}

$workspaces = @()
$fabricProp = $spec.PSObject.Properties['fabric']
if($fabricProp -and $fabricProp.Value){
	$fabricObj = $fabricProp.Value
	$workspacesProp = $fabricObj.PSObject.Properties['workspaces']
	if($workspacesProp -and $workspacesProp.Value){
		$workspaces = @($workspacesProp.Value)
	}
}

if($workspaces.Count -eq 0){
	Write-Host "No fabric.workspaces entries found. Skipping Fabric sensitivity step." -ForegroundColor DarkGray
	exit 0
}

$lakehouseTargets = @()
$seenLakehouseTargets = @{}
foreach($workspace in $workspaces){
	$workspaceName = Get-OptionalStringProperty -obj $workspace -name 'name'
	$workspaceId = Resolve-WorkspaceGuidFromSpec -workspace $workspace
	$lakehousesProp = $workspace.PSObject.Properties['lakehouses']
	if($null -eq $lakehousesProp -or $null -eq $lakehousesProp.Value){ continue }
	foreach($lakehouse in @($lakehousesProp.Value)){
		$lakehouseName = Get-OptionalStringProperty -obj $lakehouse -name 'name'
		$labelName = Get-OptionalStringProperty -obj $lakehouse -name 'sensitivityLabel'
		if([string]::IsNullOrWhiteSpace($lakehouseName) -or [string]::IsNullOrWhiteSpace($labelName)){ continue }

		$workspaceKey = if(-not [string]::IsNullOrWhiteSpace($workspaceId)) { $workspaceId } else { $workspaceName }
		$targetKey = ("{0}|{1}" -f $workspaceKey, $lakehouseName).ToLowerInvariant()
		if($seenLakehouseTargets.ContainsKey($targetKey)){
			$workspaceDisplay = if(-not [string]::IsNullOrWhiteSpace($workspaceName)) { $workspaceName } else { $workspaceId }
			Write-Host "Duplicate Fabric lakehouse target for workspace '$workspaceDisplay' and lakehouse '$lakehouseName' found in spec. Ignoring duplicate entry and continuing." -ForegroundColor DarkGray
			continue
		}
		$seenLakehouseTargets[$targetKey] = $true

		$lakehouseTargets += [pscustomobject]@{
			workspaceName = $workspaceName
			workspaceId = $workspaceId
			lakehouseName = $lakehouseName
			sensitivityLabel = $labelName
		}
	}
}

if($lakehouseTargets.Count -eq 0){
	Write-Host "No Fabric lakehouse sensitivity labels configured. Skipping." -ForegroundColor DarkGray
	exit 0
}

$requestedLabels = @($lakehouseTargets | Select-Object -ExpandProperty sensitivityLabel -Unique)

if(-not (Get-Command Get-Label -ErrorAction SilentlyContinue)){
	throw "Fabric lakehouse sensitivity labels are configured, but Get-Label is unavailable. Connect to Exchange Online/Security & Compliance first (run with -ConnectM365 and valid M365 auth parameters)."
}

function Get-LabelStringProperty($obj, [string]$name){
	if(-not $obj){ return $null }
	$prop = $obj.PSObject.Properties[$name]
	if($null -eq $prop -or $null -eq $prop.Value){ return $null }
	return [string]$prop.Value
}

function Resolve-LabelFromSpecValue([string]$labelSpecValue, $allLabels){
	if([string]::IsNullOrWhiteSpace($labelSpecValue)){
		return [pscustomobject]@{ IsResolved = $false; Label = $null; Message = "Empty sensitivity label value." }
	}

	$trimmed = $labelSpecValue.Trim()
	$exactMatches = @($allLabels | Where-Object {
		(Get-LabelStringProperty $_ 'Name') -eq $trimmed -or
		(Get-LabelStringProperty $_ 'ImmutableId') -eq $trimmed -or
		(Get-LabelStringProperty $_ 'DisplayName') -eq $trimmed
	})
	if($exactMatches.Count -eq 1){
		return [pscustomobject]@{ IsResolved = $true; Label = $exactMatches[0]; Message = $null }
	}
	if($exactMatches.Count -gt 1){
		$topLevel = @($exactMatches | Where-Object { [string]::IsNullOrWhiteSpace((Get-LabelStringProperty $_ 'ParentId')) })
		if($topLevel.Count -eq 1){
			return [pscustomobject]@{ IsResolved = $true; Label = $topLevel[0]; Message = $null }
		}
	}

	$pathSegments = @($trimmed -split '\\', 2)
	if($pathSegments.Count -eq 2){
		$parentDisplay = $pathSegments[0].Trim()
		$childDisplay = $pathSegments[1].Trim()
		if(-not [string]::IsNullOrWhiteSpace($parentDisplay) -and -not [string]::IsNullOrWhiteSpace($childDisplay)){
			$parentCandidates = @($allLabels | Where-Object {
				(Get-LabelStringProperty $_ 'DisplayName') -eq $parentDisplay -and [string]::IsNullOrWhiteSpace((Get-LabelStringProperty $_ 'ParentId'))
			})
			foreach($parent in $parentCandidates){
				$parentImmutableId = Get-LabelStringProperty $parent 'ImmutableId'
				$parentGuid = Get-LabelStringProperty $parent 'Guid'
				$parentName = Get-LabelStringProperty $parent 'Name'
				$childMatches = @($allLabels | Where-Object {
					$childParentId = Get-LabelStringProperty $_ 'ParentId'
					(Get-LabelStringProperty $_ 'DisplayName') -eq $childDisplay -and (
						$childParentId -eq $parentImmutableId -or
						$childParentId -eq $parentGuid -or
						$childParentId -eq $parentName
					)
				})
				if($childMatches.Count -eq 1){
					return [pscustomobject]@{ IsResolved = $true; Label = $childMatches[0]; Message = $null }
				}
			}
		}
	}

	return [pscustomobject]@{ IsResolved = $false; Label = $null; Message = "No unique label match found for '$labelSpecValue'." }
}

$allLabels = @()
try {
	$allLabels = @(Get-Label -ErrorAction Stop)
} catch {
	throw "Fabric lakehouse sensitivity labels are configured, but label lookup failed in Exchange Online/Security & Compliance session: $($_.Exception.Message)"
}

$labelLookup = @{}
$resolvedIdentityLookup = @{}
$missingLabels = @()
foreach($labelName in $requestedLabels){
	$resolution = Resolve-LabelFromSpecValue -labelSpecValue $labelName -allLabels $allLabels
	if($resolution.IsResolved){
		$labelLookup[$labelName] = $true
		$resolvedIdentity = Get-LabelStringProperty -obj $resolution.Label -name 'ImmutableId'
		if([string]::IsNullOrWhiteSpace($resolvedIdentity)){
			$resolvedIdentity = Get-LabelStringProperty -obj $resolution.Label -name 'Name'
		}
		$resolvedIdentityLookup[$labelName] = $resolvedIdentity
		Write-Host "Fabric sensitivity label resolved: '$labelName' -> '$resolvedIdentity'" -ForegroundColor Green
	} else {
		$labelLookup[$labelName] = $false
		$missingLabels += $labelName
		Write-Host "Fabric sensitivity label '$labelName' not found. $($resolution.Message)" -ForegroundColor Yellow
	}
}

if($missingLabels.Count -gt 0){
	Write-Host "" 
	Write-Host "========================================" -ForegroundColor Yellow
	Write-Host "WARNING: Missing Fabric sensitivity labels" -ForegroundColor Yellow
	Write-Host "The following label names were not found:" -ForegroundColor Yellow
	foreach($missing in ($missingLabels | Sort-Object -Unique)){
		Write-Host "  - $missing" -ForegroundColor Yellow
	}
	Write-Host "Update spec.local.json to use exact label display names, then rerun." -ForegroundColor Yellow
	Write-Host "========================================" -ForegroundColor Yellow
	Write-Host "" 
}

foreach($target in $lakehouseTargets){
	$status = if($labelLookup[$target.sensitivityLabel]) { 'VALID' } else { 'MISSING' }
	$resolvedIdentity = if($resolvedIdentityLookup.ContainsKey($target.sensitivityLabel)) { $resolvedIdentityLookup[$target.sensitivityLabel] } else { '' }
	$target | Add-Member -NotePropertyName validationStatus -NotePropertyValue $status -Force
	$target | Add-Member -NotePropertyName resolvedLabelId -NotePropertyValue $resolvedIdentity -Force
	if($status -eq 'VALID' -and -not [string]::IsNullOrWhiteSpace($resolvedIdentity)){
		Write-Host "Lakehouse label target: workspace='$($target.workspaceName)' lakehouse='$($target.lakehouseName)' label='$($target.sensitivityLabel)' resolvedIdentity='$resolvedIdentity' status=$status" -ForegroundColor DarkGray
	} else {
		Write-Host "Lakehouse label target: workspace='$($target.workspaceName)' lakehouse='$($target.lakehouseName)' label='$($target.sensitivityLabel)' status=$status" -ForegroundColor DarkGray
	}
}

$outPath = Get-FabricLakehouseLabelTargetPath -SpecPath $SpecPath
$lakehouseTargets | ConvertTo-Json -Depth 10 | Set-Content -Path $outPath -Encoding UTF8
Write-Host "Saved Fabric lakehouse label targets to $outPath" -ForegroundColor DarkGray
