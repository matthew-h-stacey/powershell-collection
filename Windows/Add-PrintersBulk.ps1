# Objective:
# Export output of Get-Printer from one server to another

# Headers:
# Name,ShareName,Shared,DriverName,PortName,PrinterStatus,Comment,Location,JobCount,PrintProcessor,Published

$printers = Import-CSV -Path "C:\TempPath\printers.csv"

function Add-PrinterPorts {
    $portExists = Get-PrinterPort -Name $printer.PortName  -ErrorAction SilentlyContinue
    if ($portExists) {
        Write-host "SKIPPED: Port $($printer.PortName) is already present"
    }
    else {
        Add-PrinterPort -Name $printer.PortName -PrinterHostAddress $printerIP
        write-host "SUCCESS: Added printer port $($printer.PortName)"
    }
}

function Add-Printers {
    if ($null -eq (Get-Printer -Name $printer.Name -ErrorAction SilentlyContinue -WarningAction SilentlyContinue)) { 
        try {
                Add-Printer -Name $printer.Name -PortName $printer.PortName -DriverName $printer.DriverName -Shared:$true
        }
        catch {
                Write-Host "Error occured while adding the printer: $($printer.Name)"
        }
        if (Get-Printer -Name $printer.Name) {
            Write-host "SUCCESS: Printer $($printer.Name) installed successfully"
        }
    }
    else {
            Write-Host "SKIPPED: Printer $($printer.Name) is already present"
    }
}

foreach($printer in $printers){
    Add-PrinterPorts
    Add-Printers
}