$aadTenantFQDN = Read-Host "Enter FQDN"
$appName = "Purple Knight"

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



Install-RequiredModules
Connect-Modules


# Create the App Registration
$replyURL = "https://localhost"
if (!($myApp = Get-AzureADApplication -Filter "DisplayName eq '$($appName)'"  -ErrorAction SilentlyContinue)) {
    try {
        $myApp = New-AzureADApplication -DisplayName $appName -ReplyUrls $replyURL
    }
    catch {
        Write-Host $_
        BREAK
    }
    Add-AzADAppPermission -ObjectId $myApp.ObjectId -ApiId 00000003-0000-0000-c000-000000000000 -PermissionId 5b567255-7703-4780-807c-7be8301ae99b -Type Role
    Add-AzADAppPermission -ObjectId $myApp.ObjectId -ApiId 00000003-0000-0000-c000-000000000000 -PermissionId 483bed4a-2ad3-4361-a73b-c83ccdbdc53c -Type Role
    Add-AzADAppPermission -ObjectId $myApp.ObjectId -ApiId 00000003-0000-0000-c000-000000000000 -PermissionId 246dd0d5-5bd0-4def-940b-0421030a5b68 -Type Role
    Add-AzADAppPermission -ObjectId $myApp.ObjectId -ApiId 00000003-0000-0000-c000-000000000000 -PermissionId 134fd756-38ce-4afd-ba33-e9623dbe66c2 -Type Role
    Add-AzADAppPermission -ObjectId $myApp.ObjectId -ApiId 00000003-0000-0000-c000-000000000000 -PermissionId df021288-bdef-4463-88db-98f22de89214 -Type Role
    Add-AzADAppPermission -ObjectId $myApp.ObjectId -ApiId 00000003-0000-0000-c000-000000000000 -PermissionId 230c1aed-a721-4c5d-9cb4-a90514e508ef -Type Role
    Add-AzADAppPermission -ObjectId $myApp.ObjectId -ApiId 00000003-0000-0000-c000-000000000000 -PermissionId 7ab1d382-f21e-4acd-a863-ba3e13f7da61 -Type Role
    Add-AzADAppPermission -ObjectId $myApp.ObjectId -ApiId 00000003-0000-0000-c000-000000000000 -PermissionId 4cdc2547-9148-4295-8d11-be0db1391d6b -Type Role
    Add-AzADAppPermission -ObjectId $myApp.ObjectId -ApiId 00000003-0000-0000-c000-000000000000 -PermissionId 9a5d68dd-52b0-4cc2-bd40-abcf44ac3a30 -Type Role
    Add-AzADAppPermission -ObjectId $myApp.ObjectId -ApiId 00000003-0000-0000-c000-000000000000 -PermissionId 38d9df27-64da-44fd-b7c5-a6fbac20248f -Type Role
    Write-host "New App Registration has been created ($($appName))"
    Write-Host "ACTION REQUIRED: Please grant admin consent to the required permissions through the GUI and upload your certificate there"
}
else {
    Write-Host "Azure app registration already exists: $appName"
}


$aadTenantID = retrieveTenantIDFromTenantFQDN $aadTenantFQDN
If (!$([guid]::TryParse($aadTenantID, $([ref][guid]::Empty)))) {
    Write-Host ""
    Write-Host "Specified Tenant '$aadTenantFQDN' DOES NOT Exist..." -ForegroundColor Red
    Write-Host ""
    Write-Host " => Aborting Script..." -ForegroundColor Red
    Write-Host ""

    BREAK
}
$appID = (Get-AzureADApplication -SearchString $appName).AppId

Write-Host "Directory (tenant) ID: $($aadTenantID)"
Write-Host "Application (client) ID: $($appID)"




# DIsconnect-modules





