function Invoke-GraphPaginatedRequest {
        <#
    .SYNOPOSIS
    Perform a GET against a Graph endpoint with support for 999+ objects

    .PARAMETER Uri
    The full Graph endpoint to query

    .EXAMPLE
    $graphResponse = Invoke-GraphPaginatedRequest -Uri $uri
    #>
        param (
            [Parameter(Mandatory = $true)]
            [string]
            $Uri
        )
        $graphResponse = @()
        $nextLink = $null
        do {
            # Check for nextLink
            $Uri = if ($nextLink) {
                $nextLink
            } else {
                $Uri
            }
            # Perform Graph Request
            $response = try {
                Invoke-MgGraphRequest -Uri $Uri -Method GET
            } catch {
                Write-Error "Microsoft Graph query failed. Error: $($_.Exception.Message)"
                exit 1
            }
            $output = $response.Value
            $graphResponse += $output
            $nextLink = $response.'@odata.nextLink'
        } until (-not $nextLink)

        return $graphResponse
    }