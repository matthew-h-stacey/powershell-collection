# https://docs.microsoft.com/en-us/microsoft-365/admin/add-users/set-password-to-never-expire?view=o365-worldwide

param (
    # UserPrincipalName of the account to change password expiration on
    [Parameter(Mandatory=$True)][String]$UserPrincipalName
)

# Validate that the UPN provided is for a valid user account
try {
    Get-AzureADUser -ObjectId $UserPrincipalName | Out-Null
}
catch {
    Write-Warning "User not found, please try again"
    exit
}

# Check to see if the password is already set to never expire. If not, continue
$pwExpires = Get-AzureADUser -ObjectId $UserPrincipalName | Select-Object @{L = "PasswordNeverExpires"; E = { $_.PasswordPolicies -contains "DisablePasswordExpiration" } } | Select-Object -ExpandProperty PasswordNeverExpires
if ($pwExpires -eq $True ) {
    Write-Output "SKIPPED: User $($UserPrincipalName) password is already set to never expire. Exiting"
}
else {

    try { # Set the password ot never expire
        Write-Output "Setting user $($UserPrincipalName) password to never expire"
        Set-AzureADUser -ObjectId $UserPrincipalName -PasswordPolicies DisablePasswordExpiration
    }
    catch {
        Write-Warning "An error occurred when setting user $($UserPrincipalName) password to never expire"
        $_
    }

    # Verify that the password expiration has been updated
    $pwExpires = Get-AzureADUser -ObjectId $UserPrincipalName | Select-Object @{L = "PasswordNeverExpires"; E = { $_.PasswordPolicies -contains "DisablePasswordExpiration" } } | Select-Object -ExpandProperty PasswordNeverExpires
    if ( $pwExpires -eq $True) {
        Write-Output "SUCCESS: User $($UserPrincipalName) password successfully set to never expire"
    }
    else {
        Write-Output "FAILURE: Failed to set password expiration on $($UserPrincipalName) to never expire. Please try again"
    }

}
