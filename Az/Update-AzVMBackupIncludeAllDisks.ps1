function Update-AzVMBackupIncludeAllDisks {

    param(

        [Parameter(Mandatory = $true)]
        [String]
        $VmName,

        [Parameter(Mandatory = $true)]
        [String]
        $Subscription,
        
        [Parameter(Mandatory = $true)]
        [String]
        $RgName,
    
        [Parameter(Mandatory = $true)]
        [String]
        $VaultName
    
    )

    Set-AzContext -SubscriptionId (Get-AzSubscription -SubscriptionName $Subscription).Id

    try {
        $Datadisks = (Get-AzVM -Name $VmName -ErrorAction Stop -WarningAction Stop).StorageProfile.DataDisks.Lun
        $DatadisksString = $Datadisks -join ', '
    }
    catch {
        Write-Output "[ERROR] Failed to locate VM: $VmName"
    }

    $Vault = Get-AzRecoveryServicesVault -ResourceGroupName $RgName -Name $VaultName
    Set-AzRecoveryServicesVaultContext -Vault $Vault
    $Container = Get-AzRecoveryServicesBackupContainer -ContainerType AzureVM -VaultId $vault.ID | Where-Object { $_.FriendlyName -like $VmName }
    $BackupItem = Get-AzRecoveryServicesBackupItem -Container $Container -WorkloadType AzureVM -VaultId $vault.ID
    $Policy = Get-AzRecoveryServicesBackupProtectionPolicy -Name $BackupItem.PolicyId.Split("/")[-1]
    
    Write-Output "[INFO] Disks/LUNs for ${VmName}: $DatadisksString"

    try {
        Enable-AzRecoveryServicesBackupProtection -Item $BackupItem -InclusionDisksList $Datadisks -VaultId $Vault.ID -Policy $Policy
        Write-Output "[INFO] Successfully updated the backup for $VmName to include disks/LUNs: $DatadisksString"
    }
    catch {
        Write-Output "[ERROR] Failed include the following disks/LUNs in the backup for ${VmName}:"
        Write-Output $Datadisks
        Write-Output $_.Exception.Message
    }

}