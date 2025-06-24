
<# ----- About: ----
    # Deploy N-able Backup Manager
    # Revision v21 - 2021-08-10
    # Author: Eric Harless, Head Backup Nerd - N-able
    # Twitter @Backup_Nerd  Email:eric.harless@n-able.com
    # Reddit https://www.reddit.com/r/Nable/
# -----------------------------------------------------------#>
# https://github.com/BackupNerd/Backup-Scripts/blob/master/Deployment/Windows/N-able_Backup_WindowsAutoDeployScript.v21.ps1

<# ----- Legal: ----
    # Sample scripts are not supported under any N-able support program or service.
    # The sample scripts are provided AS IS without warranty of any kind.
    # N-able expressly disclaims all implied warranties including, warranties
    # of merchantability or of fitness for a particular purpose.
    # In no event shall N-able or any other party be liable for damages arising
    # out of the use of or inability to use the sample scripts.
# -----------------------------------------------------------#>

<# ----- Behavior: ----
    # [-Documents] [-Uid] <string>
        ## D\L then deploy a NEW "Document" Backup device
    # [-AutoDeploy] [-Uid] <string>
        ## D\L then deploy a NEW Backup Manager as a Passphrase compatible device
    # [-AutoDeploy] [-Uid] <string> [-SetBandWidth] [-SetArchive]
        ## D\L then deploy a NEW Backup Manager as a Passphrase compatible device
       # [-Upgrade]
        ## D\L then upgrade existing Backup Manager installation to the latest Backup Manager release
    # [-Redeploy]
        ## D\L then install\reinstall with PrivateKey Encryption or PassPhrase (supports [-RestoreOnly] mode)
    # [-Reuse]
        ## Copy previously stored Backup Manager Config.ini credentials to the Backup Manager installation director
    # [-Reuse] {-Restart]
        ## Restart Backup Services after [-Reuse] command
    # [-Copy]
        ## Store a copy of the current Backup Manager Config.ini credentials
    # [-Copy] [-Ditto]
        ## Store a primary and secondary copy of the current Backup Manager Config.ini credentials
    # [-Force]
        ## Force overwrite of existing Backup Manager installation or Config.ini credentials
    # [-Remove]
        ## Uninstall existing Backup Manager installation (supports [-Copy] [-Ditto] prior to removal)
    # [-Test]
        ## Returns configuration and settings information for the current Backup Manager installation
    # [-Help]
        ## Displays Script Parameter Syntax
    #
    # https://documentation.n-able.com/backup/userguide/documentation/Content/backup-manager/backup-manager-installation/regular-install.htm
    # https://documentation.n-able.com/backup/userguide/documentation/Content/backup-manager/backup-manager-installation/silent.htm
    # https://documentation.n-able.com/backup/userguide/documentation/Content/backup-manager/backup-manager-installation/reinstallation.htm
# -----------------------------------------------------------#>

