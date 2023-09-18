# Note: Must be run as Global Administrator or user with SPO admin rights

param (
    # SPO Admin URL
    [Parameter(Mandatory = $true)]
    [String]
    $AdminURL,

    # Secondary admin account, the admin user with Global Admin or SPO that will be temporarily added as a secondary admin to all personal OneDrive sites
    [Parameter(Mandatory = $true)]
    [String]
    $SecondaryAdmin
)

$ExportPath = "C:\TempPath"
$OutputFile = "$ExportPath\AddtlOneDriveAdmins.csv"
$ErrorLog = @() # empty error to store errors/warnings
$results = @()

Function Add-OnedriveSecondaryAdmin($AdminURL, $SecondaryAdmin) {
    foreach ($OneDriveURL in $OneDriveURLs) {
        # Add Secondary administrator to Onedrive Site.
        try { 
            Set-SPOUser -Site $OneDriveURL.URL -LoginName $SecondaryAdmin -IsSiteCollectionAdmin $true
            Write-Host "Added secondary admin to the site $($OneDriveURL.URL)"
        }
        catch {
            $Warning = "Unable to grant $($SecondaryAdmin) access to URL: $($OneDriveURL.URL)"
            Write-Warning $Warning
            $ErrorLog += $Warning
            $ErrorLog += $_
        }
    }
}
Function Remove-OnedriveSecondaryAdmin {
    foreach ($OneDriveURL in $OneDriveURLs) {
        #Remove Secondary administrator to Onedrive Site.
        try {
            Set-SPOUser -Site $OneDriveURL.URL -LoginName $SecondaryAdmin -IsSiteCollectionAdmin $false | Out-Null
            Write-Host "Removed secondary admin from the site $($OneDriveURL.URL)" 
        }
        catch {
            $Warning = "Failed to remove $SecondaryAdmin from URL: $($OneDriveURL.URL)"
            Write-Warning $Warning
            $ErrorLog += $Warning
            $ErrorLog += $_
        }
    }
}

function Get-OneDriveSecondaryAdmins {
    $allOneDriveURLs = Get-SPOSite -Filter { Url -like "/personal/" } -IncludePersonalSite $true -Limit All | Select-Object -ExpandProperty Url
    foreach ($URL in $allOneDriveURLs) {
        try {

            $SitePermissions = get-spouser -site $URL -Limit all | Where-Object { $_.IsSiteAdmin -eq $true }
            $SiteOwners = $SitePermissions.LoginName
            $PermissionOutput = [PSCustomObject]@{
                User   = $URL
                Owners = $SiteOwners -join ";"
            }

            $results += $PermissionOutput

        }

        catch {
            "Unable to pull permissions for URL: $URL"
        }
    }
}

Connect-SPOService -Url $AdminURL
$OneDriveURLs = Get-SPOSite -IncludePersonalSite $true -Limit All -Filter "Url -like '-my.sharepoint.com/personal/'"
Add-OnedriveSecondaryAdmin
Get-OneDriveSecondaryAdmins
Remove-OnedriveSecondaryAdmin
Disconnect-SPOService

if ( $ErrorLog ) { $ErrorLog | Out-File $ExportPath\AddtlOneDriveAdmins_Errors.log }
if ( $results ) { $results | Export-Csv $OutputFile -NoTypeInformation }
