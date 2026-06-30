# Filename: 18-Set-CompliancePermissions.ps1
param([Parameter(Mandatory=$true)][string]$RoleGroup,[Parameter(Mandatory=$true)][string]$UserUpn)
Import-Module ExchangeOnlineManagement -ErrorAction Stop
Connect-IPPSSession | Out-Null
if(Get-RoleGroupMember -Identity $RoleGroup -ErrorAction SilentlyContinue | Where-Object PrimarySmtpAddress -eq $UserUpn){
  Write-Host "$UserUpn already in $RoleGroup" -ForegroundColor DarkGray
} else {
  Add-RoleGroupMember -Identity $RoleGroup -Member $UserUpn
  Write-Host "Added $UserUpn to $RoleGroup" -ForegroundColor Green
}
