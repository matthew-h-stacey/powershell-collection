<#
.SYNOPSIS
Creates a distribution list with options to add members from txt file and set autoreply

.EXAMPLE
New-EXODistributionList.ps1 -Name "Lunch Crew" -ManagedBy jsmith@contoso.com -CaseNumber CS123456 -PrimarySmtpAddress lunchcrew@contoso.com -Path C:\TempPath\lunchcrewusers.txt
#>

param (
    # Name of the new distribution list
    [Parameter(Mandatory = $true)]
    [string]
    $Name,

    # Primary email address of the distibution list
    [Parameter(Mandatory = $true)]
    [string]
    $PrimarySmtpAddress,

    # Owner of the distribution list
    [Parameter(Mandatory = $true)]
    [string]
    $ManagedBy,

    # Optional case number
    [Parameter(Mandatory = $false)]
    [string]
    $CaseNumber,

    # Path to a txt file containing the email addresses of users to add
    [Parameter(Mandatory = $false)]
    [string]
    $File,  

    # Optional autoreply message text
    [Parameter(Mandatory = $false)]
    [string]
    $AutoReplyMessage
)

# Initialize hashtable for mailbox creation
$params = @{
    ManagedBy           = $ManagedBy
    Name                = $Name
    PrimarySmtpAddress  = $PrimarySmtpAddress
}
# Optionally add CaseNumber
if ($CaseNumber) {
    $params['CaseNumber'] = $true
}

try {
    New-DistributionGroup @params -ErrorAction Stop
} catch {
    Write-Output "[ERROR] Failed to create new distribution group $PrimarySmtpAddress. Error message: $($_.Exception.Message)"
}

# Add all members
if ( $File ) {
    $users = Get-Content -Path $File
    foreach($u in $users){
        try { 
            $isValid = Get-Mailbox $u -ErrorAction Stop
        } catch {
            Write-Output "[ERROR] Failed to locate mailbox for $Trustee. Unable to add them to $PrimarySmtpAddress"
        }
        if ( $isValid ) {
            try { 
                Add-DistributionGroupMember -Identity $PrimarySmtpAddress -Member $u
            } catch {
                Write-Output "[ERROR] Failed to add $u to $PrimarySmtpAddress. Error: $($_.Exception.Message)"
            }
        }    
    }
}

if ( $AutoReplyMessage ) {
    Set-MailboxAutoReplyConfiguration -Identity $PrimarySmtpAddress -AutoReplyState Enabled -InternalMessage $AutoReplyMessage -ExternalMessage $AutoReplyMessage 
}