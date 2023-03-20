# ALl
# Get-AppxPackage -allusers | foreach {Add-AppxPackage -register "$($_.InstallLocation)\appxmanifest.xml" -DisableDevelopmentMode}

# One app 
# Get-AppxPackage -Name "Microsoft.MicrosoftStickyNotes" | Reset-AppxPackage
