
$rootDir = "\\Server.FQDN\Share\Subshare"

$foldersToReview = Get-ChildItem $rootDir -Directory | select -ExpandProperty Name

$results = @()

foreach ( $f in $foldersToReview ) {
    try {
        $topFolderSizeMB = [Math]::Round(((Get-ChildItem $rootDir\$f -Recurse  | ? { !$_.PsIsContainer } | Measure-Object -Property Length -Sum -erroraction Stop).Sum / 1MB), 0) 
    }
    catch {
        $topFolderSizeMB = "ERROR"
        write-warning "Unable to pull folder size. You may not have permissions to access this folder"
    }
    try {
        $fileCount = (Get-ChildItem $rootDir\$f -Recurse -File | Measure-Object).Count
    }
    catch {
        [System.Management.Automation.ErrorRecord]
        Write-warning "Error pulling folder details. Possible character file limit issue"
    }
    

    $folderReport = [PSCustomObject]@{
        Folder            = $f
        TotalItems        = $fileCount
        TotalFolderSizeMB = $topFolderSizeMB
    }

    $results += $folderReport

}

$results