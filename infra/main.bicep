targetScope = 'subscription'

@description('Deployment location for the no-op bootstrap deployment used to satisfy azd infrastructure validation.')
param deploymentLocation string = deployment().location

@description('Spec file that the post-provision hook should hand to run.ps1.')
param dagaSpecPath string = './spec.local.json'

@description('Tags (in run.ps1 format) that the hook should execute after provisioning.')
param dagaTags array = [
	'foundation'
	'dspm'
	'defender'
	'foundry'
]

@description('Set to true when Microsoft 365 portions of the run plan should execute during the hook.')
param dagaConnectM365 bool = false

@description('Interactive operator UPN for Exchange Online steps (optional).')
param dagaM365UserPrincipalName string = ''

@description('App registration (client) ID for certificate-based Microsoft 365 auth (optional).')
param dagaM365AppId string = ''

@description('Microsoft 365 organization/tenant (GUID or domain) for app-only auth (optional).')
param dagaM365Organization string = ''

@description('Thumbprint for the certificate stored on the execution host (optional).')
param dagaM365CertificateThumbprint string = ''

@description('Path to a PFX certificate that the automation can read (optional).')
param dagaM365CertificatePath string = ''

@description('Password for the file-based certificate (optional).')
param dagaM365CertificatePassword string = ''

// azd preflight rejects an ARM template with zero resources. This nested deployment is intentionally
// inert and exists only so azd can validate and invoke the post-provision hook-driven automation.
resource bootstrapNoOp 'Microsoft.Resources/deployments@2024-03-01' = {
	name: 'daga-bootstrap-noop'
	location: deploymentLocation
	properties: {
		mode: 'Incremental'
		template: {
			'$schema': 'https://schema.management.azure.com/schemas/2019-04-01/deploymentTemplate.json#'
			contentVersion: '1.0.0.0'
			outputs: {
				status: {
					type: 'string'
					value: 'noop'
				}
			}
			resources: []
		}
	}
}

output dagaSpecPath string = dagaSpecPath
output dagaTags array = dagaTags
output dagaConnectM365 bool = dagaConnectM365
output dagaM365UserPrincipalName string = dagaM365UserPrincipalName
output dagaM365AppId string = dagaM365AppId
output dagaM365Organization string = dagaM365Organization
output dagaM365CertificateThumbprint string = dagaM365CertificateThumbprint
output dagaM365CertificatePath string = dagaM365CertificatePath
output dagaM365CertificatePassword string = dagaM365CertificatePassword
