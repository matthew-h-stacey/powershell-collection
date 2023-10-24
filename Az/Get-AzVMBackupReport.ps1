<#
.SYNOPSIS
	Generate a backup report for all VMs in a client tenant, or across many tenants.

.DESCRIPTION
	This script does two main things. It will iterate through Azure subscriptions to find all VMs and report if they are backed up, and for those that are backed up, it will pull the relevant details to the backup jobs and status.

.PARAMETER Clients
	The array of clients to select from the Cloud Manager interface.

.PARAMETER FailedJobsOnly
	If set to true, this will only report VMs whose backup ProtectionStatus is "Unhealthy." That includes VMs with failed jobs, but also VMs that aren't backed up at all.

.PARAMETER OutputFormat
	Output using the SkyKick-formatted HTML report, or to a downloaded CSV.

.EXAMPLE
	Used via Command Center in Cloud Manager

.NOTES
	Author: Matt Stacey
	Date:   June 13, 2023
	Tags: 	#CloudManager
#>

function Get-AzVMBackupReport {

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

        [Parameter(Mandatory = $true)]
        [SkyKickParameter(
            DisplayName = "Output format",    
            Section = "Options",
            DisplayOrder = 2,
            HintText = "Choose to output in Cloud Manager's HTML format or CSV."
        )]
        [ValidateSet("CSV", "HTML")]
        [String]$OutputFormat        
    
    )

    
    $AzVMBackupReport = @() # Empty array to store the results
    $VMDatadisks = @() # Empty array to store datadisk arrays

    # CSV filename
    $timestamp = (Get-Date).ToString("MM-dd-yyyy_HHmm")
    $CsvFilename = "AzureBackupReport_$timestamp_UTC.csv"

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
                            Write-Output "[WARNING] Azure VM backup is not configured for $($_.Name)"
                            $AzVMBackupReport += [PSCustomObject]@{
                                Client               = $ClientName
                                Name                 = ($_.Name).ToUpper()
                                ProtectionStatus     = "Unhealthy"
                                ProtectionState      = "Backup not configured"
                                LatestRecoveryPoint  = "N/A"
                                LastBackupStatus     = "N/A"
                                LastBackupTime       = "N/A"
                                Policy               = "N/A"
                                DataDiskIDs          = "N/A"
                                DataDisksIDsBackedUp = "N/A"
                                Location             = "N/A"
                                Subscription         = "N/A"
                                ResourceGroupName    = "N/A"
                                Vault                = "N/A"
                            }
                        }
                        if ( $BackedUp) {
                            $VMDatadisks += @{
                                VM        = ($_.Name).ToUpper()
                                Datadisks = $_.StorageProfile.DataDisks.Lun
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

                                $BackupItem = Get-AzRecoveryServicesBackupItem -WorkloadType AzureVM -Container $Item -VaultId $Vault.ID # Backup instance object
                                $VMName = (($BackupItem.ContainerName -split ';')[-1]).ToUpper() # Formatted VM name
                                $DataDiskIDs = ($VMDatadisks | Where-Object { $_.VM -like $VMName } | Select-Object -ExpandProperty Datadisks) -join ', ' # LUN IDs for data drives

                                # If the VM has LUNs present for data disks, check to see which of those disks are incuded in the backup. Separate handling for empty value to fix empty string outputting incorrectly
                                if ( $DataDiskIDs ) {
                                    if ( $BackupItem.DiskLunList.Count -gt 0 ) {
                                        $DataDisksBackedUp = $BackupItem.DiskLunList -join ', '
                                    }
                                    else {
                                        $DataDisksBackedUp = "None"
                                    }
                                }
                                else {
                                    $DataDisksBackedUp = ""
                                }


                                $AzVMBackupReport += [PSCustomObject]@{

                                    Client               = $ClientName
                                    Name                 = $VMName
                                    ProtectionStatus     = $BackupItem.ProtectionStatus
                                    ProtectionState      = $BackupItem.ProtectionState  
                                    LatestRecoveryPoint  = $BackupItem.LatestRecoveryPoint
                                    LastBackupStatus     = $BackupItem.LastBackupStatus
                                    LastBackupTime       = $BackupItem.LastBackupTime
                                    Policy               = $BackupItem.ProtectionPolicyName
                                    DataDiskIDs          = $DataDiskIDs
                                    DataDisksIDsBackedUp = $DataDisksBackedUp
                                    Location             = $Vault.Location
                                    Subscription         = $Subscription.Name
                                    ResourceGroupName    = $Vault.ResourceGroupName
                                    Vault                = $Vault.Name

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
                $AzVMBackupReport = $AzVMBackupReport | Where-Object { $_.ProtectionStatus -ne "Healthy" } 
                switch ( $OutputFormat ) {
                    "CSV" {
                        $AzVMBackupReport | ConvertTo-CSV | Out-SkyKickFile -Filename $CsvFilename
                    }
                    "HTML" {
                        $AzVMBackupReport | Out-SkyKickTableToHtmlReport -IncludePartnerLogo -ReportTitle "Azure VM Backup Report" -ReportFooter "Report created using SkyKick Cloud Manager" -OutTo NewTab
                    }
                }
            }
            False {
                switch ( $OutputFormat ) {
                    "CSV" {
                        $AzVMBackupReport | ConvertTo-CSV | Out-SkyKickFile -Filename $CsvFilename
                    }
                    "HTML" {
                        $AzVMBackupReport | Out-SkyKickTableToHtmlReport -IncludePartnerLogo -ReportTitle "Azure VM Backup Report" -ReportFooter "Report created using SkyKick Cloud Manager" -OutTo NewTab
                    }
                }
            }
        }
    }

    Write-Output "[INFO] Sending output to $OutputFormat"

}