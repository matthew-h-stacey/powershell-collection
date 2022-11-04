param (
    [Parameter(Mandatory = $true)][ParameterType]$regKey # Path in the registry, including key name (ex: "HKLM:\SOFTWARE\Microsoft\Windows\CurrentVersion\Policies\Associations")
    [Parameter(Mandatory=$true)][ParameterType]$regType, # Type of registry entry (ex: "String", "DWORD")
    [Parameter(Mandatory=$true)][ParameterType]$regName, # Name of the registry entry (ex: "LowRiskFileTypes")
    [Parameter(Mandatory = $true)][ParameterType]$regValue # Value of the registry entry (ex: ".pdf;.epub;.ica")
)

# Create registry key if it does not exist
if ((Test-Path -LiteralPath $regKey) -ne $true) {  
    New-Item $regKey -force -ea SilentlyContinue 
}

# Create/update registry entry if it does not exist
$check = (Get-ItemProperty $regKey).$regName
if ( $check -ne $regValue ) {
    New-ItemProperty -LiteralPath $regKey -Name $regName -Value $regValue -PropertyType $regType -Force 
}
else {
    # Value matches
    }

# New-Item "HKLM:\SOFTWARE\Microsoft\Windows\CurrentVersion\Policies\Associations" -force -ea SilentlyContinue 
# New-ItemProperty -LiteralPath  "HKLM:\SOFTWARE\Microsoft\Windows\CurrentVersion\Policies\Associations" -Name LowRiskFileTypes -Value ".pdf;.epub;.ica;.exe" -PropertyType String -Force 