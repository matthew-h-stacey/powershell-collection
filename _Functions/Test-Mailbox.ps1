function Test-EXOMailbox {

    <#
    .SYNOPSIS
    This function is used to either return a mailbox (if located) or null without errors

    .EXAMPLE
    if ( Test-EXOMailbox -UserPrincipalName jsmith@contoso.com ) {
        # do the thing
    }
    #>
    
    param (
        [Parameter(Position=0)]
        [string]$UserPrincipalName,
        [string]$PrimarySmtpAddress,
        [string]$DisplayName
    )

    if ( $UserPrincipalName ) {
        $filter = "UserPrincipalName -like '" + $Userprincipalname + "'"
    }
    if ( $PrimarySmtpAddress ) {
        $filter = "PrimarySmtpAddress -like '" + $PrimarySmtpAddress + "'"
    }
    if ( $DisplayName ) {
        $filter = "DisplayName -like '" + $DisplayName + "'"
    }        
    $mailbox = Get-Mailbox -Filter $filter
    return $mailbox

}