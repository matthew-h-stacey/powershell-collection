<#
.SYNOPSIS
    This script will create a Compliance Search and initiate a "Soft Delete" of any emails found in the search, using the required parameters. A typical use-case for this would be deleting unsafe email that was delivered to multiple recipients.
.PARAMETER SearchName
    This is the descriptive name for the search, example "OneDrive phish emails" or similar.
.PARAMETER Case
    This string is for the ServiceNow Case number associated with the request.
.PARAMETER Subject
    Enter the full (or partial) subject of the email address to search for.
.PARAMETER From
    Enter the sender, or "From" address. This is the sender of the malicious email you are searching for.
.PARAMETER Mailbox
    Enter the recipient, or "To" address. Or, enter "All" to search all mailboxes for the email.
.EXAMPLE
    C:\PS> 
    New-ComplianceSearchEmailDeletion -SearchName "OneDrive phish emails" -Case CS000123 -Subject "You have a new file shared with you" -From noreply@microsoft.com -Mailbox All
.NOTES
    Author: Matt Stacey
    Date:   December 15, 2021
#>

Param
(   
    [Parameter(Mandatory = $true)] [string] $SearchName,
    [Parameter(Mandatory = $true)] [string] $Case,
    [Parameter(Mandatory = $true)] [string] $Subject,
    [Parameter(Mandatory = $true)] [string] $From,
    [Parameter(Mandatory = $true)] [string] $Mailbox
)

function Get-ComplianceSearchStatus {
    Get-ComplianceSearch $SearchName | Select-Object -ExpandProperty Status
}

function Request-ComplianceSearchStatus {
    $result = ""
    Write-Host "Checking to see if ComplianceSearch is done ..."
    do {
        $result = Get-ComplianceSearchStatus
        Write-Host "Not done yet, waiting 30 seconds"
        Start-Sleep -Seconds 30

    } while ($result -notlike "Completed")
    if ($result -eq "Completed") {
        Write-Host "ComplianceSearch is Completed"
    }
}

function Remove-ComplianceSearchEmails {
    New-ComplianceSearchAction -SearchName $SearchName -Purge -PurgeType SoftDelete -Confirm:$false | Out-Null
}

# Connect to Protection and Compliance center
Connect-IPPSSession -ConnectionUri https://ps.compliance.protection.outlook.com/powershell-liveid/

# Format the query using input from parameters
$ContentMatchQuery = "subject:" + """$Subject""" + " AND " + "from:" + $From
# The query is formatted like the following:
# subject:"You have a new file shared with you" AND from:noreply@microsoft.com

# Create a new Compliance Search
New-ComplianceSearch -Name $SearchName -ExchangeLocation $Mailbox -ContentMatchQuery $ContentMatchQuery -Description $Case

# Start the new Compliance Search
Start-ComplianceSearch -Identity $SearchName
Write-Host "Waiting one minute to let ComplianceSearch run ..."
Start-Sleep -Seconds 60 # Wait at least 60 seconds before starting to check

# Continue to check status of the search, finishes when it is done
Request-ComplianceSearchStatus

# Issue a Soft Delete of the emails the search finds
Remove-ComplianceSearchEmails


