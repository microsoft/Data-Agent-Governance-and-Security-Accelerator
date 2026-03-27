# Filename: 14-Create-RetentionPolicy.ps1
param([Parameter(Mandatory=$true)][string]$SpecPath)
$spec = Get-Content $SpecPath -Raw | ConvertFrom-Json
Import-Module ExchangeOnlineManagement -ErrorAction Stop
Connect-IPPSSession | Out-Null

function Resolve-RetentionDurationDays($rule){
  if($null -ne $rule.durationDays -and -not [string]::IsNullOrWhiteSpace([string]$rule.durationDays)){
    return [int]$rule.durationDays
  }

  if($null -eq $rule.duration -or [string]::IsNullOrWhiteSpace([string]$rule.duration)){
    return $null
  }

  $duration = ([string]$rule.duration).Trim().ToUpperInvariant()
  if($duration -match '^P(\d+)D$'){
    return [int]$Matches[1]
  }
  if($duration -match '^P(\d+)Y$'){
    return ([int]$Matches[1]) * 365
  }
  if($duration -match '^P(\d+)M$'){
    return ([int]$Matches[1]) * 30
  }

  return $null
}

foreach($p in $spec.retentionPolicies){
  $rp = Get-RetentionCompliancePolicy -Identity $p.name -ErrorAction SilentlyContinue
  if(!$rp){
    New-RetentionCompliancePolicy -Name $p.name -Enabled $true -ExchangeLocation $p.locations.Exchange -SharePointLocation $p.locations.SharePoint -OneDriveLocation $p.locations.OneDrive -TeamsChatLocation $p.locations.TeamsChat -TeamsChannelLocation $p.locations.TeamsChannel | Out-Null
    Write-Host "Created retention policy $($p.name)" -ForegroundColor Green
  } else { Write-Host "Retention policy exists: $($p.name)" -ForegroundColor DarkGray }
    $policyRules = @($p.rules)
    for($ruleIndex = 0; $ruleIndex -lt $policyRules.Count; $ruleIndex++){
      $r = $policyRules[$ruleIndex]
      $ruleName = if($r.name){ [string]$r.name } else { "{0}-rule-{1}" -f $p.name, ($ruleIndex + 1) }
      $durationDays = Resolve-RetentionDurationDays -rule $r

      if([string]::IsNullOrWhiteSpace($ruleName) -or $null -eq $durationDays){
        Write-Host "Skipping retention rule in policy '$($p.name)' due to missing/invalid name or duration." -ForegroundColor Yellow
        continue
      }

      if(-not (Get-RetentionComplianceRule -Identity $ruleName -ErrorAction SilentlyContinue)){
        New-RetentionComplianceRule -Name $ruleName -Policy $p.name -RetentionDuration $durationDays -RetentionAction $r.action | Out-Null
        Write-Host "Created retention rule $ruleName" -ForegroundColor Green
      } else { Write-Host "Retention rule exists: $ruleName" -ForegroundColor DarkGray }
    }
  }
