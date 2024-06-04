# Objective:
# Return the 365 usage report for EXO
# Optionally filter the output for a specific group (supports nested membership)

function Get-EXOUsageReport {

    param(
        # Client name
        [Parameter(Mandatory=$true)]
        [String]
        $ClientName,

        [Parameter(Mandatory = $true)]
        [String]
        [ValidateSet("7", "30", "90", "180")]
        $Range,

        [Parameter(Mandatory = $false)]
        [string]
        $GroupDisplayName,

        [Parameter(Mandatory = $true)]
        [String]
        $ExportPath
    )

    # Note: If user display name/UserPrincipalnames are obfuscated and need to be shown, a data privacy setting is enabled that needs to be disabled:
    # Settings>Org Settings>Services>Reports>[ ] Display concealed user, group, and site names in all reports
    # https://learn.microsoft.com/en-us/microsoft-365/admin/activity-reports/activity-reports?view=o365-worldwide
    
    # "Microsoft 365 usage reports show how people in your business are using Microsoft 365 services. Reports are available for the last 7 days, 30 days, 90 days, and 180 days. Data won't exist for all reporting periods right away. The reports become available within 48 hours."
    $ExportPath = $($ExportPath.TrimEnd("\")) # trim trailing "\"
    $filePath = "$ExportPath\$($ClientName.Replace(" ", "_"))_EmailActivity.csv"
    $output = @()
    $uri = "https://graph.microsoft.com/v1.0/reports/getEmailActivityUserDetail(period='D" + $Range + "')"
    Invoke-MgGraphRequest -Method GET -Uri  $uri -OutputFilePath $filePath                                                                                                                     
    $CSV = Import-Csv $filePath 
    $mailboxes = Get-Mailbox -ResultSize Unlimited | Select-Object UserPrincipalName, PrimarySmtpAddress

    if ($GroupDisplayName) {

        # Retrieve the group
        $filter = "DisplayName eq '" + $GroupDisplayName + "'"
        try {
            $mgGroup = Get-MgGroup -Filter $filter
            # Recursively retrieve all members (includes nested group membership
            $members = Get-MgGroupTransitiveMember -GroupId $mgGroup.Id -All

            # Array with only the display names of the users
            $membersDisplayNames = ($members.AdditionalProperties).displayName | Sort-Object

            Write-Output "[INFO] Filtering output by members of group: $GroupDisplayName"
        }
        catch {
            throw "Failure: Unable to locate MgGroup: $DisplayName"
        }
    
    }
    else {
        Write-Output "[INFO] No filter provided. Generating report for all users"
    }

    $CSV | ForEach-Object {
        $userPrincipalName = $_.'User Principal Name'
        $primarySmtpAddress = $mailboxes | Where-Object { $_.UserPrincipalName -eq $userPrincipalName } | Select-Object -ExpandProperty PrimarySmtpAddress 
        $user = [PSCustomObject]@{
            DisplayName            = $_.'Display Name'
            UserPrincipalName      = $userPrincipalName
            PrimarySmtpAddress     = $primarySmtpAddress
            LastActivityDate       = $_.'Last Activity Date'
            SendCount              = $_.'Send Count'
            ReceiveCount           = $_.'Receive Count'
            ReadCount              = $_.'Read Count'
            MeetingCreatedCount    = $_.'Meeting Created Count'
            MeetingInteractedCount = $_.'Meeting Interacted Count'
        }

        if ($GroupDisplayName) {
            $userInGroup = $membersDisplayNames -contains $user.DisplayName
            if ($userInGroup ) { 
                $output += $user
            }
        }
        else {
            $output += $user
        }
    }
    
    if ( $output ) {
        $output = $output | Sort-Object DisplayName | Export-Csv -Path $filePath
    }
    else {
        "[INFO] Output is empty, no data to export. Please try again"
    }

}