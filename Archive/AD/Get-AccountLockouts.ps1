$PDCEmulator = (Get-ADDomain).PDCEmulator
$LockOutID = 4740
$events = Get-WinEvent -ComputerName $PDCEmulator -FilterHashtable @{
    LogName = 'Security'
    ID      = $LockOutID
}

$results = @()
foreach ($event in $events) {
    $eventExport = [pscustomobject]@{
        UserName       = $event.Properties[0].Value
        CallerComputer = $event.Properties[1].Value
        TimeStamp      = $event.TimeCreated
    }
    $results += $eventExport
}
$results

# Optional: Specific user:
$results | ?{$_.UserName -like "PatrickF"}