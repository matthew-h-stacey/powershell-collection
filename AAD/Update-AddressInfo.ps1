$workDir = "C:\TempPath"
$userList = Import-Csv -Path $workDir\users.csv # Required header(s): UserPrincipalName
$logFile = $workDir + "\" + "user_prop_update_$((Get-Date -Format "MM-dd-yyyy_HHmm"))_errors.log"

Function Write-Log {
    Param ([string]$logstring)
    Add-Content $logFile -Value "$(Get-Date -Format "MM/dd/yyyy HH:mm") $logstring"
}

# Back up properties before changing them
$results = @()
foreach ( $user in $userList) {
    $userObject = Get-AzureADUser -ObjectId $user.UserPrincipalName
    $userExport = [PSCustomObject]@{
        UserPrincipalName =         $userObject.UserPrincipalName
        DisplayName =               $userObject.DisplayName
        Office =                    $userObject.PhysicalDeliveryOfficeName
        StreetAddress =             $userObject.StreetAddress
        City =                      $userObject.City
        State =                     $userObject.State
        PostalCode =                $userObject.PostalCode
    }
    $results += $userExport
}
$results | Export-Csv $workDir\users_properties_BACKUP.csv -NoTypeInformation

#
function Update-Properties {
    foreach ( $user in $userList) {
        $userObject = Get-MsolUser -UserPrincipalName $user.UserPrincipalName

        try {
            Set-MsolUser -UserPrincipalName $userObject.UserPrincipalName -StreetAddress "$Null"
        }
        catch {
            $message = $_
            Write-Log "[ERROR] Unable to set -StreetAddress to null:"
            Write-Log "$message"
            Write-Warning "Error occured updating user StreetAddress. See log file"      
        }

        try {
            Set-MsolUser -UserPrincipalName $userObject.UserPrincipalName -City "$Null"
        }
        catch {
            $message = $_
            Write-Log "[ERROR] Unable to set City to null:"
            Write-Log "$message"
            Write-Warning "Error occured updating user City. See log file"      
        }
        
    }  
}

# Update properties based on input in users.csv
Update-Properties

# Get updated properties and export for review
$results2 = @()
foreach ( $user in $userList) {
    $userObject = Get-AzureADUser -ObjectId $user.UserPrincipalName
    $userExport = [PSCustomObject]@{
        UserPrincipalName = $userObject.UserPrincipalName
        StreetAddress     = $userObject.StreetAddress
        City              = $userObject.City
        State             = $userObject.State
        PostalCode        = $userObject.PostalCode
    }
    $results2 += $userExport
}
$results2 | Export-Csv $workDir\users_properties_NEW.csv -NoTypeInformation