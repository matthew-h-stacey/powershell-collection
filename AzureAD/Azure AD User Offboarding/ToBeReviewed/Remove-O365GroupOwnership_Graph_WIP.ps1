$allO365Groups = Get-MgGroup

function Remove-O365GroupOwnership {

    <#
    Find all groups that a user is a member of. If they are the only owner, change the owner to be their manager
    If there are already other users (owners) present, just remove the user from the owners list
    #>

    $o365groupOwnerReport = @()  # Array used for the total output of group removal
 
    foreach ($group in $allO365Groups) {
        
        $owners = Get-MgGroupOwner -GroupId $group.Id
        if ($owners.id -like $MgUser.id) { # User is an Owner of this Group
            if ($owners.Count -eq 1) { # If User is the ONLY Owner of the Group
                Write-Log "[EXO] $($group.DisplayName) is ONLY owned by $($UserPrincipalName). Changing ownership to $($MgUserManager.UserPrincipalName)"
                
                $ManagerOData = @{
                    "@odata.id" = "https://graph.microsoft.com/v1.0/directoryObjects/$($MgUserManager.Id)"
                }

                New-MgGroupMemberByRef -GroupId $group.Id -BodyParameter $ManagerOData # add Manager as a Member of the Group
                New-MgGroupOwnerByRef -GroupId $group.Id -BodyParameter $ManagerOData # add Manager as an Owner of the Group
                Remove-MgGroupOwnerByRef -GroupId $group.Id -DirectoryObjectId $MgUser.Id # remove User's ownership of group
            }
            if ($owners.Count -gt 1) { # If there are other Owners, just remove User's ownership of Group
                Write-Log "[EXO] There are other owners present on $($group.DisplayName). Removing user from owners list"
                Remove-MgGroupOwnerByRef -GroupId $group.Id -DirectoryObjectId $MgUser.Id
            }

            # Add a list of the groups that the user was an Owner of to an object for export/review
            $o365groupOwnerExport = [PSCustomObject]@{
                O365Group = $group.DisplayName
            } 
            $o365groupOwnerReport += $o365groupOwnerExport

            }
        }
        
        if ( $o365groupOwnerReport.Length -eq 0) { 
        Write-Log "[EXO] $($UserPrincipalName) is not an owner of any groups"
        }
        
        # Write to summary file
        "[EXO] Removed $($UserPrincipalName) Ownership from 365 Group(s): " + ($o365groupOwnerReport.O365Group -join ', ') | Out-File $summaryFile -Append

        # Export report
        $o365groupOwnerReport  | export-csv -Path "$workDir\$($UserPrincipalName)_Offboard_O365OwnedGroups.csv" -NoTypeInformation

}