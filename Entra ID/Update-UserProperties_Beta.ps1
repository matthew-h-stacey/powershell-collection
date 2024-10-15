<#
.DESCRIPTION
This script takes a pre-filled CSV and iterates through it to update user properties. The CSV must include a header that contains a
UserIdentifier (UserPrincipalName, PrimarySmtpAddress) and the rest must be valid properties available in Update-MgUser/Set-ADUser.
The script will update all properties in the CSV with the exception of the UserIdentifier

.PARAMETER DirectoryType
For Active Directory user changes, use "ActiveDirectory." For Entra ID user changes, use "EntraID"

.PARAMETER CsvPath
Full file/folder path of the CSV

.PARAMETER UserIdentifier
This is the user identifier in the CSV file. 
Typically, this should be UserPrincipalName or PrimarySmtpAddress

.PARAMETER ManagerIdentifier
Optional parameter for cases when a Manager column is provided but the content is a different format from UserIdentifier. 
For example, UserIdentifier may be UserPrincipalName but display names are used in the Manager column.
In that case, ManagerIdentifier should be "DisplayName"

.PARAMETER ExportPath
Directory to export output to (ex: C:\TempPath)

.PARAMETER OverrideBlankValue
If this switch is used and there is a blank value in the provided CSV, it will overwrite the value of the user's property
Use this switch to clear values on the user object. Omit this switch to update cells with values, only

.PARAMETER SkipBackup
Skip the property backup. Useful if re-running this script and the backup was taken the first time the script ran

.PARAMETER WhatIf
Record changes but don't actually make them

.EXAMPLE
Sample execution
1) Create and populate a CSV (C:\TempPath\input.csv) with the headers: UserPrincipalName,DisplayName,Department,JobTitle,EmployeeId
2) Execute: 
Connect-MgGraph -scopes User.ReadWrite.All
Update-UserProperties.ps1 -CsvPath C:\TempPath\input.csv -UserIdentifier UserPrincipalName -ExportPath C:\TempPath
3) Review output in ExportPath

.NOTES
To-Do
- Fix "Manager" property in the backup (lines ~234) returns an object instead of value (Microsoft.Graph.PowerShell.Models.MicrosoftGraphDirectoryObject)
#>

param (
    [Parameter(Mandatory = $true)]
    [ValidateSet("ActiveDirectory", "EntraID")]
    [string]
    $DirectoryType,

    [Parameter(Mandatory = $true)]
    [string]
    $CsvPath,

    [Parameter(Mandatory = $true)]
    [string]
    $UserIdentifier,

    [Parameter(Mandatory = $false)]
    [ValidateSet("DisplayName","UserPrincipalName")]
    [string]
    $ManagerIdentifier,

    [Parameter(Mandatory = $true)]
    [string]
    $ExportPath,

    [Parameter(Mandatory = $false)]
    [switch]
    $OverwriteBlankValue,

    [Parameter(Mandatory = $false)]
    [boolean]
    $SkipBackup,

    [Parameter(Mandatory = $false)]
    [switch]
    $WhatIf
)

function Get-ADUserByIdentifier {
    <#
    .SYNOPSIS
    Dynamically get an AD user based on provided Identity and Identifier
    
    .PARAMETER Identity
    The value used to search for an Active Directory user
    
    .PARAMETER UserIdentifier
    The property to use when searching for the Active Directory user

    .PARAMETER Properties
    Optional parameter to select specific properties of the user object
    #>

    param (
        [Parameter(Mandatory = $true)]
        [string]
        $Identity,

        [Parameter(Mandatory = $true)]
        [ValidateSet("DisplayName","Mail","UserPrincipalName")]
        [string]
        $UserIdentifier,

        [Parameter(Mandatory = $false)]
        [string[]]
        $Properties
    )

    switch ($UserIdentifier) {
        "DisplayName" {
            $filter = { DisplayName -like $Identity }
        }
        "UserPrincipalName" {
            $filter = { UserPrincipalName -eq $Identity }
        }
        "Mail" {
            $filter = { Mail -eq $Identity }
        }
    }

    if ( $Properties ) {
        $userObj = Get-ADUser -Filter $filter -Properties $Properties
    } else {
        $userObj = Get-ADUser -Filter $filter
    }
    
    return $userObj
}

