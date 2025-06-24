<# Option 1 - Non-interactive. Script simply fails if not run as admin#>
# Add the following (including the #) to the top of the script

#Requires -RunAsAdministrator

<# Option 2 - Interactive. User gets popup and has to press enter to close script #>
# Add the following before other script execution

if (([Security.Principal.WindowsPrincipal][Security.Principal.WindowsIdentity]::GetCurrent()).IsInRole([Security.Principal.WindowsBuiltInRole]::Administrator) -eq $False) {
    Write-Error "Script requires Administrator access. Re-run as Administrator"
    break
}