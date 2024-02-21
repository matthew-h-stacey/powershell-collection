param (
    [parameter(Mandatory = $true)]
    [String[]]
    $Server,

    [parameter(ParameterSetName = "Name")]
    [String[]]
    $Name,

    [parameter(ParameterSetName = "DisplayName")]
    [String[]]
    $DisplayName
)

function New-Folder {
    
    <#
    .SYNOPSIS
    Determine if a folder already exists, or create it  if not.

    .EXAMPLE
    New-Folder C:\TempPath
    #>

    param(
        [Parameter(Mandatory = $True)]
        [String]
        $Path
    )
    if (-not (Test-Path -LiteralPath $Path)) {
        try {
            New-Item -Path $Path -ItemType Directory -ErrorAction Stop | Out-Null
        } catch {
            Write-Error -Message "Unable to create directory '$Path'. Error was: $_" -ErrorAction Stop
        }
    } 

}

function Write-Log {
    
    <#
    .SYNOPSIS
    Log to a specific file/folder path with timestamps

    .EXAMPLE
    Write-Log -Message "[INFO] Attempting to do the thing" -LogFile C:\Scripts\MyScript.log
    Write-Log -Message "[INFO] Attempting to do the thing" -LogFile $LogFile 
    #>
    
    param (
        [Parameter(Mandatory = $true)]
        [String]
        $Message,

        [Parameter(Mandatory = $true)]
        [String]
        $LogFile
    )

    $timeStampMessage = "$((Get-Date -Format "MM/dd/yyyy HH:mm:ss")) $Message"
    Add-Content -Value $timeStampMessage -Path $LogFile

}

function Start-ServiceRestartWorkflow {

    <#
    .SYNOPSIS
    Restart services, or just report on their status

    .EXAMPLE
    Start-ServiceRestartWorkflow -SkipRunning:$true -SearchMethod Name
    #>

    param (
        # Do not restart a service if it is already running
        [Parameter(Mandatory = $true)]
        [Boolean]
        $SkipRunning,

        # Parameter help description
        [Parameter(Mandatory = $true)]
        [ValidateSet("DisplayName", "Name")]
        [String]
        $SearchMethod,

        # Output to report
        [Parameter(Mandatory = $false)]
        [Switch]
        $Report
    )

    # Retrieve services based on Name/DisplayName
    switch ( $SearchMethod ) {
        "Name" {
            $services = Get-Service -ComputerName $serverName -Name $Name
        }
        "DisplayName" {
            $services = Get-Service -ComputerName $serverName -DisplayName $DisplayName
        }

    }
    $services | Sort-Object DisplayName | ForEach-Object {
        $serviceDisplayName = $_.DisplayName
        Write-Log -Message "[$serverName][$serviceDisplayName] Service is: $($_.Status)" -LogFile $logFile
        $isRunning = $_.Status -eq "Running"
        if ( $isRunning ) {
            if ( !$SkipRunning ) {
                try {
                    $_ | Restart-Service -Force -ErrorAction Stop -WarningAction SilentlyContinue
                    Write-Log -Message "[$serverName][$serviceDisplayName] Restarted service" -LogFile $logFile
                } catch {
                    Write-Log -Message "[$serverName][$serviceDisplayName] Failed to restart service. Error: $($_.Exception.Message)" -LogFile $logFile
                }
            }            
        } else {
            # start service
            try {
                $_ | Start-Service
                Write-Log -Message "[$serverName][$serviceDisplayName] Started service" -LogFile $logFile
            } catch {
                Write-Log -Message "[$serverName][$serviceDisplayName] Failed to start service. Error: $($_.Exception.Message)" -LogFile $logFile
            }
        }

        if ( $Report ) {
            $status = Get-Service -DisplayName $serviceDisplayName  | Select-Object -ExpandProperty Status
            Add-ReportContent -Server $serverName -ServiceDisplayName $serviceDisplayName -ServiceStatus $status
        }
    }

}

function Add-ReportContent {

    param (
        # Server name
        [Parameter(Mandatory = $true)]
        [String]
        $Server,

        # Service display name
        [Parameter(Mandatory = $true)]
        [String]
        $ServiceDisplayName,

        # Service status
        [Parameter(Mandatory = $true)]
        [String]
        $ServiceStatus
    )
    Add-Content $htmlReport "<tr>" 
    Add-Content $htmlReport "<td bgcolor= 'GainsBoro' align=center>  <B>$Server</B></td>" 
    Add-Content $htmlReport "<td bgcolor= 'GainsBoro' align=center>  <B>$ServiceDisplayName</B></td>" 
    Add-Content $htmlReport "<td bgcolor= 'Aquamarine' align=center><B>$ServiceStatus</B></td>" 
    Add-Content $htmlReport "</tr>"  

}

