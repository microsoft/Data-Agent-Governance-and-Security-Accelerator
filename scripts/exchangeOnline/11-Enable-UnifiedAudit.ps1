# Filename: 11-Enable-UnifiedAudit.ps1
param(
	[string]$UserPrincipalName
)

Import-Module ExchangeOnlineManagement -ErrorAction Stop

if(-not (Get-Command Set-AdminAuditLogConfig -ErrorAction SilentlyContinue)){
	$connectParams = @{ ShowBanner = $false; CommandName = @('Get-AdminAuditLogConfig','Set-AdminAuditLogConfig') }
	if($UserPrincipalName){ $connectParams.UserPrincipalName = $UserPrincipalName }
	Connect-ExchangeOnline @connectParams | Out-Null
}

Connect-IPPSSession | Out-Null

$cfg = Get-AdminAuditLogConfig
if(-not $cfg.UnifiedAuditLogIngestionEnabled){
	Set-AdminAuditLogConfig -UnifiedAuditLogIngestionEnabled $true
	Write-Host "Unified Audit enabled" -ForegroundColor Green
} else {
	Write-Host "Unified Audit already enabled" -ForegroundColor DarkGray
}