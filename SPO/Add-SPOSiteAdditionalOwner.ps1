function Add-SPOSiteAdditionalOwner {

    param(
        [Parameter(Mandatory=$True)]
        [String]
        $UserPrincipalName,

        [Parameter(Mandatory=$True)]
        [String]
        $OneDriveTrustee
        
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
    $task = "Grant access to OneDrive personal site"
    $status = "Failure"
    $results = [System.Collections.Generic.List[System.Object]]::new()
    
    $spoSiteUrl = Get-SPOSite -Filter "Owner -like $UserPrincipalName -and Url -like '/personal'" -IncludePersonalSite $true
    if ( $spoSiteUrl ) {
        try {
            Set-SPOUser -Site $spoSiteUrl -LoginName $OneDriveTrustee -IsSiteCollectionAdmin $true | Out-Null
            $status = "Success"
            $message = "Granted $OneDriveTrustee access to $UserPrincipalName's OneDrive"
        } catch {
            $message = "Failed to grant $OneDriveTrustee access to $UserPrincipalName's OneDrive"
            $errorMessage = $_.Exception.Message
        }
    } else {
        $message = "Failed to locate a OneDrive URL for $UserPrincipalName. Unable to grant $OneDriveTrustee access"
        $errorMessage = $_.Exception.Message
    }

    # Output
    Add-TaskResult -Task $task -Status $status -Message $message -ErrorMessage $errorMessage -Details $details
    return $results
	
}