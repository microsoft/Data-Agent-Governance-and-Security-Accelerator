# Filename: 17-Export-ComplianceInventory.ps1
param([string]$OutDir = "./compliance_inventory")
Import-Module ExchangeOnlineManagement -ErrorAction Stop
Connect-IPPSSession | Out-Null
$null = New-Item -ItemType Directory -Path $OutDir -Force
Get-Label | ConvertTo-Json -Depth 10 | Out-File "$OutDir/labels.json" -Encoding UTF8
Get-DlpCompliancePolicy | ConvertTo-Json -Depth 10 | Out-File "$OutDir/dlp_policies.json" -Encoding UTF8
Get-DlpComplianceRule | ConvertTo-Json -Depth 10 | Out-File "$OutDir/dlp_rules.json" -Encoding UTF8
Get-RetentionCompliancePolicy | ConvertTo-Json -Depth 10 | Out-File "$OutDir/retention_policies.json" -Encoding UTF8
Get-RetentionComplianceRule | ConvertTo-Json -Depth 10 | Out-File "$OutDir/retention_rules.json" -Encoding UTF8
