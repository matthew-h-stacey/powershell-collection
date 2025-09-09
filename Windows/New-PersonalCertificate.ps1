# Creates an RSA 4096-bit self-signed certificate with the naming format {UserName}-{HostName}
function New-Folder {

    <#
    .SYNOPSIS
    Determine if a folder already exists, or create it  if not.

    .EXAMPLE
    New-Folder C:\TempPath
    #>

    param(
        [Parameter(Mandatory = $True)]
        [String]
        $Path
    )
    if (-not (Test-Path -LiteralPath $Path)) {
        try {
            New-Item -Path $Path -ItemType Directory -ErrorAction Stop | Out-Null
        } catch {
            Write-Error -Message "Unable to create directory '$Path'. Error was: $_" -ErrorAction Stop
        }
    }

}

$workDir = "C:\TempPath" # Output of public key
New-Folder -Path $workDir
$certName = [System.Environment]::UserName + "_" + [System.Environment]::MachineName

# Create certificate
$mycert = New-SelfSignedCertificate -DnsName $certName -CertStoreLocation "cert:\CurrentUser\My" -NotAfter (Get-Date).AddYears(3) -KeySpec KeyExchange -KeyLength 4096 -KeyExportPolicy NonExportable

# Export certificate to .cer file
$mycert | Export-Certificate -FilePath $workDir\$certName.cer | Out-Null
Write-host "Exported public key to $workDir\$($certName).cer"

# Notate the Thumbprint of the new certificate. You will need this later
$mycert | select Thumbprint

# Finally, upload the cer to the App Registration in Azure AD