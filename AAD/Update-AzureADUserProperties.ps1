# Import the provided CSV with the users to update
$CsvUsers = Import-Csv C:\TempPath\swtx_users.csv
$WorkDirectory = "C:\TempPath"
$UserIdentifier = "PrimarySmtpAddress"
$Results = New-Object System.Collections.Generic.List[System.Object]
$SkippedUsers = New-Object System.Collections.Generic.List[System.Object]
$ErrorLog = New-Object System.Collections.Generic.List[System.Object]

function Get-AzureADUserPropertiesBackup {
    # Back up users and properties prior to making changes
    $Backup = New-Object System.Collections.Generic.List[System.Object]
    $AllAzureADUsers = Get-AzureADUser -All:$true
    foreach ( $User in $AllAzureADUsers) {
        try {
            $PrimarySmtpAddress = (Get-Mailbox -Identity $User.UserPrincipalName -ErrorAction Stop).PrimarySmtpAddress 
        }
        catch {
            # User does not have a mailbox
            $PrimarySmtpAddress = "N/A"
        }
        $UserObject = [PSCustomObject]@{
            DisplayName        = $User.DisplayName
            UserPrincipalName  = $User.UserPrincipalName
            PrimarySmtpAddress = $PrimarySmtpAddress
            Department         = $User.Department
            JobTitle           = $User.JobTitle
            Manager            = (Get-AzureADUserManager -ObjectId $User.UserPrincipalName).UserPrincipalName
        }
        $Backup.Add($UserObject)
    }
    $BackupFile = "$WorkDirectory\AzureAD_user_property_backup_$((Get-Date -Format "MM-dd-yyyy_HHmm")).csv"
    $Backup | Export-Csv $BackupFile -NoTypeInformation
    Write-Output "[INFO] Backup completed successfully. File saved to: $BackupFile"
}

# Function to handle Property updates
function Update-Property($User, $Property, $NewValue) {
       
    if ( $Property -notLike "Manager" ) {
        $OldValue = $User.$Property
        if (!$OldValue) { $OldValue = "N/A" }
    }

    # Custom update action based on the Property
    switch ($Property) {
        "Manager" {
            # Retrieve the current/old Manager UPN. If there is no Manager, set the value to "(None)"
            $CurrentManager = Get-AzureADUserManager -ObjectId $User.UserPrincipalName
            $OldValue = ($CurrentManager).UserPrincipalName
            if ( !$OldValue ) { $OldValue = "(None)" }
            
            # NewValue is the Manager's AzureAD object
            $NewManager = Get-AzureADUser -ObjectId $NewValue
            $NewValue = $NewManager.UserPrincipalName
            
            try {
                Set-AzureADUserManager -ObjectId $User.UserPrincipalName -RefObjectId $NewManager.ObjectId
                Write-Output "[INFO] $($User.UserPrincipalName): Manager updated from $OldValue -> $NewValue"
            }
            catch {
                $ErrorMessage = "[ERROR] $($User.UserPrincipalName): Failed to update the user's manager. Error: $($_.Exception.Message)"
                Write-Output $ErrorMessage
                $ErrorLog.Add($ErrorMessage)
            }

        }
        default {
            $params = @{
                $Property = $NewValue
            }
            try {
                Set-AzureADUser -ObjectId $User.ObjectId @params
                Write-Output "[INFO] $($User.UserPrincipalName): $Property updated from $OldValue -> $NewValue"
            }
            catch {
                $ErrorMessage = "[ERROR] $($User.UserPrincipalName): Failed to update the $PropertyName. Error: $($_.Exception.Message)"
                Write-Output $ErrorMessage
                $ErrorLog.Add($ErrorMessage)
            }
        }
    }
    $OutputObject = [PSCustomObject]@{
        UserPrincipalName   = $User.UserPrincipalName
        Property            = $Property
        OldValue            = $OldValue
        NewValue            = $NewValue
    }
    $Results.Add($OutputObject)
}

Get-AzureADUserPropertiesBackup

foreach ( $CsvUser in $CsvUsers ) {

    try {
        $AADUser = Get-AzureADUser -ObjectId $CsvUser.$UserIdentifier
    }
    catch {
        Write-Output "[WARNING] $($CsvUser.$UserIdentifier): SKIPPED, unable to find user"    
        $SkippedUser = $CsvUser.$UserIdentifier
        $SkippedUsers.Add($SkippedUser)
        continue
        
    }
    if ( $CsvUser.Department) {
        Update-Property $AADUser "Department" $CsvUser.Department
    }
    if ( $CsvUser.JobTitle) {
        Update-Property $AADUser "JobTitle" $CsvUser.JobTitle
    }
    if ( $CsvUser.Manager) {
        Update-Property $AADUser "Manager" $CsvUser.Manager
    }  

}


$ResultsOutput = "$WorkDirectory\AzureAD_user_property_changes.csv"
$Results | Export-Csv $ResultsOutput -NoTypeInformation
Write-Output "[INFO] Exported change log to: $ResultsOutput"