function Get-PublicFolderStructure { 

    $results = @()
    $publicFolders = Get-PublicFolder -GetChildren  | Get-PublicFolder -Recurse | Select-Object Name, ParentPath, FolderClass

    foreach ( $f in $publicFolders ) { 

        if ( $f.ParentPath -ne "\") {
            $folderName = "|->" + $f.Name 
        } else {
            $folderName = $f.Name
        }


        if ( $f.FolderClass -eq "IPF.Note") { $folderType = "Folder" }
        if ( $f.FolderClass -eq "IPF.Appointment") { $folderType = "Calendar" }

        $folderOutput = [PSCustomObject]@{
            Name       = $folderName
            FolderType = $folderType
            ParentPath = $f.ParentPath
        }
        $results += $folderOutput
    }

    return $results

}