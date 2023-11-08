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

if ($PSCmdlet.ParameterSetName -eq "Range") {
    # Convert the dates to UTC
    $StartDateUTC = (Get-Date $StartDate).ToUniversalTime().ToString("yyyy-MM-ddTHH:mm:ss.fffZ")
    $EndDateUTC = (Get-Date $EndDate).ToUniversalTime().ToString("yyyy-MM-ddTHH:mm:ss.fffZ")
    Write-Host "[START] Initiating script with date range. Converted time range to UTC: $StartDateUTC - $EndDateUTC"
    # Construct the Uri and apply the date range filter
    $Filter = "?`$filter=lastModifiedDateTime gt $StartDateUTC and lastModifiedDateTime lt $EndDateUTC"
    $Uri = "https://graph.microsoft.com/v1.0/users/$UserPrincipalName/chats/getAllMessages" + $Filter
} else {
    # Construct the Uri
    $Uri = "https://graph.microsoft.com/v1.0/users/$UserPrincipalName/chats/getAllMessages"
}

$Method = "GET"
$MSGraphOutput = @()
$NextLink = $null
do {
    $Uri = if ($NextLink) {
        $NextLink
    }
    else {
        $Uri
    }
    $Response = Invoke-MgGraphRequest -Uri $Uri -Method $Method
    $Output = $Response.Value
    $MSGraphOutput += $Output
    $NextLink = $Response.'@odata.nextLink'
} until (-not $NextLink)

# Format and output the chat messages
$Chats = $MSGraphOutput |  Select-Object  @{Name = "Sent"; Expression = { Get-Date $_.createdDateTime -Format "MM/dd/yyyy HH:mm:ss " } }, @{Name = "From"; Expression = { $_.from.user.displayName } }, @{Name = "Content"; Expression = { $_.body.content } }, @{Name = "ReplyContent"; Expression = { $_.attachments.content } }#| Export-Csv "$PSScriptRoot\ExportedChats.csv" -Append
$chats | export-csv C:\TempPath\test.csv -NoTypeInformation