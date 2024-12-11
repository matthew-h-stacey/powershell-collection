function Set-EXOMailboxGALVisibility {

    <#
    .SYNOPSIS
    Show or hide a mailbox in the GAL

    .EXAMPLE
    Hide from GAL: Set-EXOMailboxGALVisibility -UserPrincipalName $UPN -Hidden:$true
    Show in GAL: Set-EXOMailboxGALVisibility -UserPrincipalName $UPN -Hidden:$false
    #>
    
    param(
        [Parameter(Mandatory = $True)]
        [String]$UserPrincipalName,
        
        [Parameter(Mandatory = $True)]
        [Boolean]$Hidden
    )

    # Helper function
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
    $task = "Set Exchange Online GAL visibility"
    $status = "Failure"
    $results = [System.Collections.Generic.List[System.Object]]::new()

    # Strings for output
    if ( $Hidden ) {
        $visibility = "hidden"
        $visibilityAction = "hidden"
    } else {
        $visibility = "visible"
        $visibilityAction = "made visible"
    }

    $mailbox = Test-EXOMailbox -UserPrincipalName $UserPrincipalName
    if ( $mailbox ) {
        $isHidden = $mailbox.HiddenFromAddressListsEnabled
        if ( $isHidden -eq $Hidden ) {
            $status = "Skipped"
            $message = "No change needed. Mailbox is already $visibility in the GAL"
        } else {
            try {
                Set-Mailbox -Identity $UserPrincipalName -HiddenFromAddressListsEnabled:$Hidden
                $status = "Success"
                $message = "$UserPrincipalName mailbox has been $visibilityAction in the GAL"
                $errorMessage = $null
            } catch {
                $message = "An error occurred attempting to update $UserPrincipalName GAL visibility"
                $errorMessage = $_.Exception.Message
            }
        }
    } else {
        $status = "Skipped"
        $message = "No mailbox found for $UserPrincipalName"

    }
    Add-TaskResult -Task $task -Status $status -Message $message -ErrorMessage $errorMessage
    return $results
    
}