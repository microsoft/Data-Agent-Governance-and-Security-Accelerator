# Filename: 00-New-DspmSpec.ps1
param(
  [Parameter()][string]$OutFile = "./spec.dspm.template.json"
)

$tmpl = @'
{
  "tenantId": "<aad-tenant-guid>",
  "subscriptionId": "<azure-sub-guid>",
  "location": "eastus",
  "resourceGroup": "rg-purview-dspm",
  "purviewAccount": "mpv-dspm",

  "dataSources": [
    {
      "name": "ds-storage-01",
      "type": "AzureStorage",
      "resourceId": "/subscriptions/<sub>/resourceGroups/<rg>/providers/Microsoft.Storage/storageAccounts/<name>"
    }
  ],

  "scans": [
    {
      "dataSource": "ds-storage-01",
      "name": "scan-storage-01",
      "rulesetType": "System",
      "rulesetName": "AzureStorage"
    }
  ],

  "dlpPolicy": {
    "name": "AI Egress Control (Baseline)",
    "mode": "Enforce",
    "locations": { "Exchange": "All", "SharePoint": "All", "OneDrive": "All", "Teams": "All" },
    "rules": [
      {
        "name": "Block High-Confidence Sensitive Data to AI Destinations",
        "sensitiveInfoTypes": [
          { "name": "Credit Card Number", "count": 1, "confidence": 85 },
          { "name": "U.S. Social Security Number (SSN)", "count": 1, "confidence": 85 }
        ],
        "blockAccess": true,
        "notifyUser": true
      }
    ]
  },

  "labels": [
    {
      "name": "Confidential",
      "publishPolicyName": "Publish: Confidential (All Users)",
      "encryptionEnabled": true,
      "publishScopes": { "Exchange": "All", "SharePoint": "All", "OneDrive": "All" }
    }
  ],

  "retentionPolicies": [
    {
      "name": "AI Data – 7 Years",
      "rules": [ { "name": "Keep 7y then Delete", "durationDays": 2555, "action": "Delete" } ],
      "locations": { "Exchange": "All", "SharePoint": "All", "OneDrive": "All", "TeamsChat": "All", "TeamsChannel": "All" }
    }
  ],

  "activityExport": {
    "outputPath": "./audit_export",
    "contentTypes": ["Audit.General","Audit.SharePoint","Audit.Exchange","DLP.All","Audit.AzureActiveDirectory","Audit.PowerBI"]
  },

  "azurePolicies": [
    {
      "name": "deny-public-access-cognitiveservices",
      "displayName": "Cognitive Services accounts should disable public network access",
      "scope": "resourceGroup",
      "parameters": {}
    }
  ],

  "defenderForAI": {
    "enableDefenderForCloudPlans": ["CognitiveServices","Storage","Containers"],
    "logAnalyticsWorkspaceId": "/subscriptions/<sub>/resourceGroups/<rg>/providers/Microsoft.OperationalInsights/workspaces/<law>",
    "diagnosticCategories": ["Audit","RequestResponse","AllMetrics"]
  },

  "foundry": {
    "resources": [
      {
        "name": "aoai-eastus-01",
        "resourceId": "/subscriptions/<sub>/resourceGroups/<rg>/providers/Microsoft.CognitiveServices/accounts/<openaiAccount>",
        "diagnostics": true,
        "logCategories": ["Audit","RequestResponse","AllMetrics"],
        "tags": { "stage": "4", "owner": "sas-accel", "classification": "ai-workload" }
      }
    ],
    "contentSafety": {
      "endpoint": "https://<contentsafety>.cognitiveservices.azure.com",
      "apiKeySecretRef": {
        "keyVaultResourceId": "/subscriptions/<sub>/resourceGroups/<rg>/providers/Microsoft.KeyVault/vaults/<kv>",
        "secretName": "ContentSafety-ApiKey"
      },
      "textBlocklists": [
        { "name": "pii-terms", "items": ["password","api key","secret","ssn","credit card"] }
      ],
      "harmSeverityThreshold": 6
    }
  }
}
'@

$tmpl | Out-File -FilePath $OutFile -Encoding UTF8 -Force
Write-Host "Scaffolded spec at $OutFile" -ForegroundColor Green