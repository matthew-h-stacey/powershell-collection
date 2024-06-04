function Add-RecursivePublicFolderPermission {
    param (
        
        # Folder to add permissions to
        [Parameter(Mandatory = $true)]
        [String]
        $Identity, 

        # User to grant permissions to
        [Parameter(Mandatory = $true)]
        [String]
        $User,
                
        # Level of access to grant user
        [Parameter(Mandatory = $true)]
        [String]
        $AccessRights 
    )

    # Pre-pend the required forward slash at the beginning of the folder name, if not specified
    if ( $Identity[0] -ne "\" ) { 
        $Identity = "\" + $Identity
    }

    Write-Host "Granting user $($User) access to $($Identity) ..."
    try {
        Get-Publicfolder -Identity $Identity -Recurse | Add-PublicFolderClientPermission -User $User -AccessRights $AccessRights -ErrorAction Stop
    } catch [System.Exception] {
        Write-Warning "Skipped $($Identity), user $($User) already has permissions to the folder"
    }

}