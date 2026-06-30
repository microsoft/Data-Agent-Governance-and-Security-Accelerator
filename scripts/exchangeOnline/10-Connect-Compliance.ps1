# Filename: 10-Connect-Compliance.ps1
Import-Module ExchangeOnlineManagement -ErrorAction Stop
Connect-IPPSSession | Out-Null
Write-Host "Connected to Security & Compliance PowerShell."
