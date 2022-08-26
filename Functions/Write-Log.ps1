Function Write-Log{
    Param ([string]$logstring)
    Add-Content $logFile -Value "$(Get-Date -Format "MM/dd/yyyy HH:mm") $logstring"
    }