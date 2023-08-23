[CmdletBinding()]
param (
    [Parameter(Mandatory = $true)][string]$Name,
    [Parameter(Mandatory = $true)][string]$DisplayName,
    [Parameter(Mandatory = $true)][string]$PrimarySmtpAddress,
    [Parameter(Mandatory = $false)][string]$Trustee,
    [Parameter(Mandatory = $false)][switch]$Hidden,
    [Parameter(ParameterSetName = "Shared")][switch]$Shared,
    [Parameter(ParameterSetName = "Room")][switch]$Room
)

# Shared:
if($Shared){
    New-Mailbox -DisplayName $DisplayName -Name $Name -PrimarySmtpAddress $PrimarySmtpAddress -Shared | Out-Null
}


# Room:
if($Room){
    New-Mailbox -DisplayName $DisplayName -Name $Name -PrimarySmtpAddress $PrimarySmtpAddress -Room  | Out-Null
}

# Optional: Grant user FullAccess to new mailbox
if ($Trustee){
    Add-MailboxPermission -Identity $PrimarySmtpAddress -User $Trustee -AccessRights FullAccess
}

# Optional: Hide the new mailbox
if ($Hidden) {
    Set-Mailbox -Identity $PrimarySmtpAddress -HiddenFromAddressListsEnabled:$true
}
