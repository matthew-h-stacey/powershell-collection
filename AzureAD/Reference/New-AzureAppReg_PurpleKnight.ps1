###
# Parameters Used By Script
###
Param (
    [Parameter(Mandatory = $TRUE, ValueFromPipeline = $TRUE, ValueFromPipelineByPropertyName = $TRUE,
        HelpMessage = 'Please specify the FQDN of the AAD Tenant to target')]
    [ValidateNotNullOrEmpty()]
    [string]$aadTenantFQDN,
    [Parameter(Mandatory = $TRUE, ValueFromPipeline = $TRUE, ValueFromPipelineByPropertyName = $TRUE,
        HelpMessage = 'Please specify the name of the Application Registration')]
    [ValidateNotNullOrEmpty()]
    [string]$appRegDisplayName,
    [string]$customLifetimeSecretInDays,
    [switch]$createOrUpdateApp,
    [switch]$deleteApp,
    [switch]$updateAPIPerms,
    [switch]$createClientSecret,
    [switch]$deleteAllClientSecrets
)

###
# Version Of Script
###
$version = "v0.4, 2022-11-21"

<#
	AUTHOR
		Written By....................: Jorge de Almeida Pinto
		Re-Written By.................: N.A.
		Company.......................: SEMPERIS [https://www.semperis.com/]

	DISCLAIMER
		- The script is FREEWARE, you are free to distribute/update it, but always refer to this website (https://github.com/Semperis/) as the location where you got it
		- This script is furnished "AS IS". NO warranty is expressed or implied!
		- I/We HAVE NOT tested it in every scenario or environment
		- ALWAYS TEST FIRST in lab environment to see if it meets your needs!
		- Use this script at YOUR OWN RISK! YOU ARE RESPONSIBLE FOR ANY OUTCOME/RESULT BY USING THIS SCRIPT!
		- I/We DO NOT warrant this script to be fit for any purpose, use or environment!
		- I/We have tried to check everything that needed to be checked, but I/We DO NOT guarantee the script does not have bugs!
		- I/We DO NOT guarantee the script will not damage or destroy your system(s), environment or anything else due to improper use or bugs!
		- I/We DO NOT accept liability in any way when making mistakes, use the script wrong or in any other way where damage is caused to your environment/systems!
		- If you do not accept these terms DO NOT use the script in any way and delete it immediately!

	TODO
		- N.A.

	KNOWN ISSUES/BUGS
		- The script does not check for the correct combination of parameters

	RELEASE NOTES
		v0.4, 2022-11-21, Jorge de Almeida Pinto [MVP-EMS]:
			- Added the MSFT Graph roles "AuditLog.Read.All" to the list of MSFT Graph required roles

		v0.3, 2022-10-20, Jorge de Almeida Pinto [MVP-EMS]:
			- Fixed the name of the variable, after community feedback (Submitted by 'aps-support', THANK YOU!)
			- Changed the structure of the script for easier maintenance and to match other scripts
			- Moved the definition of MSFT Graph required roles into its own section for easier maintenance and better visibility
			- Added the MSFT Graph roles "RoleManagement.Read.All" and "UserAuthenticationMethod.Read.All" to the list of MSFT Graph required roles
			- Updated the logic, added try/catch, to give a nicer error when the initial authentication fails with either Connect-AzureAD or Connect-AzAccount

		v0.2, 2022-07-01, Jorge de Almeida Pinto [MVP-EMS]:
			- Added a default timer of 1 hour for the secret
			- Added the ability to provide a custom lifetime in days
			- Added a parameter to delete all the secrets present
			- Some code improvements

		v0.1, 2022-06-24, Jorge de Almeida Pinto [MVP-EMS]:
			- Initial version of the script
#>

<#
.SYNOPSIS
	This PoSH Script Creates The App Registration In AAD For PK To Be Able To Scan For Vulnerabilities In AAD

.DESCRIPTION
    This PoSH script provides the following functions:
	- Create and update the app registration in AAD for PK To Be Able To Scan For Vulnerabilities In AAD
	- Delete the app registration in AAD
	- Assign the following MSFT Graph Application Permissions and consent those, when either creating or updating the app
		- AdministrativeUnit.Read.All
		- Application.Read.All
		- AuditLog.Read.All
		- Directory.Read.All
		- Group.Read.All
		- Policy.Read.All
		- PrivilegedAccess.Read.AzureAD
		- Reports.Read.All
		- RoleManagement.Read.All
		- RoleManagement.Read.Directory
		- User.Read.All
		- UserAuthenticationMethod.Read.All
	- Create an client secret that by default is valid for an hour, when either creating or updating the app. If needed it is possible to provide a customer lifetime in days for the client secret. This is not recommended as it may be a security issue
	- Deleting all client secrets from the app registration in AAD
	- Display the tenant ID, the application ID, the assigned and consented permissions, and the client secret to be used in the Purple Knight executable

.PARAMETER aadTenantFQDN
	With his Parameter, You Can Specify The Tenant FQDN To Target The AAD Tenant To create The App Registration In

.PARAMETER appRegDisplayName
	With his Parameter, You Can Specify The Name For The Application Registration
	
.PARAMETER customLifetimeSecretInDays
	With his Parameter, You Can Specify The Custom Lifetime Of The Client Secret In Days

.PARAMETER createOrUpdateApp
	With his Parameter, You Can Specify To Either Create A New App Registration Or Update An Existing App Registration
	
.PARAMETER deleteApp
	With his Parameter, You Can Specify To Delete An Existing App Registration
	
.PARAMETER updateAPIPerms
	With his Parameter, You Can Specify To Update The API Permissions When Either Creating A New App Registration Or Updating An Existing App Registration

.PARAMETER createClientSecret
	With his Parameter, You Can Specify To Create A New Client Secret When Either Creating A New App Registration Or Updating An Existing App Registration

.PARAMETER deleteAllClientSecrets
	With his Parameter, You Can Specify To Delete All Existing Secrets Whether Those Are Expired Or Not (Only When App Already Exists!)

.EXAMPLE
	Create A Purple Knight Vulnerability Scanning App In AAD

	.\Create-Update-Delete-AAD-PK-Vulnerability-Scanning-App.ps1 -aadTenantFQDN XXX.ONMICROSOFT.COM -appRegDisplayName "Semperis Purple Knight Vulnerability Scanning App" -createOrUpdateApp -updateAPIPerms -createClientSecret

.EXAMPLE
	Update An Existing Purple Knight Vulnerability Scanning App In AAD With Updated API Permissions

	.\Create-Update-Delete-AAD-PK-Vulnerability-Scanning-App.ps1 -aadTenantFQDN XXX.ONMICROSOFT.COM -appRegDisplayName "Semperis Purple Knight Vulnerability Scanning App" -createOrUpdateApp -updateAPIPerms

.EXAMPLE
	Update An Existing Purple Knight Vulnerability Scanning App In AAD With A New Client Secret (Existing Client Secrets WILL NOT Be Deleted!)

	.\Create-Update-Delete-AAD-PK-Vulnerability-Scanning-App.ps1 -aadTenantFQDN XXX.ONMICROSOFT.COM -appRegDisplayName "Semperis Purple Knight Vulnerability Scanning App" -createOrUpdateApp -createClientSecret

.EXAMPLE
	Delete All Existing Client Secrets On The Existing Purple Knight Vulnerability Scanning App In AAD

	.\Create-Update-Delete-AAD-PK-Vulnerability-Scanning-App.ps1 -aadTenantFQDN XXX.ONMICROSOFT.COM -appRegDisplayName "Semperis Purple Knight Vulnerability Scanning App" -createOrUpdateApp -deleteAllClientSecrets

.EXAMPLE
	Delete An Existing Purple Knight Vulnerability Scanning App In AAD

	.\Create-Update-Delete-AAD-PK-Vulnerability-Scanning-App.ps1 -aadTenantFQDN XXX.ONMICROSOFT.COM -appRegDisplayName "Semperis Purple Knight Vulnerability Scanning App" -deleteApp

.NOTES
	- Requires AzureAD PoSH Module to connect to Azure AD and perform all actions, except consenting API permissions
	- Requires Az.Accounts PoSH Module to be able to consent the API permissions
	- To create, configure AND consent application permissions for the Microsoft Graph, at least membership of the "Global Administrator" built-in role is required
	- To create and configure (without assigning and consenting application permissions for the Microsoft Graph), at least membership of the "Application Administrator" or "Cloud Application Administrator" built-in role is required
	- To create a new client secret, at least application ownership is required of the existing application
#>

###
# Functions Used In Script
###

# FUNCTION: Retrieve The Tenant ID From The Tenant FQDN
Function retrieveTenantIDFromTenantFQDN () {
    Param (
        [Parameter(Mandatory = $TRUE, ValueFromPipeline = $TRUE, ValueFromPipelineByPropertyName = $TRUE,
            HelpMessage = 'Please specify the AAD Tenant FQDN')]
        [ValidateNotNullOrEmpty()]
        $tenantFQDN
    )

    # Specify The Tenant Specific Discovery Endpoint URL
    $oidcConfigDiscoveryURL = $null
    $oidcConfigDiscoveryURL = "https://login.microsoftonline.com/$tenantFQDN/v2.0/.well-known/openid-configuration"
    $oidcConfigDiscoveryResult = $null

    # Retrieve The Information From The Discovery Endpoint URL
    $tenantId = $null
    $oidcConfigDiscoveryResult = $null
    Try {
        $oidcConfigDiscoveryResult = Invoke-RestMethod -Uri $oidcConfigDiscoveryURL -ErrorAction Stop
    }
    Catch {
        Write-Host ""
        Write-Host "Failed To Retrieve The Information From The Discovery Endpoint URL..." -ForegroundColor Red
        Write-Host ""
    }

    # If There Is A Result Determine The Tenant ID
    If ($null -ne $oidcConfigDiscoveryResult) {
        $tenantId = $oidcConfigDiscoveryResult.authorization_endpoint.Split("/")[3]
    }

    Return $tenantId
}

###
# Clear The Screen
###
Clear-Host

###
# Configure The Appropriate Screen And Buffer Size To Make Sure Everything Fits Nicely
###
$uiConfig = (Get-Host).UI.RawUI
$uiConfig.WindowTitle = "+++ CREATE/UPDATE/DELETE PURPLE KNIGHT VULNERABILITY SCANNING APP IN AAD +++"
$uiConfig.ForegroundColor = "Yellow"
$uiConfigBufferSize = $uiConfig.BufferSize
$uiConfigBufferSize.Width = 200
$uiConfigBufferSize.Height = 9999
$uiConfigScreenSizeMax = $uiConfig.MaxPhysicalWindowSize
$uiConfigScreenSizeMaxWidth = $uiConfigScreenSizeMax.Width
$uiConfigScreenSizeMaxHeight = $uiConfigScreenSizeMax.Height
$uiConfigScreenSize = $uiConfig.WindowSize
If ($uiConfigScreenSizeMaxWidth -lt 200) {
    $uiConfigScreenSize.Width = $uiConfigScreenSizeMaxWidth
}
Else {
    $uiConfigScreenSize.Width = 200
}
If ($uiConfigScreenSizeMaxHeight -lt 50) {
    $uiConfigScreenSize.Height = $uiConfigScreenSizeMaxHeight - 5
}
Else {
    $uiConfigScreenSize.Height = 50
}
$uiConfig.BufferSize = $uiConfigBufferSize
$uiConfig.WindowSize = $uiConfigScreenSize

###
# Definition Of Some Constants
###
$msftGraphListOfRequiredPermissions = @()
$msftGraphListOfRequiredPermissions += "AdministrativeUnit.Read.All"
$msftGraphListOfRequiredPermissions += "Application.Read.All"
$msftGraphListOfRequiredPermissions += "AuditLog.Read.All"
$msftGraphListOfRequiredPermissions += "Directory.Read.All"
$msftGraphListOfRequiredPermissions += "Group.Read.All"
$msftGraphListOfRequiredPermissions += "Policy.Read.All"
$msftGraphListOfRequiredPermissions += "PrivilegedAccess.Read.AzureAD"
$msftGraphListOfRequiredPermissions += "Reports.Read.All"
$msftGraphListOfRequiredPermissions += "RoleManagement.Read.All"
$msftGraphListOfRequiredPermissions += "RoleManagement.Read.Directory"
$msftGraphListOfRequiredPermissions += "User.Read.All"
$msftGraphListOfRequiredPermissions += "UserAuthenticationMethod.Read.All"

###
# Loading Any Applicable Libraries
###
# N.A.

###
# Execute Any Additional Actions Required For The Script To Run Successfully
###
# N.A.

###
# Start Of Script
###
# Presentation Of Script Header
Write-Host ""
Write-Host "                                                            *******************************************************************************" -ForeGroundColor Magenta
Write-Host "                                                            *                                                                             *" -ForeGroundColor Magenta
Write-Host "                                                            *--> Create/Update/Delete Purple Knight Vulnerability Scanning App In AAD <-- *" -ForeGroundColor Magenta
Write-Host "                                                            *                                                                             *" -ForeGroundColor Magenta
Write-Host "                                                            *                      Written By: Jorge de Almeida Pinto                     *" -ForeGroundColor Magenta
Write-Host "                                                            *                                   SEMPERIS                                  *" -ForeGroundColor Magenta
Write-Host "                                                            *                                                                             *" -ForeGroundColor Magenta
Write-Host "                                                            *                              $version                               *" -ForeGroundColor Magenta
Write-Host "                                                            *                                                                             *" -ForeGroundColor Magenta
Write-Host "                                                            *******************************************************************************" -ForeGroundColor Magenta
Write-Host ""

###
# Loading Azure AD (Preview) PowerShell Module
###
$azureADModule = Get-Module -Name "AzureAD" -ListAvailable
If ($null -eq $azureADModule) {
    $azureADModule = Get-Module -Name "AzureADPreview" -ListAvailable
}
If ($null -eq $azureADModule) {
    Write-Host ""
    Write-Host "The Azure AD (Preview) PowerShell Module IS NOT Installed" -ForegroundColor Red
    Write-Host ""
    Write-Host " => The Azure AD (Preview) PowerShell Module Can Be Installed From An Elevated PowerShell Command Prompt By Running Either" -ForegroundColor Red
    Write-Host "    - 'Install-Module AzureAD'" -ForegroundColor Red
    Write-Host "      OR" -ForegroundColor Red
    Write-Host "    - 'Install-Module AzureADPreview'" -ForegroundColor Red
    Write-Host ""
    Write-Host " => Aborting Script..." -ForegroundColor Red
    Write-Host ""

    BREAK
}
If ($azureADModule.count -gt 1) {
    $latestVersion = ($azureADModule | Select-Object version | Sort-Object)[-1]
    $azureADModule = $azureADModule | Where-Object { $_.version -eq $latestVersion.version }
}
Import-Module $azureADModule

###
# Loading Azure Accounts PowerShell Module
###
$azAccountsModule = Get-Module -Name "Az.Accounts" -ListAvailable
If ($null -eq $azAccountsModule) {
    Write-Host ""
    Write-Host "The Azure Accounts PowerShell Module IS NOT Installed" -ForegroundColor Red
    Write-Host ""
    Write-Host " => The Azure Accounts PowerShell Module Can Be Installed From An Elevated PowerShell Command Prompt By Running" -ForegroundColor Red
    Write-Host "    - 'Install-Module Az.Accounts'" -ForegroundColor Red
    Write-Host ""
    Write-Host " => Aborting Script..." -ForegroundColor Red
    Write-Host ""

    BREAK
}
If ($azAccountsModule.count -gt 1) {
    $latestVersion = ($azAccountsModule | Select-Object version | Sort-Object)[-1]
    $azAccountsModule = $azAccountsModule | Where-Object { $_.version -eq $latestVersion.version }
}
Import-Module $azAccountsModule

###
# Getting AAD Tenant Details
###
$aadTenantID = retrieveTenantIDFromTenantFQDN $aadTenantFQDN
If (!$([guid]::TryParse($aadTenantID, $([ref][guid]::Empty)))) {
    Write-Host ""
    Write-Host "Specified Tenant '$aadTenantFQDN' DOES NOT Exist..." -ForegroundColor Red
    Write-Host ""
    Write-Host " => Aborting Script..." -ForegroundColor Red
    Write-Host ""

    BREAK
}

###
# Connecting To Azure AD Tenant
###
Write-Host "### Connecting To Azure AD Tenant '$aadTenantFQDN'..." -ForegroundColor Cyan
Write-Host ""
Try {
    Connect-AzureAD -TenantId $aadTenantID -ErrorAction Stop
}
Catch {
    Write-Host "Connecting And Authenticating To The Azure AD Tenant '$aadTenantFQDN' Failed..." -ForegroundColor Red
    Write-Host ""
    Write-Host "    - Exception Type......: $($_.Exception.GetType().FullName)" -ForegroundColor Red
    Write-Host "    - Exception Message...: $($_.Exception.Message)" -ForegroundColor Red
    Write-Host "    - Error On Script Line: $($_.InvocationInfo.ScriptLineNumber)" -ForegroundColor Red
    Write-Host ""
    Write-Host " => Aborting Script..." -ForegroundColor Red
    Write-Host ""
    Write-Host ""

    BREAK
}
If ($updateAPIPerms) {
    Try {
        Connect-AzAccount -Tenant $aadTenantID -ErrorAction Stop
    }
    Catch {
        Write-Host ""
        Write-Host "Connecting And Authenticating To The Azure AD Tenant '$aadTenantFQDN' Failed..." -ForegroundColor Red
        Write-Host ""
        Write-Host "    - Exception Type......: $($_.Exception.GetType().FullName)" -ForegroundColor Red
        Write-Host "    - Exception Message...: $($_.Exception.Message)" -ForegroundColor Red
        Write-Host "    - Error On Script Line: $($_.InvocationInfo.ScriptLineNumber)" -ForegroundColor Red
        Write-Host ""
        Write-Host " => Aborting Script..." -ForegroundColor Red
        Write-Host ""
        Write-Host ""

        BREAK
    }
}
Write-Host " => Connected To Tenant ID '$aadTenantID' ($aadTenantFQDN)..." -ForegroundColor Green
Write-Host ""
Write-Host ""

###
# Creating/Updating The Purple Knight Vulnerability Scanning App In AAD
###
If ($createOrUpdateApp) {
    Write-Host "### Creating/Updating The Purple Knight Vulnerability Scanning App In AAD..." -ForegroundColor Cyan
    Write-Host ""
    $aadPKVulnerabilityScanApp = Get-AzureADApplication -SearchString $appRegDisplayName
    If ($aadPKVulnerabilityScanApp) {
        $aadPKVulnerabilityScanAppObjectID = $aadPKVulnerabilityScanApp.ObjectID
        $aadPKVulnerabilityScanAppApplicationID = $aadPKVulnerabilityScanApp.AppId
        Write-Host " => Purple Knight Vulnerability Scanning App In AAD '$appRegDisplayName' Already Exists..." -ForegroundColor Yellow
        Write-Host ""
    }
    Else {
        $aadPKVulnerabilityScanAppReplyURL = "http://localhost"
        Try {
            $aadPKVulnerabilityScanApp = New-AzureADApplication -DisplayName $appRegDisplayName -ReplyUrls @($aadPKVulnerabilityScanAppReplyURL) -ErrorAction Stop
            $aadPKVulnerabilityScanAppObjectID = $aadPKVulnerabilityScanApp.ObjectID
            $aadPKVulnerabilityScanAppApplicationID = $aadPKVulnerabilityScanApp.AppId
            Write-Host " => Purple Knight Vulnerability Scanning App In AAD '$appRegDisplayName' Has Been Created Successfully..." -ForegroundColor Green
            Write-Host ""
        }
        Catch {
            Write-Host " => Purple Knight Vulnerability Scanning App In AAD '$appRegDisplayName' Failed To Be Created..." -ForegroundColor Red
            Write-Host ""
            Write-Host "    - Exception Type......: $($_.Exception.GetType().FullName)" -ForegroundColor Red
            Write-Host "    - Exception Message...: $($_.Exception.Message)" -ForegroundColor Red
            Write-Host "    - Error On Script Line: $($_.InvocationInfo.ScriptLineNumber)" -ForegroundColor Red
            Write-Host ""
            Write-Host " => Aborting Script..." -ForegroundColor Red
            Write-Host ""
            Write-Host ""

            BREAK
        }

        # Creating The Purple Knight Vulnerability Scanning Svc Principal In AAD
        Write-Host " => Waiting A Few Seconds Before Continuing..." -ForegroundColor Yellow
        Write-Host ""
        Start-Sleep -s 10
        Try {
            $aadPKVulnerabilityScanSvcPrinc = New-AzureADServicePrincipal -DisplayName $appRegDisplayName -AppId $aadPKVulnerabilityScanAppApplicationID -AccountEnabled $true -AppRoleAssignmentRequired $false -ErrorAction Stop
            $aadPKVulnerabilityScanSvcPrincObjectID = $aadPKVulnerabilityScanSvcPrinc.ObjectID
            $aadPKVulnerabilityScanSvcPrincApplicationID = $aadPKVulnerabilityScanSvcPrinc.AppId
            Write-Host " => Purple Knight Vulnerability Scanning Svc Principal In AAD '$appRegDisplayName' Has Been Created Successfully..." -ForegroundColor Green
            Write-Host ""
        }
        Catch {
            Write-Host " => Purple Knight Vulnerability Scanning Svc Principal In AAD '$appRegDisplayName' Failed To Be Created..." -ForegroundColor Red
            Write-Host ""
            Write-Host "    - Exception Type......: $($_.Exception.GetType().FullName)" -ForegroundColor Red
            Write-Host "    - Exception Message...: $($_.Exception.Message)" -ForegroundColor Red
            Write-Host "    - Error On Script Line: $($_.InvocationInfo.ScriptLineNumber)" -ForegroundColor Red
            Write-Host ""
            Write-Host " => Aborting Script..." -ForegroundColor Red
            Write-Host ""
            Write-Host ""

            BREAK
        }
    }

    # Configuring API Permissions And Granting Admin Consent For The Purple Knight Vulnerability Scanning Svc Principal In AAD
    If ($updateAPIPerms) {
        $resourceAppId = $((Get-AzureADServicePrincipal -filter "DisplayName eq 'Microsoft Graph'").AppId) # MSFT Graph
        $resourceAccess = @()
        $msftGraphListOfRequiredPermissions | ForEach-Object {
            $appRoleName = $_
            $appRoleID = ((Get-AzureADServicePrincipal -filter "DisplayName eq 'Microsoft Graph'").AppRoles | ? { $_.Value -eq $appRoleName }).Id
            $resourceAccess += @{id = $appRoleID; type = "Role" }
        }
        $requiredResourceAccessPSObjectListAADPKVulnerabilityScanApp = @(
            [PSCustomObject]@{
                resourceAppId  = $resourceAppId
                resourceAccess = $resourceAccess
            }
        )
        $requiredResourceAccessListAADPKVulnerabilityScanApp = @()
        ForEach ($resourceApp in $requiredResourceAccessPSObjectListAADPKVulnerabilityScanApp) {
            $requiredResourceAccess = New-Object -TypeName "Microsoft.Open.AzureAD.Model.RequiredResourceAccess"
            $requiredResourceAccess.ResourceAppId = $resourceApp.resourceAppId
            ForEach ($resourceAccess in $resourceApp.resourceAccess) {
                $requiredResourceAccess.resourceAccess += New-Object -TypeName "Microsoft.Open.AzureAD.Model.ResourceAccess" -ArgumentList $resourceAccess.Id, $resourceAccess.type
            }
            $requiredResourceAccessListAADPKVulnerabilityScanApp += $requiredResourceAccess
        }
        Try {
            Set-AzureADApplication -ObjectId $aadPKVulnerabilityScanAppObjectID -RequiredResourceAccess $requiredResourceAccessListAADPKVulnerabilityScanApp -ErrorAction Stop
            Write-Host " => API Permissions For Purple Knight Vulnerability Scanning App In AAD '$appRegDisplayName' Has Been Configured Successfully..." -ForegroundColor Green
            Write-Host ""
        }
        Catch {
            Write-Host " => API Permissions For Purple Knight Vulnerability Scanning Svc Principal In AAD '$appRegDisplayName' Failed To Be Configured..." -ForegroundColor Red
            Write-Host ""
            Write-Host "    - Exception Type......: $($_.Exception.GetType().FullName)" -ForegroundColor Red
            Write-Host "    - Exception Message...: $($_.Exception.Message)" -ForegroundColor Red
            Write-Host "    - Error On Script Line: $($_.InvocationInfo.ScriptLineNumber)" -ForegroundColor Red
            Write-Host ""
            Write-Host ""
        }
		
        # Inspired By: https://stackoverflow.com/questions/63529599/how-to-grant-admin-consent-to-an-azure-aad-app-in-powershell
        $permissionsScopes = @()
        $requiredResourceAccessPSObjectListAADPKVulnerabilityScanApp | ForEach-Object {
            $resourceAppID = $null
            $resourceAppID = $_.resourceAppId
            $resourceAccess = $null
            $resourceAccess = $_.resourceAccess
            $resource = $null
            $resource = (Get-AzureADServicePrincipal -filter "AppId eq '$resourceAppID'")
            $resourceName = $null
            $resourceName = $resource.DisplayName
            $resourceAccessValues = @()
            $resourceAccess | ForEach-Object {
                $resourceAccessType = $null
                $resourceAccessType = $_.type
                $resourceAccessID = $null
                $resourceAccessID = $_.id
                $resourceAccessValue = $null
                If ($resourceAccessType -eq "Role") {
                    $resourceAccessValue = "AppRole: " + ($resource.AppRoles | Where-Object { $_.id -eq $resourceAccessID }).Value
                }
                If ($resourceAccessType -eq "scope") {
                    $resourceAccessValue = "Scope: " + ($resource.Oauth2Permissions | Where-Object { $_.id -eq $resourceAccessID }).Value
                }
                $resourceAccessValues += $resourceAccessValue
            }
            $permissionsScopes += $($resourceName + "|" + $($resourceAccessValues -join ","))
        }
        $azureContext = [Microsoft.Azure.Commands.Common.Authentication.Abstractions.AzureRmProfileProvider]::Instance.Profile.DefaultContext
        $resourceIDAADPortalMgmtUI = "74658136-14ec-4630-ad9b-26e160ff0fc6" # Resource ID For Azure AD Portal Management UI
        $AzureMgmtAccessToken = [Microsoft.Azure.Commands.Common.Authentication.AzureSession]::Instance.AuthenticationFactory.Authenticate($azureContext.Account, $azureContext.Environment, $azureContext.Tenant.Id.ToString(), $null, [Microsoft.Azure.Commands.Common.Authentication.ShowDialog]::Never, $null, $resourceIDAADPortalMgmtUI).AccessToken
        $requestHeaders = @{
            'Authorization'          = 'Bearer ' + $AzureMgmtAccessToken
            'X-Requested-With'       = 'XMLHttpRequest'
            'x-ms-client-request-id' = [guid]::NewGuid()
            'x-ms-correlation-id'    = [guid]::NewGuid()
        }
        $azureMgmtAdminConsentAADPKVulnerabilityScanAppEndpointURL = "https://main.iam.ad.ext.azure.com/api/RegisteredApplications/$aadPKVulnerabilityScanAppApplicationID/Consent?onBehalfOfAll=true"
        Write-Host " => Waiting A Few Seconds Before Continuing To Make Sure The Application, The Service Principal And Permissions Are In Place..." -ForegroundColor Yellow
        Write-Host ""
        Start-Sleep -s 30
        Try {
            Invoke-RestMethod -Uri $azureMgmtAdminConsentAADPKVulnerabilityScanAppEndpointURL -Headers $requestHeaders -Method POST -ErrorAction SilentlyContinue | Out-Null
            Write-Host " => Admin Consent Successfully Granted For The Purple Knight Vulnerability Scanning App In AAD '$appRegDisplayName'..." -ForegroundColor Green
            Write-Host "    WARNING: Although Possible, This IS NOT Officially Supported!..." -ForegroundColor Green
            Write-Host ""
        }
        Catch {
            Write-Host " => Failed To Grant Admin Consent For The Purple Knight Vulnerability Scanning App In AAD '$appRegDisplayName'..." -ForegroundColor Red
            Write-Host ""
            Write-Host "    - Exception Type......: $($_.Exception.GetType().FullName)" -ForegroundColor Red
            Write-Host "    - Exception Message...: $($_.Exception.Message)" -ForegroundColor Red
            Write-Host "    - Error On Script Line: $($_.InvocationInfo.ScriptLineNumber)" -ForegroundColor Red
            Write-Host ""
            Write-Host ""
        }
    }

    # Deleting All Existing Client Secrets For The Configured Permissions For The Purple Knight Vulnerability Scanning App In AAD
    If ($deleteAllClientSecrets) {
        Try {
            Get-AzureADApplicationPasswordCredential -ObjectId $aadPKVulnerabilityScanAppObjectID | % { Remove-AzureADApplicationPasswordCredential -ObjectId $aadPKVulnerabilityScanAppObjectID -KeyId $_.KeyId }
            Write-Host " => All Existing Client Secrets For Purple Knight Vulnerability Scanning App In AAD '$appRegDisplayName' Have Been Deleted..." -ForegroundColor Green
            Write-Host ""
        }
        Catch {
            Write-Host " => All Existing Client Secrets For Purple Knight Vulnerability Scanning App In AAD '$appRegDisplayName' Failed To Be Deleted..." -ForegroundColor Red
            Write-Host ""
            Write-Host "    - Exception Type......: $($_.Exception.GetType().FullName)" -ForegroundColor Red
            Write-Host "    - Exception Message...: $($_.Exception.Message)" -ForegroundColor Red
            Write-Host "    - Error On Script Line: $($_.InvocationInfo.ScriptLineNumber)" -ForegroundColor Red
            Write-Host ""
            Write-Host ""
        }
    }

    # Creating A Client Secret For The Configured Permissions For The Purple Knight Vulnerability Scanning App In AAD
    If ($createClientSecret) {
        Try {
            $startDate = Get-Date
            If ($customLifetimeSecretInDays) {
                $endDate = $startDate.AddDays($customLifetimeSecretInDays)
            }
            Else {
                $endDate = $startDate.AddHours(1)
            }
            $aadPKVulnerabilityScanClientSecret = New-AzureADApplicationPasswordCredential -ObjectId $aadPKVulnerabilityScanAppObjectID -CustomKeyIdentifier "PK CS ($(Get-Date -Format 'yyyyMMdd_HHmmss'))" -StartDate $startDate -EndDate $endDate
            Write-Host " => Client Secret For Purple Knight Vulnerability Scanning App In AAD '$appRegDisplayName' Has Been Created..." -ForegroundColor Green
            Write-Host ""
        }
        Catch {
            Write-Host " => Client Secret For Purple Knight Vulnerability Scanning App In AAD '$appRegDisplayName' Failed To Be Created And Configured..." -ForegroundColor Red
            Write-Host ""
            Write-Host "    - Exception Type......: $($_.Exception.GetType().FullName)" -ForegroundColor Red
            Write-Host "    - Exception Message...: $($_.Exception.Message)" -ForegroundColor Red
            Write-Host "    - Error On Script Line: $($_.InvocationInfo.ScriptLineNumber)" -ForegroundColor Red
            Write-Host ""
            Write-Host ""
        }
    }

    # Displaying The Required Data For The Purple Knight Vulnerability Scanning App In AAD
    Write-Host "### Displaying The Required Data For The Purple Knight Vulnerability Scanning App In AAD..." -ForegroundColor Cyan
    Write-Host ""
    Write-Host " => Tenant ID......................: '$aadTenantID'" -ForegroundColor Yellow
    Write-Host " => Application Name...............: '$appRegDisplayName'" -ForegroundColor Yellow
    Write-Host " => Application ID.................: '$aadPKVulnerabilityScanAppApplicationID'" -ForegroundColor Yellow
    If ($updateAPIPerms) {
        Write-Host " => API Permissions................:" -ForegroundColor Yellow
        $permissionsScopes | ForEach-Object {
            $resourceApp = $null
            $resourceApp = $_.Split("|")[0]
            Write-Host "    - Resource.....................: $resourceApp..." -ForegroundColor Yellow
            $_.Split("|")[1].Split(",") | ForEach-Object {
                Write-Host "      * Permissions................: $($_)..." -ForegroundColor Yellow
            }
        }
    }
    If ($createClientSecret) {
        Write-Host " => Client Secret..................: '$($aadPKVulnerabilityScanClientSecret.Value)'" -ForegroundColor Yellow
        If ($customLifetimeSecretInDays) {
            Write-Host " => Custom Lifetime Client Secret..: '$customLifetimeSecretInDays Days'" -ForegroundColor Yellow
        }
        Else {
            Write-Host " => Default Lifetime Client Secret.: '1 Hour'" -ForegroundColor Yellow
        }
        Write-Host " => Start Date.....................: '$($aadPKVulnerabilityScanClientSecret.StartDate)'" -ForegroundColor Yellow
        Write-Host " => End Date.......................: '$($aadPKVulnerabilityScanClientSecret.EndDate)'" -ForegroundColor Yellow
        Write-Host ""
        Write-Host "WARNING: Make Sure To Store The Client Secret Specified Above In A Secure Location Like E.g. A Password vault And Restrict Access To That Credential!!!" -ForegroundColor Red
    }
    Write-Host ""
}

###
# Deleting The Purple Knight Vulnerability Scanning App In AAD
###
If ($deleteApp) {
    Write-Host "### Deleting The Purple Knight Vulnerability Scanning App In AAD..." -ForegroundColor Cyan
    Write-Host ""
    $aadPKVulnerabilityScanApp = Get-AzureADApplication -SearchString $appRegDisplayName
    If ($aadPKVulnerabilityScanApp) {
        $deleteConfirmation = Read-Host " => Do You Really Want To Continue And Delete The Specified Purple Knight Vulnerability Scanning App In AAD? [YES | NO]"
        Write-Host ""
        If ($deleteConfirmation.ToUpper() -eq "YES" -Or $deleteConfirmation.ToUpper() -eq "Y") {
            Try {
                Remove-AzureADApplication -ObjectId $aadPKVulnerabilityScanApp.ObjectId
                Write-Host " => Purple Knight Vulnerability Scanning App In AAD '$appRegDisplayName' Has Been Deleted Successfully..." -ForegroundColor Green
                Write-Host ""
                Write-Host ""
            }
            Catch {
                Write-Host " => Purple Knight Vulnerability Scanning App In AAD '$appRegDisplayName' Failed To Be Deleted..." -ForegroundColor Red
                Write-Host ""
                Write-Host "    - Exception Type......: $($_.Exception.GetType().FullName)" -ForegroundColor Red
                Write-Host "    - Exception Message...: $($_.Exception.Message)" -ForegroundColor Red
                Write-Host "    - Error On Script Line: $($_.InvocationInfo.ScriptLineNumber)" -ForegroundColor Red
                Write-Host ""
                Write-Host ""
            }
        }
        Else {
            Write-Host " => Purple Knight Vulnerability Scanning App In AAD '$appRegDisplayName' HAS NOT BEEN Deleted..." -ForegroundColor Yellow
            Write-Host ""
            Write-Host ""
        }
    }
    Else {
        Write-Host " => Purple Knight Vulnerability Scanning App In AAD '$appRegDisplayName' DOES NOT Exist..." -ForegroundColor Red
        Write-Host ""
        Write-Host ""
    }
}

###
# Disconnect From Azure (AD)
###
Try {
    Disconnect-AzAccount -ErrorAction SilentlyContinue | Out-Null
}
Catch {
    Write-Host ""
    Write-Host "    - Exception Type......: $($_.Exception.GetType().FullName)" -ForegroundColor Red
    Write-Host "    - Exception Message...: $($_.Exception.Message)" -ForegroundColor Red
    Write-Host "    - Error On Script Line: $($_.InvocationInfo.ScriptLineNumber)" -ForegroundColor Red
    Write-Host ""
    Write-Host ""
}
Try {
    Disconnect-AzureAD -ErrorAction SilentlyContinue | Out-Null
}
Catch {
    Write-Host ""
    Write-Host "    - Exception Type......: $($_.Exception.GetType().FullName)" -ForegroundColor Red
    Write-Host "    - Exception Message...: $($_.Exception.Message)" -ForegroundColor Red
    Write-Host "    - Error On Script Line: $($_.InvocationInfo.ScriptLineNumber)" -ForegroundColor Red
    Write-Host ""
    Write-Host ""
}

###
# THE END OF THE SCRIPT
###
Write-Host ""
Write-Host " +++ DONE +++ " -ForegroundColor Cyan
Write-Host ""