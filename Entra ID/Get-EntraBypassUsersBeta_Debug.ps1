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

# Audit logs:
$urlTemplate = "auditLogs/signins?`$filter=userPrincipalName eq '{UserPrincipalName}' and status/errorCode ne 0 and IsInteractive eq true&`$select=UserPrincipalName,createdDateTime,location,ipAddress,isInteractive&`$top=1"
$ApiQuery = $urlTemplate
$placeholder = "UserPrincipalName"
$InputObjects = $allGroupMembers | Sort-Object -Unique -Property UserPrincipalName



# Bulk get users:
# NOTE: Requires using ID to lookup, not UPN
$urlTemplate = "/users/{Id}?`$select=UserPrincipalName,AccountEnabled,AssignedLicenses,DisplayName,SignInActivity"
$ApiQuery = $urlTemplate
$placeholder = "Id"
$InputObjects = $allGroupMembers | Sort-Object -Unique -Property UserPrincipalName

# START BELOW

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
$outputList

# convert to hash
$auditLogOutput = $outputList
$auditlogHash = ConvertTo-HashTable -List $auditLogOutput.value -KeyName UserPrincipalName

$userOutput = $outputList
$userHash = ConvertTo-HashTable -List $userOutput -KeyName UserPrincipalName

$mergedHash = Merge-HashTables -First $userHash -Second $auditlogHash


# Format licenses
if ( $h3[$key].assignedLicenses ) {
    $licenses = @()
    $skus = $h3[$key].assignedLicenses
    foreach ($sku in $skus.skuId) {
        $licenses += ($skusMappingTable | Where-Object { $_.GUID -eq "$sku" } | Select-Object -expand DisplayName -Unique)
    }
    $licenses = ($licenses | Sort-Object) -join ', '
    $h3[$key] | Add-Member -MemberType NoteProperty -Name Licenses -Value $licenses -Force
}


$mergedHash.values | ForEach-Object {
    [PSCustomObject]@{
        Id                               = $_.Id
        userPrincipalName                = $_.userPrincipalName
        displayName                      = $_.displayName
        accountEnabled                   = $_.accountEnabled
        assignedLicenses                 = $_.assignedLicenses
        lastSuccessfulSignInDateTime     = $_.signInActivity.lastSuccessfulSignInDateTime
        lastNonInteractiveSignInDateTime = $_.signInActivity.lastNonInteractiveSignInDateTime
        location                         = $_.location
        ipAddress                        = $_.ipAddress
        isInteractive                    = $_.isInteractive
    }
} | Export-Csv c:\temppath\asdasd.csv -NoTypeInformation

