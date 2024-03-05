#Requires -RunAsAdministrator

<#
.SYNOPSIS
Restart a specific IIS site, log the output, and create an HTML report

.EXAMPLE
Restart-IISSite -Site Commerce
Restart-IISSite -Site (Get-Content C:\Scripts\IIS_Websites.txt)
#>

param (
    [parameter(Mandatory = $true)]
    [String[]]
    $Site
)

function New-Folder {
    
    <#
    .SYNOPSIS
    Determine if a folder already exists, or create it if not.

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

function New-HTMLReport {

    <#
    .SYNOPSIS
    Create a pre-formatted HTML file and populate it with specified headers and row values

    .EXAMPLE
    New-HTMLReport -Path $htmlReport -Title $reportTitle -ColumnHeaders @("Server","Status") -Data $data
    #>

    param (
        [Parameter(Mandatory = $true)]
        [String]
        $Path,

        [Parameter(Mandatory = $true)]
        [String]
        $Title,

        [Parameter(Mandatory = $true)]
        [String[]]
        $ColumnHeaders,

        [Parameter(Mandatory = $true)]
        [Object[]]
        $Data
    )

    # Check if report already exists and delete it
    if (Test-Path $Path) {
        Remove-Item $Path -Force
    }

    # Define the HTML content using a Here-String
    $htmlContent = @"
<html>
<head>
    <meta http-equiv='Content-Type' content='text/html; charset=iso-8859-1'>
    <title>$Title</title>
    <style type='text/css'>
        td {
            font-family: Tahoma;
            font-size: 11px;
            border: 1px solid #999999;
            padding: 0px;
        }
        body {
            margin: 5px;
        }
        table {
            border: thin solid #000000;
            border-collapse: collapse;
            width: 100%;
        }
        th {
            background-color: Lavender;
            border: 1px solid #999999;
            padding: 5px;
        }
    </style>
</head>
<body>
    <h1>$Title</h1>
    <table>
        <tr bgcolor='Azure'>
"@

    # Add column headers to the HTML content
    foreach ($header in $ColumnHeaders) {
        $htmlContent += "<th>$header</th>"
    }

    $htmlContent += @"
        </tr>
"@

    # Add data rows to the HTML content
    foreach ($row in $Data) {
        $htmlContent += "<tr>"
        foreach ($column in $row.PSObject.Properties) {
            $htmlContent += "<td align=center>" + $column.Value + "</td>"
        }
        $htmlContent += "</tr>"
    }

    $htmlContent += @"
    </table>
</body>
</html>
"@

    # Write the HTML content to the file
    $htmlContent | Out-File -FilePath $Path
}
function Start-SiteRestartWorkFlow {

    $reportData = @()
    $Site | ForEach-Object { 

        try {
            $timeStopped = Get-Date -Format "MM/dd/yyyy HH:mm:ss"
            Stop-Website -Name $_
            Write-Log -Message "[INFO] Successfully stopped site: $_" -LogFile $logFile
            Start-Sleep -Seconds 30
        } catch {
            Write-Log -Message "[ERROR] Error occurred attempting to stop site: $_. Error: $($_.Exception.Message)" -LogFile $logFile
        }

        try {
            $timeStarted = Get-Date -Format "MM/dd/yyyy HH:mm:ss"
            Start-Website -Name $_
            Write-Log -Message "[INFO] Successfully started site: $_" -LogFile $logFile
        } catch {
            Write-Log -Meessage "[ERROR] occurred attempting to start site: $_. Error: $($_.Exception.Message)" -LogFile $logFile
        }

        $status = Get-Website -Name $_ | Select-Object -ExpandProperty State

        $reportData += [PSCustomObject]@{
            "Site Name"     =   $_
            "Time Stopped"  =   $timeStopped
            "Time Started"  =   $timeStarted
            Status          =   $status
        }

    }

    return $reportData

}

############ Variables #############

# Logging
$outputPath = "C:\Scripts"
$logFile = "$outputPath\Restart-IISSite.log"

# Report 
$htmlReport = "$outputPath\WebsiteStatusReport.html" 
$reportTitle = "IIS Website Restart Report"
$columnHeaders = @("Site Name","Time Stopped","Time Started","Status")

# SMTP server variables
$mailTo = "to@domain.com"
$mailFrom = "from@domain.com"
$mailSubject = "subject"
$mailBody = "body"
$mailSMTPServer = "server.contoso.com"

####################################

############ Execution #############
New-Folder $outputPath
$data = Start-SiteRestartWorkFlow
New-HTMLReport -Path $htmlReport -Title $reportTitle -ColumnHeaders $columnHeaders -Data $data
try {
    Send-MailMessage -To $mailTo -From $mailFrom -Subject $mailSubject -SmtpServer $mailSMTPServer -Body $mailBody -Attachments $htmlReport -ErrorAction Stop -WarningAction Stop
} catch {
    Write-Log -Message "[ERROR] Failed to send report to $mailTo. Error $($_.Exception.Message)" -LogFile $logFile
}
####################################