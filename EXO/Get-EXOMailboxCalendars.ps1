<#
.SYNOPSIS
A script to report on calendars/calendar permissions for a mailbox

.DESCRIPTION
Use this script to either output a list of all calendars in a user mailbox (useful for finding/applying permissions at a client's request) or output permissions for review

.PARAMETER PrimarySmtpAddress
Address of the mailbox to query

.PARAMETER Permissions
Optional parameter to output a list of permissions across all calendars in the mailbox

.EXAMPLE
Get-EXOMailboxCalendars -PrimarySmtpAddress jsmith@contoso.com
#>

param(
    [Parameter(Mandatory = $true)]
    [string]
    $PrimarySmtpAddress,

    [Parameter(Mandatory = $false, ParameterSetName = "Permissions")]
    [switch]
    $Permissions
)

$results = [System.Collections.ArrayList]@()
$mailbox = Test-EXOMailbox -PrimarySmtpAddress $PrimarySmtpAddress
if ( $mailbox ) {

    $calendars = Get-MailboxFolderStatistics $Mailbox | Where-Object { $_.FolderPath -like "/Calendar*" -and $_.FolderPath -notlike "/Calendar Logging" } | Select-Object Name, Identity
    if ( $Permissions ) {
        $calendars | ForEach-Object {
            # Replace the first "\" with ":\"
            $splitPath = $_.Identity -split '\\', 2
            $calendarPath = "$($splitPath[0]):\$($splitPath[1])"
            Get-MailboxFolderPermission -Identity $calendarPath | ForEach-Object {
                $mailboxOutput = [PSCustomObject]@{
                    Mailbox    = $mailbox.UserPrincipalName
                    Calendar   = $calendarPath
                    Trustee    = $_.User
                    Permission = [string]$_.AccessRights
                }
                $results.Add($mailboxOutput) | Out-Null
            }
        }
        $results | Format-Table

    } else {
        return $calendars
    }

} else {
    Write-Output "[ERROR] Unable to locate mailbox: $Mailbox. Please check that the email address provided is valid and try again"
}