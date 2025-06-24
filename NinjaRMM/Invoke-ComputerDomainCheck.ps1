function Invoke-ComputerDomainCheck {
    param (
        [Parameter(Mandatory = $false)]
        [string]
        $ActiveDirectoryFQDN,

        [Parameter(Mandatory = $false)]
        [string]
        $EntraTenantID
    )

    <#
    .SYNOPSIS
        Checks if the computer is joined to a specific Active Directory domain and/or Entra ID tenant.

    .DESCRIPTION
        This script checks if the computer is joined to a specified Active Directory domain and Entra ID tenant.
        It returns "PASS" if either conditions are met, otherwise it returns "FAIL". The output of this can be used
        in other scripts or processes to ensure scripts are run on the correct machines. It will also retrieve the
        device domain join type and store it as a custom property.
    .EXAMPLE
        In this example, $env:ADFQDN and $env:EntraTenantID are script variables in the NinjaRMM script interface.
        The following can be used within a sepatate script to evaluate the domain of the device and exit on mismatch.

        $domainCheck = Invoke-ComputerDomainCheck -ActiveDirectoryFQDN $env:ADFQDN -EntraIDTenantName $env:EntraTenantID
        if ($domainCheck -ne "PASS") {
          Write-Output "FAILURE: This script is intended to run on a computer joined to the specified domain or Entra ID tenant."
          exit 1
        }
    #>

    function Get-IntuneEnrollmentStatus {
        <#
        .SYNOPOSIS
        This function checks if the device is enrolled in Microsoft Intune by looking for the IntuneManagementExtension.log file
        and Intune-issued certificates.

        .DESCRIPTION
        First, the function checks for the presence of the IntuneManagementExtension.log file in the specified path. If the file
        exists and was modified within the last 7 days, it then checks for certificates issued by Microsoft Intune MDM. If those
        certificates are found and are valid, it indicates that the device is enrolled in Intune.

        .EXAMPLE
        if ( Get-IntuneEnrollmentStatus ) {
            # device is enrolled in Intune
            # do Intune-related tasks here
        }

        #>
        [CmdletBinding()]
        param ()

        $intuneEnrolled = $false

        # Check if the IntuneManagementExtension.log file exists and is recent
        if (Test-Path -Path "C:\ProgramData\Microsoft\IntuneManagementExtension\Logs\IntuneManagementExtension.log") {
            $intuneLog = Get-Item -Path "C:\ProgramData\Microsoft\IntuneManagementExtension\Logs\IntuneManagementExtension.log"
            $today = Get-Date
            $timespan = New-TimeSpan -Start $intuneLog.LastWriteTime -End $today
            if ($timespan.TotalDays -lt 7) {
                # Check for Intune issued certificates
                $intuneIssuedCerts = Get-ChildItem -Path Cert:\LocalMachine\My | Where-Object { $_.Issuer -like "*Microsoft Intune MDM*" }
                $intuneEnrolled = ($intuneIssuedCerts | ForEach-Object { (New-TimeSpan -Start $today -End $_.NotAfter).TotalDays -gt 1 }) -contains $true
            }
        }

        return $intuneEnrolled
    }

    function Get-ComputerJoinStatus {
        [CmdletBinding()]
        param()

        # Attempt to pull the FQDN of the Active Directory domain, if joined to one
        try {
            $fqdn = [System.DirectoryServices.ActiveDirectory.Domain]::GetComputerDomain().Name
        } catch {
            # Computer is not joined to an Active Directory domain
        }

        # Check if dsregcmd is available
        if (-not (Get-Command dsregcmd -ErrorAction SilentlyContinue)) {
            Write-Error "dsregcmd command not found"
            return
        }

        # Execute dsregcmd /status and parse the output into a custom object
        $status = dsregcmd /status
        $parsedStatus = [PSCustomObject]@{
            AzureADJoined  = ($status | Select-String -Pattern "AzureAdJoined" | ForEach-Object { $_.ToString().Split(':')[1].Trim() }) -eq "YES"
            TenantName     = ($status | Select-String -Pattern "TenantName" | ForEach-Object { $_.ToString().Split(':')[1].Trim() })
            TenantId       = ($status | Select-String -Pattern "TenantId" | ForEach-Object { $_.ToString().Split(':')[1].Trim() })
            IntuneEnrolled = Get-IntuneEnrollmentStatus
            DomainJoined   = ($status | Select-String -Pattern "DomainJoined" | ForEach-Object { $_.ToString().Split(':')[1].Trim() }) -eq "YES"
            DomainFQDN     = $fqdn
        }
        return $parsedStatus
    }

    # Initialize the result variable to fail
    $result = "FAIL"

    # Retrieve parsed join status
    $joinStatus = Get-ComputerJoinStatus

    ### Update result based on the join status ###
    # Check if the computer is joined to the specified Active Directory domain
    if ( $ActiveDirectoryFQDN ) {
        if ($joinStatus.DomainFQDN -match $ActiveDirectoryFQDN) {
            $result = "PASS"
            Write-Verbose "$($joinStatus.DomainFQDN) matches $ActiveDirectoryFQDN"
        }
    }
    # Check if the computer is joined to the specified Entra ID tenant
    if ( $EntraTenantID ) {
        if ($joinStatus.TenantName -match $EntraTenantID) {
            $result = "PASS"
            Write-Verbose "$($joinStatus.TenantName) matches $EntraTenantID"
        }
    }
    # If neither condition is met, the result remains "FAIL"

    ### Update device custom values ###
    if ( $joinStatus.AzureADJoined -eq $true -and $joinStatus.DomainJoined -eq $false ) {
        $computerJoinType = "Entra joined"
    } elseif ( $joinStatus.AzureADJoined -eq $true -and $joinStatus.DomainJoined -eq $true ) {
        $computerJoinType = "Hybrid joined"
    } elseif ( $joinStatus.AzureADJoined -eq $false -and $joinStatus.DomainJoined -eq $true ) {
        $computerJoinType = "Domain joined"
    } elseif ( $joinStatus.AzureADJoined -eq $false -and $joinStatus.DomainJoined -eq $false ) {
        $computerJoinType = "Workgroup joined"
    }
    Ninja-Property-Set intuneenrolled $joinStatus.IntuneEnrolled
    Ninja-Property-Set computerJoinType $computerJoinType
    if ( $joinStatus.TenantName ) {
        Ninja-Property-Set EntraIDTenantName $joinStatus.TenantName
        Write-Verbose "Updating custom property in NinjaRMM: EntraIDTenantName to $($joinStatus.TenantName)"
    }
    if ( $joinStatus.TenantId ) {
        Ninja-Property-Set entraIdTenantId $joinStatus.TenantId
        Write-Verbose "Updating custom property in NinjaRMM: EntraIdTenantId to $($joinStatus.TenantId)"
    }
    if ( $joinStatus.DomainFQDN) {
        Ninja-Property-Set activeDirectoryDomain $joinStatus.DomainFQDN
        Write-Verbose "Updating custom property in NinjaRMM: ActiveDirectoryDomain to $($joinStatus.DomainFQDN)"
    }
    # Output the domain check result
    return $result
}

Invoke-ComputerDomainCheck -ActiveDirectoryFQDN $env:ADFQDN -EntraTenantID $env:EntraTenantID