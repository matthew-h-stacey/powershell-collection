# Reference for Egnyte cmd:
# https://helpdesk.egnyte.com/hc/en-us/articles/360026687112-Connected-Folders-on-the-Desktop-App

# Script variables
$DriveLabel = "ClientDomainHere"
$SkipOneDriveKfb = $true

function Connect-FolderToEgnyte {

    param (
        # Name of the folder to connect to Egnyte (Documents/Desktop/Pictures)
        [Parameter(Mandatory = $true)]
        [String]
        $Folder
    )

    $CurrentPath = '"' + ($FolderStatus | Where-Object { $_.Name -eq $Folder } | Select-Object -ExpandProperty Path) + '"'
    $EgnytePath = '"' + "/Private/::egnyte_username::/$Folder" + '"'
    Write-Output "[INFO] Connecting folder to Egnyte: $CurrentPath"
    & $InstallPath -command connect_folder -l $DriveLabel -a $CurrentPath -r $EgnytePath 
   
}

function Set-EgnyteFolderBackup {

    param (
    
        # $DriveLabel should be the domain name used by the Egnyte tenant
        # Example, for domain: https://contoso.egynte.com, $DriveLabel should be set to "contoso"
        [Parameter(Mandatory = $true)]
        [String]
        $DriveLabel,

        # Optional flag to skip if Desktop/Documents/Pictures are redirected to OneDrive (OneDrive Known Folder Backup)
        [Parameter(Mandatory = $false)]
        [Boolean]
        $SkipOneDriveKfb

    )

    $Egnyte32bit = "${env:ProgramFiles(x86)}\Egnyte Connect\EgnyteClient.exe"
    $Egnyte64bit = "$env:ProgramFiles\Egnyte Connect\EgnyteClient.exe"

    if ( Test-Path $Egnyte32bit ) {
        $InstallPath = $Egnyte32bit
    }
    if ( Test-Path $Egnyte64bit ) {
        $InstallPath = $Egnyte64bit
    }
        
    $FolderStatus = @()
    $DesktopPath = [Environment]::GetFolderPath("Desktop")
    $DocumentsPath = [Environment]::GetFolderPath("MyDocuments")
    $PicturesPath = [Environment]::GetFolderPath("MyPictures")

    $FolderStatus += [PSCustomObject]@{
        Name       = "Desktop"
        Path       = $DesktopPath
        KfbEnabled = $DesktopPath -like "*OneDrive*"
    }
    $FolderStatus += [PSCustomObject]@{
        Name       = "Documents"
        Path       = $DocumentsPath
        KfbEnabled = $DocumentsPath -like "*OneDrive*"
    }
    $FolderStatus += [PSCustomObject]@{
        Name       = "Pictures"
        Path       = $PicturesPath
        KfbEnabled = $PicturesPath -like "*OneDrive*"
    }
        
    foreach ( $Folder in $FolderStatus) { 
        # If $SkipOneDriveKfb is true, do not connect folders which are already connected to OneDrive
        if ( $SkipOneDriveKfb ) { 
            if ( $Folder.KfbEnabled -eq $true ) {
                $ConnectFolder = $false
                Write-Output "[INFO] Skipped connecting $($Folder.Name) to Egnyte, folder is backed up to OneDrive"
            }
        }
        # $SkipOneDriveKfb is false, so all folders should be connected to Egnyte
        else {
            $ConnectFolder = $true
        }
        if ( $ConnectFolder -eq $true ) {
            Connect-FolderToEgnyte -Folder $Folder.Name
        }
    }

}


$IsEgnyteInstalled = Get-WmiObject -Class Win32_Product | Where-Object { $_.Name -like "*egnyte*desktop*" }
if ( $IsEgnyteInstalled ) {

    $IsConnected = Test-Path Z:\

    switch ( $IsConnected ) {

        True {
            Set-EgnyteFolderBackup -DriveLabel $DriveLabel -SkipOneDriveKfb $SkipOneDriveKfb
        }
        False {
            Write-Output "[WARNING] Egnyte is not connected to Z:\, folder sync cannot proceed. Quitting."
        }
    }
}
else {
    Write-Output "[WARNING] Egnyte Desktop is not installed. Quitting."
}