param (
    # $DriveLabel should be the domain name used by the Egnyte tenant
    # Example, for domain: https://contoso.egynte.com, $DriveLabel should be set to "contoso"
    [Parameter(Mandatory=$true)]
    [String]
    $DriveLabel
)

# https://helpdesk.egnyte.com/hc/en-us/articles/360026687112-Connected-Folders-on-the-Desktop-App

$IsConnected = Test-Path Z:\

switch ( $IsConnected ) {

    True {

        $Egnyte32bit = "${env:ProgramFiles(x86)}\Egnyte Connect\EgnyteClient.exe"
        $egnyte64bit = "$env:ProgramFiles\Egnyte Connect\EgnyteClient.exe"

        if ( Test-Path $Egnyte32bit ) {
            $InstallPath = $Egnyte32bit
        }
        if ( Test-Path $egnyte64bit ) {
            $InstallPath = $egnyte64bit
        }
        
        $IsDocsRedirected = [Environment]::GetFolderPath("MyDocuments") -like "*OneDrive*"
        $IsPicsRedirected = [Environment]::GetFolderPath("MyPictures") -like "*OneDrive*"
        $IsDesktopRedirected = [Environment]::GetFolderPath("Desktop") -like "*OneDrive*"

        switch ( $IsDocsRedirected ) {
            True {
                Write-Output "Docs is redirected to OneDrive"
            }
            False {
                Write-Output "Docs is local. Attempting to sync to Egnyte"
                $command = "-command connect_folder -l $DriveLabel -a 'C:\Users\$env:USERNAME\Documents' -r '/Private/::egnyte_username::/Documents'"
                Start-Process -FilePath "cmd.exe" -ArgumentList "/c", "`"$InstallPath`" $command" -WindowStyle Hidden

            }
        }
        switch ( $IsPicsRedirected ) {
            True {
                Write-Output "Pictures are redirected to OneDrive"
            }
            False {
                Write-Output "Pictures are local. Attempting to sync to Egnyte"
                $command = "-command connect_folder -l $DriveLabel -a 'C:\Users\$env:USERNAME\Pictures' -r '/Private/::egnyte_username::/Pictures'"
                Start-Process -FilePath "cmd.exe" -ArgumentList "/c", "`"$InstallPath`" $command" -WindowStyle Hidden

            }
        }
        switch ( $IsDesktopRedirected ) {
            True {
                Write-Output "Desktop is redirected to OneDrive"
            }
            False {
                Write-Output "Desktop is local. Attempting to sync to Egnyte"
                $command = "-command connect_folder -l $DriveLabel -a 'C:\Users\$env:USERNAME\Desktop' -r '/Private/::egnyte_username::/Desktop'"
                Start-Process -FilePath "cmd.exe" -ArgumentList "/c", "`"$InstallPath`" $command" -WindowStyle Hidden

            }
        }
    }

    False {
        Write-Output "WARNING: Egnyte is not connected to Z:\, folder sync cannot proceed. Quitting."
    
    }


}

