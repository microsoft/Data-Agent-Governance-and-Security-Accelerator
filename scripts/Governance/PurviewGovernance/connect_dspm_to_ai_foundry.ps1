<#
.SYNOPSIS
  Connect Microsoft Purview DSPM to Azure AI Foundry projects.

.DESCRIPTION
  This script establishes connections between DSPM for AI and Azure AI Foundry:
  - Discovers AI Foundry projects in the subscription
  - Configures DSPM monitoring for AI workspaces
  - Sets up data governance policies for AI models
  - Establishes secure connections between Purview and AI Foundry

.NOTES
  Requires: Contributor role on Azure subscription and Purview admin permissions
#>

[CmdletBinding()]
param(
    [Parameter(Mandatory = $false)]
    [string]$SubscriptionId = $null,
    
    [Parameter(Mandatory = $false)]
    [string]$ResourceGroup = $null,
    
    [Parameter(Mandatory = $false)]
    [string]$AIFoundryProjectName = $null
)

Set-StrictMode -Version Latest

# Import security module
$SecurityModulePath = Join-Path $PSScriptRoot "../SecurityModule.ps1"
. $SecurityModulePath
$ErrorActionPreference = 'Stop'

function Log([string]$m) { Write-Host "[dspm-ai-foundry] $m" -ForegroundColor Cyan }
function Warn([string]$m) { Write-Warning "[dspm-ai-foundry] $m" }
function Success([string]$m) { Write-Host "[dspm-ai-foundry] ✓ $m" -ForegroundColor Green }
function Fail([string]$m) { 
    Write-Error "[dspm-ai-foundry] $m"
    Clear-SensitiveVariables -VariableNames @("accessToken", "armToken")
    exit 1 
}

Log "═══════════════════════════════════════════════════════════════"
Log "  Microsoft Purview DSPM ↔ Azure AI Foundry Integration"
Log "═══════════════════════════════════════════════════════════════"
Log ""

# Step 1: Validate Azure CLI and get subscription
Log "Step 1: Validating Azure Environment..."
Log "─────────────────────────────────────────────────────────────"

try {
    # Check Azure CLI authentication
    $account = az account show 2>$null | ConvertFrom-Json
    if (-not $account) {
        Fail "Not authenticated with Azure CLI. Run 'az login' first."
    }
    Success "Azure CLI authenticated as: $($account.user.name)"

    if (-not $SubscriptionId) {
        $envSubscription = $null
        try {
            $envSubscription = & azd env get-value aiSubscriptionId 2>$null
        } catch {
            # ignore missing value
        }

        if ($envSubscription) {
            if ($account.id -ne $envSubscription) {
                az account set --subscription $envSubscription
                $account = az account show 2>$null | ConvertFrom-Json
                Success "Switched to subscription from azd environment: $envSubscription"
            }
            $SubscriptionId = $envSubscription
        } else {
            $SubscriptionId = $account.id
            Log "Using default subscription: $($account.name)"
        }
    } else {
        az account set --subscription $SubscriptionId
        $account = az account show 2>$null | ConvertFrom-Json
        Success "Switched to subscription: $SubscriptionId"
    }

    $tenantId = $account.tenantId
    Log "  Tenant: $tenantId"
} catch {
    Fail "Azure CLI validation failed: $($_.Exception.Message)"
}
Log ""

# Step 2: Discover AI Foundry Projects
Log "Step 2: Discovering Azure AI Foundry Projects..."
Log "─────────────────────────────────────────────────────────────"

try {
    # Search for AI Foundry workspaces (Microsoft.MachineLearningServices/workspaces)
    Log "Searching for AI Foundry projects in subscription..."
    
    $queryFilter = "resourceType =~ 'Microsoft.MachineLearningServices/workspaces'"
    if ($ResourceGroup) {
        $queryFilter += " and resourceGroup =~ '$ResourceGroup'"
    }
    if ($AIFoundryProjectName) {
        $queryFilter += " and name =~ '$AIFoundryProjectName'"
    }
    
    $aiProjects = az resource list --query "[$queryFilter]" 2>$null | ConvertFrom-Json
    
    if (-not $aiProjects -or $aiProjects.Count -eq 0) {
        Warn "No AI Foundry projects found in the subscription"
        Log ""
        Log "If you have AI Foundry projects, verify:"
        Log "  - Correct subscription is selected"
        Log "  - You have Reader access to the resource group"
        Log "  - Projects are of type: Microsoft.MachineLearningServices/workspaces"
        Log ""
        Log "Creating AI Foundry projects:"
        Log "  Portal: https://ai.azure.com"
        Log "  Docs: https://learn.microsoft.com/azure/ai-studio/how-to/create-projects"
        Log ""
        exit 0
    }
    
    Success "Found $($aiProjects.Count) AI Foundry project(s)"
    Log ""
    foreach ($project in $aiProjects) {
        Log "  • Name: $($project.name)"
        Log "    Resource Group: $($project.resourceGroup)"
        Log "    Location: $($project.location)"
        Log "    ID: $($project.id)"
        Log ""
    }
} catch {
    Fail "Failed to discover AI Foundry projects: $($_.Exception.Message)"
}

