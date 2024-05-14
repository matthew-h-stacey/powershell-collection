<#
.SYNOPSIS
Use a CSV to bulk update Entra ID user properties
The script will automatically update all columns except $UserIdentifier. Ensure that all other headers are supported properties to update using Set-ADUser

.EXAMPLE
1) Update $propertiesToUpdate to include the properties that need to be updated from the CSV
2) Update-AzureADUserProperties.ps1 -CsvPath C:\TempPath\input.csv -UserIdentifier UserPrincipalName -ExportPath C:\TempPath

.NOTES
To Do:
[ ] Update backup function to only back up the provided users instead of the entire tenant
[ ] Add option in Start-PropertyUpdateWorkflow to accept blank values to replace what is in Entra ID
#>

param (
    # Full file/folder path of the CSV
    [Parameter(Mandatory=$true)]
    [String]
    $CsvPath,

    # This is the identifier in the CSV file. Typically this should be UserPrincipalName or PrimarySmtpAddress
    [Parameter(Mandatory=$true)]
    [String]
    $UserIdentifier,

    # Directory to export output to (ex: C:\TempPath)
    [Parameter(Mandatory=$true)]
    [String]
    $ExportPath,

    # If this switch is used and there is a blank value in the provided CSV, it will overwrite the value of the user's property. Use this switch to potentially clear values on the user object. Omit this switch to update cells with values, only
    [Parameter(Mandatory=$false)]
    [Switch]
    $OverwriteBlankValue,

    # Record changes but don't actually make them
    [Parameter(Mandatory=$false)]
    [Switch]
    $WhatIf
)

function Update-Property {

    [CmdletBinding()]
    param (
        # The Entra ID user object to be passed to the function
        [Parameter(Mandatory=$true)]
        [Object[]]$UserObject,

        # The property to update
        [Parameter(Mandatory=$true)]
        [string]$Property,

        # The new value for the property
        [Parameter(Mandatory=$true)]
        [string]$NewValue,

        # Optional parameter to record changes but not actually make them
        [Parameter(Mandatory=$false)]
        [switch]$WhatIf
    )

    <#
    .SYNOPSIS
    Executes the property update for a given user

    .EXAMPLE
    Update-Property -UserObject (Get-MgUser -UserId jsmith@contoso.com) -Property Department -NewValue Sales
    #>

    # Take specific action based on the property
    switch ($Property) {
        "Manager" {

            # Retrieve the current/old Manager UPN. If there is no Manager, set the value to "(None)"
            $currentManager = Get-MgUserManager -UserId $UserObject.Id
            $oldValue = $currentManager.AdditionalProperties.userPrincipalName
            if ( !$oldValue ) { 
                $oldValue = "(None)"
            }
            $newManager = Get-AzureADUser -ObjectId $NewValue
            if ( $newManager.UserPrincipalName -eq $oldValue) {
                Write-Output "[INFO] $($UserObject.UserPrincipalName): No change to Manager"
                $changed = $False
            } else {
                # Set the new manager
                try {
                    if ( $WhatIf) {
                        Write-Output "[INFO][WHATIF] $($UserObject.UserPrincipalName): Manager updated from $oldValue -> $($newManager.UserPrincipalName)"
                    } else {
                        Set-AzureADUserManager -ObjectId $UserObject.UserPrincipalName -RefObjectId $newManager.ObjectId
                        Write-Output "[INFO] $($UserObject.UserPrincipalName): Manager updated from $oldValue -> $($newManager.UserPrincipalName)"
                    }
                    $changed = $True
                }
                catch {
                    $errorMessage = "[ERROR] $($UserObject.UserPrincipalName): Failed to update the user's manager. Error: $($_.Exception.Message)"
                    Write-Output $errorMessage
                    $errorLog.Add($errorMessage)
                    $changed = $False
                }
            }
        }
        "EmployeeId" {

            # Retrieve the current/old employee ID. If there is no ID, set the value to "(None)"
            $oldValue = $UserObject.ExtensionProperty.employeeId
            if ( !$oldValue ) { 
                $oldValue = "(None)"
            }
            # If no change, output as such
            if ( $UserObject.employeeId -eq $NewValue) {
                Write-Output "[INFO] $($UserObject.UserPrincipalName): No change to employeeId"
                $changed = $False
            } else {
                # Attempt to update the property
                try {
                    if ( $WhatIf) {
                        Write-Output "[INFO][WHATIF] $($UserObject.UserPrincipalName): employeeId updated from $oldValue -> $NewValue"
                    } else {
                        $dictionary = New-Object System.Collections.Generic.Dictionary"[String,String]"
                        $dictionary.Add("employeeId", "$employeeId")
                        Set-AzureADUser -ObjectId $UserObject.ObjectId -ExtensionProperty $dictionary
                        Write-Output "[INFO] $($UserObject.UserPrincipalName): employeeId updated from $oldValue -> $NewValue"
                    }
                    $changed = $True
                } catch {
                    $errorMessage = "[ERROR] $($UserObject.UserPrincipalName): Failed to update the employeeId. Error: $($_.Exception.Message)"
                    Write-Output $errorMessage
                    $errorLog.Add($errorMessage)
                    $changed = $False
                }
            }
        }
        default {
            # This portion of the switch is for all other generic properties that are set via Set-AzureADUser (ex: Department, JobTitle, etc.)

            # For all properties except manager, retrieve the current value and store it as $oldValue. If $oldValue doesn't exist, instead label it as "N/A"
            # This excludes "Manager" because Manager requires a specific cmdlet to pull the property (ex: $user.Manager is not a valid property)
            $oldValue = $UserObject.$Property
            if (!$oldValue) { 
                $oldValue = "N/A"
            }


            if ( $UserObject.$Property -eq $NewValue) {
                Write-Output "[INFO] $($UserObject.UserPrincipalName): No change to $Property"
                $changed = $False
            } else {
                $params = @{
                    $Property = $NewValue
                }
                try {
                    if ( $WhatIf) {
                        Write-Output "[INFO][WHATIF] $($UserObject.UserPrincipalName): $Property updated from $oldValue -> $NewValue"
                    } else {
                        Set-AzureADUser -ObjectId $UserObject.ObjectId @params
                        Write-Output "[INFO] $($UserObject.UserPrincipalName): $Property updated from $oldValue -> $NewValue"
                    }
                    $changed = $True
                }
                catch {
                    $errorMessage = "[ERROR] $($UserObject.UserPrincipalName): Failed to update the $propertyName. Error: $($_.Exception.Message)"
                    Write-Output $errorMessage
                    $errorLog.Add($errorMessage)
                    $changed = $False
                }
            }
        }
    }
    $outputObject = [PSCustomObject]@{
        UserPrincipalName   = $UserObject.UserPrincipalName
        Property            = $Property
        OldValue            = $oldValue
        NewValue            = $NewValue
        ValueChanged        = $changed
    }
    $results.Add($outputObject)
}

