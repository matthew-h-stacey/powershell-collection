# NOTE: API requires Application vs Delegated permissions
# Create and authenticate to Graph with an app reg that has Chat.ReadWrite.All permissions
# Connect-MgGraph -CertificateThumbprint XXXXXXXXXX -ClientId XXXXXXXXXX -TenantId XXXXXXXXXX

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

function Get-GraphOutput {

    <#
    .SYNOPSIS
    This is a simple function to perform a GET request to a Graph endpoint with support for 999+ objects

    .EXAMPLE
    Get-GraphOutput -URI  https://graph.microsoft.com/v1.0/users/$UserPrincipalName/chats/getAllMessages
    #>

    param(
        # URI to retrieve output from
        [Parameter(Mandatory = $true)]
        [String]
        $URI
    )

    $method = "GET"
    $msGraphOutput = @()
    $nextLink = $null
    do {
        $uri = if ($nextLink) {
            $nextLink
        } else {
            $uri
        }
        try {
            $response = Invoke-MgGraphRequest -Uri $uri -Method $method
        } catch {
            Write-Output "[ERROR] Failed to retrieve output from MS Graph. Error:"
            $_.ErrorDetails.Message
            exit
        }
        $output = $response.Value
        $msGraphOutput += $output
        $nextLink = $response.'@odata.nextLink'
    } until (-not $nextLink)

    return $msGraphOutput
}

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

# Retrieve Graph output
$output = Get-GraphOutput -URI $uri

# Format and output the chat messages
$chats = $output | Select-Object -Property (
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