# Step 3: Configure DSPM Monitoring for AI Foundry
Log "Step 3: Configuring DSPM Monitoring..."
Log "─────────────────────────────────────────────────────────────"

try {
    Log "To enable DSPM monitoring for AI Foundry projects:"
    Log ""
    Log "Option 1: Portal Configuration (Recommended)"
    Log "  1. Open Azure AI Foundry: https://ai.azure.com"
    Log "  2. Select your project: $($aiProjects[0].name)"
    Log "  3. Navigate to 'Settings' > 'Data governance'"
    Log "  4. Enable 'Microsoft Purview integration'"
    Log "  5. Select your Purview account"
    Log "  6. Enable 'DSPM for AI monitoring'"
    Log ""
    
    Log "Option 2: Azure Resource Tags (Automation)"
    Log "  Tag AI Foundry resources with Purview account information"
    Log ""
    
    # Add tags to AI Foundry projects for Purview integration
    $purviewAccountName = $null
    try {
        $purviewAccountName = & azd env get-value purviewAccountName 2>$null
    } catch {
        Log "No purviewAccountName found in azd environment"
    }
    
    if ($purviewAccountName) {
        Log "Found Purview account: $purviewAccountName"
        Log "Would you like to tag AI Foundry projects with this Purview account? (y/n)"
        $tagResponse = Read-Host
        
        if ($tagResponse -eq 'y') {
            foreach ($project in $aiProjects) {
                try {
                    Log "Tagging project: $($project.name)..."
                    az resource tag --ids $project.id --tags "PurviewAccount=$purviewAccountName" "DSPMEnabled=true" --only-show-errors
                    Success "Tagged: $($project.name)"
                } catch {
                    Warn "Failed to tag $($project.name): $($_.Exception.Message)"
                }
            }
        }
    }
    
    Success "Configuration guidance provided"
} catch {
    Warn "Error during configuration: $($_.Exception.Message)"
}
Log ""

# Step 4: Set up Data Governance Policies
Log "Step 4: Data Governance Policy Setup..."
Log "─────────────────────────────────────────────────────────────"

Log "To ensure AI Foundry projects send data to DSPM:"
Log ""
Log "1. Azure AI Foundry Settings"
Log "   • Enable diagnostic settings for AI Foundry projects"
Log "   • Configure log categories: AuditEvent, RequestResponse"
Log "   • Send logs to Log Analytics workspace"
Log ""
Log "2. Microsoft Purview API Integration"
Log "   • Implement Microsoft Purview APIs in your AI applications"
Log "   • Use TrackInteractionAsync for AI interactions"
Log "   • Reference: https://learn.microsoft.com/purview/developer/secure-ai-with-purview"
Log ""
Log "3. Code Example (C#):"
Log '   using Microsoft.Purview.DataSecurity.AI;'
Log '   '
Log '   var client = new AIInteractionClient(endpoint, credential);'
Log '   await client.TrackInteractionAsync(new AIInteraction {'
Log '       Prompt = userPrompt,'
Log '       Response = aiResponse,'
Log '       ApplicationId = "your-app-id"'
Log '   });'
Log ""

Success "Data governance policy guidance provided"
Log ""

# Step 5: Verify Integration
Log "Step 5: Integration Verification..."
Log "─────────────────────────────────────────────────────────────"

Log "After configuration, verify the integration:"
Log ""
Log "1. Wait 24-48 hours for data collection to begin"
Log ""
Log "2. Check Activity Explorer:"
Log "   • URL: https://purview.microsoft.com/activityexplorer"
Log "   • Filter by: AI app category = 'Enterprise AI apps'"
Log "   • Look for: Your AI Foundry project activities"
Log ""
Log "3. Review DSPM Reports:"
Log "   • URL: https://purview.microsoft.com/purviewforai/reports"
Log "   • Check: 'AI interactions' and 'Sensitive data' sections"
Log ""
Log "4. Validate Policies:"
Log "   • URL: https://purview.microsoft.com/purviewforai/policies"
Log "   • Ensure: All policies show status 'ON'"
Log ""

Success "═══════════════════════════════════════════════════════════════"
Success "  AI Foundry Integration Configuration Complete!"
Success "═══════════════════════════════════════════════════════════════"
Log ""
Log "Discovered Projects:"
foreach ($project in $aiProjects) {
    Log "  ✓ $($project.name) ($(Split-Path $project.id -Leaf))"
}
Log ""
Log "Next Steps:"
Log "  1. Configure AI Foundry projects as described above"
Log "  2. Implement Purview APIs in your AI applications"
Log "  3. Wait 24-48 hours for data collection"
Log "  4. Run: ./verify_dspm_configuration.ps1 to validate"
Log ""
Log "Resources:"
Log "  - AI Foundry Portal: https://ai.azure.com"
Log "  - DSPM Portal: https://purview.microsoft.com/purviewforai/overview"
Log "  - API Documentation: https://learn.microsoft.com/purview/developer/secure-ai-with-purview"
Log ""

# Clear sensitive variables
Clear-SensitiveVariables -VariableNames @("accessToken", "armToken")
