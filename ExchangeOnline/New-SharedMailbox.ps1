[CmdletBinding()]
param (
    [Parameter(Mandatory = $true)][string]$Name,
    [Parameter(Mandatory = $true)][string]$DisplayName,
    [Parameter(Mandatory = $true)][string]$PrimarySmtpAddress,
    [Parameter()][string]$Trustee,
    [Parameter(ParameterSetName = "Shared")][switch]$Shared,
    [Parameter(ParameterSetName = "Room")][switch]$Room
)

# Shared:
if($Shared){
    New-Mailbox -DisplayName $DisplayName -Name $Name -PrimarySmtpAddress $PrimarySmtpAddress -Shared
}


# Room:
if($Room){
    New-Mailbox -DisplayName $DisplayName -Name $Name -PrimarySmtpAddress $PrimarySmtpAddress -Room
}

# Optional: Grant user FullAccess to new mailbox
if ($Trustee){
    Add-MailboxPermission -Identity $PrimarySmtpAddress -User $Trustee -AccessRights FullAccess
}
