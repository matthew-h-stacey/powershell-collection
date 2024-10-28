function Write-Log {
    
    <#
    .SYNOPSIS
    Log to a specific file/folder path with timestamps

    .EXAMPLE
    Write-Log -Message "[INFO] Attempting to do the thing" -LogFile C:\Scripts\MyScript.log
    Write-Log -Message "[INFO] Attempting to do the thing" -LogFile $LogFile 
    #>
    
    param (
        [Parameter(Mandatory = $true)]
        [String]
        $Message,

        [Parameter(Mandatory = $true)]
        [String]
        $LogFile
    )

    $timeStampMessage = "$((Get-Date -Format "MM/dd/yyyy HH:mm:ss")) $Message"
    Add-Content -Value $timeStampMessage -Path $LogFile

}

function Wait-ForProcessToClose {
    param (
        [string]$ProcessName
    )

    Write-Output "Waiting for $ProcessName to close..."

    while (Get-Process -Name $ProcessName -ErrorAction SilentlyContinue) {
        Start-Sleep -Seconds 2
    }

    Write-Output "$ProcessName has been closed."
}

function Stop-EdgeProcesses {

    <#
    .SYNOPSIS
    Stop Edge primary (with a user prompt) and background processes
    #>

    $mainEdgeWindow = Get-Process msedge -ErrorAction SilentlyContinue | Where-Object { $_.MainWindowTitle -ne "" } | Select-Object -First 1
    if ($mainEdgeWindow ) {
        # Prompt the user to close Edge
        [System.Windows.Forms.MessageBox]::Show("Microsoft Edge needs to close for a bookmark import. Please close Microsoft Edge then click OK", "BCS365 Support", 'OK', 'Warning')
        Close-EdgeProcesses
        Wait-ForProcessToClose -ProcessName $mainEdgeWindow.Name        
    } else {
        # CLose any other background processes for Edge
        Get-Process msedge -ErrorAction SilentlyContinue | ForEach-Object { Stop-Process -Id $_.Id }
    }
    $edgeProcesses = Get-Process msedge -ErrorAction SilentlyContinue
    if ( -not $edgeProcesses ) {
        Write-Log "[INFO] All Microsoft Edge processes have been closed." -LogFile $logFile
    } else {
        Write-Log "[ERROR] Failed to close all Edge processes. Exiting." -LogFile $logFile
        exit 1
    }

}

function Close-EdgeProcesses {
    $processes = Get-AllEdgeProcesses
    foreach ($process in $processes) {
        try {
            $process.CloseMainWindow() | Out-Null
            if (!$process.HasExited) {
                $process.WaitForExit(5000)  # Wait up to 5 seconds for graceful exit
                if (!$process.HasExited) {
                    $process.Kill()  # Force close if it doesn't exit gracefully
                }
            }
        } catch {
        }
    }
}

