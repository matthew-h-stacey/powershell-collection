$workDir = "C:\TempPath"
$userList = Import-Csv -Path $workDir\users.csv # Columns: UserPrincipalName,JobTitle,Department,Manager; Use UserPrincipalName for Manager
$logFile = $workDir + "\" + "user_prop_update_$((Get-Date -Format "MM-dd-yyyy_HHmm"))_errors.log"

Function Write-Log {
    Param ([string]$logstring)
    Add-Content $logFile -Value "$(Get-Date -Format "MM/dd/yyyy HH:mm") $logstring"
}

# Back up properties before changing them
$results = @()
foreach ( $user in $userList) {
    $userObject = Get-AzureADUser -ObjectId $user.UserPrincipalName

    <#  $userExport properties from old run 
        JobTitle                =       $userObject.JobTitle
        Manager                 =       (Get-AzureADUserManager -ObjectId $userObject.UserPrincipalName).UserPrincipalName
        Department              =       $userObject.Department    
    #>

    $userExport = [PSCustomObject]@{
        UserPrincipalName       = $userObject.UserPrincipalName
        Department       = $userObject.Department
        Office                  = $userObject.Office
        StreetAddress           = $userObject.StreetAddress
        City                    = $userObject.City
        State                   = $userObject.State
        PostalCode              = $userObject.PostalCode
    }
    $results += $userExport
}
$results | Export-Csv $workDir\users_properties_BACKUP.csv -NoTypeInformation

#
function Update-Properties {
    foreach ( $user in $userList) {
        $userObject = Get-AzureADUser -ObjectId $user.UserPrincipalName

        try {
            Set-AzureADUser -ObjectId $userObject.UserPrincipalName -Office $user.Office
        }
        catch {
            $message = $_
            Write-Log "[ERROR] Unable to set Office: $($user.Office)"
            Write-Log "to user object $($user.UserPrincipalName)"
            Write-Warning "Error occured updating user Office. See log file"      
        }
    
        try {
            Set-MsolUser -UserPrincipalName $userObject.UserPrincipalName -StreetAddress "$null"
        }
        catch {
            $message = $_
            Write-Log "[ERROR] Unable to set StreetAddress: $($user.StreetAddress)"
            Write-Log "to user object $($user.UserPrincipalName)"
            Write-Warning "Error occured updating user StreetAddress. See log file"      
        }  

        try {
            Set-MsolUser -UserPrincipalName $userObject.UserPrincipalName -City "$null"
        }
        catch {
            $message = $_	
            Write-Log "[ERROR] Unable to set City: $($user.City)"
            Write-Log "to user object $($user.UserPrincipalName)"
            Write-Warning "Error occured updating user City. See log file"      
        }  

        try {
            Set-MsolUser -UserPrincipalName $userObject.UserPrincipalName -State "$null"
        }
        catch {
            $message = $_	
            Write-Log "[ERROR] Unable to set State: $($user.State)"
            Write-Log "to user object $($user.UserPrincipalName)"
            Write-Warning "Error occured updating user State. See log file"      
        }  

        try {
            Set-MsolUser -UserPrincipalName $userObject.UserPrincipalName -PostalCode "$null"
        }
        catch {
            $message = $_	
            Write-Log "[ERROR] Unable to set PostalCode: $($user.PostalCode)"
            Write-Log "to user object $($user.UserPrincipalName)"
            Write-Warning "Error occured updating user PostalCode. See log file"      
        }  

        <#
        try{
            Set-AzureADUserManager -ObjectId $userObject.ObjectId -RefObjectId (Get-AzureADUser -ObjectId $user.Manager).ObjectID
        }
        catch {
            $message = $_
            Write-Log "[ERROR] Unable to set Manager: $($user.Manager)"
            Write-Log "to user object $($user.UserPrincipalName)"
            Write-Warning "Error occured updating user Manager. See log file"      
        }
        #>
        
    }  
}

# Update properties based on input in users.csv
Update-Properties

# Get new properties and export for review
$results2 = @()
foreach ( $user in $userList) {
    $userObject = Get-AzureADUser -ObjectId $user.UserPrincipalName
    $userExport2 = [PSCustomObject]@{
        UserPrincipalName       = $userObject.UserPrincipalName
        Office                  = $userObject.Office
        StreetAddress           = $userObject.StreetAddress
        City                    = $userObject.City
        State                   = $userObject.State
        PostalCode              = $userObject.PostalCode
    }
    $results2 += $userExport2
}
$results2 | Export-Csv $workDir\users_properties_NEW.csv -NoTypeInformation
