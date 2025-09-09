function Invoke-ComputerDomainCheck {
    param (
        [Parameter(Mandatory = $false)]
        [string]
        $ActiveDirectoryFQDN,

        [Parameter(Mandatory = $false)]
        [string]
        $EntraTenantID,

        [Parameter(Mandatory = $false)]
        [string]
        $WorkgroupID
    )

    <#
    .SYNOPSIS
        Perform a domain check to ensure a script is run on the correct computer.

    .DESCRIPTION
        This function checks if a computer is joined to a specified Entra ID tenant, Active Directory domain, or if
        it matches an organization workgroup ID. It returns true/false depending on the result. The output of this
        can be used in other scripts or processes to ensure scripts are run on the correct machines.

		The script will also update the following custom properties in NinjaRMM:
		- devDomainJoinType: Type of domain join (Entra joined, Hybrid joined, Domain joined, Workgroup joined)
		- devIntuneEnrolled: Boolean indicating if the device is enrolled in Intune
		- devEntraTenantName: Name of the Entra ID tenant
		- devEntraTenantId: ID of the Entra ID tenant
		- devActiveDirectoryFqdn: FQDN of the Active Directory domain
	.PARAMETER ActiveDirectoryFQDN
		The FQDN of the Active Directory domain to check against.
	.PARAMETER EntraTenantID
		The Entra ID tenant ID to check against.
	.PARAMETER WorkgroupID
		The workgroup ID to check against.
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
        $intuneLogExists = Test-Path -Path "C:\ProgramData\Microsoft\IntuneManagementExtension\Logs\IntuneManagementExtension.log"
        if ( $intuneLogExists ) {
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

    # Retrieve parsed computer domain status
    Write-Verbose "Starting computer domain check"
    Write-Verbose "- Active Directory FQDN: $ActiveDirectoryFQDN"
    Write-Verbose "- Entra Tenant ID: $EntraTenantID"
    Write-Verbose "- WorkgroupID: $WorkgroupID"
    $joinStatus = Get-ComputerJoinStatus

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
    Ninja-Property-Set devDomainJoinType $computerJoinType
    Write-Verbose "Updating custom property in NinjaRMM: devDomainJoinType to $computerJoinType"
    Ninja-Property-Set devIntuneEnrolled $joinStatus.IntuneEnrolled
    Write-Verbose "Updating custom property in NinjaRMM: devIntuneEnrolled to $($joinStatus.IntuneEnrolled)"
    if ( $joinStatus.TenantName ) {
        Ninja-Property-Set devEntraTenantName $joinStatus.TenantName
        Write-Verbose "Updating custom property in NinjaRMM: EntraIDTenantName to $($joinStatus.TenantName)"
    }
    if ( $joinStatus.TenantId ) {
        Ninja-Property-Set devEntraTenantId $joinStatus.TenantId
        Write-Verbose "Updating custom property in NinjaRMM: EntraIdTenantId to $($joinStatus.TenantId)"
    }
    if ( $joinStatus.DomainFQDN) {
        Ninja-Property-Set devActiveDirectoryFqdn $joinStatus.DomainFQDN
        Write-Verbose "Updating custom property in NinjaRMM: ActiveDirectoryDomain to $($joinStatus.DomainFQDN)"
    }

    # If domain check bypass is enabled, skip checks and return true
    # Otherwise:
    #   - If Entra Tenant ID is provided and matches, return true. Otherwise, return false immediately
    #   - If Entra ID is not provided, check Active Directory FQDN and fall back to Workgroup ID
    #   - If either AD or workgroup ID match, return true. Otherwise, return false.
    $bypassDomainChecks = [boolean](Ninja-Property-Get devBypassDomainChecks)
    if ( $bypassDomainChecks ) {
        Write-Verbose "Bypass domain checks is enabled, skipping domain check"
        return $true
    }
    if ( ($null -eq $ActiveDirectoryFQDN) -and ($null -eq $EntraTenantID) -and ($null -eq $WorkgroupID) ) {
        Write-Error "No values provided for Active Directory FQDN, Entra tenant ID, or workgroup ID. Please check your input and try again."
        exit 1
    }
    if ( $EntraTenantID ) {
        if ( $joinStatus.TenantId -match $EntraTenantID ) {
            Write-Verbose "EntraTenantID $($joinStatus.TenantId) matches $EntraTenantID"
            return $true
        } else {
            Write-Verbose "EntraTenantID $($joinStatus.TenantId) does not match $EntraTenantID"
            return $false
        }
    }
    if ($ActiveDirectoryFQDN) {
        if ( $joinStatus.DomainFQDN -match $ActiveDirectoryFQDN ) {
            Write-Verbose "ActiveDirectoryFQDN $($joinStatus.DomainFQDN) matches $ActiveDirectoryFQDN"
            return $true
        }
    }
    if ( $WorkgroupID ) {
        $deviceWorkgroupID = Ninja-Property-Get devWorkgroupID
        if ( $deviceWorkgroupID -match $WorkgroupID ) {
            Write-Verbose "WorkgroupID $deviceWorkgroupID matches $WorkgroupID"
            return $true
        }
    }
    Write-Verbose "Failed to match computer by Entra tenant ID, Active Directory FQDN, or WorkGroup ID"
    return $false
}

# Domain check to ensure the script is running on the correct machine
$dcPassed = Invoke-ComputerDomainCheck -ActiveDirectoryFQDN (Ninja-Property-Get orgActiveDirectoryFqdn) -EntraTenantID (Ninja-Property-Get orgEntraTenantId) -WorkgroupID (Ninja-Property-Get orgWorkgroupID) -Verbose
if ( -not ($dcPassed) ) {
    Write-Output "FAILURE: This script is intended to run on a computer joined to the specified domain or Entra ID tenant."
    exit 1
}

# Install Qualys Cloud Agent
$installerPath = "C:\Temp\NinjaRMM\QualysCloudAgent.exe"
if ( Test-Path -Path $installerPath ) {
    Write-Verbose "Qualys installer file found at $installerPath. Starting installation..."
    $activationId = "{$(Ninja-Property-Get orgQualysActivationId)}"
    $argList = @(
        "CustomerId={be921b91-f1f4-cbe0-809e-2e4d41bd4b9b}",
        "ActivationId=$activationId"
        "WebServiceUri=https://qagpublic.qg3.apps.qualys.com/CloudAgent/"
    ) -join " "

    $process = Start-Process -FilePath $installerPath -ArgumentList $argList -PassThru
    if ( $process.ExitCode -ne 0 ) {
        Write-Output "FAILURE: Qualys Cloud Agent installation failed with exit code $($process.ExitCode)"
        exit 1
    } else {
        Write-Output "SUCCESS: Qualys Cloud Agent installed successfully"
        Remove-Item $installerPath -Force
        exit 0
    }
} else {
    Write-Output "FAILURE: Installer file not found at $installerPath"
    exit 1
}
