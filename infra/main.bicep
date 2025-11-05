// Placeholder infrastructure for governance wrapper deployments.
// This template intentionally deploys no Azure resources, but allows
// `azd up` to complete successfully so postprovision hooks can execute.

param location string = resourceGroup().location
param purviewAccountName string = ''
param purviewResourceGroup string = ''
param purviewSubscriptionId string = ''
param aiFoundryProjectName string = ''
param aiFoundryResourceGroup string = ''
param aiSubscriptionId string = ''
param azureOpenAIResourceName string = ''
param azureOpenAIResourceGroup string = ''

output governanceParameters object = {
	purviewAccountName: purviewAccountName
	purviewResourceGroup: purviewResourceGroup
	purviewSubscriptionId: purviewSubscriptionId
	aiFoundryProjectName: aiFoundryProjectName
	aiFoundryResourceGroup: aiFoundryResourceGroup
	aiSubscriptionId: aiSubscriptionId
	azureOpenAIResourceName: azureOpenAIResourceName
	azureOpenAIResourceGroup: azureOpenAIResourceGroup
}
