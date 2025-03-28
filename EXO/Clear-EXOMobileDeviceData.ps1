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
    $task = "Clear mobile device data"
    $status = "Failure"
    $results = [System.Collections.Generic.List[System.Object]]::new()
    $removedPhones = New-Object System.Collections.Generic.List[System.Object]

    if ( Test-EXOMailbox -UserPrincipalName $UserPrincipalName ) {
        $userDevices = Get-MobileDevice -Mailbox $UserPrincipalName
        $userDevicesCount = $userDevices.Count
        if ($null -eq $userDevices) {
            $status = "Skipped"
            $message = "No mobile devices found for $UserPrincipalName"
        } else {
            foreach ($p in $userDevices) {
                try {
                    Clear-MobileDevice -Identity $p.DistinguishedName -AccountOnly -Confirm:$false
                    $removedPhones.Add($p)
                    $status = "Success"
                    $errorMessage = $null
                } catch {
                    $message = "Failed to initiate removal command to device"
                    $errorMessage = $_.Exception.Message
                    $details = $p
                    Add-TaskResult -Task $task -Status $status -Message $message -ErrorMessage $errorMessage -Details $details
                }
            }
        }
    } else {
        $status = "Skipped"
        $message = "No mailbox found for $UserPrincipalName"
    }
    
    if ( $removedPhones ) {
        $status = "Success"
        $message = "Initiated data removal commands to each connected device (count: $userDevicesCount)"
        Add-TaskResult -Task $task -Status $status -Message $message -ErrorMessage $errorMessage -Details $removedPhones

    }
    # Output
    return $results

}