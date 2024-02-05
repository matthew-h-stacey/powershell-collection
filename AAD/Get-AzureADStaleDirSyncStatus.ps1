function Get-AzureADStaleDirSyncStatus {

    [SkyKickCommand(DisplayName = "Set Parameter Sections", Sections = { "Threshold" })]
    param(

        [Parameter(Mandatory = $true)][CustomerContext[]] $Clients,

        [SkyKickParameter(
            DisplayName = "Inactivity threshold (hours)",    
            Section = "Threshold",
            DisplayOrder = 1,
            HintText = "Find clients with DirSync enabled that haven't synced in X hours."
        )]
        [Int]$Threshold = 2
    )
    $results = New-Object System.Collections.Generic.List[System.Object]
    Write-Output "Starting stale DirSync (Entra ID Connect) check script ..."
    
    Foreach ( $client in $Clients ) {

        Set-CustomerContext $client
        $clientName = (Get-CustomerContext).CustomerName

        $isConnected = Get-ConnectorStatus -ConnectorName office365
        if ( $isConnected ) {
            $msolCompanyInformation = Get-msolCompanyInformation
            if ( $msolCompanyInformation.DirectorySynchronizationEnabled -eq $True ) {

                $lastSync = $msolCompanyInformation.LastDirSyncTime
                $timeDifference = New-TimeSpan -Start $lastSync -End (Get-Date)
        
                if ($timeDifference.TotalHours -gt $Threshold) {

                    $StaleSyncObject = [PSCustomObject]@{
                        Client                  = $clientName
                        SyncServer              = $msolCompanyInformation.DirSyncClientMachineName
                        LastDirSyncTime         = $msolCompanyInformation.LastDirSyncTime
                        LastPasswordSyncTime    = $msolCompanyInformation.LastPasswordSyncTime
                        Status                  = "Stale"
                    }

                    $results.Add($StaleSyncObject)
                    Write-Output "[$clientName] DirSync Status: STALE. Last sync: $lastSync"

                } else {
                    Write-Output "[$clientName] DirSync Status: OK"
                }
                
            }
        } else {
            $StaleSyncObject = [PSCustomObject]@{
                Client                  = $clientName
                SyncServer              = "N/A"
                LastDirSyncTime         = "N/A"
                LastPasswordSyncTime    = "N/A"
                Status                  = "Unable to determine DirSync status. Please check the SkyKick connectors for this client and try again"
            }
            $results.Add($StaleSyncObject)
            Write-Output "[$clientName] DirSync Status: UNKNOWN. Unable to determine DirSync status. Please check the SkyKick connectors for this client and try again"
        }
    
    }

    if ( $results) {
        $results | Out-SkyKickTableToHtmlReport -IncludePartnerLogo -ReportTitle "Stale DirSync Report" -ReportFooter "Report created using SkyKick Cloud Manager" -OutTo NewTab
    } else {
        Write-Output "No stale DirSync status detected"
    }

}