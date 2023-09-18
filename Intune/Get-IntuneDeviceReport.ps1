function Get-IntuneDeviceReport {
	
    param(
    )

	$ClientName = (Get-CustomerContext).CustomerName
    $HTMLReportName = "$($ClientName) Managed Device Report"
    $HTMLReportFooter = "Report created using SkyKick Cloud Manager"

    $URI = 'https://graph.microsoft.com/v1.0/deviceManagement/managedDevices?$top=999'
    $MSGraphOutput = @()

	# Retrieve all objects from MS Graph GET request, supports >1000 objects
    $nextLink = $null
    do {
        $uri = if ($nextLink) { $nextLink } else { $URI }
        $response = Invoke-MgGraphRequest -Uri $uri -Method GET
        $output = $response.Value
        $MSGraphOutput += $output
        $nextLink = $response.'@odata.nextLink'
    } until (-not $nextLink)

	# Select key properties from devices and add them to $results for output
    $results = @()
    $results = $MSGraphOutput | Select-Object `
        deviceName,
    	operatingSystem,
    	osVersion,
    	manufacturer,
    	model,
    	userPrincipalName,
    	azureADRegistered,
    	deviceRegistrationState,
    	managedDeviceOwnerType,
    	deviceEnrollmentType,
    	enrolledDateTime,
    	lastSyncDateTime,
    	complianceState,
    	isEncrypted

	$results | Out-SkyKickTableToHtmlReport -IncludePartnerLogo -ReportTitle $HTMLReportName -ReportFooter $HTMLReportFooter -OutTo NewTab

}