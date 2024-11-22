function Clear-EXOMailboxMobileData {
    
    <#
    .SYNOPSIS
    Using a provided UPN, locate and initiate a data removal command to delete Outlook data from the phone (not a remote wipe)

    .EXAMPLE
    Clear-EXOMailboxMobileData -UserPrincipalName jsmith@contoso.com
    #>

    param(
        [Parameter(Mandatory = $True)]
        [String]$UserPrincipalName	
    )

    if ( !(Test-EXOMailbox -UserPrincipalName $UserPrincipalName) ) {
        return "[Clear mobile devices] Skipped, no mailbox found for $UserPrincipalName"
    }

    $uerPhones = Get-MobileDevice -Mailbox $UserPrincipalName
    if ($null -eq $uerPhones) {
        Write-Output "[Clear mobile devices] No mobile devices found for $UserPrincipalName."
    } else {
        Write-Output "[Clear mobile devices] Found mobile device(s) for $UserPrincipalName. Initiating data removal commands to each device."
        foreach ($p in $uerPhones) {
            Clear-MobileDevice -Identity $p.DistinguishedName -AccountOnly -Confirm:$false
        }
    }
    
}