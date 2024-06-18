<#
.SYNOPSIS
This script updates calendar permissions for a given trustee

.PARAMETER Mailbox
The mailbox containing the calendar

.PARAMETER Calendar
The path of the calendar to manage

.PARAMETER Trustee
The user who is being granted access to the calendar

.PARAMETER AccessRights
The level of permissions to grant the trustee

.NOTES
See https://learn.microsoft.com/en-us/powershell/module/exchange/add-mailboxfolderpermission?view=exchange-ps for more details on the specific AccessRights levels
#>

function Update-EXOCalendarPermissions {

    param (
        # Mailbox
        [ArgumentCompleter({
                param ($CommandName, $ParameterName, $WordToComplete, $CommandAst, $FakeBoundParameters)

                $params = @{}
                if ( $WordToComplete ) {
                    $params["Filter"] = "PrimarySmtpAddress -like '*" + $WordToComplete + "*'"
                }
                Get-Mailbox @params | Sort-Object DisplayName | ForEach-Object {
                    New-SkyKickCompletionResult -Value $_.PrimarySmtpAddress -DisplayName $_.PrimarySmtpAddress
                }
            })]
        [SkyKickParameter(
            DisplayName = "Mailbox"
        )] 
        [Parameter(Mandatory = $true)]
        [string] $Mailbox,

        # Calendar
        [ArgumentCompleter({
                param ($CommandName, $ParameterName, $WordToComplete, $CommandAst, $FakeBoundParameters)

                if ($fakeBoundParameters.ContainsKey('Mailbox')) {

                    Get-MailboxFolderStatistics -Identity $fakeBoundParameters['Mailbox'] | Where-Object { $_.FolderPath -like "/Calendar*" -and $_.FolderPath -notlike "/Calendar Logging" } | Select-Object Name, Identity | ForEach-Object {
                        New-SkyKickCompletionResult -Value $_.Identity -DisplayName $_.Name
                    }
                }
            })]   
        [SkyKickParameter(
            DisplayName = "Calendar"
        )]
        [Parameter(Mandatory = $false)]
        [String]$Calendar,

        # Trustee
        [ArgumentCompleter({
                param ($CommandName, $ParameterName, $WordToComplete, $CommandAst, $FakeBoundParameters)

                $params = @{}
                if ( $WordToComplete ) {
                    $params["Filter"] = "PrimarySmtpAddress -like '*" + $WordToComplete + "*'"
                }
                Get-Mailbox @params | Sort-Object DisplayName | ForEach-Object {
                    New-SkyKickCompletionResult -Value $_.PrimarySmtpAddress -DisplayName $_.PrimarySmtpAddress
                }
            })]
        [SkyKickParameter(
            DisplayName = "Trustee"
        )] 
        [Parameter(Mandatory = $true)]
        [string] $Trustee,

        [Parameter(Mandatory = $true)]
        [string]
        [ValidateSet("None", "Author", "Editor", "NonEditingAuthor", "Owner", "PublishingAuthor", "PublishingEditor", "Reviewer")]
        $AccessRights
    )

    # Replace the first "\" with ":\"
    $splitPath = $Calendar -split '\\', 2
    $calendarPath = "$($splitPath[0]):\$($splitPath[1])"

    try {
        $trusteePerms = Get-MailboxFolderPermission -Identity $calendarPath -User $Trustee -ErrorAction SilentlyContinue
    } catch {
        # User does not already have permissions
    }
    if ( $trusteePerms ) {
        if ( $AccessRights = "None") {
            # Just remove the user's permissions
            try {
                Remove-MailboxFolderPermission -Identity $calendarPath -User $Trustee -Confirm:$False
            } catch {
                Write-Output "[ERROR] Failed to remove $Trustee $AccessRights permissions from $calendarPath. Error $($_.Exception.Message)"
            }
        } else {
            # If trustee has access but the permission level does not match the request, remove and re-add the requested permissiosn
            if ( $trusteePerms.AccessRights -ne $AccessRights ) {
                Remove-MailboxFolderPermission -Identity $calendarPath -User $Trustee -Confirm:$False
                Add-MailboxFolderPermission -Identity $calendarPath -User $Trustee -AccessRights $AccessRights | Out-Null
                Write-Output "[INFO] Replaced ${Trustee}'s permissions over $calendarPath with $AccessRights."
            }
        } else {
            # Trustee does not have permissions. Grant them access
            try {
                Add-MailboxFolderPermission -Identity $calendarPath -User $Trustee -AccessRights $AccessRights -ErrorAction Stop | Out-Null
                Write-Output "[INFO] Granted $Trustee $AccessRights to $calendarPath"
            } catch {
                Write-Output "[ERROR] Failed to grant $Trustee $AccessRights to $calendarPath. Error $($_.Exception.Message)"
            }
        }
    }

}