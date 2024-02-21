<#
.SYNOPSIS
	Report on tenants where DirSync is stale/out of date

.DESCRIPTION
	This script uses Get-MsolCompanyInformation to retrieve sync status for clients and will determine if the last sync is older than the threshold defined by $Threshold. This is used in CloudManager to generate an HTML report

.PARAMETER Threshold
	The number of hours without sync to consider DirSync to be "stale." Defaults to 4 hours.

.NOTES
	Author: Matt Stacey
	Date:   April 27, 2023
	Tags: 	#CloudManager
#>


function Get-AADStaleDirSyncStatus {

    [SkyKickCommand(DisplayName = "Set Parameter Sections", Sections = { "Threshold" })]
    param(

        [Parameter(Mandatory = $true)][CustomerContext[]] $Clients,

        [SkyKickParameter(
            DisplayName = "Inactivity threshold (hours)",    
            Section = "Threshold",
            DisplayOrder = 1,
            HintText = "Find clients with DirSync enabled that haven't synced in X hours."
        )]
        [Int]$Threshold = 4
    )
    $results = @()

    Foreach ( $Client in $Clients ) {

        Set-CustomerContext $Client

        $MsolCompanyInformation = Get-MsolCompanyInformation

        if ( $MsolCompanyInformation.DirectorySynchronizationEnabled -eq $True ) {

            $LastSync = $MsolCompanyInformation.LastDirSyncTime
            $TimeDifference = New-TimeSpan -Start $LastSync -End (Get-Date)
	
            if ($TimeDifference.TotalHours -gt $Threshold) {

                $OutdatedClientSync = [PSCustomObject]@{
                    Client               = (Get-CustomerContext).CustomerName
                    SyncServer           = $MsolCompanyInformation.DirSyncClientMachineName
                    LastDirSyncTime      = $MsolCompanyInformation.LastDirSyncTime
                    LastPasswordSyncTime	= $MsolCompanyInformation.LastPasswordSyncTime
                }

                $results += $OutdatedClientSync 

            }
            
        }
    
    }

    $results | Out-SkyKickTableToHtmlReport -IncludePartnerLogo -ReportTitle "Stale DirSync Report" -ReportFooter "Report created using SkyKick Cloud Manager" -OutTo NewTab

}