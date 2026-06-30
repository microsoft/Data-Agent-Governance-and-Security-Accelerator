# Filename: 32-Foundry-GenerateBindings-Stub.ps1
param([string]$OutFile="./compliance_report.txt")
Import-Module ExchangeOnlineManagement -ErrorAction Stop
Connect-IPPSSession | Out-Null
$cfg = Get-AdminAuditLogConfig
$dlp = (Get-DlpCompliancePolicy | Measure-Object).Count
$lbl = (Get-Label | Measure-Object).Count
$ret = (Get-RetentionCompliancePolicy | Measure-Object).Count
"UnifiedAudit: $($cfg.UnifiedAuditLogIngestionEnabled)`nDLP Policies: $dlp`nLabels: $lbl`nRetention Policies: $ret" | Out-File $OutFile -Encoding UTF8
Write-Host "Wrote $OutFile" -ForegroundColor Green