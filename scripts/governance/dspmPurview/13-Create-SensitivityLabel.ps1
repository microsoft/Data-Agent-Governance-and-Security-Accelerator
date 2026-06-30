# Filename: 13-Create-SensitivityLabel.ps1
param([Parameter(Mandatory=$true)][string]$SpecPath)
$spec = Get-Content $SpecPath -Raw | ConvertFrom-Json
Import-Module ExchangeOnlineManagement -ErrorAction Stop
Connect-IPPSSession | Out-Null

function Resolve-Label {
  param(
    [string]$Name,
    [string]$DisplayName
  )
  $candidates = @()
  if($Name){ $candidates += $Name }
  if($DisplayName -and -not ($candidates -contains $DisplayName)){ $candidates += $DisplayName }

  foreach($id in $candidates){
    $result = Get-Label -Identity $id -ErrorAction SilentlyContinue
    if($result){ return $result }
  }

  if($DisplayName){
    try{
      $allLabels = Get-Label -ErrorAction Stop
      return $allLabels | Where-Object { $_.DisplayName -eq $DisplayName } | Select-Object -First 1
    } catch {
      return $null
    }
  }
  return $null
}

foreach($l in $spec.labels){
  $displayName = if($l.displayName){ $l.displayName } else { $l.name }
  $tooltip = if($l.tooltip){ $l.tooltip } else { $displayName }
  $label = Resolve-Label -Name $l.name -DisplayName $displayName
  if($label){
    Write-Host "Label exists: $($label.DisplayName)" -ForegroundColor DarkGray
  } else {
    try{
      $label = New-Label -Name $l.name -DisplayName $displayName -Tooltip $tooltip -ContentType File,Email -EncryptionEnabled:([bool]$l.encryptionEnabled) -ErrorAction Stop
      Write-Host "Created label $($l.name)" -ForegroundColor Green
    } catch {
      $label = Resolve-Label -Name $l.name -DisplayName $displayName
      if($label){
        Write-Host "Label already exists, reusing $displayName" -ForegroundColor Yellow
      } else {
        throw
      }
    }
  }
  if(!$label){ throw "Unable to resolve label for $($l.name)" }
  $labelNameToPublish = $label.Name
  $pp=$l.publishPolicyName
  if(-not (Get-LabelPolicy -Identity $pp -ErrorAction SilentlyContinue)){
    # EXO can lag before new labels appear; retry a few times to avoid false negatives
    $retry = 0
    while($retry -lt 5){
      $labelCheck = Get-Label -Identity $labelNameToPublish -ErrorAction SilentlyContinue
      if($labelCheck){ break }
      Start-Sleep -Seconds 5
      $retry++
    }
    if(-not (Get-Label -Identity $labelNameToPublish -ErrorAction SilentlyContinue)){
      throw "Label $labelNameToPublish not available for publishing after waiting"
    }
    New-LabelPolicy -Name $pp -Labels $labelNameToPublish -ExchangeLocation $l.publishScopes.Exchange -SharePointLocation $l.publishScopes.SharePoint -OneDriveLocation $l.publishScopes.OneDrive | Out-Null
    Write-Host "Published label via $pp" -ForegroundColor Green
  } else { Write-Host "Publish policy exists: $pp" -ForegroundColor DarkGray }
}
