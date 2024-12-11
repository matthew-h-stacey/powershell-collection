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

    # Construct the filter
    switch ( $PSCmdlet.ParameterSetName ) {
        "DisplayName" { $filter = "DisplayName -eq '" + $DisplayName + "'" }
        "PrimarySmtpAddress" { $filter = "PrimarySmtpAddress -eq '" + $PrimarySmtpAddress + "'"}
        "UserPrincipalName" { $filter = "UserPrincipalName -eq '" + $UserPrincipalName + "'" }
    }
    if ($Shared) {
        $filter += " -and RecipientTypeDetails -eq 'SharedMailbox'"
    } elseif ($User) {
        $filter += " -and RecipientTypeDetails -eq 'UserMailbox'"
    }
    # Retrieve the mailbox
    $mailbox = Get-Mailbox -Filter $filter

    return $mailbox

}