# https://adamtheautomator.com/powershell-gui/
# https://www.foxdeploy.com/blog/part-ii-deploying-powershell-guis-in-minutes-using-visual-studio.html
# https://adamtheautomator.com/ps1-to-exe/

# Optional parameter used to show variables for building the GUI functionality
param([Parameter(Mandatory = $False)][switch]$Design)

# XAML file for GUI. Created in Visual Studio
$inputXML = Get-Content "C:\Users\mstacey\OneDrive - bcservicenet\Documents\Visual Studio Projects\TestGUI\MainWindow.xaml" -Raw

Add-Type -AssemblyName PresentationFramework

#===========================================================================
# Convert XAML file - Do not touch
#===========================================================================

$inputXML = $inputXML -replace 'mc:Ignorable="d"', '' -replace "x:N", 'N' -replace '^<Win.*', '<Window'
[void][System.Reflection.Assembly]::LoadWithPartialName('presentationframework')
[xml]$XAML = $inputXML
#Read XAML
 
$reader = (New-Object System.Xml.XmlNodeReader $xaml)
try {
    $Form = [Windows.Markup.XamlReader]::Load( $reader )
}
catch {
    Write-Warning "Unable to parse XML, with error: $($Error[0])`n Ensure that there are NO SelectionChanged or TextChanged properties in your textboxes (PowerShell cannot process them)"
    throw
}
 
#===========================================================================
# Load XAML Objects In PowerShell - Do not touch
#===========================================================================
$xaml.SelectNodes("//*[@Name]") | ForEach-Object { 
    if ($Design) { "trying item $($_.Name)" } # only show variable test if working on Design ($Design -eq $true)
    else {
        try { Set-Variable -Name "var_$($_.Name)" -Value $Form.FindName($_.Name) -ErrorAction Stop }
        catch { throw }
    }
}
 
Function Get-FormVariables {
    if ($global:ReadmeDisplay -ne $true) { Write-host "If you need to reference this display again, run Get-FormVariables" -ForegroundColor Yellow; $global:ReadmeDisplay = $true }
    write-host "Found the following interactable elements from our form" -ForegroundColor Cyan
    get-variable var*
}
 
# !! Remove this comment to see all of the form variables
# Get-FormVariables
# !!
 
if ($Design) {
    Get-FormVariables
}

#===========================================================================
# This space below is used to build functionality into the GUI using the XAML
#===========================================================================s
Start-Transcript -Path C:\TempPath\test.log

$var_buttonGo.Add_Click({ 

    Connect-ExchangeOnline -Verbose -Debug
    $form.Close()
    Stop-Transcript

    })

#===========================================================================
# Shows the form - This should ALWAYS be the last command
#===========================================================================
$Form.ShowDialog() | out-null

