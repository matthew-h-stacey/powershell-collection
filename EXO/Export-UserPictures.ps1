Param
(   
    [Parameter(Mandatory = $true)][string] $ClientName,
    [parameter(Mandatory = $true,ParameterSetName = "1")][boolean] $EnabledOnly,
    [parameter(Mandatory = $false,ParameterSetName = "2")][string] $CSV
)

# Exports all pictures for a given tenant unless a CSV is provided with specific UPNs
# Example:  .\Export-UserPictures.ps1 -ClientName contoso -EnabledOnly $true
# Example:  .\Export-UserPictures.ps1 -ClientName contoso -CSV "C:\TempPath\users.csv"
# https://blog.jijitechnologies.com/how-to-download-office365-user-profile-photo

# Change as needed
$exportPath = "C:\TempPath\"
$folderPath = $exportPath + $ClientName + "\M365UserPictures\"

function New-Folder {
    Param([Parameter(Mandatory = $True)][String] $folderPath)
    if (-not (Test-Path -LiteralPath $folderPath)) {
        try {
            New-Item -Path $folderPath -ItemType Directory -ErrorAction Stop | Out-Null
            Write-Host "Created folder: $folderPath"
        }
        catch {
            Write-Error -Message "Unable to create directory '$folderPath'. Error was: $_" -ErrorAction Stop
        }
    }
    else {
        "$folderPath already exists, continuing ..."
    }
}

# Create new folder to export pictures to
New-Folder $folderPath

# -EnabledOnly
if ($EnabledOnly -ne '') { 
    if ($EnabledOnly -eq $true){ # If EnabledOnly is True, filter out disabled mailboxes
        $feed = Get-Mailbox -RecipientTypeDetails UserMailbox -ResultSize Unlimited -Filter {IsMailboxEnabled -eq $True} | Sort-Object UserPrincipalName | Select-Object UserPrincipalName, Alias 
        Write-Host "Exporting user profile pictures from all ENABLED users"
    }
    if($EnabledOnly -eq $false){ # If EnabledOnly is False, do not filter out disabled mailboxes
        $feed = Get-Mailbox -RecipientTypeDetails UserMailbox -ResultSize Unlimited | Sort-Object UserPrincipalName | Select-Object UserPrincipalName, Alias
        Write-Host "Exporting user profile pictures from ALL users"
    }
}

# -Csv
if ($CSV -ne '') {
    # if CSV parameter was provided
    $feed = Import-CSV -Path $CSV | Sort-Object UserPrincipalName
    Write-Host "Exporting user profile pictures from all users in CSV"
}

foreach($u in $feed){
    $UPN = $u.UserPrincipalName
    $output = $folderpath + $UPN + ".jpg"
    $photo = Get-UserPhoto -identity $UPN -ErrorAction SilentlyContinue
    if ($null -ne $photo.PictureData) {
        [IO.File]::WriteAllBytes($output, $photo.PictureData)
        Write-Host $UPN "picture exported to" $output
    }
}
