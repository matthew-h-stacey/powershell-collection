# Function to create a full user properties backup prior to making changes
function Get-AzureADUserPropertiesBackup {
    $Backup = New-Object System.Collections.Generic.List[System.Object]
    $AllAzureADUsers = Get-AzureADUser -All:$true
    foreach ( $User in $AllAzureADUsers) {
        # Retrieve the email address. Requires separate call to EXO vs. pulling from AAD user object
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
    
    # For all properties except manager, retrieve the current value and store it as $OldValue
    # If $OldValue doesn't exist, instead label it as "N/A"
    # This excludes "Manager" because Manager requires a specific cmdlet to pull the property (ex: $User.Manager is not a valid property)
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
            
            # Set the new manager
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
            # This portion of the switch is for all other generic properties that are set via Set-AzureADUser (ex: Department, JobTitle, etc.)
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

# Import the provided CSV with the users to update
$WorkDirectory = "C:\TempPath"
$CsvUsers = Import-Csv $WorkDirectory\users.csv

# Set this to the be the identifier in the CSV file. Typically this should be UserPrincipalName, but may be PrimarySmtpAddress or other property depending on what is provided
$UserIdentifier = "UserPrincipalName"

# Create lists to store output
$Results = New-Object System.Collections.Generic.List[System.Object]
$SkippedUsers = New-Object System.Collections.Generic.List[System.Object]
$ErrorLog = New-Object System.Collections.Generic.List[System.Object]

# First take a backup
Get-AzureADUserPropertiesBackup

# Define the properties to update. Note: the columns from the CSV need to match these exactly. Additional supported fields from Set-AzureADUser can be added if needed
$propertiesToUpdate = @("City", "CompanyName", "Department", "JobTitle", "Mobile", "PostalCode", "State", "StreetAddress", "Manager")

# Iterate through the CSV and update properties as needed
foreach ($CsvUser in $CsvUsers) {
    try {
        $AADUser = Get-AzureADUser -ObjectId $CsvUser.$UserIdentifier
    }
    catch {
        Write-Output "[WARNING] $($CsvUser.$UserIdentifier): SKIPPED, unable to find user"    
        $SkippedUser = $CsvUser.$UserIdentifier
        $SkippedUsers.Add($SkippedUser)
        continue
    }

    # Iterate over the properties to update
    foreach ($property in $propertiesToUpdate) {
        if ($CsvUser.$property) {
            Update-Property $AADUser $property $CsvUser.$property
        }
    }
}

# Output the results
$ResultsOutput = "$WorkDirectory\AzureAD_user_property_changes.csv"
$Results | Export-Csv $ResultsOutput -NoTypeInformation
Write-Output "[INFO] Exported change log to: $ResultsOutput"