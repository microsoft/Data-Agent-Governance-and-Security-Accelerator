# Filename: 31-Foundry-ConfigureContentSafety.ps1
param([Parameter(Mandatory=$true)][string]$SpecPath)
$ErrorActionPreference='Stop'
$spec = Get-Content $SpecPath -Raw | ConvertFrom-Json
if(!$spec.foundry.contentSafety){ Write-Host "No foundry.contentSafety"; exit 0 }
$ensureContextPath = Join-Path $PSScriptRoot "..\..\common\Ensure-AzContext.ps1"
. $ensureContextPath
Import-Module Az.Accounts, Az.KeyVault, Az.Resources -ErrorAction Stop
Ensure-AzContext -TenantId $spec.tenantId -SubscriptionId $spec.subscriptionId
$cs = $spec.foundry.contentSafety
if([string]::IsNullOrWhiteSpace($cs.endpoint)){ Write-Host "foundry.contentSafety.endpoint not provided" -ForegroundColor Yellow; exit 0 }
$base = $cs.endpoint.TrimEnd('/')
$headers = @{}
$hasKey = $cs.apiKeySecretRef -and $cs.apiKeySecretRef.keyVaultResourceId -and $cs.apiKeySecretRef.secretName
if($hasKey){
  $kvRes = Get-AzResource -ResourceId $cs.apiKeySecretRef.keyVaultResourceId -ErrorAction SilentlyContinue
  if(-not $kvRes){ Write-Warning "Key Vault not found, skipping Content Safety key fetch: $($cs.apiKeySecretRef.keyVaultResourceId)"; exit 0 }
  $kvName = ($kvRes.ResourceId -split "/")[-1]
  $apiKey = (Get-AzKeyVaultSecret -VaultName $kvName -Name $cs.apiKeySecretRef.secretName -ErrorAction Stop).SecretValueText
  $headers["Ocp-Apim-Subscription-Key"] = $apiKey
  Write-Host "Using Content Safety API key from Key Vault '$kvName'" -ForegroundColor Cyan
}
else{
  try{
    $token = (Get-AzAccessToken -ResourceUrl "https://cognitiveservices.azure.com" -TenantId $spec.tenantId).Token
    $headers["Authorization"] = "Bearer $token"
    Write-Host "Using Entra ID access token for Content Safety (disableLocalAuth=true scenario)" -ForegroundColor Cyan
  }catch{
    throw "Unable to obtain Content Safety access token. Provide Key Vault secret or ensure identity has permissions. $_"
  }
}
if($cs.textBlocklists){
  foreach($bl in $cs.textBlocklists){
    $blocklistName = if($bl.name){ [string]$bl.name } elseif($bl.blocklistName){ [string]$bl.blocklistName } else { '' }
    if([string]::IsNullOrWhiteSpace($blocklistName)){
      Write-Host "Skipping blocklist entry with missing name/blocklistName." -ForegroundColor Yellow
      continue
    }

    $blockItems = @()
    if($bl.items){ $blockItems = @($bl.items) }
    elseif($bl.terms){ $blockItems = @($bl.terms) }

    $uri = "$base/contentsafety/text/blocklists/$blocklistName?api-version=2024-02-15-preview"
    try{ Invoke-RestMethod -Method PUT -Uri $uri -Headers $headers -ContentType "application/json" -Body (@{}|ConvertTo-Json) | Out-Null; Write-Host "Ensured blocklist: $blocklistName" -ForegroundColor Green }catch{ Write-Host "Blocklist ensure may exist: $($_.Exception.Message)" -ForegroundColor DarkGray }
    if($blockItems -and $blockItems.Count -gt 0){
      $itemsUri = "$base/contentsafety/text/blocklists/$blocklistName/:blockItems?api-version=2024-02-15-preview"
      $body = @{ blockItems=@() }; foreach($itm in $blockItems){ $body.blockItems += @{ description=$itm; text=$itm } }
      Invoke-RestMethod -Method POST -Uri $itemsUri -Headers $headers -ContentType "application/json" -Body ($body|ConvertTo-Json -Depth 10) | Out-Null
      Write-Host "Added $($blockItems.Count) items to '$blocklistName'" -ForegroundColor Green
    }
  }
}
if($cs.harmSeverityThreshold){ Write-Host "harmSeverityThreshold=$($cs.harmSeverityThreshold). Enforce in request filter." }