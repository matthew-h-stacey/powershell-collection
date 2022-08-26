# Example #1: One-off folder
# .\robocopy_cs_data_folders.ps1 -folder 2018Nov05
#
# Example #2: Multiple folders, one line
# .\robocopy_cs_data_folders.ps1 -folder 2018Nov05,2019Apr22,2019Dec02
#
# Example #3: Large number of folders, using text file
# .\robocopy_cs_data_folders.ps1 -folder (get-content C:\temppath\FoldersToMove.txt)

param (
    [Parameter()][string[]]$folder
)

foreach ($f in $folder) {

    $srcDrive = "I:\"
    $dstDrive = "Z:\"
    $folderRoot = "CS_DATA_SHARE\"
    $logPath = "C:\TempPath\robocopy_$($f)_log.txt"
    #$options = "/move /e /ts /log:$logPath"

    $srcPath = $srcDrive + $folderRoot + $f
    $dstPath = $dstDrive + $folderRoot + $f

    robocopy $srcPath $dstPath /move /e /ts /log:$logPath
    # uncomment out the below line, comment the above line for visual confirmation before running it live:
    # write-host "robocopy $srcPath $dstPath /move /e /ts /log:$logPath"

}