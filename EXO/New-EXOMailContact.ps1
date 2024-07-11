function New-EXOMailContact {

    <#
    .SYNOPSIS
    Create a mail contact with an internal PrimarySmtpAddress and external alias

    .PARAMETER DisplayName
    The display name of the mail contact

    .PARAMETER Alias
    The alias/name of the mail contact

    .PARAMETER PrimarySmtpAddress
    The internal email address of the mail contact

    .PARAMETER ExternalEmailAddress
    The external email address of the mail contact

    .EXAMPLE
    New-EXOMailContact -DisplayName "IT Support" -Alias itsupport -PrimarySmtpAddress itsupport@contoso.com -ExternalEmailAddress support@fabrikam.com
    #>

    param (
        [Parameter(Mandatory = $true)]
        [string]
        $DisplayName,

        [Parameter(Mandatory = $true)]
        [string]
        $Alias,

        [Parameter(Mandatory = $true)]
        [ValidatePattern('^[\w-\.]+@([\w-]+\.)+[\w-]{2,4}$')]
        [string]
        $PrimarySmtpAddress,

        [Parameter(Mandatory = $true)]
        [ValidatePattern('^[\w-\.]+@([\w-]+\.)+[\w-]{2,4}$')]
        [string]
        $ExternalEmailAddress 
    )

    $isSuccessful = $true
    try {
        $null = New-MailContact  -Name $DisplayName -Alias $Alias -ExternalEmailAddress "SMTP:$ExternalEmailAddress" -ErrorAction Stop -WarningAction Stop
        $emailAddresses = "SMTP:$PrimarySmtpAddress", "smtp:$ExternalEmailAddress"
        try {
            Set-Mailcontact $Alias -EmailAddresses $emailAddresses -ErrorAction Stop -WarningAction Stop
        } catch {
            Write-Output "[ERROR] Failed to set email addresses on mail contact. Error: $($_.Exception.Message)"
            $isSuccessful = $false
            exit 1
        }
    } catch {
        Write-Output "[ERROR] Failed to create new mail contact: $DisplayName. Error: $($_.Exception.Message)"
        $isSuccessful = $false
        exit 1
    }
    if ( $isSuccessful ) {
        Write-Output "[SUCCESS] Created new mail contact '$DisplayName' ($PrimarySmtpAddress -> $ExternalEmailAddress)"
    }
	
}