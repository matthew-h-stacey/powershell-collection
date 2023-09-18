function Disable-DirSync {
[SkyKickCommand(DisplayName = "Set Parameter Sections", Sections = { "Confirm" })]
    param(
	
        [SkyKickParameter(
            DisplayName = "Are you sure you want to disable DirSync on the tenant? If you use this command, you must wait 72 hours before you can turn directory synchronization back on. https://learn.microsoft.com/en-us/microsoft-365/enterprise/turn-off-directory-synchronization?view=o365-worldwide",    
            Section = "Confirm",
            DisplayOrder = 1
        )]
        [Parameter(Mandatory=$true)]
        [ValidateSet("Yes")]
        [string]$UserConfirmation

    )
	
    if ( $UserConfirmation -like "Yes" ) {

        try {
            Set-MsolDirSyncEnabled -EnableDirSync $false -Force -ErrorAction Stop -WarningAction Stop
            Write-Output "Successfully disabled DirSync on the tenant"
        }
        catch {
            Write-Output "Failed to disable DirSync on the tenant."
        }

    }

}