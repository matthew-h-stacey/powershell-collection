# Purpose:
# Run a ping test and log the output with timestamps to a log file for troubleshooting

$hostAddress = "1.1.1.1"
$logFile = "C:\TempPath\pingtest.log"

ping.exe -t $hostAddress | Foreach{"{0} - {1}" -f (Get-Date),$_} | Out-File $logFile