$driverDlPath = "\\sm-fs01.corp.local\Public\IT_Software\Print_drivers\Kx_8.1.1109_UPD_Signed_EU\en\64bit"
$driverDisplayName = "Kyocera TASKalfa 3552ci KX" # taken from the .inf file. Must match a valid display name or the install will fail
$printerIP = "10.5.56.55"
$printerDisplayName = "QC West Kyocera"

if (([Security.Principal.WindowsPrincipal][Security.Principal.WindowsIdentity]::GetCurrent()).IsInRole([Security.Principal.WindowsBuiltInRole]::Administrator) -eq $False) {
    Write-Warning "Script requires Administrator access. Re-run as Administrator"
    Read-Host -Prompt "Press Enter to exit"
    break
}

# Install the printer driver
$printDriverExists = Get-PrinterDriver -name $driverDisplayName -ErrorAction SilentlyContinue
if ($printDriverExists) {
    Write-host "Printer driver is already installed. Continuing"
}
else {
    Write-Output "Printer driver not installed. Attempting to install the driver"
    # Add the driver package to the driver store
    try { 
        $driverFile = Get-ChildItem -Path $driverDlPath -Recurse -Filter "*.inf"
        $driverFile | ForEach-Object { PNPUtil.exe /add-driver $_.FullName /install } | Out-Null
        Write-host "Copied driver package ($($driverDisplayName)) to the driver store in Windows"
    }
    catch {
        Write-Warning $_
    }
    $filter = "*" + $driverFile.Name + "*"
    $driverLocalPath = (Get-ChildItem -Path  C:\Windows\System32\DriverStore\FileRepository\ | Where-Object { $_.Name -like $filter }).FullName

    if ( $driverLocalPath.length -gt 1 ) {
        Write-Warning "NOTE: Multiple drivers matched the filename. Errors may occur if the other drivers do not install successfully"
    }

    foreach ( $d in $driverLocalPath ) {

        try {
            Write-host "Attempting to install the driver package"
            Add-PrinterDriver -name $driverDisplayName -InfPath ($d + "\" + $driverFile.Name) -ErrorAction Stop
        }
        catch {
            Write-Warning "Error occurred while installing printer driver: $($d)"
            Write-warning "Skipped driver installation"
        }
        $printDriverExists = Get-PrinterDriver -name $driverDisplayName -ErrorAction SilentlyContinue
        if ($printDriverExists) {
            Write-host "Printer driver was installed successfully"
        }
    }

}

# Add the printer port
$portName = "IP_" + $printerIP
$portExists = Get-Printerport -Name $portname -ErrorAction SilentlyContinue
if ($portExists) {
    Write-host "Printer port is already present. Continuing"
}
else {
    Add-PrinterPort -Name $portName -PrinterHostAddress $printerIP
    write-host "Added printer port $($portName)"
}

# Add the printer
if ($null -eq (Get-Printer -Name $printerDisplayName -ErrorAction SilentlyContinue -WarningAction SilentlyContinue)) { 
    try {
        Add-Printer -Name $printerDisplayName -PortName $portName -DriverName $driverDisplayName
    }
    catch {
        Write-Host "Error occured while adding the printer"
    }
    if (Get-Printer -Name $printerDisplayName) {
        Write-host "Printer installed successfully"
    }
}
else {
    Write-Host "Printer is already present"
}

Read-Host -Prompt "Press Enter to exit"