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
    
    Foreach ( $Client in $Clients ) {

        Set-CustomerContext $Client
        $ClientName = (Get-CustomerContext).CustomerName

        $MsolCompanyInformation = Get-MsolCompanyInformation

        if ( $MsolCompanyInformation.DirectorySynchronizationEnabled -eq $True ) {

            $LastSync = $MsolCompanyInformation.LastDirSyncTime
            $TimeDifference = New-TimeSpan -Start $LastSync -End (Get-Date)
	
            if ($TimeDifference.TotalHours -gt $Threshold) {

                $StaleSyncObject = [PSCustomObject]@{
                    Client               = $ClientName
                    SyncServer           = $MsolCompanyInformation.DirSyncClientMachineName
                    LastDirSyncTime      = $MsolCompanyInformation.LastDirSyncTime
                    LastPasswordSyncTime	= $MsolCompanyInformation.LastPasswordSyncTime
                }

                $results.Add($StaleSyncObject)

            }
            else {
                Write-Output "[DirSync Status] ${ClientName}: OK"
            }
            
        }
    
    }

    if ( $results) {
        $results | Out-SkyKickTableToHtmlReport -IncludePartnerLogo -ReportTitle "Stale DirSync Report" -ReportFooter "Report created using SkyKick Cloud Manager" -OutTo NewTab
    }
    else {
        Write-Output "No stale DirSync status detected"
    }

}