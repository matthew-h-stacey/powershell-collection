<#
.SYNOPSIS
	Installs Chrome Extensions

.DESCRIPTION
	This can be used to install Chrome extensions on Windows. Modify the $ExtensionID value to deploy more add-ons.

.EXTENSIONS
    Windows 10 Accounts - "ppnbnpeolgkicgegkbkbjmhlideopiji;https://clients2.google.com/service/update2/crx"

.NOTES
	Author: CJ Tarbox
	Date:   March 28, 2023
	Tags: 	#IntuneSetup

#>

# Function to enumerate registry values
Function Get-RegistryValues {
    param(
        [Parameter(Mandatory=$true)]
        [string]$Path
    )
 
    Push-Location
    Set-Location -Path $Path
    Get-Item . | Select-Object -ExpandProperty property | ForEach-Object {
        New-Object psobject -Property @{“Property”=$_;“Value” = (Get-ItemProperty -Path . -Name $_).$_}
    }
    Pop-Location
} 
 
#Chrome Extension to be installed. Change this to whatever needs to be installed
$ExtensionID = "ppnbnpeolgkicgegkbkbjmhlideopiji;https://clients2.google.com/service/update2/crx"

# Registry path for the ExtensionInstallForcelist
$RegistryPath = "HKLM:\SOFTWARE\Policies\Google\Chrome\ExtensionInstallForcelist"
$KeyType = "String"

# Registry path does not exist. Creating the path
if (-not(Test-Path -Path $RegistryPath)) {
    Write-Host -ForegroundColor Red "Registry patch on $RegistryPath does not exist - trying to create it"
    try {
        New-Item -Path $RegistryPath -Force
    }
    catch {
        Write-Host -ForegroundColor Red "Failed to create registry path"
    }
}
 
# Loop through the existing values and properties in the registry
$InstalledExtensionsProperties = Get-RegistryValues -Path $RegistryPath | Select-Object Property
$InstalledExtensions = Get-RegistryValues -Path $RegistryPath | Select-Object Value
 
# Assuming that the list of forced extensions will never exceed a count of 20
$Values = 1..20
 
# If no registry key properties found, continue do something. No need to do something complicated, if no extensions exists already.
if ($InstalledExtensionsProperties -ne $null) { 
    
    # Finding next available number for use in KeyName
    $NextNumber = Compare-Object $InstalledExtensionsProperties.Property $Values | Select-Object -First 1
    $KeyName = $NextNumber.InputObject
    
    # If the extension is not installed already, install it
    if ($InstalledExtensions -match $ExtensionID) {
        Write-Host -ForegroundColor Green "$ExtensionID is already added."
        
    }
    # else try to add the extension please
    else {
        Write-Host -ForegroundColor Red "The extenion $ExtensionID is not found. Adding it."
        try {
            New-ItemProperty -Path $RegistryPath -Name $KeyName -PropertyType $KeyType -Value $ExtensionID
        }
        catch {
            Write-Host -ForegroundColor Red "Failed to create registry key"   
        }    
    }
}
# Else just add the extension as the first extension
else {
    
    Write-Host -ForegroundColor Red "No extensions already added. Adding the extensions as the first one"
    try {
        New-ItemProperty -Path $RegistryPath -Name 1 -PropertyType $KeyType -Value $ExtensionID
    }
    catch {
        Write-Host -ForegroundColor Red "Failed to create registry key"   
    }
}