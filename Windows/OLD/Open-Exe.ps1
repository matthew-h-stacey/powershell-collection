$process = "calculator"

###

function Show-Process($Process, [Switch]$Maximize) {
    $sig = '
    [DllImport("user32.dll")] public static extern bool ShowWindowAsync(IntPtr hWnd, int nCmdShow);
    [DllImport("user32.dll")] public static extern int SetForegroundWindow(IntPtr hwnd);
  '
  
    if ($Maximize) { $Mode = 3 } else { $Mode = 4 }
    $type = Add-Type -MemberDefinition $sig -Name WindowAPI -PassThru
    $hwnd = $process.MainWindowHandle
    $null = $type::ShowWindowAsync($hwnd, $Mode)
    $null = $type::SetForegroundWindow($hwnd) 
}

###


$isRunning = Get-Process $process -ErrorAction SilentlyContinue
if ($isRunning -eq $null) {
    # Not running
    # START PROCESS
    Start-Process -FilePath C:\windows\system32\calc.exe
    
}
else {
    # Already running
    #SHOW PROCESS
    Show-Process $process
}