# Example:
# .\Install-NAbleBackup.ps1 -AutoDeploy -Uid XXXXX-XXXX-XXXX-XXXX-XXXXXX -ProfileName Daily_All -ProductName "90_Days" -Alias $env:COMPUTERNAME

    function Invoke-ComputerDomainCheck {
    param (
        [Parameter(Mandatory = $false)]
        [string]
        $ActiveDirectoryFQDN,

        [Parameter(Mandatory = $false)]
        [string]
        $EntraIDTenantName
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
        -ADFQDN "bcstech.service"
        -EntraIDTenantName "BCS Tech"

        This will check if the computer is joined to the Active Directory domain "bcservice.tech" and/or the Entra ID
        tenant "BCS Tech". If either condition is met, it will return "PASS", otherwise "FAIL".
    #>

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
            AzureADJoined = ($status | Select-String -Pattern "AzureAdJoined" | ForEach-Object { $_.ToString().Split(':')[1].Trim() }) -eq "YES"
            TenantName    = ($status | Select-String -Pattern "TenantName" | ForEach-Object { $_.ToString().Split(':')[1].Trim() })
            TenantId      = ($status | Select-String -Pattern "TenantId" | ForEach-Object { $_.ToString().Split(':')[1].Trim() })
            DomainJoined  = ($status | Select-String -Pattern "DomainJoined" | ForEach-Object { $_.ToString().Split(':')[1].Trim() }) -eq "YES"
            DomainFQDN    = $fqdn
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
    if ( $EntraIDTenantName ) {
        if ($joinStatus.TenantName -match $EntraIDTenantName) {
            $result = "PASS"
            Write-Verbose "$($joinStatus.TenantName) matches $EntraIDTenantName"
        }
    }
    # If neither condition is met, the result remains "FAIL"

    ### Update device custom fields  ###
    if ( $joinStatus.AzureADJoined -eq $true -and $joinStatus.DomainJoined -eq $false ) {
        $computerJoinType = "Entra joined"
    } elseif ( $joinStatus.AzureADJoined -eq $true -and $joinStatus.DomainJoined -eq $true ) {
        $computerJoinType = "Hybrid joined"
    } elseif ( $joinStatus.AzureADJoined -eq $false -and $joinStatus.DomainJoined -eq $true ) {
        $computerJoinType = "Domain joined"
    } elseif ( $joinStatus.AzureADJoined -eq $false -and $joinStatus.DomainJoined -eq $false ) {
        $computerJoinType = "Workgroup joined"
    }
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

    ### Output the domain check result ###
    return $result
}

    Function Download-BackupManager {
        $OSVersion = [System.Environment]::OSVersion.Version
        if ( $OSVersion.Major -gt 6 ) {
            # Enforce TLS1.2
            try {
                [Net.ServicePointManager]::SecurityProtocol = [Net.SecurityProtocolType]::Tls12
            }
            catch {
                Write-Output "An error occured while attempting to enforce TLS"
                Write-Output $_
            }

            # Download installer over TLS1.2
            Write-Output "Downloading BackupManager over HTTPS to: c:\windows\temp\mxb-windows-x86_x64.exe"
            (New-Object System.Net.WebClient).DownloadFile("https://cdn.cloudbackup.management/maxdownloads/mxb-windows-x86_x64.exe","c:\windows\temp\mxb-windows-x86_x64.exe")
        }
        else {
            Write-Output "Downloading BackupManager over HTTP to: c:\windows\temp\mxb-windows-x86_x64.exe"
            (New-Object System.Net.WebClient).DownloadFile("http://cdn.cloudbackup.management/maxdownloads/mxb-windows-x86_x64.exe","c:\windows\temp\mxb-windows-x86_x64.exe")
        }
        try {
            Get-Item "c:\windows\temp\mxb-windows-x86_x64.exe" | Out-Null
            Write-Output "Download succeeded. Continuing"
        }
        catch {
            Write-Output "File failed to download. Exiting"
            break
        }
    }

    Function Autodeploy-Passphrase {
        $clienttool = "c:\program files\backup manager\clienttool.exe"
        $BMConfig = "C:\Program Files\Backup Manager\config.ini"

        if (((Test-Path $BMConfig -PathType leaf) -eq $false) -or ($Force)) {

            if ($ProfileName) { $BackupProfile = "-profile-name `"$ProfileName`"" }
            if ($ProductName) { $BackupProduct = "-product-name `"$ProductName`"" }

            Write-Output "  Profile param  : $backupprofile"
            Write-Output "  Product name   : $productname"
            Write-Output "  Set Archive    : $($SetArchive.IsPresent)"
            Write-Output ""

            Download-BackupManager
            Stop-BackupProcess
            Write-Output ""
            Write-Output "  Autodeploying Backup Manager instance"
            Write-Output ""
            start-process -FilePath "c:\windows\temp\mxb-windows-x86_x64.exe" -ArgumentList "-unattended-mode -silent -partner-uid $Uid $BackupProfile $BackupProduct" -PassThru
            Get-BackupService
            if ($SetArchive) { Set-Archive }
        }

    }

    Function Stop-BackupProcess {
        stop-process -name "BackupFP" -Force -ErrorAction SilentlyContinue
    }

    Function Stop-BackupService {
        $BackupService = get-service -name "Backup Service Controller" -ErrorAction SilentlyContinue

        if ($BackupService.Status -eq "Stopped") {
        Write-Output "  Backup Service : $($BackupService.status)"
        }else{
        Write-Output "  Backup Service : $($BackupService.status)"
        stop-service -name "Backup Service Controller" -force -ErrorAction SilentlyContinue
        Get-BackupService
        }
    }

    Function Start-BackupService {
        $BackupService = get-service -name "Backup Service Controller" -ErrorAction SilentlyContinue

        if ($BackupService.Status -eq "Running") {
        Write-Output "  Backup Service : $($BackupService.status)"
        Get-InitError
        }else{
        Write-Output "  Backup Service : $($BackupService.status)"
        start-service -name "Backup Service Controller" -ErrorAction SilentlyContinue
        Get-BackupService
        Get-InitError
        }
    }

    Function Get-BackupService {
        $BackupService = get-service -name "Backup Service Controller" -ErrorAction SilentlyContinue

        if ($backupservice.status -eq "Stopped") {
        Write-Output "  Backup Service : $($BackupService.status)"
        }
        elseif ($backupservice.status -eq "Running") {
            Write-Output "  Backup Service : $($BackupService.status)"
            #start-sleep -seconds 10
            #$initmsg = & $clienttool control.initialization-error.get | ConvertFrom-Json -ErrorAction SilentlyContinue
            #if ($($initmsg.message)) { Write-Output "  InitMsg Error  : $($initmsg.message)" }
        }
        else{
        Write-Output "  Backup Service : Not Present"
        }
    }

    Function Get-InitError {
        start-sleep -seconds 10
        $initmsg = & $clienttool control.initialization-error.get | ConvertFrom-Json -ErrorAction SilentlyContinue
        if ($($initmsg.message)) { Write-Output "  InitMsg Error  : $($initmsg.message)" }
    }

    # NinjaRMM-specific modifications
    $Uid            = Ninja-Property-Get nableCoveUid
    if ( $null -eq $Uid ) {
        Write-Output "FAILURE: There is no value for 'nableCoveUid' on this device's organization. Please set the value before running this script."
        exit 1
    }
    $ProfileName    = $env:coveprofilename
    $ProductName    = $env:coveproductname
    $domainCheck    = Invoke-ComputerDomainCheck -ActiveDirectoryFQDN $env:ADFQDN -EntraIDTenantName $env:EntraIDTenantName
    if ($domainCheck -ne "PASS") {
        Write-Output "FAILURE: This script is intended to run on a computer joined to the specified domain or Entra ID tenant."
        exit 1
    }


    Get-BackupService
    Autodeploy-Passphrase