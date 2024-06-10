function Convert-EXOMailboxToShared {

    param(
        [Parameter(Mandatory = $True)]
        [String]
        $UserPrincipalName
    )

    # Check that the mailbox exists before proceeding
    if ( !(Test-EXOMailbox -UserPrincipalName $UserPrincipalName) ) {
        return "[Shared Mailbox] Skipped, no mailbox found for $UserPrincipalName"
    }
    
    try {
        Set-Mailbox -Identity $UserPrincipalName -Type Shared
        Write-Output "[Shared Mailbox] Converted $UserPrincipalName to a shared mailbox"
    } catch {
        Write-Output "An error occurred attempting to convert $UserPrincipalName to a shared mailbox:"
        Write-Output $_.Exception.Message
    }
	
}