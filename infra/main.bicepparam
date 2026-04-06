using './main.bicep'

// Auto-populated by azd from the current environment name.
param environmentName = readEnvironmentVariable('AZURE_ENV_NAME', 'default')

// Customize these values per azd environment. The hook reads them and forwards the
// resolved configuration to run.ps1, so no additional environment variables are required.
param dagaSpecPath = './spec.local.json'
param dagaTags = [
  'foundation'
  'dspm'
  'defender'
  'foundry'
]
param dagaConnectM365 = true

// Interactive Microsoft 365 auth for the m365 workflow.
// Use this when an operator can complete browser-based sign-in and MFA.
param dagaM365UserPrincipalName = 'v-saswatoc@MngEnvMCAP993385.onmicrosoft.com'

// App-only Microsoft 365 auth for the m365 workflow.
// These are NOT used for Azure deployment itself. They are only passed to run.ps1
// when the repo needs to connect to Exchange Online / Security & Compliance cmdlets
// without interactive user sign-in, such as unattended runs or CI/CD.
// Provide AppId + Organization, and then either:
// - CertificateThumbprint, or
// - CertificatePath + CertificatePassword.
param dagaM365AppId = ''
param dagaM365Organization = ''
param dagaM365CertificateThumbprint = ''
param dagaM365CertificatePath = ''
param dagaM365CertificatePassword = ''
