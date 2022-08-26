#Replace calculator with desired app
#Get-AppxPackage -allusers *windowscalculator* | Foreach {Add-AppxPackage -DisableDevelopmentMode -Register “$($_.InstallLocation)\AppXManifest.xml”}