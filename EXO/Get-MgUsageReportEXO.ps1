# Objective:
# Return the 365 usage report for EXO
# Optionally filter the output for a specific group (supports nested membership)

function Get-MgUsageReportEXO {

    [SkyKickCommand(DisplayName = "Set Parameter Sections", Sections = { "Range","Filter" })]
    param(
        [SkyKickParameter(
                Section = "Range",
                DisplayName = "Past X days",
                DisplayOrder = 1
        )]
        [Parameter(Mandatory=$true)]
        [String]
        [ValidateSet("7","30","90","180")]
        $Range,

        [SkyKickParameter(
                Section = "Filter",
                DisplayName = "(Optional) Filter results by Azure AD group",
                DisplayOrder = 1,
                HintText = "Enter the display name of an Azure AD group to filter the results by."
        )]
        [Parameter(Mandatory=$false)]
        [string] $GroupDisplayName 
    )

    # Note: If user display name/UserPrincipalnames are obfuscated and need to be shown, a data privacy setting is enabled that needs to be disabled:
    # Settings>Org Settings>Services>Reports>[ ] Display concealed user, group, and site names in all reports
    # https://learn.microsoft.com/en-us/microsoft-365/admin/activity-reports/activity-reports?view=o365-worldwide
    
    # "Microsoft 365 usage reports show how people in your business are using Microsoft 365 services. Reports are available for the last 7 days, 30 days, 90 days, and 180 days. Data won't exist for all reporting periods right away. The reports become available within 48 hours."

    $ReportFooter = "Report created using SkyKick Cloud Manager"
    $ClientName = (Get-CustomerContext).CustomerName
    $FilePath = "/cloud-manager/users/System/${ClientName}_EmailActivity.csv"
    $Uri = "https://graph.microsoft.com/v1.0/reports/getEmailActivityUserDetail(period='D" + $Range + "')"
    Invoke-MgGraphRequest -Method GET -Uri  $Uri -OutputFilePath $FilePath                                                                                                                     
    $CSV = Import-Csv $FilePath 
    $ReportTitle = "$ClientName Email Activity Report (past $Range days) - as of $(($csv | Select-Object -ExpandProperty 'Report Refresh Date')[0])"
    $CSV = $CSV | Select-Object 'Display Name','User Principal Name','Last Activity Date','Send Count','Receive Count','Read Count','Meeting Created Count','Meeting Interacted Count'

    if ($GroupDisplayName) {

        $Filter = "DisplayName eq '" + $GroupDisplayName + "'"

        # Retrieve the group
        try {
            $MgGroup = Get-MgGroup -Filter $Filter
        }
        catch {
            throw "Failure: Unable to locate MgGroup: $DisplayName"
        }

        # Recursively retrieve all members (includes nested group membership
        $Members = Get-MgGroupTransitiveMember -GroupId $MgGroup.Id

        # Array with only the display names of the users
        $MembersDisplayNames = ($Members.AdditionalProperties).displayName | Sort-Object

        $Output = $CSV | where-object { $MembersDisplayNames -contains $_."Display Name" }
        
        if ( $Output ) {   
            Write-Output "[INFO] Outputting results filtered based on users who are members of: $($MgGroup.DisplayName)"     
            Out-SKSolutionReport -Content $Output -ReportTitle $ReportTitle -ReportFooter $ReportFooter -FileExportType HTML
        }
        else {
            Write-Output "[INFO] No data found for the Azure AD group provided. Please confirm that the group has licensed users and try again"
        }
    }
    else {
        if ( $CSV ) {
            Write-Output "[INFO] No group filter provided. Outputting results for all users"
            Out-SKSolutionReport -Content $CSV -ReportTitle $ReportTitle -ReportFooter $ReportFooter -FileExportType HTML
        }
        else {
            "[INFO] Output is empty. No data to export to HTML"
        }
    }

}