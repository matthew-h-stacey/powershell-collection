function New-EXOTeamsRoomMailbox {

    <#
    .SYNOPSIS
    Create a mailbox to be used for a Teams Room. After running this, apply a Teams Room license to the account.

    .PARAMETER UserPrincipalName
    The UserPrincipalName for the mailbox (ex: confroomA@contoso.com)

    .PARAMETER Alias
    The name/alias for the mailbox (ex: confroomA)

    .PARAMETER ProcessExternalMeetingMessages
    Whether or not external senders shall be allowed to send calendar invitations directly to the room mailbox. If disabled, an internal user will need to invite the room to the meeting.

    .PARAMETER Password
    The password for the mailbox

    .PARAMETER City
    The city where the conference room is located

    .PARAMETER State
    The state where the conference room is located

    .PARAMETER Floor
    The floor number where the conference room is located

    .PARAMETER FloorLabel
    A friendly name to describe the floor number where this conference room is located (ex: Ground, Main)

    .PARAMETER Capacity
    The capacity of this conference room

    .NOTES
    Reference https://learn.microsoft.com/en-us/microsoftteams/rooms/create-resource-account?tabs=exchange-online%2Cgraph-powershell-password for additional information
    #>

    [SkyKickCommand(DisplayName = "Set Parameter Sections", Sections = { "Basic Details", "Room location", "Password" })]
    param (
        [SkyKickParameter(
                DisplayName = "UserPrincipalName",    
                Section = "Basic Details",
                DisplayOrder = 1,
                HintText = "Enter the desired UserPrincipalName for the Teams Room user account."
            )]
        [Parameter(Mandatory= $true)]
        [string]
        $UserPrincipalName,

        [SkyKickParameter(
            DisplayName = "Alias",    
            Section = "Basic Details",
            DisplayOrder = 2,
            HintText = "Enter the desired alias/name for the Teams Room user account."
        )]
        [Parameter(Mandatory=$true)]
        [string]
        $Alias,

        [SkyKickParameter(
            DisplayName = "Process external meeting requests",    
            Section = "Basic Details",
            DisplayOrder = 3,
            HintText = "Enable or disable the ability for external senders to book meetings on this calendar."
        )]
        [Parameter(Mandatory = $true)]
        [boolean]
        $ProcessExternalMeetingMessages,

        [SkyKickParameter(
                DisplayName = "Password",
                Section = "Password",
                DisplayOrder = 1,
                HintText = "Enter the password for the Teams Room user account.",
                Sensitive = $true
        )]
        [ValidatePattern(
            "(?=.{8,})((?=.*\d)(?=.*[a-z])(?=.*[A-Z])|(?=.*\d)(?=.*[a-zA-Z])(?=.*[\W_])|(?=.*[a-z])(?=.*[A-Z])(?=.*[\W_])).*",
            ErrorMessage = "The specified password does not comply with password complexity requirements. Please provide a different password."
        )]
        [Parameter (Mandatory = $true)]
        [SecureString]$Password,
        
        [SkyKickParameter(
            DisplayName = "City",
            Section = "Room location",
            DisplayOrder = 1,
            HintText = "The city where this conference room is located."
        )]
        [Parameter(Mandatory = $true)]
        [string]
        $City,

        [SkyKickParameter(
            DisplayName = "State",
            Section = "Room location",
            DisplayOrder = 2,
            HintText = "The state where this conference room is located."
        )]
        [Parameter(Mandatory = $true)]
        [string]
        $State,

        [SkyKickParameter(
            DisplayName = "Floor",
            Section = "Room location",
            DisplayOrder = 3,
            HintText = "The floor number where this conference room is located."
        )]
        [Parameter(Mandatory = $true)]
        [string]
        $Floor,

        [SkyKickParameter(
            DisplayName = "Floor label",
            Section = "Room location",
            DisplayOrder = 4,
            HintText = "A friendly name to describe the floor number where this conference room is located (ex: Ground, Main)."
        )]
        [Parameter(Mandatory = $false)]
        [string]
        $FloorLabel,

        [SkyKickParameter(
            DisplayName = "Floor",
            Section = "Room location",
            DisplayOrder = 5,
            HintText = "The capacity of this conference room"
        )]
        [Parameter(Mandatory = $true)]
        [int]
        $Capacity
    )

    $operationSucceeded = $true

    # 1) Create the room mailbox
    $mailboxParams = @{
        MicrosoftOnlineServicesID   = $UserPrincipalName
        Name                        = $Alias
        Alias                       = $Alias
        Room                        = $true
        EnableRoomMailboxAccount    = $true 
        RoomMailboxPassword         = $Password
    }
    try {
        $null = New-Mailbox @mailboxParams -ErrorAction Stop
        Write-Output "[INFO] Successfully created new room mailbox: $UserPrincipalName"

        # 2) Set calendar settings
        $calendarParams = @{
            Identity                        = $Alias
            AutomateProcessing              = "AutoAccept"
            AddOrganizerToSubject           = $false
            DeleteComments                  = $false
            DeleteSubject                   = $false
            ProcessExternalMeetingMessages  = $ProcessExternalMeetingMessages
            RemovePrivateProperty           = $false
            AddAdditionalResponse           = $true
        }
        try {
            Set-CalendarProcessing @calendarParams -ErrorAction Stop
            Write-Output "[INFO] Successfully applied calendar processing settings to room mailbox: $UserPrincipalName"

            # 3) Disable password expiration
                try {
                    Update-MgUser -UserId $UserPrincipalName -PasswordPolicies DisablePasswordExpiration -ErrorAction Stop
                    Write-Output "[INFO] Successfully disabled password expiration for room mailbox: $UserPrincipalName"
                } catch {
                    Write-Output "[ERROR] Failed to disable password expiration for room mailbox: $UserPrincipalName"
                    $operationSucceeded = $false
                }
        } catch {
            Write-Output "[ERROR] Failed to apply calendar processing settings to room mailbox: $UserPrincipalName. Error: $($_.Exception.message)"
            $operationSucceeded
        }
    } catch {
        Write-Output "[ERROR] Failed to create new mailbox: $UserPrincipalName. Error: $($_.Exception.message)"
        $operationSucceeded = $false
        exit 1
    }

    # 4) Set location metadata for Room Finder
    if ( $City ) {
        $locationParams.City = $City
    }
    if ( $State ) {
        $locationParams.State = $State
    }
    if ( $Floor ) {
        $locationParams.Floor = $Floor
    }
    if ( $FloorLabel ) {
        $locationParams.FloorLabel = $FloorLabel
    }
    if ( $Capacity ) {
        $locationParams.Capacity = $Capacity
    }

    try { 
        Set-Place -Identity $UserPrincipalName @locationParams
    } catch {
        Write-Output "[ERROR] Failed to set location metadata on room mailbox: $UserPrincipalName. Error: $($_.Exception.message)"
        $operationSucceeded = $false
        exit 1
    }

    if ( $operationSucceeded ) {
        Write-Output "[SUCCESS] Created new resource room calendar successfully"
    }

}