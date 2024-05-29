# NOTE: API permissions require Application permissions (app reg) - does NOT work with delegated (account) permissions
# Create an app reg with Chat.ReadWrite.All permissions
# Connect-mggraph -CertificateThumbprint XXXXXXXXXX -ClientId XXXXXXXXXX -TenantId XXXXXXXXXX

[CmdletBinding(DefaultParameterSetName="All")]
param (
    # Parameter help description
    [Parameter(Mandatory=$true)]
    [String]
    $UserPrincipalName,

    # Parameter help description
    [Parameter(ParameterSetName = "All")]
    [Switch]
    $All,

    # Parameter help description
    [Parameter(ParameterSetName = "Range")]
    [String]
    $StartDate,

    # Parameter help description
    [Parameter(ParameterSetName = "Range")]
    [String]
    $EndDate
)

function Get-ChatParticipants {
    param (
        [String] $ChatId
    )
    $uri = "https://graph.microsoft.com/v1.0/users/$UserPrincipalName/chats/$ChatId/members"
    $response = Invoke-MgGraphRequest -Uri $uri -Method "GET"
    return $response.value | ForEach-Object { $_.displayName }
}

if ($PSCmdlet.ParameterSetName -eq "Range") {
    # Convert the dates to UTC
    $startDateUTC = (Get-Date $StartDate).ToUniversalTime().ToString("yyyy-MM-ddTHH:mm:ss.fffZ")
    $endDateUTC = (Get-Date $EndDate).ToUniversalTime().ToString("yyyy-MM-ddTHH:mm:ss.fffZ")
    Write-Host "[START] Initiating script with date range. Converted time range to UTC: $startDateUTC - $endDateUTC"
    # Construct the Uri and apply the date range filter
    $filter = "?`$filter=lastModifiedDateTime gt $StartDateUTC and lastModifiedDateTime lt $EndDateUTC"
    $uri = "https://graph.microsoft.com/v1.0/users/$UserPrincipalName/chats/getAllMessages" + $filter
} else {
    # Construct the Uri
    $uri = "https://graph.microsoft.com/v1.0/users/$UserPrincipalName/chats/getAllMessages"
}

$method = "GET"
$msGraphOutput = @()
$nextLink = $null
do {
    $uri = if ($nextLink) {
        $nextLink
    }
    else {
        $uri
    }
    try {
        $response = Invoke-MgGraphRequest -Uri $uri -Method $method
    } catch {
        Write-Output "[ERROR] Failed to retrieve output from MS Graph. Error: $($_.Exception.Message)"
        exit
    }
    $output = $response.Value
    $msGraphOutput += $output
    $nextLink = $response.'@odata.nextLink'
} until (-not $nextLink)

# Format and output the chat messages
$chats = $msGraphOutput | Select-Object -Property (
    @{Name = "Sent"; Expression = { Get-Date $_.createdDateTime -Format "MM/dd/yyyy HH:mm:ss" } },
    @{Name = "From"; Expression = { $_.from.user.displayName } },
    @{Name = "To"; Expression = {
            $participants = Get-ChatParticipants -ChatId $_.chatId
            $msgSender = $_.from.user.displayName
            ($participants | Where-Object { $_ -ne $msgSender }) -join ", "
        }
    },
    @{Name = "Content"; Expression = { $_.body.content } },
    @{Name = "ReplyContent"; Expression = { $_.attachments.content } }
)
$chats | Export-Csv C:\TempPath\TeamsChatExport_$UserPrincipalName.csv -NoTypeInformation