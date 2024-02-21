<#
.SYNOPSIS
    This script will create an Azure App Registration to report on certificates in use on the tenant and their expirations. This script can very easily be combined with Get-AllCertExpiration.ps1
    which can query the certificates. After creation, the permissions must be consented in the Azure interface. The script also exports the TenantID and ClientID to $exportFile to facilitate
    checking certificates across multiple tenants. For increased security, use certificates instead of secrets to connect to the app. The permissions for the App Registration are as follows: 
    Graph>Application.Read.All, DeviceManagementManagedDevices.Read.All, DeviceManagementServiceConfig.Read.All
.EXAMPLE
	.\New-CertChecker
.NOTES
    Author: Matt Stacey
    Date:   June 15, 2022
#>

# Script variables
$exportFile = ".\Graph_CertChecker_ClientIDs.csv" # Must have headers: Tenant,TenantID,ClientID. Note: "Tenant" header is simply a display name for the client tenant, for example "Contoso"
$appName = "Graph - Certificate Checker" # The name of the App Registration

function Install-RequiredModules {

    if (($null -eq (Get-Module -ListAvailable -Name AzureAD)) -and ($null -eq (Get-Module -ListAvailable -Name AzureADPreview))) {
        Write-Host "[MODULE] Required module AzureAD/AzureADPreview is not installed"
        Write-Host "[MODULE] Installing AzureAD" -ForegroundColor Cyan
        Install-Module AzureAD -Repository PSGallery -AllowClobber -Force -Scope CurrentUser
    } 
    else { 
        Write-Host "[MODULE] AzureAD/AzureADPreview is installed, continuing ..." 
    }
    if ($null -eq (Get-Module -ListAvailable -Name Az.Resources)) {
        Write-Host "[MODULE] Required module Az.Resources is not installed"
        Write-Host "[MODULE] Installing module Az.Resources" -ForegroundColor Cyan
        Install-Module -Name Az.Resources -AllowClobber -Scope CurrentUser -Force
    } 
    else {
        Write-Host "[MODULE] Az.Resources is installed, continuing ..."
    }

}

function Connect-Modules {

    # AzureAD - Import AzureAD module (Powershell 7 compatibility)
    if ( $PSVersionTable.PSVersion.Major -ge 7) { 
        try {
            Import-Module AzureAD -UseWindowsPowershell -ErrorAction SilentlyContinue -WarningAction SilentlyContinue
        }
        catch {
            [System.Management.Automation.RemoteException]
        }
        try {
            Import-Module AzureADPreview -UseWindowsPowershell  -ErrorAction SilentlyContinue -WarningAction SilentlyContinue | Out-Null 
        }
        catch {
            [System.Management.Automation.RemoteException]
        }
    }
    # AzureAD - Check if already connected to AzureAD, connect if not connected
    Write-Host "[MODULE] Connecting to AzureAD, check for a pop-up authentication window"
    try { 
        Get-AzureADTenantDetail -ErrorAction Stop
    } 
    catch {
        Connect-AzureAD | Out-Null
    }
    # Az.Resources - Connect
    Write-Host "[MODULE] Connecting to Az.Resources, check for a pop-up authentication window"
    Import-Module Az.Accounts
    Connect-AzAccount  | Out-Null
}

function Disconnect-Modules {
    Write-host "[MODULE] Disconnecting from all sessions"
    Disconnect-AzureAD | out-null
    Disconnect-AzAccount | out-null
    Get-PSSession | Remove-PSSession
}

Install-RequiredModules
Connect-Modules

# Create the App Registration
$replyURL = "https://localhost"
if (!($myApp = Get-AzureADApplication -Filter "DisplayName eq '$($appName)'"  -ErrorAction SilentlyContinue)) {
    $myApp = New-AzureADApplication -DisplayName $appName -ReplyUrls $replyURL
    Add-AzADAppPermission -ObjectId $myApp.ObjectId -ApiId 00000003-0000-0000-c000-000000000000 -PermissionId 2f51be20-0bb4-4fed-bf7b-db946066c75e -Type Role
    Add-AzADAppPermission -ObjectId $myApp.ObjectId -ApiId 00000003-0000-0000-c000-000000000000 -PermissionId 06a5fe6d-c49d-46a7-b082-56b1b14103c7 -Type Role
    Add-AzADAppPermission -ObjectId $myApp.ObjectId -ApiId 00000003-0000-0000-c000-000000000000 -PermissionId 9a5d68dd-52b0-4cc2-bd40-abcf44ac3a30 -Type Role
    Write-host "New App Registration has been created ($($appName))"
    Write-Host "ACTION REQUIRED: Please grant admin consent to the required permissions through the GUI and upload your certificate there"
}
else {
    Write-Host "Azure app registration already exists: $appName"
}

# Create custom object to retrieve information for the export
$appExport = [PSCustomObject]@{
    Tenant = (Get-AzureADTenantDetail).DisplayName
    TenantID = (Get-AzureADTenantDetail).ObjectID
    ClientID = $myapp.AppId
}

Disconnect-Modules

# Strip the first (header) row so this can be re-run against many different clients to populate a large list of all IDs
$exportCSV = $appExport | ConvertTo-Csv -NoTypeInformation
$null, $IDsOnly = $exportCSV
Add-Content -Path $exportFile -Value $IDsOnly -Encoding UTF8

Write-Host "Exported CSV with tenant/client ID info to $exportFile"
