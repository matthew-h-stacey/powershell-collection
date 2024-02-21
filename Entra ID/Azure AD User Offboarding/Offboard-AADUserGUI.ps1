# https://adamtheautomator.com/powershell-gui/
# https://www.foxdeploy.com/blog/part-ii-deploying-powershell-guis-in-minutes-using-visual-studio.html
# https://adamtheautomator.com/ps1-to-exe/

# Optional parameter used to show variables for building the GUI functionality
param([Parameter(Mandatory = $False)][switch]$Design)

# XAML file for GUI. Created in Visual Studio
$inputXML = Get-Content ".\MainWindow.xaml" -Raw

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
    if($Design) {"trying item $($_.Name)"} # only show variable test if working on Design ($Design -eq $true)
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

# Note: Due to some bug with running Connect-ExchangeOnline from a UI form, this currently needs to be executed BEFORE the GUI is called
# https://www.sapien.com/forums/viewtopic.php?t=15297
# https://stackoverflow.com/questions/69371555/connect-exchangeonline-freezing-when-importing-cmdlet-test-activetoken

if($Design -eq $False){ # Do not execute if in design mode

    # Check if ExchangeOnlineManagement is installed and connect if no connection exists
    if ($null -eq (Get-Module -ListAvailable -Name ExchangeOnlineManagement)) {
        Write-Host "[MODULE] Required module ExchangeOnlineManagement is not installed"
        Write-Host "[MODULE] Installing ExchangeOnlineManagement" -ForegroundColor Cyan
        Install-Module ExchangeOnlineManagement -Repository PSGallery -AllowClobber -Force -Scope CurrentUser
    } 
    else { 
        Write-Host "[MODULE] ExchangeOnlineManagement is installed, continuing ..." 
    }

    $isConnected = Get-PSSession | Where-Object { $_.Name -like "ExchangeOnlineInternalSession*" -and $_.Availability -like "Available" }

    if ($null -eq $isConnected) {
        Write-Host "[MODULE] Connecting to ExchangeOnline, check for a pop-up authentication window"
        Start-Sleep -Seconds 5
        Connect-ExchangeOnline -ShowBanner:$False
    }

}

# Mailbox delegate: Show/hide the "Who" and textbox when Yes/No is selected
$var_buttonMailboxDelegate_Yes.Add_Checked({
        $var_labelMailboxDelegateWho.Visibility = "Visible"
        $var_txtboxMailboxDelegate.Visibility = "Visible"
        $var_chkboxAutomapInbox.Visibility = "Visible"
        $var_chkboxCalendarAccess.Visibility = "Visible"
        $var_chkboxContactAccess.Visibility = "Visible"
    })
$var_buttonMailboxDelegate_No.Add_Checked({
        $var_labelMailboxDelegateWho.Visibility = "Hidden"
        $var_txtboxMailboxDelegate.Visibility = "Hidden"
        $var_chkboxAutomapInbox.Visibility = "Hidden"
        $var_chkboxCalendarAccess.Visibility = "Hidden"
        $var_chkboxContactAccess.Visibility = "Hidden"
    })

# OneDrive Access: Show/hide the "Who" and textbox when Yes/No is selected
$var_buttonOneDrive_Yes.Add_Checked({
        $var_labelOneDriveAccessWho.Visibility = "Visible"
        $var_txtboxOneDriveAccess.Visibility = "Visible"
    })
$var_buttonOneDrive_No.Add_Checked({
        $var_labelOneDriveAccessWho.Visibility = "Hidden"
        $var_txtboxOneDriveAccess.Visibility = "Hidden"
    })

# Forward email: Show/hide the "Who" and textbox when Yes/No is selected
$var_buttonFwEmail_Yes.Add_Checked({
        $var_labelFwEmailWho.Visibility = "Visible"
        $var_txtboxFwEmail.Visibility = "Visible"
    })
$var_buttonFwEmail_No.Add_Checked({
        $var_labelFwEmailWho.Visibility = "Hidden"
        $var_txtboxFwEmail.Visibility = "Hidden"
    })

# When "Go" button is clicked
$var_buttonGo.Add_Click({ 

    # Retrieve values from the GUI
    $UserPrincipalName      = $var_txtboxupn.Text
    $Delegate               = $var_txtboxMailboxDelegate.Text
    $DelegateCalendar       = $var_chkboxCalendarAccess.IsChecked
    $DelegateContacts       = $var_chkboxContactAccess.IsChecked
    $ForwardTo              = $var_txtboxFwEmail.Text
    $OneDriveTrustee        = $var_txtboxOneDriveAccess.Text
    $RemoveLicenses         = $var_chkboxRemoveLicenses.IsChecked

    # Create a hashtable with required parameter(s)
    $offboardParams = @{
        UserPrincipalName = $UserPrincipalName
    }

    # Add optional parameter(s) to the hashtable, if present
    if ($Delegate) {
        $offboardParams.Delegate = $Delegate
        $offboardParams.AutoMapping = $var_chkboxAutomapInbox.IsChecked
    }
    if ($DelegateCalendar -eq $true) {
        $offboardParams.Calendar = $True
    }
    if ($DelegateContacts -eq $true) {
        $offboardParams.Contacts = $True
    }
    if ($ForwardTo) {
        $offboardParams.Delegate = $ForwardTo
    }
    if ($OneDriveTrustee) {
        $offboardParams.OneDriveTrustee = $OneDriveTrustee
    }
    if ($RemoveLicenses -eq $true) {
        $offboardParams.RemoveLicenses = $True
    }

    # Close form
    $form.Close() 
    
    # Invoke the offboard script
     .\Offboard-AADUser.ps1 @offboardParams
    #Write-host @offboardparams

    })

#===========================================================================
# Shows the form - This should ALWAYS be the last command
#===========================================================================
$Form.ShowDialog() | out-null

