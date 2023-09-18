function Get-AzVMBackupReportBR {

    [SkyKickCommand(DisplayName = "Set Parameter Sections", Sections = { "Client", "Options" })]
    param(
	
        [SkyKickParameter(
            DisplayName = "Select the clients to run the report on",    
            Section = "Client",
            DisplayOrder = 1
        )]
        [Parameter(Mandatory = $true)][CustomerContext[]] $Clients,

        [SkyKickParameter(
            DisplayName = "Failed jobs only",    
            Section = "Options",
            DisplayOrder = 1,
            HintText = "Show results for all jobs, or failed jobs only."
        )]
        [Boolean]$FailedJobsOnly = $false,

        [SkyKickParameter(
            DisplayName = "Output format",    
            Section = "Options",
            DisplayOrder = 2,
            HintText = "Choose to output in Cloud Manager's HTML format or CSV."
        )]
        [Parameter(Mandatory=$True)]
        [ValidateSet("CSV", "HTML")]
        [String]$OutputFormat        
    
    )

    # Empty array to store the results
    $AzVMBackupReport = @()

    # Foreach loop to iterate through selected clients
    foreach ( $Client in $Clients) {    

        # Change context to the selected client
        Set-CustomerContext $Client 
        
        # Client name for the report
        $ClientName = (Get-CustomerContext).CustomerName

        $IsConnected = Get-ConnectorStatus -ConnectorName Azure

        if ( $IsConnected ) {

            Write-Output "[INFO] Azure connector for $ClientName is active. Proceeding ..."

            # Get all Azure Subscriptions
            $Subscriptions = Get-AzSubscription

            # Iterate through each Subscription
            foreach ($Subscription in $Subscriptions) {

                # Walk through each subscription
                Write-Output "[INFO] Changing subscription to $($Subscription.Name)"
                Set-AzContext -SubscriptionId $Subscription.Id | Out-Null

                # Start processing each VM. Attempt to locate VMs not being backed up
                Write-Output "[INFO] Retrieving the backup status for all VMs in the subscription"
                $VMs = Get-AzVM | Sort-Object Name
                $VMs  | ForEach-Object { 
                    try {
                        $BackedUp = Get-AzRecoveryServicesBackupStatus -ResourceGroupName $_.ResourceGroupName -Name $_.Name -Type AzureVM | Select-Object -ExpandProperty BackedUp
                        if (!( $BackedUp )) {
                            Write-Output "[WARNING] VM backup is not configured for $($_.Name)"
                            $AzVMBackupReport += [PSCustomObject]@{
                                Client              = $ClientName
                                Device              = ($_.Name).ToUpper()
                                Status              = "Warning"
                                'Backup Date'       = "N/A"
                                Job                 = "Azure"
                            }
                        }
                    }
                    catch {
                        Write-Output "[ERROR] Unable to retrieve VM backup status for $($VM.Name). Error:"
                        Write-Output $_
                    }

                }
                if ( $VMs.Count -eq 0 ) { Write-Host "[INFO] No VMs in this subscription" }

                # Start processing vaults
                $AzRecoveryServicesVaults = Get-AzRecoveryServicesVault |  Where-Object { $_.SubscriptionId -eq $Subscription.Id }

                Write-Output "[INFO] ($($Subscription.Name)): Processing subscription ... "

                if ( $AzRecoveryServicesVaults ) {

                    Write-Output "[INFO] ($($Subscription.Name)): Recovery vaults found. Proceeding ..."

                    foreach ( $Vault in $AzRecoveryServicesVaults ) {
                
                        $Container = Get-AzRecoveryServicesBackupContainer -ContainerType AzureVM -VaultId $vault.id
                
                        if ( $Container ) {
                    
                            foreach ( $Item in $Container ) {

                                $BackupItem = Get-AzRecoveryServicesBackupItem -Container $Item -WorkloadType AzureVM -VaultId $Vault.ID
                                $VMName = ($BackupItem.ContainerName -split ';')[-1]

                                $AzVMBackupReport += [PSCustomObject]@{

                                    Client              = $ClientName
                                    Device              = $VMName.ToUpper()
                                    Status              = switch ($BackupItem.LastBackupStatus) {
                                                            "Completed" { "Success" }
                                                            "Failed" { "Failed" }
                                                            "Warning" { "Warning" }
                                                            default { $BackupItem.LastBackupStatus }
                                                        }
                                    'Backup Date'       = $BackupItem.LastBackupTime
                                    Job                 = "Azure"

                                }

                                Write-Output "[DATA] $($VMName): Added backup status to the output"

                            }

                        }
                    
                    }

                }
                else {
                    Write-Output "[INFO] ($($Subscription.Name)): No recovery vaults found. Skipping ..."
                }
            }
        }
        else {
            Write-Output "[INFO] Azure connector for $ClientName is not active. Skipping ..."
        }
    }

    Write-Output "[DONE] All subscriptions processed"

    if ( $AzVMBackupReport ) {

        switch ( $FailedJobsOnly) {
            True {
                $AzVMBackupReport = $AzVMBackupReport | Where-Object { $_.Status -ne "Success" } 
                switch ( $OutputFormat ) {
                    "CSV" {
                        $AzVMBackupReport | ConvertTo-CSV | Out-SkyKickFile -Filename AzureBackupReport.csv
                    }
                    "HTML" {
                        $AzVMBackupReport | Out-SkyKickTableToHtmlReport -IncludePartnerLogo -ReportTitle "Azure VM Backup Report" -ReportFooter "Report created using SkyKick Cloud Manager" -OutTo NewTab
                    }
                }
            }
            False {
                switch ( $OutputFormat ) {
                    "CSV" {
                        $AzVMBackupReport | ConvertTo-CSV | Out-SkyKickFile -Filename AzureBackupReport.csv
                    }
                    "HTML" {
                        $AzVMBackupReport | Out-SkyKickTableToHtmlReport -IncludePartnerLogo -ReportTitle "Azure VM Backup Report" -ReportFooter "Report created using SkyKick Cloud Manager" -OutTo NewTab
                    }
                }
            }
        }
    }

}