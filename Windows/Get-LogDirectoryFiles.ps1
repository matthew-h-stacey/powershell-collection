# Objective: Use a PS script and Task Scheduler to create Event Logs that monitor and alert on the lack of new logs in a specific directory
# Example: SyncBackPro logs

$LogDirectory = "C:\SyncBackPro logs" # the directory where the SyncBackPro profile stores logs in
$TimeThreshold = (Get-Date).AddHours(-24) # the threshold of time to pass before reporting an error
$EventSource = "SyncBackProMonitoring" # a custom EventLog Source to track events related to SyncBackPro

try {
    if (-not (Get-EventLog -LogName Application -Source $EventSource -ErrorAction Stop)) { 
        New-EventLog -LogName Application -Source $EventSource # create the custom EventLog Source only if it doesn't exist
    }

    $latestFile = Get-ChildItem -Path $LogDirectory -File | Sort-Object LastWriteTime -Descending | Select-Object -First 1 # find the newest file in the log directory

    if ($latestFile.LastWriteTime -lt $TimeThreshold) {
        # if the file is older than 24 hours, create an error
        $eventParams = @{
            LogName   = "Application"
            Source    = $EventSource 
            EventID   = 1001
            EntryType = "Error"
            Category  = 1
            Message   = "SyncBackPro: No new log files created within the last 24 hours in $LogDirectory. Confirm that the profiles configured under the username syncbackpro are still enabled."
        }

        Write-EventLog @eventParams
    }
    else {
        # if the file is newer than 24 hours, create an information event
        $eventParams = @{
            LogName   = "Application"
            Source    = $EventSource 
            EventID   = 1002
            EntryType = "Information"
            Category  = 1
            Message   = "SyncBackPro: New log files have been created within the last 24 hours in $LogDirectory. This check indicates that the job is still functional."
        }

        Write-EventLog @eventParams
    }
}
catch {
    # attempt to catch errors created by the script
    Write-Host "Error occurred: $($_.Exception.Message)"
}
