param (
    [Parameter(Mandatory = $true)]
    [String]
    $Name
)

# ex: Start-WindowsService -Name ADSync

$IsRunning = (Get-Service -Name $Name | Select-Object -ExpandProperty Status) -like "Running"
if (!($IsRunning)) {
    Start-Service -Name $Name
}
else {
    # $Service is already running
}