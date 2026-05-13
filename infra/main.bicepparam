using './main.bicep'

param location = 'eastus'
param namePrefix = 'ms'

// Primary POC target. Fallback models must be selected explicitly by editing these parameters.
param modelDeploymentName = 'gpt-5-4'
param modelName = 'gpt-5.4'
param modelVersion = '2026-03-05'
param modelSkuName = 'GlobalStandard'
param modelCapacity = 50

param rbacPropagationWaitSeconds = 60
