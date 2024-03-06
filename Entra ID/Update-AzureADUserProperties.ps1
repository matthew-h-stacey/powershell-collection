<#
.SYNOPSIS
Use a CSV to bulk update Entra ID user properties

.EXAMPLE
1) Update $propertiesToUpdate to include the properties that need to be updated from the CSV
2) Update-AzureADUserProperties.ps1 -CsvPath C:\TempPath\input.csv -UserIdentifier UserPrincipalName -ExportPath C:\TempPath

.NOTES
To Do:
[ ] Replace $propertiesToUpdate with a dynamic approach of checking headers in a CSV and pulling all except $UserIdentifier
#>

param (
    # Path of CSV
    [Parameter(Mandatory=$true)]
    [String]
    $CsvPath,

    # This is the identifier in the CSV file. Typically this should be UserPrincipalName, but may be PrimarySmtpAddress or other property depending on what is provided
    [Parameter(Mandatory=$true)]
    [String]
    $UserIdentifier,

    # Directory to export to (ex: C:\TempPath)
    [Parameter(Mandatory=$true)]
    [String]
    $ExportPath,

    # Directory to export to (ex: C:\TempPath)
    [Parameter(Mandatory = $false)]
    [Switch]
    $WhatIf
)

function Export-AzureADUserPropertiesBackup {

    <#
    .SYNOPSIS
    Export a backup of relevant user properties

    .EXAMPLE
    Export-AzureADUserPropertiesBackup
    #>

    Write-Output "[INFO] Starting Azure AD user property backup/export. Please note, this can take a while depending on the amount of users ..."
    $backup = New-Object System.Collections.Generic.List[System.Object]
    $allAzureADUsers = Get-AzureADUser -All:$true
    foreach ( $user in $allAzureADUsers) {
        # Retrieve the email address. Requires separate call to EXO vs. pulling from AAD user object
        try {
            $primarySmtpAddress = (Get-Mailbox -Identity $user.UserPrincipalName -ErrorAction Stop).PrimarySmtpAddress 
        } catch {
            # User does not have a mailbox
            $primarySmtpAddress = "N/A"
        }
        $userObject = [PSCustomObject]@{
            DisplayName        = $user.DisplayName
            UserPrincipalName  = $user.UserPrincipalName
            PrimarySmtpAddress = $primarySmtpAddress
            Department         = $user.Department
            JobTitle           = $user.JobTitle
            Manager            = (Get-AzureADUserManager -ObjectId $user.UserPrincipalName).UserPrincipalName
        }
        $backup.Add($userObject)
    }
    $backupFile = "$ExportPath\AzureAD_user_property_backup_$((Get-Date -Format "MM-dd-yyyy_HHmm")).csv"
    $backup | Export-Csv $backupFile -NoTypeInformation
    Write-Output "[INFO] Backup completed successfully. File saved to: $backupFile"

}
function Update-Property {

    [CmdletBinding()]
    param (
        # The Azure AD user object to be passed to the function
        [Parameter(Mandatory=$true, Position=0)]
        [Object[]]$userObject,

        # The property to update
        [Parameter(Mandatory=$true, Position=1)]
        [string]$property,

        # The new value for the property
        [Parameter(Mandatory=$true, Position=2)]
        [string]$newValue,

        # Optional parameter to record changes but not actually make them
        [Parameter(Mandatory=$false)]
        [switch]$WhatIf
    )

    <#
    .SYNOPSIS
    Executes the property update for a given user

    .DESCRIPTION
    TBD

    .EXAMPLE
    Update-Property (Get-AzureADUser -ObjectId jsmith@contoso.com) Department Sales
    #>

    # For all properties except manager, retrieve the current value and store it as $oldValue. If $oldValue doesn't exist, instead label it as "N/A"
    # This excludes "Manager" because Manager requires a specific cmdlet to pull the property (ex: $user.Manager is not a valid property)
    if ( $property -notLike "Manager" ) {
        $oldValue = $userObject.$property
        if (!$oldValue) { 
            $oldValue = "N/A"
        }
    }

    # Take specific action based on the property
    switch ($property) {
        "Manager" {
            # Retrieve the current/old Manager UPN. If there is no Manager, set the value to "(None)"
            $currentManager = Get-AzureADUserManager -ObjectId $userObject.UserPrincipalName
            $oldValue = ($currentManager).UserPrincipalName
            if ( !$oldValue ) { 
                $oldValue = "(None)"
            }
            $newManager = Get-AzureADUser -ObjectId $newValue
            if ( $newManager.UserPrincipalName -eq $oldValue) {
                Write-Output "[INFO] $($userObject.UserPrincipalName): No change to Manager"
                $changed = $False
            } else {
                # Set the new manager
                try {
                    if ( $WhatIf) {
                        Write-Output "[INFO][WHATIF] $($userObject.UserPrincipalName): Manager updated from $oldValue -> $($newManager.UserPrincipalName)"
                    } else {
                        Set-AzureADUserManager -ObjectId $userObject.UserPrincipalName -RefObjectId $newManager.ObjectId
                        Write-Output "[INFO] $($userObject.UserPrincipalName): Manager updated from $oldValue -> $($newManager.UserPrincipalName)"
                    }
                    $changed = $True
                }
                catch {
                    $errorMessage = "[ERROR] $($userObject.UserPrincipalName): Failed to update the user's manager. Error: $($_.Exception.Message)"
                    Write-Output $errorMessage
                    $errorLog.Add($errorMessage)
                    $changed = $False
                }
            }
        }
        default {
            # This portion of the switch is for all other generic properties that are set via Set-AzureADUser (ex: Department, JobTitle, etc.)
            if ( $userObject.$property -eq $newValue) {
                Write-Output "[INFO] $($userObject.UserPrincipalName): No change to $property"
                $changed = $False
            } else {
                $params = @{
                    $property = $newValue
                }
                try {
                    if ( $WhatIf) {
                        Write-Output "[INFO][WHATIF] $($userObject.UserPrincipalName): $property updated from $oldValue -> $newValue"
                    } else {
                        Set-AzureADUser -ObjectId $userObject.ObjectId @params
                        Write-Output "[INFO] $($userObject.UserPrincipalName): $property updated from $oldValue -> $newValue"
                    }
                    $changed = $True
                }
                catch {
                    $errorMessage = "[ERROR] $($userObject.UserPrincipalName): Failed to update the $propertyName. Error: $($_.Exception.Message)"
                    Write-Output $errorMessage
                    $errorLog.Add($errorMessage)
                    $changed = $False
                }
            }
        }
    }
    $outputObject = [PSCustomObject]@{
        UserPrincipalName   = $userObject.UserPrincipalName
        Property            = $property
        OldValue            = $oldValue
        NewValue            = $newValue
        ValueChanged        = $changed
    }
    $results.Add($outputObject)
}
function Start-PropertyUpdateWorkflow {
    param(
        # Array of user objects
        [Parameter(Mandatory=$true)]
        [Object[]]
        $CSV
    )

    # Iterate through users and update properties as needed
    foreach ($user in $CSV) {
        try {
            $AADUser = Get-AzureADUser -ObjectId $user.$UserIdentifier
        } catch {
            Write-Output "[WARNING] $($user.$UserIdentifier): SKIPPED, unable to find user"    
            $skippedUser = $user.$UserIdentifier
            $skippedUsers.Add($skippedUser)
            continue
        }

        # Iterate over the properties to update
        foreach ($property in $propertiesToUpdate) {
            if ($user.$property) {
                Update-Property -userObject $AADUser -Property $property -newValue $user.$property
            }
        }
    }

}

############ Variables #############

# Report name/location
$resultsOutput = "$ExportPath\AzureAD_user_property_changes.csv"
$skippedUsersOutput = "$ExportPath\AzureAD_user_property_changes_skippedUsers.txt"
$errorLogOutput = "$ExportPath\AzureAD_user_property_changes_errors.txt"

# Empty lists to store results
$results = New-Object System.Collections.Generic.List[System.Object]
$skippedUsers = New-Object System.Collections.Generic.List[System.Object]
$errorLog = New-Object System.Collections.Generic.List[System.Object]

# Array to define the properties to update. Note: the columns from the CSV need to match these exactly. Additional supported fields from Set-AzureADUser can be added if needed
$propertiesToUpdate = @("JobTitle", "Department", "PhysicalDeliveryOfficeName", "OtherMails", "Manager")
####################################


############ Execution #############

Export-AzureADUserPropertiesBackup
Start-PropertyUpdateWorkflow -CSV (Import-Csv $CsvPath)
$results | Export-Csv $resultsOutput -NoTypeInformation
$skippedUsers | Out-File $skippedUsersOutput
$errorLog | Out-File $errorLogOutput
Write-Output "[INFO] Exported change log to: $resultsOutput"

####################################