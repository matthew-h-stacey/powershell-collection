function Get-IntuneEnrollmentStatus {
    <#
    .SYNOPOSIS
    This function checks if the device is enrolled in Microsoft Intune by looking for the IntuneManagementExtension.log file
    and Intune-issued certificates.

    .DESCRIPTION
    First, the function checks for the presence of the IntuneManagementExtension.log file in the specified path. If the file
    exists and was modified within the last 7 days, it then checks for certificates issued by Microsoft Intune MDM. If those
    certificates are found and are valid, it indicates that the device is enrolled in Intune.

    .EXAMPLE
    if ( Get-IntuneEnrollmentStatus ) {
        # device is enrolled in Intune
        # do Intune-related tasks here
    }

    #>
    [CmdletBinding()]
    param ()

    $intuneEnrolled = $false

    # Check if the IntuneManagementExtension.log file exists and is recent
    if (Test-Path -Path "C:\ProgramData\Microsoft\IntuneManagementExtension\Logs\IntuneManagementExtension.log") {
        $intuneLog = Get-Item -Path "C:\ProgramData\Microsoft\IntuneManagementExtension\Logs\IntuneManagementExtension.log"
        $today = Get-Date
        $timespan = New-Timespan -Start $intuneLog.LastWriteTime -End $today
        if ($timespan.TotalDays -lt 7) {
            # Check for Intune issued certificates
            $intuneIssuesCerts = Get-ChildItem -Path Cert:\LocalMachine\My | Where-Object { $_.Issuer -like "*Microsoft Intune MDM*" }
            $intuneEnrolled = ($intuneIssuesCerts | ForEach-Object { (New-TimeSpan -Start $today -End $_).TotalDays -gt 1 }) -contains $true
        }
    }

    return $intuneEnrolled
}