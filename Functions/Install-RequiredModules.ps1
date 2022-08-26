function Install-RequiredModules {

    # Check if ExchangeOnlineManagement is installed and connect if no connection exists
    if ($null -eq (Get-Module -ListAvailable -Name ExchangeOnlineManagement)) {
        Write-Host "Required module ExchangeOnlineManagement is not installed"
        Write-Host "Installing ExchangeOnlineManagement" -ForegroundColor Cyan
        Install-Module ExchangeOnlineManagement -Repository PSGallery -AllowClobber -Force -Scope CurrentUser
    } 
    else{ 
        Write-Host "ExchangeOnlineManagement is installed, continuing ..." 
    }

    # Check if AzureAD/AzureADPreview is installed and connect if no connection exists
    if (($null -eq (Get-Module -ListAvailable -Name AzureAD)) -and ($null -eq (Get-Module -ListAvailable -Name AzureADPreview))) {
        Write-Host "Required module  AzureAD/AzureADPreview is not installed"
        Write-Host "Installing AzureAD" -ForegroundColor Cyan
        Install-Module AzureAD -Repository PSGallery -AllowClobber -Force -Scope CurrentUser
    } 
    else { 
        Write-Host "AzureAD/AzureADPreview is installed, continuing ..." 
    }


    # Check if MSOnline is installed and connect if no connection exists
    if ($null -eq (Get-Module -ListAvailable -Name MSOnline)) {
        Write-Host "Required module MSOnline is not installed"
        Write-Host "Installing MSOnline" -ForegroundColor Cyan
        Install-Module MSOnline -Repository PSGallery -AllowClobber -Force -Scope CurrentUser
    } 
    else { 
        Write-Host "MSOnline is installed, continuing ..." 
    }

    # Check if Microsoft.Online.SharePoint.PowerShell is installed and connect if no connection exists
    if ($null -eq (Get-Module -ListAvailable -Name Microsoft.Online.SharePoint.PowerShell)) {
        Write-Host "Required module Microsoft.Online.SharePoint.PowerShell is not installed"
        Write-Host "Installing Microsoft.Online.SharePoint.PowerShell" -ForegroundColor Cyan
        Install-Module Microsoft.Online.SharePoint.PowerShell -Repository PSGallery -AllowClobber -Force -Scope CurrentUser
    } 
    else { 
        Write-Host "Microsoft.Online.SharePoint.PowerShell is installed, continuing ..." 
    }

}

