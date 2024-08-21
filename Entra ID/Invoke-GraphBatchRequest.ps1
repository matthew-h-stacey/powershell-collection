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
    $errorList = [System.Collections.Generic.List[System.Object]]::new()

    # Hash table to store original requests by their ID
    $requestCache = @{}

    # 20 is the current maximum size of batch jobs per Microsoft
    $batchSize = 20

    # Retry variables
    $maxRetries = 5  # Maximum number of retry attempts
    $initialDelay = 2 # Initial delay in seconds before the first retry

    # Start processing objects in InputObjects, creating batches of up to 20 Graph queries
    for ($i = 0; $i -lt $InputObjects.Count; $i += $batchSize) {
        Write-Debug "Chunk: $i"
        $end = $i + $batchSize - 1
        if ($end -ge $InputObjects.Count) {
            $end = $InputObjects.Count - 1
        }
        $index = $i
        $graphBatchRequests = $InputObjects[$i..$end] | ForEach-Object {
            # Replace the placeholder from the Url with the actual value
            if ( $Placeholder) {
                $propertyValue = $_.$Placeholder
                $url = $ApiQuery -replace "\{$Placeholder\}", $propertyValue
            } else {
                $url = $ApiQuery
            }
            $request = [PSCustomobject]@{
                'Id'     = ++$index
                'Method' = 'GET'
                'Url'    = $url
            }
            # Store the original request in the cache
            $requestCache[$request.Id.ToString()] = $request

            # Return the request object to $graphBatchRequests
            $request
        }
        # Construct and format the batch query as JSON
        $graphBatchParams = @{
            'Method'      = 'Post'
            'Uri'         = 'https://graph.microsoft.com/v1.0/$batch'
            'ContentType' = 'application/json'
            'Body'        = @{
                'requests' = $graphBatchRequests
            } | ConvertTo-Json
        }

        # Retrieve and format the output
        $graphBatchResponse = Invoke-MgGraphRequest @graphBatchParams

        foreach ( $response in $graphBatchResponse.responses ) {
            # Store the current response in a variable
            $originalRequest = $requestCache[$response.id]
            $retryCount = 1
            $timeStamp = Get-Date -Format "yyyy-MM-ddTHH:mm:ssK"

            switch ($response.status) {
                200 {
                    # 200 = OK
                    Write-Output "$timeStamp [SUCCESS] Request ID $($response.id) succeeded with status code: $($response.status)"
                    $outputList.Add([PSCustomObject]$response.body)
                }
                429 {
                    # 429 = Too many requests (throttling)
                    $retryAfter = $response.headers.'retry-after'
                    Write-Output "$timeStamp [WARNING] Request ID $($response.id) was throttled. Retrying after $retryAfter seconds"
                    do {
                        Start-Sleep -Seconds $retryAfter
                        Write-Output "$timeStamp [INFO] Request ID $($response.id)] - retrying request... (attempt $retryCount/$maxRetries)"

                        # Retry the throttled request
                        $throttledRequest = @{
                            Id     = $originalRequest.id
                            Method = $originalRequest.method
                            Url    = $originalRequest.url
                        }
                        $retryRequest = @{
                            requests = @($throttledRequest)
                        } | ConvertTo-Json -Depth 10
                        $retryParams = @{
                            'Method'      = 'Post'
                            'Uri'         = 'https://graph.microsoft.com/v1.0/$batch'
                            'ContentType' = 'application/json'
                            'Body'        = $retryRequest
                        }

                        # Process the retried response and add to output
                        try {
                            $retryResponse = Invoke-MgGraphRequest @retryParams
                            if ( $retryResponse.responses.status -eq 200) {
                                $timeStamp = Get-Date -Format "yyyy-MM-ddTHH:mm:ssK"
                                $outputList.Add([PSCustomObject]$retryResponse.responses.body)
                                Write-Output "$timeStamp [SUCCESS] Request ID $($response.id) succeeded with status code: $($retryResponse.responses.status)"
                                break
                            }
                            $retryCount++
                            if ($retryCount -ge $maxRetries) {
                                Write-Output "$timeStamp [ERROR] Request ID $($response.id)] skipped due to max retries reached"
                                $errorList.Add([pscustomobject]@{
                                        Id     = $response.id
                                        Status = $retryResponse.responses.status
                                        Error  = $retryResponse.responses.body.error.message
                                        Object = $retryResponse
                                    })
                                break
                            }
                            $retryAfter = $initialDelay * [math]::Pow(2, $retryCount)
                        } catch {
                            Write-Output "$timeStamp [ERROR] Request ID $($response.id)] failed after retry with status code $($retryResponse.status). Error: $($retryResponse.body.error.message)"
                            $errorList.Add([pscustomobject]@{
                                    Id     = $response.id
                                    Status = $retryResponse.responses.status
                                    Error  = $retryResponse.responses.body.error.message
                                    Object = $retryResponse
                                })   
                        }
                    } while ( $retryCount -lt $maxRetries )
                }
                default {
                    # Log errors for unexpected status codes
                    Write-Output "$timeStamp [ERROR] Request ID $($response.id)] failed with status code $($response.status). Error: $($response.body.error.code) $($response.body.error.message)"
                    $errorList.Add([pscustomobject]@{
                            Id     = $response.id
                            Status = $response.status
                            Url    = $originalRequest.url
                            Error  = $response.body
                        })
                }
            }            
        }
    }
    return $outputList
}

