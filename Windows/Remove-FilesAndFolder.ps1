param (
    # Path to the files
    [Parameter(Mandatory=$true)]
    [String]
    $Path,

    # Remove the parent directory when done
    [Parameter(Mandatory = $false)]
    [Switch]
    $RemoveParentDirectory
)

Get-ChildItem -File $path -Recurse | ForEach-Object { 
    $fileName = $_.FullName
    try {
        Remove-Item $fileName
    } catch {
        Write-Output "[ERROR] Failed to remove file: $fileName. Error: $($_.Exception.Message)"
    }
}
if ( $RemoveParentDirectory) {
    try {
        Remove-Item -Path $path -Recurse
    } catch {
        Write-Output "[ERROR] Failed to remove directory: $path. Error: $($_.Exception.Message)"
    }
}