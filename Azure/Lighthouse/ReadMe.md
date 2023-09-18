#How To

Create Azure Subscription in client tenant

<span style="color: red;">Do not modify delegatedResourceManagement.json this is a standard template for all Lighthouse Connections. 
</span>

<span style="color: green;">Modify the delegatedResourceManagement.parameters.json to satisfy your requirements. </span>


Open Azure CLI and upload two json files, delegatedResourceManagement.parameters.json and delegatedResourceManagement.json

Example deployment: 
New-AzSubscriptionDeployment -Name AzureLighthouse -Location "East US" -TemplateFile delegatedResourceManagement.json -TemplateParameterFile delegatedResourceManagement.parameters.json -Verbose


| ID                                   | Role Name                           | Description                                                                      |
|--------------------------------------|------------------------------------|----------------------------------------------------------------------------------|
| 5e467623-bb1f-42f4-a55d-6e525e11384b | Backup Contributor                 | Lets you manage backup service                                                   |
| 00c29273-979b-4161-815c-10b084fb9324 | Backup Operator                    | Lets you manage backup services                                                  |
| a795c7a0-d4a2-40c1-ae25-d81f01202912 | Backup Reader                      | Can view backup services                                                         |
| fa23ad8b-c56e-40d8-ac0c-ce449e1d2c64 | Billing Reader                     | Allows read access to billing data                                                |
| b24988ac-6180-42a0-ab88-20f7382dd24c | Contributor                         | Grants full access to manage all resources                                        |
| 00482a5a-887f-4fb3-b363-3b7fe8e74483 | Key Vault Administrator             | Perform all data plane operations on a key vault and all objects in it            |
| a4417e6f-fecd-4de8-b567-7b0420556985 | Key Vault Certificates Officer      | Perform any action on the certificates of a key vault                             |
| f25e0fa2-a7c8-4377-a976-54943a77a395 | Key Vault Contributor               | Lets you manage key vaults                                                       |
| 21090545-7ca7-4776-b22c-e363652d74d2 | Key Vault Reader                    | Read metadata of key vaults and its certificates                                  |
| 92aaf0da-9dab-42b6-94a3-d43ce8d16293 | Log Analytics Contributor           | Log Analytics Contributor can read all monitoring data and edit monitoring settings. Editing monitoring settings includes adding the VM extension to VMs; reading storage account keys to be able to configure collection of logs from Azure Storage; adding solutions; and configuring Azure diagnostics on all Azure resources.|
| 73c42c96-874c-492b-b04d-ab87d138a893 | Log Analytics Reader                | Log Analytics Reader can view and search all monitoring data as well as and view monitoring settings                                           |
| 87a39d53-fc1b-424a-814c-f7e04687dc9e | Logic App Contributor               | Lets you manage logic app                                                        |
| 515c2055-d9d4-4321-b1b9-bd0c9a0f79fe | Logic App Operator                  | Lets you read                                                                     |
| f4c81013-99ee-4d62-a7ee-b3f1f648599a | Sentinel Automation Contributor     | Microsoft Sentinel Automation Contributor                                         |
| ab8e14d6-4a74-4a29-9ba8-549422addade | Sentinel Contributor                | Microsoft Sentinel Contributor                                                    |
| 51d6186e-6489-4900-b93f-92e23144cca5 | Sentinel Playbook Operator          | Microsoft Sentinel Playbook Operator                                              |
| 8d289c81-5878-46d4-8554-54e1e3d8b5cb | Sentinel Reader                     | Microsoft Sentinel Reader                                                         |
| 3e150937-b8fe-4cfb-8069-0eaf05ecd056 | Sentinel Responder                  | Microsoft Sentinel Responder                                                      |
| 749f88d5-cbae-40b8-bcfc-e573ddc772fa | Monitoring Contributor  	         | Can read all monitoring data and update monitoring settings.
| 8e3af657-a8ff-443c-a75c-2fe8c4bcb635 | Owner	                             | Grants full access to manage all resources
| acdd72a7-3385-48ef-bd42-f606fba81ae7 |  Reader	                         | View all resources
| c12c1c16-33a1-487b-954d-41c89c60f349 | Reader and Data Access	             | Lets you view everything but will not let you delete or create a storage account or contained resource. It will also allow read/write access to all data contained in a storage account via access to storage account keys.
| fb1c8493-542b-48eb-b624-b4c8fea62acd | Security Admin	                     | Security Admin Role
| 39bc4728-0917-49c7-9d2c-d95423bc2eb4 | Security Reader         	         | Security Reader Role
| 17d1049b-9a84-46fb-8f53-869881c3d3ab | Storage Account Contributor	     | Lets you manage storage accounts
| 1c0163c0-47e6-4577-8991-ea5c82e286e4 | Virtual Machine Administrator       | Login	View Virtual Machines in the portal and login as administrator
| 9980e02c-c2be-4d73-94e8-173b1dc7cf3c | Virtual Machine Contributor	     | Lets you manage virtual machines
| 602da2ba-a5c2-41da-b01d-5360126ab525 | Virtual Machine Local Login         | View Virtual Machines in the portal and login as a local user configured on the arc server
| fb879df8-f326-4884-b1cf-06f3ad86be52 | Virtual Machine User Login	         | View Virtual Machines in the portal and login as a regular user.
| e8ddcd69-c73f-4f9f-9844-4100522f16ad | Workbook Contributor	             | Can save shared workbooks.
| b279062a-9be3-42a0-92ae-8b3cf002ec4d | Workbook Reader	                 | Can read workbooks.
