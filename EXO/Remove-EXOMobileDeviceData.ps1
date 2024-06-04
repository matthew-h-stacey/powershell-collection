<#
.SYNOPSIS
This script does something useful.

.DESCRIPTION
This script performs some important tasks.

.PARAMETER Parameter1
Specifies the first parameter. Explain what it does.

.PARAMETER Parameter2
Specifies the second parameter. Explain its purpose.

.EXAMPLE
Remove-EXOMobileDeviceData.ps1 -UserPrincipalName jsmith@contoso.com
#>

param (   
    # UPN of the user to clear mobile data and partnerships from    
    [Parameter(Mandatory = $true)]
    [string[]]
    $UserPrincipalName,
    
    # Optional, use this parameter to ONLY clear native (non-Outlook) mobile app data/partnerships
    [Parameter(Mandatory = $false)]
    [switch]
    $NativeAppOnly,

    # Display output but do not perform any actions
    [Parameter(Mandatory=$false)]
    [switch]
    $WhatIf
)

function Remove-MobileDeviceData {

    param(
        # Display output but do not perform any actions
        [Parameter(Mandatory=$false)]
        [switch]
        $WhatIf
    )

    foreach ($UPN in $UserPrincipalName) {
        Write-Output "[INFO] Attempting to locate $($UPN)'s mobile devices to delete data from..."
        if ($NativeAppOnly) {
            $userPhones = Get-MobileDevice -Mailbox $UPN | Where-Object { $_.DeviceModel -notLike "*outlook*" }
        } else {
            $userPhones = Get-MobileDevice -Mailbox $UPN
        }
        if ( $userPhones ) {
            Write-Output "[INFO] Found mobile device(s). Removing the account from mobile device(s)"
            foreach ($p in $userPhones) {
                if ( $WhatIf ) {
                    Write-Output "[INFO] Initiated email account wipe from mobile device: $($p.Name),$($p.DeviceModel)"
                } else {
                    Clear-MobileDevice -Identity $p.DistinguishedName -AccountOnly -Confirm:$false
                    Write-Output "[INFO] Initiated email account wipe from mobile device: $($p.Name),$($p.DeviceModel)"
                }
            }
        } else {
            Write-Output "[INFO] SKIPPED: Remove mobile device data; Reason: No mobile devices found"
        } 
    }

}

function Remove-MobileDevicePartnerships {

    param(
        # Display output but do not perform any actions
        [Parameter(Mandatory = $false)]
        [switch]
        $WhatIf
    )

    foreach ($UPN in $UserPrincipalName) {
        Write-Output "[INFO] Checking for mobile device partnerships..."
        if ($NativeAppOnly) {
            $userPhones = Get-MobileDevice -Mailbox $UserPrincipalName | Where-Object { $_.DeviceModel -notLike "*outlook*" }
        }
        else {
            $userPhones = Get-MobileDevice -Mailbox $UserPrincipalName | Where-Object { $_.DeviceModel -notLike "*outlook*" }
        }
        if ($null -eq $userPhones) {
            Write-Output "[INFO] SKIPPED: Remove mobile device partnerships; Reason: No mobile device partnerships found"
        }
        else {
            Write-Output "[INFO] Found mobile device(s). Removing the account from $($UPN)'s mobile device(s)"
            foreach ($p in $userPhones) {
                if ( $WhatIf ) {
                    Write-Output "[INFO] Removed mobile device partnership: $($p.Name),$($p.DeviceModel)"
                } else {
                    Remove-MobileDevice -Identity $p.DistinguishedName -Confirm:$False 
                    Write-Output "[INFO] Removed mobile device partnership: $($p.Name),$($p.DeviceModel)"
                }
            }
        }
    }
}

if ( $WhatIf ) {
    Remove-MobileDeviceData -WhatIf
    Remove-MobileDevicePartnerships -WhatIf
} else {
    Remove-MobileDeviceData
    Write-Output "[INFO] Waiting 15 minutes before removing mobile device partnerships, please wait ..."
    Start-Sleep -Seconds 900
    Remove-MobileDevicePartnerships
}