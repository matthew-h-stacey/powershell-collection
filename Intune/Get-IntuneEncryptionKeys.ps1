<#
.SYNOPSIS
This script exports all BitLocker (PC) and FileVault (Mac) encryption keys from managed devices in Intune

.PARAMETER DetailLevel
The level of detail to use in the report. Basic will pull only basic properties related to the device and recovery key. Full will grab additional details about the hardware, user, Entra and Intune device state

.PARAMETER ExportPath
Directory to export output to (ex: C:\TempPath)

.EXAMPLE
Get-IntuneEncryptionKeys -DetailLevel Basic

.NOTES
Matt Stacey
Version 1.0
8/9/2024
#>

param (
    [Parameter(Mandatory = $true)]
    [ValidateSet("Basic", "Full")]
    [string]
    $DetailLevel = "Basic",

    [Parameter(Mandatory = $true)]
    [string]
    $ExportPath
)

Connect-MgGraph -Scopes BitLockerKey.Read.All, Device.Read.All, DeviceManagementManagedDevices.Read.All, DeviceManagementManagedDevices.PrivilegedOperations.All

# Retrieve all devices managed by Intune
$uri = "https://graph.microsoft.com/beta/deviceManagement/managedDevices"
$graphResponse = (Invoke-MgGraphRequest -Method GET -Uri $uri).Value
if ( !$graphResponse) {
    Write-Output "[ERROR] No managed devices found. Exiting script"
    exit 1
}

# Create empty variable to store results in
$results = [System.Collections.Generic.List[System.Object]]::new()

# Retrieve all BitLocker keys
$bitlockerKeys = Get-MgInformationProtectionBitlockerRecoveryKey -All

# Initialize an empty hash table
$bitlockerKeysHashTable = @{}

# Set properties based on desired detail level
switch ( $DetailLevel ) {
    "Basic" {
        $properties = @(
            # OS
            'deviceName'
            'OperatingSystem', 
            'IsEncrypted', 

            # User Info
            'UserPrincipalName'
        )
    }
    "Full" {
        $properties = @(
            # OS
            'deviceName'
            'OperatingSystem', 
            'IsEncrypted', 

            # User Info
            'UserDisplayName', 
            'UserPrincipalName',

            # Hardware
            'Manufacturer', 
            'Model', 
            'SerialNumber',

            # Entra (Azure AD / Intune)
            'AzureADRegistered', 
            'AutoPilotEnrolled', 
            'AadRegistered', 
            'ManagementState', 
            'EnrolledDateTime', 
            'lastSyncDateTime'
            'OwnerType', 
            'JoinType', 
            'deviceEnrollmentType', 
            'deviceRegistrationState', 
            'enrolledByUserPrincipalName', 
            'managedDeviceOwnerType',
    
            # Device State
            'CompianceState', 
            'IsSupervised'    
        )
    }
}

# Add all BitLocker key IDs to a hash table
foreach ($key in $bitlockerKeys) {
    if ( $key.DeviceId ) {
        $bitlockerKeysHashTable[$key.DeviceId] = @{
            DeviceId             = $key.DeviceId
            VolumeId             = $key.Id
            BitLockerRecoveryKey = (Get-MgInformationProtectionBitlockerRecoveryKey -BitlockerRecoveryKeyId $key.Id -Property key -ErrorAction Stop -Verbose:$false).Key
        }
    }
}

# Start processing managed devices
foreach ( $device in $graphResponse) {
    $deviceId = $device.azureADDeviceId
    $deviceOutput = [PSCustomObject]@{
        DeviceId = $deviceId
    }
    switch ( $device.deviceType ) {
        "macMDM" {
            # Mac does not use BitLocker. Set BitLocker values to N/A
            Add-Member -InputObject $deviceOutput -MemberType NoteProperty -Name BitLockerVolumeId -Value "N/A"
            Add-Member -InputObject $deviceOutput -MemberType NoteProperty -Name BitLockerRecoveryKey -Value "N/A"
            $uri = "https://graph.microsoft.com/beta/deviceManagement/managedDevices/$deviceId/getFileVaultKey"
            try {
                # Retrieve the FileVault recovery key and add it to results
                $graphResponse = Invoke-MgGraphRequest -Method GET -Uri $uri
                $fileVaultKey = $graphResponse.Value
                if ( $fileVaultKey ) {
                    Add-Member -InputObject $deviceOutput -MemberType NoteProperty -Name FileVaultKey -Value $fileVaultKey
                }
            } catch {
                # No FileVault key found for this device
                Add-Member -InputObject $deviceOutput -MemberType NoteProperty -Name FileVaultKey -Value "None found"
            }            
        }
        "windowsRT" {
            # Windows does not use FileVault. Set FileVault to N/A
            Add-Member -InputObject $deviceOutput -MemberType NoteProperty -Name FileVaultKey -Value "N/A"
            # Attempt to locate a BitLocker ID from the hash table
            $blKeyFound = $bitlockerKeysHashTable[$deviceId]
            if ( $blKeyFound ) {
                # Retrieve the BitLocker recovery key and volume ID then add them to results
                $bitLockerRecoveryKey = $bitlockerKeysHashTable[$deviceId].BitLockerRecoveryKey
                $volumeId = $bitlockerKeysHashTable[$deviceId].VolumeId
                if ( $bitLockerRecoveryKey ) {
                    Add-Member -InputObject $deviceOutput -MemberType NoteProperty -Name BitLockerRecoveryKey -Value $bitLockerRecoveryKey
                }
                if ( $volumeId ) {
                    Add-Member -InputObject $deviceOutput -MemberType NoteProperty -Name BitLockerVolumeId -Value $volumeId
                }
            } else {
                # No BitLocker key found for this device
                Add-Member -InputObject $deviceOutput -MemberType NoteProperty -Name BitLockerRecoveryKey -Value "N/A"
                Add-Member -InputObject $deviceOutput -MemberType NoteProperty -Name BitLockerVolumeId -Value "N/A"
            }
        }
    }
    # Add additional properties
    foreach ( $property in $properties) {
        if ( $device.$property) {
            Add-Member -InputObject $deviceOutput -MemberType NoteProperty -Name $property -Value $device.$property
        }
    }
    if ( $deviceOutput ) {
        $results.Add($deviceOutput)
    }
}

# Export to CSV
$results | Select-Object $properties | Export-Csv -Path "$ExportPath\Intune_Encryption_keys.csv" -NoTypeInformation