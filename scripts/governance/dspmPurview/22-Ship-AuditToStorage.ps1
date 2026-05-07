# Filename: 22-Ship-AuditToStorage.ps1
param([Parameter(Mandatory=$true)][string]$StorageAccount,[Parameter(Mandatory=$true)][string]$Container,[Parameter(Mandatory=$true)][string]$LocalPath)
@('Az.Accounts','Az.Storage') | Where-Object { -not (Get-Module $_) } | ForEach-Object { Import-Module $_ -ErrorAction Stop }
$ctx = (Get-AzStorageAccount -Name $StorageAccount -ErrorAction Stop).Context
Get-ChildItem -Path $LocalPath -File | ForEach-Object {
  Set-AzStorageBlobContent -File $_.FullName -Container $Container -Blob $_.Name -Context $ctx -Force | Out-Null
  Write-Host "Uploaded $($_.Name) to $StorageAccount/$Container" -ForegroundColor Green
}