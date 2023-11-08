# Creates an RSA 4096-bit self-signed certificate with the naming format {UserName}-{HostName}

$workDir = "C:\TempPath" # Output of public key
$certName = [System.Environment]::UserName + "_" + [System.Environment]::MachineName

# Create certificate
$mycert = New-SelfSignedCertificate -DnsName $certName -CertStoreLocation "cert:\CurrentUser\My" -NotAfter (Get-Date).AddYears(3) -KeySpec KeyExchange -KeyLength 4096 -KeyExportPolicy NonExportable

# Export certificate to .cer file
$mycert | Export-Certificate -FilePath $workDir\$certName.cer | Out-Null
Write-host "Exported public key to $workDir\$($certName).cer"

# Notate the Thumbprint of the new certificate. You will need this later
$mycert | select Thumbprint

# Finally, upload the cer to the App Registration in Azure AD


