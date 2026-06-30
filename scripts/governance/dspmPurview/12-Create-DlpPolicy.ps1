# Filename: 12-Create-DlpPolicy.ps1
param([Parameter(Mandatory=$true)][string]$SpecPath)
$spec = Get-Content $SpecPath -Raw | ConvertFrom-Json
Import-Module ExchangeOnlineManagement -ErrorAction Stop
Connect-IPPSSession | Out-Null
$dlpName = $spec.dlpPolicy.name; $mode = $spec.dlpPolicy.mode; $loc = $spec.dlpPolicy.locations
$modeMap = @{
  "Enforce" = "Enable"
  "Enable" = "Enable"
  "TestWithNotifications" = "TestWithNotifications"
  "TestWithoutNotifications" = "TestWithoutNotifications"
  "Disable" = "Disable"
}
$modeValue = if($modeMap.ContainsKey($mode)){ $modeMap[$mode] } else { $mode }
if(-not (Get-DlpCompliancePolicy -Identity $dlpName -ErrorAction SilentlyContinue)){
  New-DlpCompliancePolicy -Name $dlpName -Mode $modeValue -ExchangeLocation $loc.Exchange -SharePointLocation $loc.SharePoint -OneDriveLocation $loc.OneDrive -TeamsLocation $loc.Teams | Out-Null
  Write-Host "Created DLP policy $dlpName" -ForegroundColor Green
} else { Write-Host "DLP policy exists" -ForegroundColor DarkGray }
 $sitCache = @{}
function Resolve-SensitiveInfoType([string]$name){
  if($sitCache.ContainsKey($name)){ return $sitCache[$name] }
  $type = Get-DlpSensitiveInformationType -Identity $name -ErrorAction SilentlyContinue
  if(-not $type){
    $type = Get-DlpSensitiveInformationType | Where-Object Name -eq $name
  }
  if(-not $type){ throw "Sensitive information type '$name' not found in tenant." }
  $sitCache[$name] = $type
  return $type
}

function ConvertTo-ConfidenceLevel($value){
  if($null -eq $value){ return $null }
  if(($value -is [string]) -and [string]::IsNullOrWhiteSpace($value)){ return $null }
  $normalized = $value
  if($value -isnot [string]){ $normalized = [string][int]$value }
  $normalized = $normalized.Trim()
  switch -Regex ($normalized){
    '^(high)$'   { return 'High' }
    '^(medium)$' { return 'Medium' }
    '^(low)$'    { return 'Low' }
  }
  $intValue = 0
  if(-not [int]::TryParse($normalized,[ref]$intValue)){ return $null }
  if($intValue -ge 85){ return 'High' }
  elseif($intValue -ge 65){ return 'Medium' }
  return 'Low'
}
foreach($r in $spec.dlpPolicy.rules){
  $ruleName=$r.name
  $sit=@()
  foreach($t in $r.sensitiveInfoTypes){
    $type = Resolve-SensitiveInfoType -name $t.name
    $entry = @{ Name = $type.Name }
    $labelId = $null
    if($type.PSObject.Properties.Match('ImmutableId') -and $type.ImmutableId){ $labelId = $type.ImmutableId }
    elseif($type.PSObject.Properties.Match('Id') -and $type.Id){ $labelId = $type.Id }
    elseif($type.PSObject.Properties.Match('Identity') -and $type.Identity){ $labelId = $type.Identity }
    if($labelId){ $entry['Id'] = $labelId.ToString() }
    if($t.count){ $entry['minCount'] = [string][int]$t.count }
    $confidenceLevel = ConvertTo-ConfidenceLevel -value $t.confidence
    if($confidenceLevel){ $entry['confidencelevel'] = $confidenceLevel }
    $sit += $entry
  }
  if(-not (Get-DlpComplianceRule -Policy $dlpName -ErrorAction SilentlyContinue | Where-Object Name -eq $ruleName)){
    $params = @{
      Name = $ruleName
      Policy = $dlpName
      ContentContainsSensitiveInformation = $sit
      BlockAccess = [bool]$r.blockAccess
    }
    if($r.notifyUser){ Write-Host "NotifyUser requested for $ruleName. Configure notification settings manually until automated support ships." -ForegroundColor Yellow }
    New-DlpComplianceRule @params | Out-Null
    Write-Host "Created DLP rule $ruleName" -ForegroundColor Green
  } else { Write-Host "DLP rule exists: $ruleName" -ForegroundColor DarkGray }
}