function Start-PropertyUpdateWorkflow {

    <#
    .SYNOPSIS
    Pulls in a CSV and iterates through it to retrieve user objects, then calls a separate function to update each property

    .EXAMPLE
    Start-PropertyUpdateWorkflow -CSV $CsvPath
    #>

    param(
        # Path to the CSV
        [Parameter(Mandatory = $true)]
        [String]
        $CSV,

        # This is the identifier in the CSV file. Typically this should be UserPrincipalName, but may be PrimarySmtpAddress or other property depending on what is provided
        [Parameter(Mandatory = $true)]
        [String]
        $UserIdentifier
    )

    $csvUsers = Import-Csv -Path $CSV 
    $propsExclIdentifier = $csvUsers | Get-Member -MemberType NoteProperty | Where-Object { $_.Name -notLike $userIdentifier } | Select-Object -ExpandProperty Name 
    $propsInclIdentifier = $csvUsers | Get-Member -MemberType NoteProperty | Select-Object -ExpandProperty Name
    $backup = @() # array to be exported to CSV
    $locatedUsers = @() # Entra ID users located during the backup portion, referenced during the property execution

    # Back up user properies first
    $csvUsers  | ForEach-Object {
        try {
            $mgUser = Get-MgUser -UserId $_.$UserIdentifier -Property $propsInclIdentifier  | Select-Object $propsInclIdentifier
            $userProps = [ordered]@{}
            foreach ($property in $mgUser.psobject.properties) {                
                if ( $property.Value -is [System.String[]]) {
                    $userProps[$property.Name] = $property.Value -join ', '
                } else {
                    $userProps[$property.Name] = $property.Value                    
                }
            }
            $backup += New-Object PSObject -Property $userProps
            $locatedUsers += $_.$UserIdentifier
        } catch {
            Write-Output "[WARNING] $($_.$UserIdentifier): SKIPPED, unable to find an Entra ID user using provided the identifier"    
            $skippedUsers.Add($_.$UserIdentifier)
            continue
        }
    }
    if ( $backup ) {
        $backup | Export-Csv $backupFile -NoTypeInformation
        Write-Output "[INFO] Exported user property backup to: $backup"
    }

    # Iterate over the properties to update. Only overwrite user properties with blank values if $OverwriteBlankValue is used. Otherwise, only update properties that have values in the CSV
    foreach ($user in $csvUsers) {
        if ( $locatedUsers -contains $user.$UserIdentifier ) {
            # Locate user objects that were previously stored in $locatedUsers
            $mgUser = Get-MgUser -UserId $user.$UserIdentifier -Property $propsExclIdentifier
            foreach ($property in $propsExclIdentifier) {
                if ( $OverwriteBlankValue ) {
                    # Update property regardless of what is in the cell
                    Update-Property -userObject $mgUser -Property $property -newValue $user.$property
                } elseif (-not [string]::IsNullOrWhiteSpace($user.$property)) {
                    # Update the property only if the cell contains text
                    Update-Property -userObject $mgUser -Property $property -newValue $user.$property
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
$resultsOutput = "$ExportPath\AzureAD_user_property_changes_$((Get-Date -Format "MM-dd-yyyy_HHmm")).csv"
$skippedUsersOutput = "$ExportPath\AzureAD_user_property_changes_skippedUsers_$((Get-Date -Format "MM-dd-yyyy_HHmm")).txt"
$errorLogOutput = "$ExportPath\AzureAD_user_property_changes_errors_$((Get-Date -Format "MM-dd-yyyy_HHmm")).txt"
$backupFile = "$ExportPath\AzureAD_user_property_backup_$((Get-Date -Format "MM-dd-yyyy_HHmm")).csv"

# Empty lists to store results
$results = New-Object System.Collections.Generic.List[System.Object]
$skippedUsers = New-Object System.Collections.Generic.List[System.Object]
$errorLog = New-Object System.Collections.Generic.List[System.Object]


####################################


############ Execution #############

Start-PropertyUpdateWorkflow -CSV $CsvPath -UserIdentifier $UserIdentifier
Export-Results

####################################