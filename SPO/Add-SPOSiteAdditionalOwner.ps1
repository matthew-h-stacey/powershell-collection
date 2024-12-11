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

    try {
        $SPOSiteUrl  = Get-SPOSite -Filter { Url -like "/personal/" } -IncludePersonalSite $true | Where-Object{$_.Owner -like $UserPrincipalName} | Select-Object -ExpandProperty Url
        try {
            Set-SPOUser -Site $SPOSiteUrl -LoginName $OneDriveTrustee -IsSiteCollectionAdmin $true | Out-Null
            $status = "Success"
            $message = "Granted $OneDriveTrustee access to $UserPrincipalName's OneDrive"
        } catch {
            $message = "Failed to grant $OneDriveTrustee access to $UserPrincipalName's OneDrive"
            $errorMessage = $_.Exception.Message
        }
    }
    catch {
        $message = "Failed to locate a OneDrive URL for $UserPrincipalName. Unable to grant $OneDriveTrustee access"
        $errorMessage = $_.Exception.Message
    }

    # Output
    Add-TaskResult -Task $task -Status $status -Message $message -ErrorMessage $errorMessage -Details $details
    return $results
	
}