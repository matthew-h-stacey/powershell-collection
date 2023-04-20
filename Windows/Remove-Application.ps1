<#

.SYNOPSIS
Uninstall an application by providing the display name from the Control Panel

.DESCRIPTION
Uses the registry to query applications for uninstall executables and their parameters. This method can be preferable over Win32_Product both for performance reasons combined with the fact that it supports uninstallation for programs installed via EXE, not just MSI. The script will first attempt to uninstall using the QuietUninstallString if provided, otherwise it will use UninstallString. These depend on the software developer properly publishing the switches to the registry but they are not always accurate.

.PARAMETER DisplayerName
The display name of the application from the Control Panel.

.PARAMETER Force
Skips the confirmation (Y/N) prompt. Required for running without user input. 

.EXAMPLE
.\Remove-Application.ps1 -DisplayName "Mozilla Firefox (x64 en-US)" -Force

.NOTES
By Matt Stacey
4/20/2023

#>



param(
    
    [Parameter(Mandatory = $True)][String]$DisplayName,
    [Parameter(Mandatory = $False)][Switch]$Force

)

function Remove-Application {

    # Uses Regex to split the path from the published parameters 
    # Has custom handling for 1 application so far where the published parameters are not actually silent
    # Uses Start-Process to call the exeuctable with the parameters 
    
    [CmdletBinding()]
    param (
        [Parameter(Mandatory = $true, ValueFromPipeline = $true)]
        [PSCustomObject]$Application
    )

    # Custom handling for problematic application (QuietUninstallString is inaccurate)
    if ($DisplayName -eq "BCS Remote Backup") {

        Write-Output "[Custom Handling] Application: BCS Remote Backup"
        $ExtractedString = $Application.QuietUninstallString
        $Regex = [Regex]'"([^"]+)"(.*)'
        $Matches = $Regex.Match($extractedString)
        $Path = $matches.Groups[1].Value
        $Arguments =  "/VERYSILENT /SUPPRESSMSGBOXES /NORESTART /SP-"
    }
    elseif ($Application.QuietUninstallString) {
        Write-Output "INFO: Located QuietUninstallString: $($Application.QuietUninstallString)"

        $ExtractedString = $Application.QuietUninstallString
        $Regex = [Regex]'"([^"]+)"(.*)'
        $Matches = $Regex.Match($extractedString)
        $Path = $matches.Groups[1].Value
        $Arguments = $matches.Groups[2].Value.Trim()
    }
    elseif ($Application.UninstallString) {
        Write-Output "INFO: Located UninstallString: $($Application.UninstallString)"

        $ExtractedString = $Application.UninstallString
        $Regex = [Regex]'"([^"]+)"(.*)'
        $Matches = $Regex.Match($extractedString)
        $Path = $Matches.Groups[1].Value
        $Arguments = $Matches.Groups[2].Value.Trim()   
    }

    Write-Output "INFO: Attempting to uninstall $($Application.DisplayName) ..."
    
    try {
        Start-Process -FilePath $Path -ArgumentList $Arguments -NoNewWindow -Wait -PassThru | Out-Null
        Write-Output "SUCCESS: $($Application.DisplayName) successfully uninstalled."
    }
    catch {
        Write-Output "ERROR: An error occurred when attempting to uninstall $($Application.DisplayName): $_"
    }

}

# Y/N confirmation required if -Force is not used
if (-not $Force) {

    Write-Output "CAUTION: This script will attempt to uninstall $($DisplayName) from the computer. "
    $Answer = Read-Host "Are you sure you want to proceed? (Y/N)?"

    if ($Answer -eq "y" -or $Answer -eq "Y") {
        Write-Output "Proceeding with uninstall script"
    } elseif ($answer -eq "n" -or $answer -eq "N") {
        Write-Output "Exiting script."
        exit
    } else {
        Write-Output "Invalid input. Please enter 'y' or 'n'."
    }

}

# Locate and uninstall 32-bit version of application
$Apps32bit = Get-ItemProperty "HKLM:\SOFTWARE\Wow6432Node\Microsoft\Windows\CurrentVersion\Uninstall\*"
Write-Output "INFO: Attempting to locate 32-bit version of application: $($DisplayName) ..."
$AppToRemove32bit = $Apps32bit | Where-Object { $_.DisplayName -eq $DisplayName }
if ( $AppToRemove32bit ) {
    Write-Output "INFO: Located 32-bit application $($AppToRemove32bit.DisplayName). Publisher $($AppToRemove32bit.Publisher)."
    $AppToRemove32bit | Remove-Application
}
else {
    Write-Output "SKIPPED: No 32-bit installed application: $DisplayName. Checking 64-bit next ..."
}

# Locate and uninstall 64-bit version of application
$Apps64bit = Get-ItemProperty "HKLM:\SOFTWARE\Microsoft\Windows\CurrentVersion\Uninstall\*"
$AppToRemove64bit = $Apps64bit | Where-Object { $_.DisplayName -eq $DisplayName }
if ( $AppToRemove64bit ) {
    Write-Output "INFO: Located 64-bit application $($AppToRemove64bit.DisplayName). Publisher $($AppToRemove64bit.Publisher)."
    $AppToRemove64bit | Remove-Application
}
else {
    Write-Output "SKIPPED: No 64-bit installed application: $DisplayName."
}