# Variables to modify as needed
$outputPath = "C:\Scripts"
$logFile = "$outputPath\ResetService.log"
$htmlReport = "$outputPath\ServiceRestartReport.html" 
$mailTo = "to@domain.com"
$mailFrom = "from@domain.com"
$mailSubject = "subject"
$mailBody = "body"
$mailSMTPServer = "server"


# 1) Start creating the HTML file
if ( Test-Path $htmlReport ) { 
    Remove-Item $htmlReport -Force
}
Add-Content $htmlReport "<html>" 
Add-Content $htmlReport "<head>" 
Add-Content $htmlReport "<meta http-equiv='Content-Type' content='text/html; charset=iso-8859-1'>" 
Add-Content $htmlReport '<title>Service Status Report</title>' 
Add-Content $htmlReport '<STYLE TYPE="text/css">' 
Add-Content $htmlReport "<!--" 
Add-Content $htmlReport "td {" 
Add-Content $htmlReport "font-family: Tahoma;" 
Add-Content $htmlReport "font-size: 11px;" 
Add-Content $htmlReport "border-top: 1px solid #999999;" 
Add-Content $htmlReport "border-right: 1px solid #999999;" 
Add-Content $htmlReport "border-bottom: 1px solid #999999;" 
Add-Content $htmlReport "border-left: 1px solid #999999;" 
Add-Content $htmlReport "padding-top: 0px;" 
Add-Content $htmlReport "padding-right: 0px;" 
Add-Content $htmlReport "padding-bottom: 0px;" 
Add-Content $htmlReport "padding-left: 0px;" 
Add-Content $htmlReport "}" 
Add-Content $htmlReport "body {" 
Add-Content $htmlReport "margin-left: 5px;" 
Add-Content $htmlReport "margin-top: 5px;" 
Add-Content $htmlReport "margin-right: 0px;" 
Add-Content $htmlReport "margin-bottom: 10px;" 
Add-Content $htmlReport "" 
Add-Content $htmlReport "table {" 
Add-Content $htmlReport "border: thin solid #000000;" 
Add-Content $htmlReport "}" 
Add-Content $htmlReport "-->" 
Add-Content $htmlReport "</style>" 
Add-Content $htmlReport "</head>" 
Add-Content $htmlReport "<body>" 
Add-Content $htmlReport "<table width='100%'>" 
Add-Content $htmlReport "<tr bgcolor='Lavender'>" 
Add-Content $htmlReport "<td colspan='7' height='25' align='center'>" 
Add-Content $htmlReport "<font face='tahoma' color='#003399' size='4'><strong>Service Status Report</strong></font>" 
Add-Content $htmlReport "</td>" 
Add-Content $htmlReport "</tr>" 
Add-Content $htmlReport "</table>" 
Add-Content $htmlReport "<table width='100%'>" 
Add-Content $htmlReport "<tr bgcolor='IndianRed'>" 
Add-Content $htmlReport "<td width='10%' align='center'><B>Server Name</B></td>" 
Add-Content $htmlReport "<td width='50%' align='center'><B>Service Name</B></td>" 
Add-Content $htmlReport "<td width='10%' align='center'><B>Status</B></td>" 
Add-Content $htmlReport "</tr>" 
########################

# 2) Iterate through all the servers and restart the requested services. This step will:
# - Notate the status of the service
# - Restart the service if it is running, or start it if it is stopped
# - Wait X seconds
# - Check the status again and add the results to the HTML report

New-Folder -Path $outputPath
$Server | ForEach-Object {
    $serverName = $_
    Start-ServiceRestartWorkflow -SkipRunning:$false -SearchMethod $PSCmdlet.ParameterSetName
    Write-Log -Message "[$serverName] Waiting 30 seconds to check the service again ..." -LogFile $logFile
    Start-Sleep -Seconds 30
    Start-ServiceRestartWorkflow -SkipRunning:$true -SearchMethod $PSCmdlet.ParameterSetName -Report
}

# 3) Close the HTML tags on the report
Add-Content $htmlReport "</table>" 
Add-Content $htmlReport "</body>" 
Add-Content $htmlReport "</html>" 

# 4) Email the report
Send-MailMessage -To $mailTo -From $mailFrom -Subject $mailSubject -SmtpServer $mailSMTPServer -Body $mailBody -Attachments $htmlReport
