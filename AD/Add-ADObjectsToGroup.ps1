<#
.SYNOPSIS
Bulk add user or computer objects to an Active Directory group using a .txt file


.EXAMPLE
.\Add-ADObjectToGroup.ps1 -Path C:\TempPath\pcs.txt -GroupName "My Group" -Computer -ExportPath C:\TempPath

#>


param (
    # Path to the .txt file that contains the names of the AD objects
    [Parameter(Mandatory = $true)]
    [String]
    $Path,

    # Name of the group to add the computers to
    [Parameter(Mandatory = $true)]
    [String]
    $GroupName,

    # Use this switch if adding computer objects to a group
    [parameter(ParameterSetName = "Computer")]
    [Switch]
    $Computer,

    # Use this switch if adding user objects to a group
    [parameter(ParameterSetName = "User")]
    [Switch]
    $User,

    # Folder to output the log to
    [Parameter(Mandatory = $true)]
    [String]
    $ExportPath
)

function Write-Log {
    
    <#
    .SYNOPSIS
    Log to a specific file/folder path with timestamps

    .EXAMPLE
    Write-Log -Message "[INFO] Attempting to do the thing" -LogFile C:\Scripts\MyScript.log
    Write-Log -Message "[INFO] Attempting to do the thing" -LogFile $LogFile 
    #>
    
    param (
        [Parameter(Mandatory = $true)]
        [String]
        $Message,

        [Parameter(Mandatory = $true)]
        [String]
        $LogFile
    )

    $timeStampMessage = "$((Get-Date -Format "MM/dd/yyyy HH:mm:ss")) $Message"
    Add-Content -Value $timeStampMessage -Path $LogFile

}

function Write-LogAndOutput {

    <#
    .SYNOPSIS
    A quick function to both log and send output to the console

    .EXAMPLE
    Write-LogAndOutput -Message "[INFO] Attempting to do the thing" -LogFile $logFile
    #>

    param (
        [Parameter(Mandatory = $True)]
        [String]
        $Message
    )

    Write-Log $Message -LogFile $logFile
    Write-Output $Message

}

function Find-ADUser {

    <#
    .SYNOPSIS
    Searches for an ADUser with a UPN, DisplayName, or samAccount name. This allows the input to be more flexible than just using Get-ADUser

    .EXAMPLE
    Find-ADUser -Identity "John Smith"
    Find-ADUser -Identity jsmith@contoso.com -LogFile $logFile
    #>

    param (
        # Identity of the user to locate
        [Parameter(Mandatory = $true)]
        [String]
        $Identity,

        # Properties to retrieve for the user
        # Example 1: All properties - "*"
        # Example 2: Specific properties - "Department,Title,Manager"
        [Parameter(Mandatory = $false)]
        [String[]]
        $Properties,

        # If enabled, skips users that aren't found instead of exiting with an error code
        [Parameter(Mandatory = $false)]
        [Switch]
        $SkipFailures,

        # Optionally log to a file
        [Parameter(Mandatory = $false)]
        [String]
        $LogFile
    )

    if ($Identity -match '@') {
        # Identity contains '@', consider it as UPN
        if ( $Properties ) {
            $user = Get-ADUser -Filter { UserPrincipalName -eq $Identity } -Properties $Properties
        } else {
            $user = Get-ADUser -Filter { UserPrincipalName -eq $Identity }
        }
        if ( $user -and $LogFile ) {
            Write-Log -Message "[INFO] Located user $Identity by UserPrincipalName" -LogFile $logFile
        }
    } else {
        # Try to get the user by samAccountName or DisplayName
        if ( $Properties ) {
            $user = Get-ADUser -Filter { samAccountName -eq $Identity -or DisplayName -eq $Identity } -Properties $Properties
        } else {
            $user = Get-ADUser -Filter { samAccountName -eq $Identity -or DisplayName -eq $Identity }
        }
        if ( $user -and $LogFile ) {
            Write-Log -Message "[INFO] Located user $Identity by UserPrincipalName" -LogFile $logFile
        }
    }
    if ( !$user ) {
        if ( $LogFile) {
            Write-LogAndOutput -Message "[ERROR] Unable to locate a user with provided input: $Identity. Please verify that you entered the correct samAccountName/DisplayName/UserPrincipalName of an existing user and try again."
        } else {
            Write-Output "[ERROR] Unable to locate a user with provided input: $Identity. Please verify that you entered the correct samAccountName/DisplayName/UserPrincipalName of an existing user and try again."
        }
        if ( !$SkipFailures ) {
            exit 1
        } 
    } elseif ( $user.Count -gt 1 ) {
        if ( $LogFile ) {
            Write-LogAndOutput -Message "[ERROR] More than one user located with the provided input: $Identity. Please try a more descriptive identifier and try again (ex: UserPrincipalName versus DisplayName)"
        } else {
            Write-LogAndOutput "[ERROR] More than one user located with the provided input: $Identity. Please try a more descriptive identifier and try again (ex: UserPrincipalName versus DisplayName)"
        }
        if ( !$SkipFailures ) {
            exit 1
        } 
    }
    $user

}

