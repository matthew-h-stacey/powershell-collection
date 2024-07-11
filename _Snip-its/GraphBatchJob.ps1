# The input array to split into batches
$users = Get-MgUser -All

# The maximum batch size to use is 20
$batchSize = 20

# The list used to store results
$usersDetails = [System.Collections.Generic.List[System.Object]]::new()

# Iterate through the input array to chunk it up into batches
for ($i = 0; $i -lt $users.Length; $i += $batchSize) {
    
    # Display chunk index
    Write-Output "Chunk $i"

    # Set the end index of this chunk
    $end = $i + $batchSize - 1

    # If this is the last chunk in the batch, set the end to be the very last object
    if ($end -ge $users.Length) {
        $end = $users.Length
    }

    # Work through the input array for the objects in the selected chunk only
    # For each of the selected items, create a PSCustomObject with an Id for the request, the Method, and Url used to retrieve the data
    $index = $i
    $requests = $users[$i..($end)] | ForEach-Object {
        [PSCustomObject]@{
            'Id'     = ++$index
            'Method' = 'GET'
            'Url'    = "users/{0}" -f $PSItem.Id 
        }
    }

    # Create a batch request using the previously created $results
    $requestParams = @{
        'Method'      = 'Post'
        'Uri'         = 'https://graph.microsoft.com/v1.0/$batch'
        'ContentType' = 'application/json'
        'Body'        = @{
            'requests' = @($requests)
        } | ConvertTo-Json
    }
    $response = Invoke-MgGraphRequest @requestParams

    # Invoke-MgGraphRequest deserializes request to a hashtable
    # Add all items to the list created at the start
    $response.responses | ForEach-Object { $usersDetails.Add([pscustomobject]$PSItem.body) }
}
# If the response does not match the count of the inputted objects, throw an error
if ($usersDetails.Count -ne $users.Count) {
    throw [System.Exception]::new()
}