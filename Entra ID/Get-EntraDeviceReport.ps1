    function Get-EntraDeviceReport {

        [CmdletBinding()]
        param (
            [Parameter(Mandatory = $true)]
            [CustomerContext[]]
            $Clients,

            [Parameter(Mandatory = $true)]
            [boolean]
            $SeparateReportFileForEachCustomer = $false
        )

        $reportTitle = "$clientName Entra Device Report"
        # Create an emptty list to store results as we loop through devices
        $results = [System.Collections.Generic.List[System.Object]]::new()

        foreach ( $client in $Clients ) {
            # SkyKick customer context and client name retrieval
            Set-CustomerContext $client
            $customerContext = Get-CustomerContext
            $clientName = $customerContext.CustomerName

            # Retrieve Entra ID devices
            $devices = Get-MgDevice -All
            Write-Verbose "Devices retrieved for ${clientName}: $($devices.Count)"
            if ( -not $devices ) {
                Write-Warning "No devices found for $clientName"
                return
            }
            # Retrieve BitLocker keys and convert to a hash table for easy lookup
            $blKeys = Get-MgInformationProtectionBitlockerRecoveryKey -All
            if ( $blKeys ) {
                Write-Verbose "BitLocker keys retrieved for ${clientName}: $($blKeys.Count)"
                $blKeysHash = ConvertTo-HashTable -Items $blKeys -KeyName DeviceId
                Write-Verbose "BitLocker keys converted to hash table for $clientName"
            } else {
                Write-Verbose "No BitLocker keys found for $clientName"
            }
            # Check if Intune is enabled before making additional API calls
            $intuneEnabled = Get-IntuneServiceEnabled
            if ( $intuneEnabled ) {
                ## Managed devices (Intune)
                # Get a hash table for all managed devices, then re-key it by id
                # Retrieves Intune-specific propertie ssuch as compliance, enrollment type, and last sync time
                $devGraphResponse = Invoke-GraphPaginatedRequest -URI 'https://graph.microsoft.com/v1.0/deviceManagement/managedDevices'
                if ( $devGraphResponse ) {
                    Write-Verbose "Managed devices retrieved for ${clientName}: $($devGraphResponse.Count)"
                    $managedDev = ConvertTo-HashTable -Items $devGraphResponse -KeyName azureADDeviceId
                } else {
                    Write-Verbose "No managed devices found for $clientName"
                }
                ## Encryption states
                # Get a hash table for all managed device encryption states, then re-key it by id
                $encryptionGraphResponse = Invoke-GraphPaginatedRequest -URI 'https://graph.microsoft.com/beta/deviceManagement/managedDeviceEncryptionStates'
                if ( $encryptionGraphResponse ) {
                    Write-Verbose "Managed device encryption states retrieved for ${clientName}: $($encryptionGraphResponse.Count)"
                    $encryptionStatus = ConvertTo-HashTable -Items $encryptionGraphResponse -KeyName id
                } else {
                    Write-Verbose "No managed device encryption states found for $clientName"
                }
                ## Merge
                # Merge the encryption state into the managed device hash table
                # managedDeviceEncryptionStates only has the Intune device id (not the Entra ID computer ID), so we have to loop through the
                # managed devices and match on the Intune id to pull the encryption state in
                foreach ($azureAdId in $managedDev.Keys) {
                    $intuneId = $managedDev[$azureAdId]["id"]
                    if ($encryptionStatus.ContainsKey($intuneId)) {
                        $managedDev[$azureAdId]["EncryptionState"] = $encryptionStatus[$intuneId].encryptionState
                    }
                }
            }

            foreach ( $device in $devices ) {
                # Initialize OS-specific properties
                $bitLockerKeyStored = $null
                $fileVaultKeyStored = $null
                switch ( $device.OperatingSystem ) {
                    "Windows" {
                        $bitLockerKeyStored = if ( $blKeysHash[$device.DeviceId].Id ) {
                            $true
                        } else {
                            $false
                        }
                    }
                    { $_ -like "MacOS" -or $_ -like "MacMDM" } {
                        # There is currently no API to pull FileVault key information for all Mac devices (similar to BitLocker),
                        # but we can pull it for each device individually
                        $fileVaultKey = Invoke-MgGraphRequest -Uri "https://graph.microsoft.com/beta/deviceManagement/managedDevices/$($device.id)/getFileVaultKey" -Method GET -SkipHttpErrorCheck
                        $fileVaultKeyStored = if ( $fileVaultKey.value ) {
                            $true
                        } else {
                            $false
                        }
                    }
                    "iOS" {
                        #
                    }
                    "Android" {
                        #
                    }
                    default {
                        #
                    }
                }
                # If Intune is enabled, retrieve the device for result export
                if ( $intuneEnabled ) {
                    $managedDevLookup = $managedDev[$device.DeviceId]
                }
                # Create a custom object for the device and add it to the results list
                $deviceObject = [PSCustomObject]@{
                    # Client
                    ClientName                    = $clientName
                    # Hardware/OS
                    DeviceName                    = $device.DisplayName
                    Manufacturer                  = $device.Manufacturer
                    Model                         = $device.Model
                    OperatingSystem               = $device.OperatingSystem
                    OperatingSystemVersion        = $device.OperatingSystemVersion
                    # User info
                    UserDisplayName               = if ($managedDevLookup) { $managedDevLookup.userDisplayName } else { $null }
                    UserPrincipalName             = if ($managedDevLookup) { $managedDevLookup.userPrincipalName } else { $null }
                    # Entra registration/activity
                    DeviceEnabled                 = $device.AccountEnabled
                    RegistrationDateTime          = $device.RegistrationDateTime
                    ApproximateLastSignInDateTime = $device.ApproximateLastSignInDateTime
                    DeviceJoinType                = $device.ProfileType
                    DeviceOwnership               = $device.DeviceOwnership
                    EnrollmentType                = $device.EnrollmentType
                    IsCompliant                   = $device.IsCompliant
                    # Intune
                    IntuneManaged                 = if ( $device.IsManaged ) { $device.IsManaged } else { $false }
                    IntuneEnrollDate              = if ($managedDevLookup) { $managedDevLookup.enrolledDateTime } else { $null }
                    IntuneLastSync                = if ($managedDevLookup) { $managedDevLookup.lastSyncDateTime } else { $null }
                    IsEncrypted                   = if ($managedDevLookup) { $managedDevLookup.isEncrypted } else { $null }
                    FileVaultKeyStored            = $fileVaultKeyStored
                    BitLockerKeyStored            = $bitLockerKeyStored
                    # Verbose/other
                    OnPremisesSyncEnabled         = $device.OnPremisesSyncEnabled
                    EntraDeviceId                 = $device.DeviceId
                    IntuneDeviceId                = if ($managedDevLookup) { $managedDevLookup.id } else { $null }
                }
                $results.Add($deviceObject)
            }
        }

         # Output the report
            if ( $results ) {
                $params = @{
                    Content                           = $results
                    ReportTitle                       = $reportTitle
                    SeparateReportFileForEachCustomer = $SeparateReportFileForEachCustomer
                }
                Out-SKSolutionReport @params
            } else {
                Write-Warning "No results found to export"
            }

    }