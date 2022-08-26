function Get-PublicFolderStructure { 

    $results = @()

     $publicFolders = Get-PublicFolder -GetChildren  | Get-PublicFolder -Recurse | select Name, ParentPath, FolderClass
    foreach ( $f in $publicFolders ) { 

        if ( $f.ParentPath -ne "\") {
            $folderName = "|->" + $f.Name 
        }
        else {
            $folderName = $f.Name
        }


        if ( $f.FolderClass -eq "IPF.Note") { $folderType = "Folder" }
        if ( $f.FolderClass -eq "IPF.Appointment") { $folderType = "Calendar" }

        $folderOutput = [PSCustomObject]@{
            Name = $folderName
            FolderType = $folderType
            ParentPath = $f.ParentPath
        }
        $results += $folderOutput
    }

    return $results

}

function Get-RecursivePublicFolderPermission {

    $allPublicFolders = Get-Publicfolder -Recurse | ? { $_.Name -ne "IPM_SUBTREE" } | select Identity 
    
    foreach ( $f in $allPublicFolders ) {

        Get-PublicFolderClientPermission -Identity $f | select Identity, User, AccessRights
    
    } 
    
}

function Add-RecursivePublicFolderPermission {
    param (
        [Parameter(Mandatory = $true)][String]$Identity, # Folder to add permissions to
        [Parameter(Mandatory = $true)][String]$User, # User to grant permissions to
        [Parameter(Mandatory = $true)][String]$AccessRights # Level of access to grant user
    )

    # Pre-pend the required forward slash at the beginning of the folder name, if not specified
    if ( $Identity[0] -ne "\" ) { 
        $Identity = "\" + $Identity
    }

    Write-Host "Granting user $($User) access to $($Identity) ..."
    try {
        Get-Publicfolder -Identity $Identity -Recurse | Add-PublicFolderClientPermission -User $User -AccessRights $AccessRights -ErrorAction Stop
    }
    catch [System.Exception] {
        Write-Warning "Skipped $($Identity), user $($User) already has permissions to the folder"
    }

}