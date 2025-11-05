<#!
.SYNOPSIS
  Apply governance parameter values to an azd environment.

.DESCRIPTION
  Reads the governance.parameters.json file (or a supplied file) and writes
  each populated value into the specified azd environment via `azd env set`.
  Empty or placeholder values are skipped so that only intentional overrides
  are written.

.PARAMETER EnvironmentName
  Name of the azd environment to update (e.g. "dev").

.PARAMETER ParametersFile
  Path to the JSON parameter file. Defaults to governance.parameters.json in
  the same directory as this script.

.EXAMPLE
  pwsh ./apply-governance-parameters.ps1 -EnvironmentName dev

.EXAMPLE
  pwsh ./apply-governance-parameters.ps1 -EnvironmentName prod \
       -ParametersFile ./custom.parameters.json
#>

[CmdletBinding()]
param(
    [Parameter(Mandatory = $true)]
    [string]$EnvironmentName,

    [Parameter(Mandatory = $false)]
    [string]$ParametersFile = $(Join-Path $PSScriptRoot "governance.parameters.json")
)

Set-StrictMode -Version Latest
$ErrorActionPreference = 'Stop'

function Write-Info([string]$Message) { Write-Host "[governance-parameters] $Message" -ForegroundColor Cyan }
function Write-Success([string]$Message) { Write-Host "[governance-parameters] ✓ $Message" -ForegroundColor Green }
function Write-Warn([string]$Message) { Write-Warning "[governance-parameters] $Message" }
function Write-Fail([string]$Message) { throw "[governance-parameters] $Message" }

if (-not (Get-Command azd -ErrorAction SilentlyContinue)) {
    Write-Fail "Azure Developer CLI (azd) is not available on PATH. Install azd before running this script."
}

if (-not (Test-Path -Path $ParametersFile)) {
    Write-Fail "Parameters file not found: $ParametersFile"
}

Write-Info "Loading parameters from $ParametersFile"

function Get-ParametersFromFile {
    param(
        [string]$FilePath
    )

    $extension = [System.IO.Path]::GetExtension($FilePath).ToLowerInvariant()

    switch ($extension) {
        ".json" {
            try {
                return Get-Content -Path $FilePath -Raw | ConvertFrom-Json
            } catch {
                Write-Fail "Unable to parse JSON file. Ensure $FilePath contains valid JSON."
            }
        }
        ".bicepparam" {
            $parameters = [ordered]@{}
            $lines = Get-Content -Path $FilePath

            foreach ($line in $lines) {
                $trimmed = $line.Trim()
                if ($trimmed -like "#*" -or $trimmed.StartsWith('//') -or [string]::IsNullOrWhiteSpace($trimmed)) {
                    continue
                }

                if ($trimmed -match '^param\s+([A-Za-z0-9_]+)\s*=\s*(.+)$') {
                    $name = $matches[1]
                    $valueExpression = $matches[2].Trim()

                    if ($valueExpression -match "^'([^']*)'") {
                        $value = $matches[1]
                    } elseif ($valueExpression -match '^"([^"]*)"') {
                        $value = $matches[1]
                    } elseif ($valueExpression -match '^(true|false)$') {
                        $value = [bool]::Parse($matches[1])
                    } elseif ($valueExpression -match '^[0-9]+$') {
                        $value = [int]$valueExpression
                    } else {
                        Write-Info "Skipping $name (unsupported expression in bicepparam)"
                        continue
                    }

                    $parameters[$name] = $value
                }
            }

            if ($parameters.Count -eq 0) {
                Write-Warn "No parameter assignments detected in $FilePath"
            }

            return [pscustomobject]$parameters
        }
        default {
            Write-Fail "Unsupported parameter file extension: $extension"
        }
    }
}

$parameterContent = Get-ParametersFromFile -FilePath $ParametersFile

if (-not $parameterContent) {
    Write-Warn "No parameters were found in the file. Nothing to apply."
    return
}

$appliedCount = 0

foreach ($property in $parameterContent.PSObject.Properties) {
    $name = $property.Name
    $value = $property.Value

    if (-not $value -or [string]::IsNullOrWhiteSpace($value)) {
        Write-Info "Skipping $name (no value provided)"
        continue
    }

    if ($value -like "<*>") {
        Write-Info "Skipping $name (placeholder value detected)"
        continue
    }

    Write-Info "Setting $name for azd environment '$EnvironmentName'"
    try {
        azd env set $name $value --environment $EnvironmentName 2>$null | Out-Null
        Write-Success "$name updated"
        $appliedCount++
    } catch {
        Write-Warn "Failed to set ${name}: $($_.Exception.Message)"
    }
}

if ($appliedCount -eq 0) {
    Write-Warn "No parameter values were applied. Provide values in $ParametersFile and rerun."
} else {
    Write-Success "Applied $appliedCount parameter value(s) to environment '$EnvironmentName'."
}
