<#
.SYNOPSIS
This function is used to either return a mailbox (if located) or null without errors

.PARAMETER DisplayName
Locate the mailbox by DisplayName

.PARAMETER PrimarySmtpAddress
Locate the mailbox by PrimarySmtpAddress

.PARAMETER UserPrincipalName
Locate the mailbox by UserPrincipalName

.PARAMETER Shared
Optionally filter results by shared mailboxes only. Can be useful if you explicitly want (or don't want) to run something on a shared mailbox

.PARAMETER User
Optionally filter results by user mailboxes only. Can be useful if you explicitly want (or don't want) to run something on a user mailbox

.EXAMPLE
if ( Test-EXOMailbox -UserPrincipalName jsmith@contoso.com ) {
    # do the thing
}
#>

function Test-EXOMailbox {
    
    param (
        # Locate mailbox using a DisplayName
        [Parameter(Mandatory = $true, ParameterSetName = "DisplayName")]
        [string]
        $DisplayName,

        # Locate mailbox using a PrimarySmtpAddress
        [Parameter(Mandatory = $true, ParameterSetName = "PrimarySmtpAddress")]
        [string]
        $PrimarySmtpAddress,

        # Locate mailbox using a UserPrincipalName
        [Parameter(Mandatory = $true, ParameterSetName = "UserPrincipalName")]
        [string]
        $UserPrincipalName,

        # Return mailbox object only if it is a shared mailbox
        [Parameter(Mandatory = $false, ParameterSetName = "Shared")]
        [Parameter(ParameterSetName = "DisplayName")]
        [Parameter(ParameterSetName = "PrimarySmtpAddress")]
        [Parameter(ParameterSetName = "UserPrincipalName")]
        [switch]
        $Shared,

        # Return mailbox object only if it is a user mailbox
        [Parameter(Mandatory = $false, ParameterSetName = "User")]
        [Parameter(ParameterSetName = "DisplayName")]
        [Parameter(ParameterSetName = "PrimarySmtpAddress")]
        [Parameter(ParameterSetName = "UserPrincipalName")]
        [switch]
        $User
    )

    # Adjust the filter based on the provided identity
    switch ( $PSCmdlet.ParameterSetName ) {
        "DisplayName" { $filter = "DisplayName -like '" + $DisplayName + "'" }
        "PrimarySmtpAddress" { $filter = "PrimarySmtpAddress -like '" + $PrimarySmtpAddress + "'"}
        "UserPrincipalName" { $filter = "UserPrincipalName -like '" + $UserPrincipalName + "'" }
    }

    $mailbox = Get-Mailbox -Filter $filter

    # Selectively return the mailbox based on the usage or absense one of the switches
    if ( $Shared ) {
        if ( $mailbox.RecipientTypeDetails -eq "SharedMailbox") {
            return $mailbox
        }
    } elseif ( $User ) {
        if ( $mailbox.RecipientTypeDetails -eq "UserMailbox") {
            return $mailbox
        }
    } else {
        return $mailbox
    }

}