function Update-Property {

    <#
    .SYNOPSIS
    Takes a user object, property to update, new value, and attempts to update the property with the new value

    .PARAMETER UserObject
    An MgUser object for a user to update properties on

    .PARAMETER Property
    The property to update (ex: "Department")

    .PARAMETER NewValue
    The new value to set (ex: "Human Resources")

    .EXAMPLE
    Update-Property -UserObject $mgUser -Property "Department" -NewValue "Human Resources"
    #>

    [CmdletBinding()]
    param (
        [Parameter(Mandatory = $true)]
        [Object]
        $UserObject,

        [Parameter(Mandatory = $true)]
        [string]
        $Property,

        [Parameter(Mandatory = $true)]
        [string]
        $NewValue
    )

    # Take specific action based on the property
    # - Updating Manager requires usage of Set-MgUserManagerByRef 
    # - Updating extensionAttributes requires updating -AdditionalProperties with a hash table object
    # - All other variables that can be directly passed to Update-MgUser are passed to Update-MgUser
    
    switch ($Property) {
        "Manager" {
            # Updating a user's manager in Entra requires a separate cmdlet than Update-MgUser
            if ( $DirectoryType -eq "ActiveDirectory" ) {
                # Retrieve the current/old Manager UPN. If there is no Manager, set the value to "N/A"       
                if ( $UserObject.Manager ) {
                    $currentManager = Get-ADUser $UserObject.Manager | Select-Object -ExpandProperty userprincipalname
                    $oldValue = $currentManager
                } else {
                    $oldValue = "N/A"
                }

                # Locate the new manager user object
                $newManager = Get-ADUserByIdentifier -Identity $NewValue -UserIdentifier $ManagerIdentifier

                # If there is no change to manager, do nothing. Otherwise, change the manager to the new value
                if ( $newManager.UserPrincipalName -eq $oldValue) {
                    Write-Output "[INFO] $($UserObject.UserPrincipalName): No change to Manager"
                    $changed = $False
                } else {
                    # Set the new manager
                    try {
                        if ( $WhatIf) {
                            Write-Output "[INFO][WHATIF] $($UserObject.UserPrincipalName): Manager updated from $oldValue -> $($newManager.UserPrincipalName)"
                        } else {
                            $UserObject | Set-ADUser -Manager $newManager.DistinguishedName
                            Write-Output "[INFO] $($UserObject.UserPrincipalName): Manager updated from $oldValue -> $($newManager.UserPrincipalName)"
                        }
                        $changed = $True
                    } catch {
                        $errorMessage = "[ERROR] $($UserObject.UserPrincipalName): Failed to update the user's manager. Error: $($_.Exception.Message)"
                        Write-Output $errorMessage
                        $errorLog.Add($errorMessage)
                        $changed = $False
                    }
                }
                
            }
            if ( $DirectoryType -eq "EntraID" ) {
                # Retrieve the current/old Manager UPN. If there is no Manager, set the value to "N/A"                
                try {
                    $currentManager = Get-MgUserManager -UserId $UserObject.UserPrincipalName -ErrorAction Stop
                    $oldValue = $currentManager.AdditionalProperties.userPrincipalName
                } catch {
                    # User does not have a manager
                    $oldValue = "N/A"
                }

                # Locate the new manager user object
                if ( $ManagerIdentifier -eq "DisplayName" ) {
                    $filter = "startsWith(DisplayName,'" + $NewValue + "')"
                    $newManager = Get-MgUser -Filter $filter -ConsistencyLevel eventual
                } elseif ( $ManagerIdentifier -eq "UserPrincipalName" ) {
                    $newManager = Get-MgUser -UserId $NewValue
                }
                
                # If there is no change to manager, do nothing. Otherwise, change the manager to the new value
                if ( $newManager.UserPrincipalName -eq $oldValue) {
                    Write-Output "[INFO] $($UserObject.UserPrincipalName): No change to Manager"
                    $changed = $False
                } else {
                    # Set the new manager
                    try {
                        if ( $WhatIf) {
                            Write-Output "[INFO][WHATIF] $($UserObject.UserPrincipalName): Manager updated from $oldValue -> $($newManager.UserPrincipalName)"
                        } else {
                            $body = @{
                                "@odata.id" = "https://graph.microsoft.com/v1.0/users/$($newManager.Id)"
                            }
                            if ($UserObject.Id) {
                                Set-MgUserManagerByRef -UserId $UserObject.Id -BodyParameter $body
                            } else {
                                Set-MgUserManagerByRef -UserId $UserObject.UserPrincipalName -BodyParameter $body
                            }
                            Write-Output "[INFO] $($UserObject.UserPrincipalName): Manager updated from $oldValue -> $($newManager.UserPrincipalName)"
                        }
                        $changed = $True
                    } catch {
                        $errorMessage = "[ERROR] $($UserObject.UserPrincipalName): Failed to update the user's manager. Error: $($_.Exception.Message)"
                        Write-Output $errorMessage
                        $errorLog.Add($errorMessage)
                        $changed = $False
                    }
                }
            }
            
        }
        { $_ -like "extensionAttribute[1-9]" -or $_ -like "extensionAttribute1[0-5]" } {
            # Handling for extensionAttribute1-extensionAttribute15

            # First, retrieve the current/old value
            $oldValue = $UserObject.OnPremisesExtensionAttributes.$Property
            if (!$oldValue) { 
                $oldValue = "N/A"
            }
            # Compare the current value to the provided one
            if ( $oldValue -eq $NewValue) {
                Write-Output "[INFO] $($UserObject.UserPrincipalName): No change to $Property"
                $changed = $False
            } else {
                if ( $WhatIf) {
                    Write-Output "[INFO][WHATIF] $($UserObject.UserPrincipalName): $Property updated from $oldValue -> $NewValue"
                } else {
                    # If the current value doesn't match the input, attempt to update it
                    try {
                        Update-MgUser -UserId $UserObject.UserPrincipalName -AdditionalProperties @{
                            "onPremisesExtensionAttributes" = @{
                                $Property = $NewValue
                            }
                        }
                        Write-Output "[INFO] $($UserObject.UserPrincipalName): $Property updated from $oldValue -> $NewValue"
                        $changed = $True
                    } catch {
                        $errorMessage = "[ERROR] $($UserObject.UserPrincipalName): Failed to update $property. Error: $($_.Exception.Message)"
                        Write-Output $errorMessage
                        $errorLog.Add($errorMessage)
                        $changed = $False
                    }
                }
            }
        }
        default {
            # This portion of the switch is for all other generic properties that are set via Update-MgUser (ex: Department, JobTitle, etc.)
            # First, retrieve the current/old value
            $oldValue = $UserObject.$property
            if (!$oldValue) { 
                $oldValue = "N/A"
            }
            # Compare the current value to the provided one
            if ( $UserObject.$Property -eq $NewValue) {
                Write-Output "[INFO] $($UserObject.UserPrincipalName): No change to $Property"
                $changed = $False
            } else {
                # If the current value doesn't match the input, attempt to update it
                $params = @{
                    $Property = $NewValue
                }
                try {
                    if ( $WhatIf) {
                        Write-Output "[INFO][WHATIF] $($UserObject.UserPrincipalName): $Property updated from $oldValue -> $NewValue"
                    } else {
                        switch ( $DirectoryType ) {
                            "ActiveDirectory" {
                                $UserObject | Set-ADUser @params                                
                            }
                            "EntraID" {
                                Update-MgUser -UserId $UserObject.UserPrincipalName @params
                            }
                        }
                        Write-Output "[INFO] $($UserObject.UserPrincipalName): $Property updated from $oldValue -> $NewValue"
                    }
                    $changed = $True
                } catch {
                    $errorMessage = "[ERROR] $($UserObject.UserPrincipalName): Failed to update $property. Error: $($_.Exception.Message)"
                    Write-Output $errorMessage
                    $errorLog.Add($errorMessage)
                    $changed = $False
                }
            }
        }
    }
    $outputObject = [PSCustomObject]@{
        UserPrincipalName = $UserObject.UserPrincipalName
        Property          = $Property
        OldValue          = $oldValue
        NewValue          = $NewValue
        ValueChanged      = $changed
    }
    $results.Add($outputObject)
}

