function Update-EXOMailboxDelegationNotifications {

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
            
        # SendNotificationToUser
        [Parameter(Mandatory = $true)]
        [boolean] $SendNotificationToUser 
    )

    # Replace the first "\" with ":\"
    $splitPath = $Calendar -split '\\', 2
    $calendarPath = "$($splitPath[0]):\$($splitPath[1])"

    try {
        $trusteePerms = Get-MailboxFolderPermission -Identity $calendarPath -User $Trustee -ErrorAction SilentlyContinue
    } catch {
        # User does not already have permissions
        Write-Error "[ERROR] $Trustee does not have delegate access to $calendarPath"
    }
    if ( $trusteePerms ) {
        Set-MailboxFolderPermission -Identity ayla@contoso.com:\Calendar -User ed@contoso.com -AccessRights Editor -SharingPermissionFlags Delegate -SendNotificationToUser $true

    }

    
    


	
}