function Convert-EXOMailboxToShared {

    param(
        [Parameter(Mandatory = $true)]
        [string]
        $UserPrincipalName
    )

    function Add-TaskResult {
        param(
            [string]$Task,
            [string]$Status,
            [string]$Message,
            [string]$ErrorMessage = $null,
            [string]$Details = $null
        )
        $results.Add([PSCustomObject]@{
                FunctionName = $function
                Task         = $Task
                Status       = $Status
                Message      = $Message
                Details      = $Details
                ErrorMessage = $ErrorMessage
            })
    }

    # Initialize output variables
    $function = $MyInvocation.MyCommand.Name
    $task = "Convert UserMailbox to SharedMailbox"
    $status = "Failure"
    $results = [System.Collections.Generic.List[System.Object]]::new()

    # Confirm the mailbox exists before proceeding
    $mailbox = Test-EXOMailbox -UserPrincipalName $UserPrincipalName
    if ( $mailbox ) {
        if ( $mailbox.RecipientTypeDetails -eq "SharedMailbox" ) {
            $status = "Skipped"
            $message = "Mailbox is already a SharedMailbox: $UserPrincipalName"
        } else {
            # Convert the mailbox
            try {
                Set-Mailbox -Identity $mailbox.UserPrincipalName -Type Shared
                $status = "Success"
                $message = "Converted $UserPrincipalName to a shared mailbox"
            } catch {
                $message = "An error occurred attempting to convert $UserPrincipalName to a shared mailbox"
                $errorMessage = $_.Exception.Message
            }
        }
    } else {
        $status = "Skipped"
        $message = "No mailbox found with UserPrincipalName: $UserPrincipalName"
    }

    # Output
    Add-TaskResult -Task $task -Status $status -Message $message -ErrorMessage $errorMessage
    return $results
    
}