function Start-PropertyUpdateWorkflow {

    <#
    .SYNOPSIS
    Pulls in a CSV and iterates through it to retrieve user objects, then calls a separate function to update each property

    .PARAMETER CSV
    Full file/folder path to the CSV

    .PARAMETER UserIdentifier
    This is the user identifier in the CSV file. Typically this should be UserPrincipalName or PrimarySmtpAddress

    .EXAMPLE
    Start-PropertyUpdateWorkflow -CSV $CsvPath
    #>

    param(
        [Parameter(Mandatory = $true)]
        [String]
        $CSV,

        [Parameter(Mandatory = $true)]
        [String]
        $UserIdentifier
    )

    $csvUsers = Import-Csv -Path $CSV

    # Validate the UserIdentifier before proceeding
    if ( $UserIdentifier -notin ($csvUsers | Get-Member | Select-Object -expand Name)) {
        Write-Output "[ERROR] UserIdentifier '$UserIdentifier' was not found in the provided CSV. Please double-check the input file and try again"
        exit 1
    }

    # Retrieve the properties from the CSV to be updated
    # Also adds "OnPremisesExtensionAttributes" to the property list in the event that one of the properties to be updated
    # NOTE: The input file may reference an attribute like extensionAttribute1, but the property to pull those values is OnPremisesExtensionAttributes

    # This variable is used to track which properties need to be changed
    $propsExclIdentifier = $csvUsers | Get-Member -MemberType NoteProperty | Where-Object { $_.Name -notLike $userIdentifier } | Select-Object -ExpandProperty Name 

    # This variable is used to select the user and relevant properties
    # OnPremisesExtensionAttributes will always be selected for Entra ID users but extensionAttributes will not be referenced directly since
    # they are under OnPremisesExtensionAttributes
    $propsInclIdentifier = $csvUsers | Get-Member -MemberType NoteProperty | Select-Object -ExpandProperty Name
    if ( $propsInclIdentifier -contains "OnPremisesExtensionAttributes" ) {
        $selectedProps = $propsInclIdentifier | Where-Object { $_ -notLike "extensionAttribute*" }
    } else {
        $selectedProps = $propsInclIdentifier | Where-Object { $_ -notLike "extensionAttribute*" } 
        $selectedProps += "OnPremisesExtensionAttributes"
    }

    $backup = @() # array to be exported to CSV
    $locatedUsers = @() # User located during the backup portion, referenced during the property execution

    # Locate valid users from the input
    foreach ( $user in $csvUsers ) {
        $userId = $user.$UserIdentifier
        # Attempt to locate the user and select the relevant properties
        switch ( $DirectoryType ) {
            "ActiveDirectory" {
                $userObj = Get-ADUserByIdentifier -Identity $userId -UserIdentifier $UserIdentifier -Properties $propsInclIdentifier | Select-Object $propsInclIdentifier
                # Replace the default DN returned by Get-ADUser with the UPN of the manager, instead
                if ( $userObj.Manager ) {
                    $userObj.Manager = Get-ADUser $userObj.Manager | Select-Object -ExpandProperty userprincipalname
                 }
            }
            "EntraID" {
                try {
                    $userObj = Get-MgUser -UserId $userId -Property $propsInclIdentifier -ErrorAction Stop | Select-Object $propsInclIdentifier
                } catch {
                    # Unable to locate Entra ID user with provided identifier
                    continue
                }
            }
        }
        # After attempting to locate the user, output a warning if the user cannot be found
        if ($userObj) {
            $locatedUsers += $userId
        } else {
            Write-Output "[WARNING] $($userId): SKIPPED, unable to find a user using provided the identifier"    
            $skippedUsers.Add($userId)
        }

        # Back up the properties to a file
        if (!($SkipBackup)) {
            # Store the properties of the users before proceeding
            $userProps = [ordered]@{}
            foreach ($property in $userObj.psobject.properties) {                
                if ( $property.Value -is [System.String[]]) {
                    $userProps[$property.Name] = $property.Value -join ', '
                } else {
                    $userProps[$property.Name] = $property.Value                    
                }
            }
            $backup += New-Object PSObject -Property $userProps
        }
    }
    if ( $backup ) {        
        $backup | Export-Csv $backupFile -NoTypeInformation
        Write-Output "[INFO] Exported user property backup to: $backupFile"
    }
    # Iterate over the properties to update. Only overwrite user properties with blank values if $OverwriteBlankValue is used. Otherwise, only update properties that have values in the CSV
    foreach ($user in $csvUsers) {
        if ( $locatedUsers -contains $user.$UserIdentifier ) {
            # Locate user objects that were previously stored in $locatedUsers

            switch ( $DirectoryType ) {
                "ActiveDirectory" {
                    $userToUpdate = Get-ADUserByIdentifier -Identity $user.$UserIdentifier -UserIdentifier $UserIdentifier -Properties $propsInclIdentifier | Select-Object $selectedProps
                }
                "EntraID" {
                    $userToUpdate = Get-MgUser -UserId $user.$UserIdentifier -Property $selectedProps
                }
            }
            
            foreach ($property in $propsExclIdentifier) {
                if ( $OverwriteBlankValue ) {
                    # Update property regardless of what is in the cell
                    Update-Property -UserObject $userToUpdate -Property $property -NewValue $user.$property
                } elseif (-not [string]::IsNullOrWhiteSpace($user.$property)) {
                    # Update the property only if the cell contains text
                    Update-Property -UserObject $userToUpdate -Property $property -NewValue $user.$property
                }
            }
        }
    }
    
}

