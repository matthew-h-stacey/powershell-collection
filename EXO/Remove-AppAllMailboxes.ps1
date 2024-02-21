<#
.SYNOPSIS
Remove a specific app from all mailboxes

.EXAMPLE
.\Remove-AppAllMailboxes.ps1 -AppName Trustifi
#>

param(
    # The display name of the app to remove (ex: Trustifi)
    [Parameter(Mandatory=$true)]
    [String]
    $AppName
)

$mailboxes = Get-Mailbox -ResultSize unlimited
$mailboxes | ForEach-Object {
    $upn = $_.UserPrincipalName
    $appToRemove = Get-App -Mailbox $upn | Where-Object { $_.DisplayName -like $appname}
    if ( $appToRemove ) { 
        Write-Output "[$upn] Located unwanted app. App name: $($appToRemove.DisplayName). App ID: $($appToRemove.AppId)"
        Write-Output "[$upn] Attempting to remove app ..."
        try {
            Remove-App -Identity $appToRemove.AppId -Mailbox $upn -Confirm:$false
            Write-Output "[$upn] Successfully removed app"
        }
        catch {
            Write-Output "[$upn] Failed to remove app: $($appToRemove.DisplayName). Error: $($_.Exception.Message)"
        }
    }
}