function Import-Bookmarks {

    param (
        [Parameter(Mandatory = $true)]
        [string]
        $sourceFile,

        [Parameter(Mandatory = $true)]
        [string]
        $destinationFile
    )

    if (Test-Path $sourceFile) {
        $sourceData = Get-Content $sourceFile -Raw | ConvertFrom-Json
        $destinationData = @{}

        if (Test-Path $destinationFile) {
            $destinationData = Get-Content $destinationFile -Raw | ConvertFrom-Json
        } else {
            $destinationData = @{
                version = "1.0"
                roots   = @{
                    bookmark_bar = @{
                        children = @()
                    }
                    other        = @{
                        children = @()
                    }
                    synced       = @{
                        children = @()
                    }
                }
            }
        }

        # Create a new folder for the Chrome bookmarks in Edge
        $newFolderName = "Imported from Chrome"
        $newFolder = [PSCustomObject]@{
            name     = $newFolderName
            type     = "folder"
            children = @()
        }
        $otherFolderName = "Other Bookmarks Imported"
        $otherFolder = [PSCustomObject]@{
            name     = $otherFolderName
            type     = "folder"
            children = @()
        }
       
        # Add Chrome bookmarks to the new folder
        foreach ($bookmark in $sourceData.roots.bookmark_bar.children) {
            $newFolder.children += $bookmark
        }
        foreach ($bookmark in $sourceData.roots.other.children) {
            $otherFolder.children += $bookmark
        }
        if ($otherFolder.children) {
            $newFolder.children += $otherFolder
        }
        if ($mobileFolder.children) {
            $newFolder.children += $mobileFolder
        }

        # Add the new folder to Edge's bookmark bar
        $destinationData.roots.bookmark_bar.children += $newFolder

        # Write the modications to the bookmarks file back to Edge
        try {
            $destinationData | ConvertTo-Json -Depth 10 | Set-Content $destinationFile -Force
            Write-Log -Message "[DONE] Bookmarks imported successfully from $sourceFile to $destinationFile" -LogFile $logFile
        } catch {
            Write-Log -Message "[ERROR] Failed to write the new bookmarks file. Error: $($_.Exception.Message)" -LogFile $logFile
        }
        
        
        
    } else {
        Write-Log -Message "[INFO] Source file $sourceFile not found. Import failed." -LogFile $logFile
    }
}

function Disable-EdgeFavoriteSync {

    <#
    .SYNOPSIS
    Disables favorite sync in edge to allow importing bookmarks
    #>

    $prefs = Get-Content "$env:LOCALAPPDATA\Microsoft\Edge\User Data\Default\Preferences" -Raw | ConvertFrom-Json
    if ( $prefs.sync.bookmarks -eq $true ) {
        Write-Log "[INFO] Browser favorite sync enabled. Temporarily disabling favorite sync" -LogFile $logFile
        $prefs.sync.bookmarks = $false
        $edgeFavoriteSyncEnabled
        try {
            $prefs | ConvertTo-Json -Depth 100 | Set-Content "$env:LOCALAPPDATA\Microsoft\Edge\User Data\Default\Preferences"
        } catch {
            Write-Log "[ERROR] Failed to disabled bookmark sync in Edge. Error: $($_.Exception.Message)" -LogFile $logfile
        }
    }
}

function Enable-EdgeFavoriteSync {

    <#
    .SYNOPSIS
    If Edge favorite sync was previously enabled but temporarily disabled, this function will re-enable it
    #>
    
    if ( $edgeFavoriteSyncEnabled ) {
        $prefs = Get-Content "$env:LOCALAPPDATA\Microsoft\Edge\User Data\Default\Preferences" -Raw | ConvertFrom-Json
        $prefs.sync.bookmarks = $true
        try {
            $prefs | ConvertTo-Json -Depth 100 | Set-Content "$env:LOCALAPPDATA\Microsoft\Edge\User Data\Default\Preferences"
            Write-Log "[INFO] Browser favorite sync enabled." -LogFile $logFile
        } catch {
            Write-Log "[ERROR] Failed to disabled bookmark sync in Edge. Error: $($_.Exception.Message)" -LogFile $logFile
        }
    } 

}

### Script variables
$logFile = "$env:USERPROFILE\ChromeMigration.log"
$chromeDataPath = "$env:LOCALAPPDATA\Google\Chrome\User Data\Default"
$edgeDataPath = "$env:LOCALAPPDATA\Microsoft\Edge\User Data\Default"
$sourceBookmarks = "$chromeDataPath\Bookmarks"
$destinationBookmarks = "$edgeDataPath\Bookmarks"
$edgeFavoriteSyncEnabled = $false

### Execution

# Create Edge data directory if it doesn't exist
if (-not (Test-Path $edgeDataPath)) {
    New-Item -ItemType Directory -Path $edgeDataPath -Force
    Write-Log "[INFO] Created Edge data directory: $edgeDataPath" -LogFile $logFile
}
Stop-EdgeProcesses
Disable-EdgeFavoriteSync
Import-Bookmarks $sourceBookmarks $destinationBookmarks
Enable-EdgeFavoriteSync