function Test-AzContextMatch {
  param(
    [object]$Context,
    [string]$TenantId,
    [string]$SubscriptionId
  )
  return ($Context -and $Context.Tenant.Id -eq $TenantId -and $Context.Subscription.Id -eq $SubscriptionId)
}

function Try-ImportAzCliContext {
  param(
    [string]$TenantId,
    [string]$SubscriptionId
  )

  $azCli = Get-Command az -ErrorAction SilentlyContinue
  if(-not $azCli){ return $false }

  try {
    $accountJson = az account show --output json 2>$null
  } catch {
    return $false
  }

  if(-not $accountJson){ return $false }
  $account = $accountJson | ConvertFrom-Json
  $targetSubscription = if($SubscriptionId){ $SubscriptionId } else { $account.id }
  $targetTenant = if($TenantId){ $TenantId } else { $account.tenantId }

  try {
    $rmArgs = @('--resource','https://management.azure.com/','--output','json')
    if($SubscriptionId){ $rmArgs += @('--subscription',$SubscriptionId) }
    $rmTokenJson = az account get-access-token @rmArgs 2>$null
  } catch {
    $rmTokenJson = $null
  }
  if(-not $rmTokenJson){ return $false }
  $rmToken = $rmTokenJson | ConvertFrom-Json

  $graphToken = $null
  try {
    $graphArgs = @('--resource','https://graph.microsoft.com/','--output','json')
    if($SubscriptionId){ $graphArgs += @('--subscription',$SubscriptionId) }
    $graphTokenJson = az account get-access-token @graphArgs 2>$null
    if($graphTokenJson){ $graphToken = $graphTokenJson | ConvertFrom-Json }
  } catch {
    $graphToken = $null
  }

  $connectParams = @{
    AccessToken    = $rmToken.accessToken
    AccountId      = $account.user.name
    Tenant         = $targetTenant
    SubscriptionId = $targetSubscription
  }
  if($graphToken -and $graphToken.accessToken){
    $connectParams['GraphAccessToken'] = $graphToken.accessToken
  }

  try {
    Connect-AzAccount @connectParams | Out-Null
    Select-AzSubscription -SubscriptionId $targetSubscription | Out-Null
    return $true
  } catch {
    return $false
  }
}

function Ensure-AzContext {
  [CmdletBinding()]
  param(
    [Parameter(Mandatory=$true)][string]$TenantId,
    [Parameter(Mandatory=$true)][string]$SubscriptionId
  )
  Import-Module Az.Accounts -ErrorAction Stop
  $current = Get-AzContext -ErrorAction SilentlyContinue
  if(Test-AzContextMatch -Context $current -TenantId $TenantId -SubscriptionId $SubscriptionId){
    return
  }

  if(Try-ImportAzCliContext -TenantId $TenantId -SubscriptionId $SubscriptionId){
    $current = Get-AzContext -ErrorAction SilentlyContinue
    if(Test-AzContextMatch -Context $current -TenantId $TenantId -SubscriptionId $SubscriptionId){
      return
    }
  }

  Disable-AzContextAutosave -Scope Process -ErrorAction SilentlyContinue | Out-Null
  $connectParams = @{
    Tenant       = $TenantId
    Subscription = $SubscriptionId
  }

  $wamErrorPatterns = @(
    'BeforeBuildClient',
    'EnableLoginByWam'
  )

  try {
    Connect-AzAccount @connectParams | Out-Null
  } catch {
    $needsFallback = $false
    $cursor = $_.Exception
    while($cursor -and -not $needsFallback){
      foreach($pattern in $wamErrorPatterns){
        if($cursor.Message -match $pattern){
          $needsFallback = $true
          break
        }
      }
      $cursor = $cursor.InnerException
    }

    if(-not $needsFallback){ throw }
    $guidance = @()
    $guidance += "Default Azure login failed due to WAM (Workplace Account Manager) limitations."
    $guidance += "Device-code authentication is disabled for this accelerator."
    $guidance += "Run Connect-AzAccount -Tenant $TenantId -Subscription $SubscriptionId from an interactive shell with a browser,"
    $guidance += "or supply service principal credentials (Connect-AzAccount -ServicePrincipal ...)."
    $guidance += "Retry the script after establishing a valid context."
    throw ($guidance -join ' ')
  }
  Select-AzSubscription -SubscriptionId $SubscriptionId | Out-Null
}
