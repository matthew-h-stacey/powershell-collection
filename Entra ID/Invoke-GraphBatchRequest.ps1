function Invoke-GraphBatchRequest {
    <#
    .SYNOPSIS
    Execute a batch GET request to an API endpoint

    .DESCRIPTION
    This functions takes a collection of objects and iterates through them to build batch Graph requests (max: 20 requests in a batch). The purpose of this is to gain better performance versus running individual Graph queries for each object in the collection. This also helps to prevent/reduce throttling.

    .PARAMETER InputObjects
    The collection to run the batch query on

    .PARAMETER ApiQuery
    The API endpoint to query. The base URL is a Graph batch endpoint, so this is just the portion after /1.0/ or /beta/ and any relevant filters

    .PARAMETER Placeholder
    If you are passing objects and need a variable to differentiate them for ApiQuery construction, enclose the variable in quotes and specify it here. See example below

    .EXAMPLE
    Assume $allGroupMembers is a collection of user objects with the property "UserPrincipalName"
    The following uses the auditLogs/signins endpoint to query signins for all users in the collection, filtering by successful interactive logins for each user
    The most important parts to review are the formatting of the endpoint and usage of the placeholder - which is {Property} and declared in -Placeholder
    Those properties are replaced as the function processes each object

    $urlTemplate = "auditLogs/signins?`$filter=userPrincipalName eq '{UserPrincipalName}' and status/errorCode ne 0 and IsInteractive eq true&`$top=1"
    $graphResponse = Invoke-GraphBatchRequest -InputObjects $allGroupMembers -ApiQuery $urlTemplate -Placeholder "UserPrincipalName"
    
    #>
    param (
        [Parameter(Mandatory = $true)]
        [Object[]]
        $InputObjects,

        [Parameter(Mandatory = $true)]
        [string]
        $ApiQuery,

        [Parameter(Mandatory = $false)]
        [string]
        $Placeholder
    )

    # Empty list to store results in
    $outputList = [System.Collections.Generic.List[System.Object]]::new()
    
    # 20 is the current maximum size of batch jobs per Microsoft
    $batchSize = 20

    # Start processing objects in InputObjects, creating batches of up to 20 Graph queries
    for ($i = 0; $i -lt $InputObjects.Count; $i += $batchSize) {
        Write-Debug "Chunk: $i"
        $end = $i + $batchSize - 1
        if ($end -ge $InputObjects.Count) {
            $end = $InputObjects.Count - 1
        }
        $index = $i
        $requests = $InputObjects[$i..$end] | ForEach-Object {
            # Replace the placeholder from the Url with the actual value
            if ( $Placeholder) {
                $propertyValue = $_.$Placeholder
                $url = $ApiQuery -replace "\{$Placeholder\}", $propertyValue
            } else {
                $url = $ApiQuery
            }
            [PSCustomObject]@{
                'Id'     = ++$index
                'Method' = 'GET'
                'Url'    = $url
            }
        }
        # Construct and format the batch query as JSON
        $requestParams = @{
            'Method'      = 'Post'
            'Uri'         = 'https://graph.microsoft.com/v1.0/$batch'
            'ContentType' = 'application/json'
            'Body'        = @{
                'requests' = $requests
            } | ConvertTo-Json
        }

        # Retrieve and format the output
        $response = Invoke-MgGraphRequest @requestParams
        $response.responses | ForEach-Object { $outputList.Add([pscustomobject]$PSItem.body) }
    
    }
    return $outputList
}

