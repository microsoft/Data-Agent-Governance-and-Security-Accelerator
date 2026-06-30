# Filename: 21-Export-Audit.ps1
param([Parameter(Mandatory=$true)][string]$SpecPath)
$spec = Get-Content $SpecPath -Raw | ConvertFrom-Json
if(-not $spec.activityExport){ Write-Host "No activityExport block in spec. Skipping audit export." -ForegroundColor Yellow; exit 0 }
Import-Module Az.Accounts -ErrorAction Stop
$outputPath = $spec.activityExport.outputPath
if([string]::IsNullOrWhiteSpace($outputPath)){ Write-Host "activityExport.outputPath missing. Skipping audit export." -ForegroundColor Yellow; exit 0 }
$null = New-Item -ItemType Directory -Path $outputPath -Force
$token = (Get-AzAccessToken -ResourceUrl "https://manage.office.com").Token
$h = @{ Authorization = "Bearer $token" }
$base = "https://manage.office.com/api/v1.0/$($spec.tenantId)/activity/feed/subscriptions"
$content = Invoke-RestMethod -Method GET -Uri "$base/content?contentType=Audit.General" -Headers $h
$ts = (Get-Date).ToString('yyyyMMdd-HHmmss')
$jsonPath = Join-Path $outputPath "audit-$ts.json"
$csvPath  = Join-Path $outputPath "audit-$ts.csv"
$recs=@(); foreach($c in $content){ $page = Invoke-RestMethod -Method GET -Uri $c.contentUri -Headers $h -ErrorAction SilentlyContinue; if($page){ $recs += $page } }
$recs | ConvertTo-Json -Depth 8 | Out-File $jsonPath -Encoding UTF8
$recs | Select-Object CreationTime,RecordType,UserId,Operation,Workload,ResultStatus,ObjectId,ClientIP | Export-Csv -NoTypeInformation -Path $csvPath
Write-Host "Exported: $jsonPath; $csvPath" -ForegroundColor Green