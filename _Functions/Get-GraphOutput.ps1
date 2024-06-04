function Get-GraphOutput {

    <#
    .SYNOPSIS
    This is a simple function to perform a GET request to a Graph endpoint with support for 999+ objects

    .EXAMPLE
    Get-GraphOutput -URI  https://graph.microsoft.com/v1.0/users/$UserPrincipalName/chats/getAllMessages
    #>

    param(
        # URI to retrieve output from
        [Parameter(Mandatory = $true)]
        [String]
        $URI
    )

    $method = "GET"
    $msGraphOutput = @()
    $nextLink = $null
    do {
        $uri = if ($nextLink) {
            $nextLink
        } else {
            $uri
        }
        try {
            $response = Invoke-MgGraphRequest -Uri $uri -Method $method
        } catch {
            Write-Output "[ERROR] Failed to retrieve output from MS Graph. Error:"
            $_.ErrorDetails.Message
            exit
        }
        $output = $response.Value
        $msGraphOutput += $output
        $nextLink = $response.'@odata.nextLink'
    } until (-not $nextLink)

    return $msGraphOutput
}