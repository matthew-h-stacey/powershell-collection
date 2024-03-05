<#
.SYNOPSIS
Restart a specific IIS site, log the output, and create an HTML report

.EXAMPLE
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
function New-HTMLReport {

    param (
        [Parameter(Mandatory = $true)]
        [String]
        $Path,

        [Parameter(Mandatory = $true)]
        [String]
        $Title,

        [Parameter(Mandatory = $true)]
        [String]
        $Column1,

        [Parameter(Mandatory = $true)]
        [String]
        $Column2,

        [Parameter(Mandatory = $true)]
        [String]
        $Column3,

        [Parameter(Mandatory = $true)]
        [String]
        $Column4
    )

    <#
    .SYNOPSIS
    Create an empty HTML report to add future content to

    .EXAMPLE
    New-HTMLReport -Path C:\TempPath\MyReport.html -Title "MyReport" -Column1 Client -Column2 Server -Column3 Service -Column4 Status
    #>

    # Remove the report if it exists
    if ( Test-Path $Path ) { 
        Remove-Item $Path -Force
    }
    Add-Content $Path "<html>" 
    Add-Content $Path "<head>" 
    Add-Content $Path "<meta http-equiv='Content-Type' content='text/html; charset=iso-8859-1'>" 
    Add-Content $Path "<title>$Title</title>" 
    Add-Content $Path '<STYLE TYPE="text/css">' 
    Add-Content $Path "<!--" 
    Add-Content $Path "td {" 
    Add-Content $Path "font-family: Tahoma;" 
    Add-Content $Path "font-size: 11px;" 
    Add-Content $Path "border-top: 1px solid #999999;" 
    Add-Content $Path "border-right: 1px solid #999999;" 
    Add-Content $Path "border-bottom: 1px solid #999999;" 
    Add-Content $Path "border-left: 1px solid #999999;" 
    Add-Content $Path "padding-top: 0px;" 
    Add-Content $Path "padding-right: 0px;" 
    Add-Content $Path "padding-bottom: 0px;" 
    Add-Content $Path "padding-left: 0px;" 
    Add-Content $Path "}" 
    Add-Content $Path "body {" 
    Add-Content $Path "margin-left: 5px;" 
    Add-Content $Path "margin-top: 5px;" 
    Add-Content $Path "margin-right: 0px;" 
    Add-Content $Path "margin-bottom: 10px;" 
    Add-Content $Path "" 
    Add-Content $Path "table {" 
    Add-Content $Path "border: thin solid #000000;" 
    Add-Content $Path "}" 
    Add-Content $Path "-->" 
    Add-Content $Path "</style>" 
    Add-Content $Path "</head>" 
    Add-Content $Path "<body>" 
    Add-Content $Path "<table width='100%'>" 
    Add-Content $Path "<tr bgcolor='Lavender'>" 
    Add-Content $Path "<td colspan='7' height='25' align='center'>" 
    Add-Content $Path "<font face='tahoma' color='#003399' size='4'><strong>$Title</strong></font>" 
    Add-Content $Path "</td>" 
    Add-Content $Path "</tr>" 
    Add-Content $Path "</table>" 
    Add-Content $Path "<table width='100%'>" 
    Add-Content $Path "<tr bgcolor='IndianRed'>" 
    Add-Content $Path "<td width='25%' align='center'><B>$Column1</B></td>" 
    Add-Content $Path "<td width='25%' align='center'><B>$Column2</B></td>" 
    Add-Content $Path "<td width='25%' align='center'><B>$Column3</B></td>" 
    Add-Content $Path "<td width='25%' align='center'><B>$Column4</B></td>" 
    Add-Content $Path "</tr>" 
    
}
function Add-ReportContent {

    param (
        [Parameter(Mandatory = $true)]
        [String]
        $Column1,

        [Parameter(Mandatory = $true)]
        [String]
        $Column2,

        [Parameter(Mandatory = $true)]
        [String]
        $Column3,

        [Parameter(Mandatory = $true)]
        [String]
        $Column4
    )

    Add-Content $htmlReport "<tr>" 
    Add-Content $htmlReport "<td bgcolor= 'GainsBoro' align=center><B>$Column1</B></td>" 
    Add-Content $htmlReport "<td bgcolor= 'GainsBoro' align=center><B>$Column2</B></td>" 
    Add-Content $htmlReport "<td bgcolor= 'Aquamarine' align=center><B>$Column3</B></td>" 
    Add-Content $htmlReport "<td bgcolor= 'Aquamarine' align=center><B>$Column4</B></td>" 
    Add-Content $htmlReport "</tr>"  

}
function Start-SiteRestartWorkFlow {

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
            Write-Log -Message "[ERROR] occurred attempting to start site: $_. Error: $($_.Exception.Message)" -LogFile $logFile
        }

        $Status = Get-Website -Name $_ | Select-Object -ExpandProperty State
        Add-ReportContent -Column1 $_ -Column2 $timeStopped -Column3 $timeStarted -Column4 $Status 

    }

}
function Close-HTMLReport {

    param (
        # Report path
        [Parameter(Mandatory = $true)]
        [String]
        $Path
    )

    <#
    .SYNOPSIS
    Add closing headers to the HTML report

    .EXAMPLE
    Close-HTMLReport -Path C:\TempPath\MyReport.html
    #>

    Add-Content $Path "</table>" 
    Add-Content $Path "</body>" 
    Add-Content $Path "</html>" 

}

############ Variables #############

# Logging
$outputPath = "C:\Scripts"
$logFile = "$outputPath\RetartIISSite.log"

# Report 
$htmlReport = "$outputPath\WebsiteStatusReport.html" 
$reportTitle = "IIS Website Restart Report"
$column1 = "Site Name"
$column2 = "Time Stopped"
$column3 = "Time Started"
$column4 = "Status"


# SMTP server variables
$mailTo = "to@domain.com"
$mailFrom = "from@domain.com"
$mailSubject = "subject"
$mailBody = "body"
$mailSMTPServer = "server"

####################################

############ Execution #############
New-Folder $outputPath
New-HTMLReport -Path $htmlReport -Title $reportTitle -Column1 $column1  -Column2 $column2 -Column3 $column3 -Column4 $column4
Start-SiteRestartWorkFlow
Close-HTMLReport -Path $htmlReport
try {
    Send-MailMessage -To $mailTo -From $mailFrom -Subject $mailSubject -SmtpServer $mailSMTPServer -Body $mailBody -Attachments $htmlReport -ErrorAction Stop -WarningAction Stop
} catch {
    Write-Log -Message "[ERROR] Failed to send report to $mailTo. Error $($_.Exception.Message)" -LogFile $logFile
}
####################################