function Start-ObjectAddWorkflow {
    
    try {
        # Find the group 
        $group = Get-ADGroup -Identity $GroupName -ErrorAction Stop
        $groupMembership = Get-ADGroupMember -Identity $group
        Write-LogAndOutput "[INFO] Group found: $GroupName. Continuing ..."
    } catch [Microsoft.ActiveDirectory.Management.ADIdentityNotFoundException] { 
        # Group not found
        Write-LogAndOutput "[ERROR] Group not found: $GroupName. Please ensure the group name is valid and try again."
        exit 1
    }
    if ( $group.Count -gt 1 ) {
        # More than one group found using provided name
        Write-LogAndOutput "[ERROR] More than one group found matching the name: $GroupName. Please use a unique identifier for the group (ex: DistinguishedName/ObjectGUID) and try again."
        exit 1
    } else {
        # Proceed to try to add user to group
        $skippedObjects = @()
        $inputObjects = Get-Content $Path
        $inputObjects | ForEach-Object {
            $objName = $_
            try {
                # Find the object 
                switch ($PSCmdlet.ParameterSetName) {
                    "Computer" {
                        $adObject = Get-ADObject -Filter { Name -eq $objName -and objectclass -eq "computer" }
                    }
                    "User" {
                        $adObject = Find-ADUser -Identity $objName -LogFile $logFile -SkipFailures
                    }
                }
                # Determine if the object is already a member of the group. If not, add them to the group
                if ( $adObject.DistinguishedName -in $groupMembership.DistinguishedName ) {
                    Write-LogAndOutput "[INFO] SKIPPED: $objName is already a member of group: $($group.Name)"
                } else {
                    Add-ADGroupMember -Identity $group.ObjectGUID -Members $adObject 
                    Write-LogAndOutput "[INFO] Added $objName to group: $($group.Name)"
                }
            } catch [Microsoft.ActiveDirectory.Management.ADIdentityNotFoundException] {
                # Object not found
                Write-LogAndOutput "[WARNING] AD object not found: $objName. Object name has been added to the skipped objects output for review."
                $skippedObjects += $objName
            }
        }
        Write-LogAndOutput "[DONE] Finished processing all objects"
    }

    $skippedObjects | Out-File $skippedObjectsOutput 

}

### Output
$logFile = "$($ExportPath.TrimEnd("\"))\Add-ADObjectsToGroup.log"
Write-Output "Log file: $logfile"
$skippedObjectsOutput = "$($ExportPath.TrimEnd("\"))\Add-ADObjectToGroup_skipped_$((Get-Date -Format "MM-dd-yyyy_HHmm")).txt"

# Execution
Start-ObjectAddWorkflow 