param
(   
    [Parameter(Mandatory = $true)] [string] $UserPrincipalName, # UPN of the user to clear mobile data and partnerships from
    [Parameter(Mandatory = $false)] [switch] $NativeAppOnly # Optional, use this parameter to ONLY clear native (non-Outlook) mobile app data/partnerships
)
function Connect-Modules {
    # Check if already connected to ExchangeOnline, connect if not connected
    $isConnected = Get-PSSession | Where-Object { $_.Name -like "ExchangeOnlineInternalSession*" -and $_.Availability -like "Available" }

    if ($null -eq $isConnected) {
        Write-Host "[MODULE] Connecting to ExchangeOnline, check for a pop-up authentication window"
        Connect-ExchangeOnline -ShowBanner:$False
    }
}
function Remove-MobileDeviceData {

    Write-Host "[EXO] Attempting to locate mobile devices to delete data from..."
    
    if ($NativeAppOnly) {
        $userPhones = Get-MobileDevice -Mailbox $UserPrincipalName | ? { $_.DeviceModel -notLike "*outlook*" }
    }
    else {
        $userPhones = Get-MobileDevice -Mailbox $UserPrincipalName | ? { $_.DeviceModel -notLike "*outlook*" }
    }
    
    if ($null -eq $userPhones) {
        Write-Host "[EXO] SKIPPED: Remove mobile device data; Reason: No mobile devices found"
    }
    else {
        Write-Host "[EXO] Found mobile device(s). Removing the account from mobile device(s)"
        foreach ($p in $userPhones) {    
            Clear-MobileDevice -Identity $p.DistinguishedName -AccountOnly -Confirm:$false
            Write-Host "[EXO] Initiated email account wipe from mobile device: $($p.FriendlyName),$($p.DeviceModel)"
        }
    }

}

function Remove-MobileDevicePartnerships {

    Write-Host "[EXO] Checking for mobile device partnerships..."
    
    if ($NativeAppOnly) {
        $userPhones = Get-MobileDevice -Mailbox $UserPrincipalName | ? { $_.DeviceModel -notLike "*outlook*" }
        }
        else {
            $userPhones = Get-MobileDevice -Mailbox $UserPrincipalName | ? { $_.DeviceModel -notLike "*outlook*" }
        }

        if ($null -eq $userPhones) {
            Write-Host "[EXO] SKIPPED: Remove mobile device partnerships; Reason: No mobile device partnerships found"
        }
        else {
            Write-Host "[EXO] Found mobile device(s). Removing the account from mobile device(s)"
            foreach ($p in $userPhones) {    
                Remove-MobileDevice -Identity $p.DistinguishedName -Confirm:$False 
                Write-Host "[EXO] Removed mobile device partnership: $($p.FriendlyName),$($p.DeviceModel)"
            }
        }
    }

    Connect-Modules
    Remove-MobileDeviceData
    Write-Host "Waiting 15 minutes before removing mobile device partnerships, please wait ..."
    Start-Sleep -Seconds 13500
    Remove-MobileDevicePartnerships