function Invoke-GraphPaginatedRequest {
    <#
    .SYNOPSIS
    Helper function to handle paginated requests to Microsoft Graph API.

    .DESCRIPTION
    This function takes a Microsoft Graph API endpoint as input and handles the pagination
    logic to retrieve all objects from that endpoint. It uses the `Invoke-MgGraphRequest`
    cmdlet to make the API calls and checks for the presence of the `@odata.nextLink`
    property in the response to determine if there are more pages of data to retrieve.

    .PARAMETER Uri
    The Microsoft Graph API endpoint to query. This should be a valid URI string.

    .EXAMPLE
    $allUsers = Invoke-GraphPaginatedRequest -URI 'https://graph.microsoft.com/v1.0/users'
    This example retrieves all users from the Microsoft Graph API, handling pagination as needed.
    #>

    [CmdletBinding()]
    param (
        [Parameter(Mandatory = $true)]
        [string]
        $Uri
    )
        $graphResponse = [System.Collections.Generic.List[object]]::new()
        $nextLink = $null
        do {
            $requestUri = if ($nextLink) {
                $nextLink
            } else {
                $Uri
            }
            if ( $Verbose ) {
                $counter = 1
            }
            Write-Verbose "Making paginated Graph request to: $requestUri (count: $counter)"
            try {
                $counter++
                $response = Invoke-MgGraphRequest -Uri $requestUri -Method GET
                if ($response.Value) {
                    $graphResponse.AddRange($response.Value)
                } else {
                    Write-Verbose "Response from $requestUri did not contain a 'value' property."
                }
                $nextLink = $response.'@odata.nextLink'
            } catch {
                Write-Error "Error occurred while making the request to ${requestUri}: $_"
                break
            }

        } until (-not $nextLink)

        $graphResponse
    }