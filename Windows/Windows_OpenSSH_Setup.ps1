# Ref: https://adamtheautomator.com/openssl-windows-10/

# 1. Install Chocolatey
# https://chocolatey.org/install#individual
Set-ExecutionPolicy Bypass -Scope Process -Force; [System.Net.ServicePointManager]::SecurityProtocol = [System.Net.ServicePointManager]::SecurityProtocol -bor 3072; iex ((New-Object System.Net.WebClient).DownloadString('https://community.chocolatey.org/install.ps1'))

# 2. Install OpenSSL.Light using Chocolatey
choco install OpenSSL.Light

# 3. Configure OpenSSL
# 3a. Create a directory to use for certs/config
$certsFolder = [Environment]::GetFolderPath([Environment+SpecialFolder]::MyDocuments) + "\Scripts\certs"
New-Item -ItemType Directory -Path $certsFolder

# 3b. Download (or configure manually) a default config file
$certsConfig = "$certsFolder\openssl.cnf"
Invoke-WebRequest 'http://web.mit.edu/crypto/openssl.cnf' -OutFile $certsConfig
# 3c. Add environment variables to PowerShell profile
# Test for a profile, if not found create one!
if (-not (Test-Path $profile) ) {
    New-Item -Path $profile -ItemType File -Force
}
# Edit profile to add these lines
'$env:path = "$env:path;C:\Program Files\OpenSSL\bin"' | Out-File $profile -Append
'$env:OPENSSL_CONF = "${certsConfig}"' | Out-File $profile -Append

# 4. Reload profile
. $profile