<#
.SYNOPSIS
This script creates a Shared or Room mailbox with convenient options to hide it from the GAL and add a trustee (full access user)

.EXAMPLE
New-DistributionGroup -Name $Name -ManagedBy $ManagedBy -Notes $CaseNumber -PrimarySmtpAddress $PrimarySmtpAddress
#>

[CmdletBinding()]
param (
    # Name of the shared mailbox
    [Parameter(Mandatory = $true)]
    [string]
    $Name,

    # Display name of the shared mailbox
    [Parameter(Mandatory = $true)]
    [string]
    $DisplayName,

    # The primary email address
    [Parameter(Mandatory = $true)]
    [string]
    $PrimarySmtpAddress,

    # Optional user to grant full control to
    [Parameter(Mandatory = $false)]
    [string]
    $Trustee,

    # Hide from the GAL
    [Parameter(Mandatory = $false)]
    [switch]
    $Hidden,

    # Use to specifically create a Room mailbox
    [Parameter(ParameterSetName = "Room")]
    [switch]
    $Room
)

# Initialize hashtable for mailbox creation
$params = @{
    DisplayName         = $DisplayName
    Name                = $Name
    PrimarySmtpAddress  = $PrimarySmtpAddress
}

# Add the appropriate type of mailbox
if ($Room) {
    $params['Room'] = $true
} else {
    $params['Shared'] = $true
}

# Attempt to create the mailbox
try {
    New-Mailbox @params
    Write-Output "[INFO] Successfully created $PrimarySmtpAddress"
} catch {
    Write-Output "[ERROR] Failed to create $PrimarySmtpAddress. Error: $($_.Exception.Message)"  -ErrorAction Stop
    exit
}

# Optional: Grant user FullAccess to new mailbox
if ($Trustee){
    try { 
        $isValid = Get-Mailbox $Trustee -ErrorAction Stop
    } catch {
        Write-Output "[ERROR] Failed to locate mailbox for $Trustee. Unable to grant FullAccess to $PrimarySmtpAddress"
    }
    if ( $isValid ) {
        try {
            Add-MailboxPermission -Identity $PrimarySmtpAddress -User $Trustee -AccessRights FullAccess -ErrorAction Stop
        } catch {
            Write-Output "[ERROR] Failed to grant $Trustee FullAccess to $PrimarySmtpAddress. Error: $($_.Exception.Message)"
        }
    }
}

# Optional: Hide the new mailbox
if ($Hidden) {
    Set-Mailbox -Identity $PrimarySmtpAddress -HiddenFromAddressListsEnabled:$true
}
