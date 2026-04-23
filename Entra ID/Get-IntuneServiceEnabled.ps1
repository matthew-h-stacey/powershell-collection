function Get-IntuneServiceEnabled {

    try {
        # Query the deviceManagement endpoint to check if Intune is enabled
        # Successful response indicates deviceManagement API is available
        # Store as a variable to suppress output
        $response = Invoke-MgGraphRequest -Uri https://graph.microsoft.com/v1.0/deviceManagement -Method GET
        return $true
    } catch {
        if ( $_.Exception.Response ) {
            # Retrieve the actual HTTP status code from the exception
            $statusCode = $_.Exception.Response.StatusCode.Value__
        } else {
            $statusCode = $null
        }
        $errorCaught = $_
        switch ($statusCode) {
            400 {
                # If the status code is 400, it can indicate that the request is not applicable to the target tenant
                return $false
            }
            403 {
                # If the status code is 403, it can indicate that the user does not have permissions to access the deviceManagement API, which may suggest that Intune is not enabled
                Write-Error "[ERROR] 403 Access forbidden. This may indicate that Intune is not enabled or you do not have permissions to access the deviceManagement API. Ensure one of the following permissions are granted: DeviceManagementConfiguration.Read.All, DeviceManagementConfiguration.ReadWrite.All"
            }
            default {
                # Throw any other exceptions
                throw $errorCaught
            }
        }


    }

}