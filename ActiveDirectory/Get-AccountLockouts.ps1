# Optional parameters for user as well as start/end times for the filter
Param
(
    [Parameter(Mandatory = $false)] [string] $StartTime,
    [Parameter(Mandatory = $false)] [string] $EndTime,
    [Parameter(Mandatory = $false)] [string] $User
)

# ex: .\Get-AccountLockouts.ps1 -StartTime 1/1/2021 -EndTime 1/7/2021 -User jsmith@contoso.com

# Default values for filter. Query the PDC Event Viewer entries with ID to 4740 for account lockout
$PDCEmulator = (Get-ADDomain).PDCEmulator
$LockOutID = 4740

# Create the initial hash table with default values for FilterHashtable
$filterOptions = @{
    LogName = "Security"
    ID      = "$LockOutID"
}

# Adds the values of optional parameters above, if applicable
if($StartTime){
    $filterOptions.StartTime = Get-Date -Date $StartTime
}
if($EndTime){
    $filterOptions.EndTime = Get-Date -Date $EndTime
}

# Get Windows events from the PDC based on the filter
$events = Get-WinEvent -ComputerName $PDCEmulator -FilterHashtable $filterOptions

# Create an empty array, then populate it with the results of the search
$results = @()
foreach ($event in $events) {
    $eventExport = [pscustomobject]@{
        UserName       = $event.Properties[0].Value
        CallerComputer = $event.Properties[1].Value
        TimeStamp      = $event.TimeCreated
        }
        $results += $eventExport
    }
    
# If a user was specified, return results only for that user. Otherwise, return all data
if($User){

    $userLockouts = $results | Where-Object{ $_.UserName -like "$User" }

    if ( $null -eq $userLockouts ) {
        Write-Output "NOTICE: No lockouts found for $($User) in the specified timeframe"
        }
    else {
        $userLockouts
        }
    }
else{
    $results
    }