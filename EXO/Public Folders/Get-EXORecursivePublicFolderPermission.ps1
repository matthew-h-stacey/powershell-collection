function Get-RecursivePublicFolderPermission {

    $allPublicFolders = Get-Publicfolder -Recurse | Where-Object { $_.Name -ne "IPM_SUBTREE" } | Select-Object Identity 
    
    foreach ( $f in $allPublicFolders ) {

        Get-PublicFolderClientPermission -Identity $f | Select-Object Identity, User, AccessRights
    
    } 
    
}