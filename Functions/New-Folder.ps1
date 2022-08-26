function New-Folder {
    Param([Parameter(Mandatory = $True)][String] $folderPath)
    if (-not (Test-Path -LiteralPath $folderPath)) {
        try {
            New-Item -Path $folderPath -ItemType Directory -ErrorAction Stop | Out-Null
            Write-Host "Created folder: $folderPath"
        }
        catch {
            Write-Error -Message "Unable to create directory '$folderPath'. Error was: $_" -ErrorAction Stop
        }
    }
    else {
        "$folderPath already exists, continuing ..."
    }
}

# ex: New-Folder C:\Scripts\Output\
# ex: New-Folder $outputFolder