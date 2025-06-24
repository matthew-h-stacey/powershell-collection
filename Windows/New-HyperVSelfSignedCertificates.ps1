#Requires -RunAsAdministrator
<#
.SYNOPSIS
    Create self-signed certificates for Hyper-V replication over HTTPS.
.DESCRIPTION
    Hyper-V replication requires kerberos or certificate authentication for replication. The intention
    of this script is to quickly perform the requisite steps for using self-signed certificates for
    replication over HTTPS. It will:

    1) Create the required registry entries to disable certificate revocation checks
    2) Enable the "Hyper-V Replica HTTPS Listener (TCP-In)" Windows Firewall rule (HTTPS port 443)
    3) Create a self-signed root certificate authority (CA) certificate
    4) Create a self-signed server certificate signed by the root CA certificate
    5) Export the root CA certificate to a .cer file

    Reference: https://www.alldiscoveries.com/how-to-set-up-replication-on-hyper-v-2022-step-by-step-with-active-directory-off-domain-self-signed-certificates/
.EXAMPLE
    .\New-HyperVSelfSignedCertificates.ps1
#>

function New-RegistryEntry {

    param (
        [Parameter(Mandatory = $true)][String]$Path, # Path in the registry, including key name (ex: "HKLM:\SOFTWARE\Microsoft\Windows\CurrentVersion\Policies\Associations")
        [Parameter(Mandatory = $true)][String]$Type, # Type of registry entry (ex: "String", "DWORD")
        [Parameter(Mandatory = $true)][String]$Name, # Name of the registry entry (ex: "LowRiskFileTypes")
        [Parameter(Mandatory = $true)][String]$Value # Value of the registry entry (ex: ".pdf;.epub;.ica")
    )

    # Create the registry key if it does not exist
    if ((Test-Path -LiteralPath $Path) -ne $true) {
        try {
            New-Item $Path -Force -ErrorAction Stop | Out-Null
            Write-Output "[INFO] Created new registry key: $Path"
        } catch {
            Write-Output "[ERROR] Failed to create new registry key: $Path. Error: $($_.Exception.Message)"
        }
    }

    # Create/update registry entry if it does not exist
    $CurrentValue = (Get-ItemProperty $Path).$Name
    if ( $CurrentValue -ne $Value ) {
        try {
            New-ItemProperty -LiteralPath $Path -Name $Name -Value $Value -PropertyType $Type -Force | Out-Null
            Write-Output "[INFO] Created new registry $Type"
            Write-Output "- Name: $Name"
            Write-Output "- Path: $Path"
            Write-Output "- Value: $Value"
        } catch {
            Write-Output "[ERROR] Failed to create new registry ${Type} in $Path. Error: $($_.Exception.Message)"
        }
    } else {
        # Value matches
        Write-Output "[INFO] Registry $Type $Name in $Path is already set to $Value"
    }
}

$ErrorActionPreference = "Stop"
$hostname = $env:COMPUTERNAME

# Create registry entries to disable certificate revocation checks, required for self-signed certs
New-RegistryEntry -Path "HKLM:\SOFTWARE\Microsoft\Windows NT\CurrentVersion\Virtualization\FailoverReplication" -Type DWORD -Name DisableCertRevocationCheck -Value 1
New-RegistryEntry -Path "HKLM:\SOFTWARE\Microsoft\Windows NT\CurrentVersion\Virtualization\Replication" -Type DWORD -Name DisableCertRevocationCheck -Value 1

# Enable Windows Firewall rule for Hyper-V replication
try {
    Enable-NetFirewallRule -DisplayName 'Hyper-V Replica HTTPS Listener (TCP-In)'
} catch {
    Write-Output "[ERROR] Failed to enable Windows Firewall rule for Hyper-V replication. Error: $($_.Exception.Message)"
}

# Create new self-signed root certificate authority certificate
try {
    $rootCA = New-SelfSignedCertificate -KeyExportPolicy Exportable -Subject "CN=$hostname-CA" -FriendlyName "$hostname-CA" -CertStoreLocation "Cert:\LocalMachine\My" -KeySpec "Signature" -KeyUsage "CertSign" -NotAfter (Get-Date).AddYears(20)
} catch {
    Write-Output "[ERROR] Failed to create new self-signed root certificate authority certificate. Error: $($_.Exception.Message)"
    exit 1
}

# Create new self-signed server certificate
try {
    New-SelfSignedCertificate -KeyExportPolicy "Exportable" -Subject $hostname -CertStoreLocation "Cert:\LocalMachine\My" -KeyUsage "KeyEncipherment", "DigitalSignature" -Signer "Cert:\LocalMachine\CA\$($rootCA.Thumbprint)" -NotAfter (Get-Date).AddYears(20) | Out-Null
} catch {
    Write-Output "[ERROR] Failed to create new self-signed certificate. Error: $($_.Exception.Message)"
    exit 1
}

# Move the root CA certificate to the Trusted Root Certification Authorities store
# It is required to create the cert then move it due to chosing a validity period longer than one year
try {
    Move-Item -Path "Cert:\LocalMachine\My\$(($rootCA).Thumbprint)" -Destination "Cert:\LocalMachine\Root"
} catch {
    Write-Output "[ERROR] Failed to move root CA certificate to Trusted Root Certification Authorities store. Error: $($_.Exception.Message)"
    exit 1
}

# Export the root CA certificate to a file
$cert = Get-ChildItem -Path "Cert:\LocalMachine\Root\$(($rootCA).Thumbprint)"
$certOutputPath = "$((Get-Location).Path)\$($hostname)-CA.cer"
Export-Certificate -Cert $cert -FilePath $certOutputPath | Out-Null
Write-Output "[INFO] Exported root certificate to: $certOutputPath. Copy this to member servers and import it to the Trusted Root Certification Authorities store."