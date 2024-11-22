function Convert-EXOMailboxToShared {

    param(
        [Parameter(Mandatory=$True)]
        [String]$UserPrincipalName
    )

    $status = "Failure"
    $message = $null
    $errorMessage = $null
    $details = $null
    
    # Check that the mailbox exists before proceeding
    try {
        $mailbox = Get-Mailbox -UserPrincipalName $UserPrincipalName -ErrorAction Stop
        # Convert mailbox
        try {
            Set-Mailbox -Identity $mailbox.UserPrincipalName -Type Shared
            $status = "Success"
            $details = $mailbox
            $message = "[Shared Mailbox] Converted $UserPrincipalName to a shared mailbox"
        } catch {
            $errorMessage = "An error occurred attempting to convert $UserPrincipalName to a shared mailbox: $($_.Exception.Message)"
        }
    } catch {
        # No mailbox found for provided UserPrincipalName
        $message = "[Shared Mailbox] Skipped, no mailbox found for $UserPrincipalName"
        $status = "Success"
    }   

    return [PSCustomObject]@{
        FunctionName = $MyInvocation.MyCommand.Name
        Status       = $status
        Message      = $message
        ErrorMessage = $errorMessage
        Details      = $details
    }
	
}