function Export-Results {
    if ( $results ) {
        $results | Export-Csv $resultsOutput -NoTypeInformation
        Write-Output "[INFO] Exported results to: $resultsOutput"
    }
    if ( $skippedUsers ) {
        $skippedUsers | Out-File $skippedUsersOutput
        Write-Output "[INFO] Some users were skipped, please review $skippedUsersOutput. Users may not have been matched with the specified UserIdentifier"
    }
    if ( $errorLog ) { 
        $errorLog | Out-File $errorLogOutput
        Write-Output "[INFO] Error log exported to: $errorLogOutput"
    }
}

############ Variables #############

# Report name/location
$resultsOutput = "$ExportPath\$($DirectoryType)_bulk_user_property_changes_$((Get-Date -Format 'yyyy-MM-dd_HHmm')).csv"
$skippedUsersOutput = "$ExportPath\$($DirectoryType)_bulk_user_property_changes_skippedUsers_$((Get-Date -Format 'yyyy-MM-dd_HHmm')).txt"
$errorLogOutput = "$ExportPath\$($DirectoryType)_bulk_user_property_changes_errors_$((Get-Date -Format 'yyyy-MM-dd_HHmm')).txt"
$backupFile = "$ExportPath\$($DirectoryType)_bulk_user_property_backup_$((Get-Date -Format 'yyyy-MM-dd_HHmm')).csv"


# Empty lists to store results
$results = New-Object System.Collections.Generic.List[System.Object]
$skippedUsers = New-Object System.Collections.Generic.List[System.Object]
$errorLog = New-Object System.Collections.Generic.List[System.Object]

####################################


############ Execution #############

Start-PropertyUpdateWorkflow -CSV $CsvPath -UserIdentifier $UserIdentifier
Export-Results

####################################