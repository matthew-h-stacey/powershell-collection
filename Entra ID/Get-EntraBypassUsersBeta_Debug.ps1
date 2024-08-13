# DEBUGGING


# RUN ONCE, LEAVE COMMENTED AFTER

connect-mggraph -scopes directory.read.all,policy.read.all,auditlog.read.all
$skusMappingTable = Import-Csv "C:\Users\mstacey\powershell-collection\_Resources\M365_License_to_friendlyName.csv"
$namedLocations = Get-EntraNamedLocations
$allGroupMembers = [System.Collections.Generic.List[System.Object]]::new()
$bypassgroups = Get-MgGroup -Search "displayName:bypass" -Sort "displayName" -CountVariable CountVar -ConsistencyLevel eventual 
foreach ($bypassgroup in $bypassgroups) {
    $groupMembers = Get-MgGroupTransitiveMember  -GroupId $bypassgroup.Id -All
    foreach ($groupmember in $groupmembers) {
        # If the member has a UPN, add it to allGroupMembers to try to find sign-in information
        if ( $groupmembers.additionalproperties.userPrincipalName ) {
            $allGroupMembers.Add([PSCustomObject]@{
                    Id                = $groupMember.Id
                    DisplayName       = $groupMember.AdditionalProperties.displayName
                    UserPrincipalName = $groupMember.AdditionalProperties.userPrincipalName
                    BypassGroup       = $bypassgroup.DisplayName
                })
        }
    }
}


$urlTemplate = "auditLogs/signins?`$filter=userPrincipalName eq '{UserPrincipalName}' and status/errorCode ne 0 and IsInteractive eq true&`$select=UserPrincipalName,createdDateTime,location,ipAddress,isInteractive&`$top=1"
$placeholder = "UserPrincipalName"
$InputObjects = $allGroupMembers | Sort-Object UserPrincipalName
$ApiQuery = $urlTemplate

# WIP
# Getting 3200 results vs. 161 of InputObjects. something getting 40x'd or it is pulling too many users

# START BELOW

# Empty list to store results in
$outputList = [System.Collections.Generic.List[System.Object]]::new()
$errorList = [System.Collections.Generic.List[System.Object]]::new()

# Hash table to store original requests by their ID
$requestCache = @{}

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

        switch ($response.status) {
            200 {
                # 200 = OK
                Write-Host "Request ID $($response.id) succeeded with status code $($response.status)."
                $outputList.Add([PSCustomObject]$response.body)
            }
            429 {
                # 429 = Too many requests (throttling)
                $retryAfter = $response.headers.'retry-after'
                Write-Output "Request ID $($response.id) was throttled. Retrying after $retryAfter seconds."
                Start-Sleep -Seconds $retryAfter
                Write-Output "Retrying batch URL: $($originalRequest.Url)"

                # Retrieve the original request that was throttled details using the ID
                $throttledRequest = @{
                    Id     = $originalRequest.id
                    Method = $originalRequest.method
                    Url    = $originalRequest.url
                }
                $retryRequest = @{
                    requests = @($throttledRequest)
                } | ConvertTo-Json -Depth 10

                # Retry the failed request
                $retryParams = @{
                    'Method'      = 'Post'
                    'Uri'         = 'https://graph.microsoft.com/v1.0/$batch'
                    'ContentType' = 'application/json'
                    'Body'        = $retryRequest
                }

                # Process the retried response and add to output
                try {
                    $retryResponse = Invoke-MgGraphRequest @retryParams
                    $outputList.Add([PSCustomObject]$retryResponse.responses.body)
                } catch {
                    Write-Output "Request ID $($response.id) failed after retry with status code $($retryResponse.status). Error: $($retryResponse.body.error.message)"
                    $errorList.Add([pscustomobject]@{
                            Id     = $response.id
                            Object = $retryResponse
                        })
                }
            }
            default {
                # Log errors for unexpected status codes
                Write-Output "Request ID $($response.id) failed with status code $($response.status). Error: $($response.body.error.message)"
                $errorList.Add([pscustomobject]@{
                    Id     = $response.id
                    Status = $response.status
                    Error  = $response.body
                })

            }
        }
    }
}
$outputList

