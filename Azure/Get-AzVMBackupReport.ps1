function Get-AzVMBackupReport {

    [SkyKickCommand(DisplayName = "Set Parameter Sections", Sections = { "Options" })]
    param(
	
        [SkyKickParameter(
            DisplayName = "Failed jobs only",    
            Section = "Options",
            DisplayOrder = 1,
            HintText = "Show results for all jobs, or failed jobs only."
        )]
        [Boolean]$FailedJobsOnly = $false
    
    )

    # TO-DO:
    # - Add option to pull failed jobs only

    # Empty array to store the results
    $AzVMBackupReport = @()

    # Client name for the report
    $ClientName = (Get-CustomerContext).CustomerName

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
                        Name                = ($_.Name).ToUpper()
                        ProtectionStatus    = "Unhealthy"
                        ProtectionState     = "Backup not configured"
                        LatestRecoveryPoint = "N/A"
                        LastBackupStatus    = "N/A"
                        LastBackupTime      = "N/A"
                        Policy              = "N/A"
                        Location            = "N/A"
                        Subscription        = "N/A"
                        ResourceGroupName   = "N/A"
                        Vault               = "N/A"
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

                            Name                = $VMName.ToUpper()
                            ProtectionStatus    = $BackupItem.ProtectionStatus
                            ProtectionState     = $BackupItem.ProtectionState  
                            LatestRecoveryPoint = $BackupItem.LatestRecoveryPoint
                            LastBackupStatus    = $BackupItem.LastBackupStatus
                            LastBackupTime      = $BackupItem.LastBackupTime
                            Policy              = $BackupItem.ProtectionPolicyName
                            Location            = $Vault.Location
                            Subscription        = $Subscription.Name
                            ResourceGroupName   = $Vault.ResourceGroupName
                            Vault               = $Vault.Name

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

    Write-Output "[DONE] All subscriptions processed"

    if ( $FailedJobsOnly ) {
        $AzVMBackupReport | Where-Object { $_.ProtectionStatus -ne "Healthy" }  | Out-SkyKickTableToHtmlReport -IncludePartnerLogo -ReportTitle "$($ClientName) AzVM Backup Report" -ReportFooter "Report created using SkyKick Cloud Manager" -OutTo NewTab
    }
    else {
        $AzVMBackupReport | Out-SkyKickTableToHtmlReport -IncludePartnerLogo -ReportTitle "$($ClientName) AzVM Backup Report" -ReportFooter "Report created using SkyKick Cloud Manager" -OutTo NewTab
    }

}