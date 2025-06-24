function Get-EntraDirSyncStatus {

    <#
    .SYNOPSIS
        Checks the status of DirSync/Entra ID Connect for specified clients.
    .DESCRIPTION
        This script checks the DirSync/Entra ID Connect status for specified clients. It retrieves the last sync time
        and determines if the sync is active or stale based on a 2-hour threshold. Results are output to a report.
    #>

    [SkyKickCommand(DisplayName = "Set Parameter Sections", Sections = { "Client", "Scope" })]
    param(
        [SkyKickParameter(
            DisplayName = "Client(s)"
        )]
        [Parameter(Mandatory = $true)]
        [CustomerContext[]]
        $Clients,

        [SkyKickParameter(
            DisplayName = "Stale only?"
        )]
        [Bool]
        $StaleOnly = $False
    )

    # Report variables
    $results = New-Object System.Collections.Generic.List[System.Object] # list to store results
    $customerContext = Get-CustomerContext
    $clientName = $customerContext.CustomerName
    $reportTitle = "$($clientName) DirSync Report"
    $reportFooter = "Report created using SkyKick Cloud Manager"

    Write-Output "Starting stale DirSync/Entra ID Connect check script ..."
    foreach ( $client in $Clients ) {
        Set-CustomerContext $client
        $clientName = (Get-CustomerContext).CustomerName
        $isConnected = Get-ConnectorStatus -ConnectorName office365
        if ( $isConnected ) {
            $org = Get-MgOrganization
            if ( $org.OnPremisesSyncEnabled -eq $True ) {
                $dirSyncState = "-"
                $addToReport = $true
                $lastSync = $org.OnPremisesLastSyncDateTime
                $lastSyncFormatted = Get-Date $lastSync -Format "yyyy-MM-dd HH:mm:ss zzz"
                $lastSyncTimespan = New-TimeSpan -Start $lastSync -End (Get-Date)
                # Determine sync status and optionally filter out stale results
                if ( $lastSyncTimespan.TotalHours -gt 2 ) {
                    $dirSyncState = "Stale"
                } else {
                    $dirSyncState = "Active"
                    if ( $StaleOnly ) {
                        $addToReport = $False
                    }
                }
                # Output to console
                Write-Output "[$clientName] DirSync Status: $($dirSyncState). Last sync: $lastSyncFormatted"
                # Add results to output
                if ( $addToReport ) {
                    $syncObject = [PSCustomObject]@{
                        Client          = $clientName
                        DirSyncEnabled  = $org.OnPremisesSyncEnabled
                        DirSyncLastSync = $lastSyncFormatted
                        DirSyncState    = $dirSyncState
                    }
                    $results.Add($syncObject)
                }
            } else {
                # Dirsync not enabled on this tenant, do nothing
            }
        } else {
            $syncObject = [PSCustomObject]@{
                Client          = $clientName
                DirSyncEnabled  = "Cloud Manager's Office365 connector is not connected for this client. Please check the connector and try again."
                DirSyncLastSync = "N/A"
                DirSyncState    = "N/A"
            }
            results.Add($syncObject)
        }
    }
    if ( $results.Count -gt 0) {
        $results = $results | Sort-Object Client
        Out-SKSolutionReport -Content $results -ReportTitle $reportTitle -ReportFooter $reportFooter -SeparateReportFileForEachCustomer
    } else {
        Write-Output "No results found for the specified client(s)."
    }

}