########################################
# Base Variables

# Tenant Domain
$domain = "contoso.onmicrosoft.com"

# Used for Exchange Online app-based authentication. Do not change unless a new certificate is generated on this machine and the thumbprint changes
$certThumbprint = "XXXXXXXXXXXXXXXXXXXXXXX"
$appID = "XXXXXXXXXXXXXXXXXXXXXXXXXXXXX"

# Used for MS Graph app-based authentication. Currently uses Secret, looking to change this to certificate when possible
$ClientName = "contoso"
$AzureAppID = "XXXXXXXXXXXXXXXXXXXXXXXXX"
$AzureAppSecret = "XXXXXXXXXXXXXXXXXXXXXXXXXXXXX"
$AzureTenantDomain = "contoso.com"

# Values for the email report. Change as needed
$mailTo = "it@contoso.com"
$mailFrom = "donotreply@contoso.com"
$mailSubject = "Exchange Large Mailbox Report"
$mailSMTPServer = "smtprelay.contoso.com"

$output = "C:\Scripts" # output path
$threshold = "40GB"  # what size defines a "large" mailbox

# Import the complementing CSV which will allow for conversion of license ID to friendly name
# MS Graph will pull license GUIDs, then the CSV matches GUID to Product_Display_Name to GUID for easier reporting
$licenseToFriendlyName = import-csv C:\Scripts\M365_License_to_friendlyName.csv
$excludedLicenses = @("visio","power","mobility","flow","team","project","audio") # Array used to filter out extraneous licenses from the report (licenses not relevant for this report)

#
########################################

Start-Transcript -Path "C:\Scripts\Get-EXOLargeMailboxes.log"

# Remove any old exports if they exist before proceeding
if (Test-Path $output\largeMailboxes.csv) {
  Remove-Item $output\largeMailboxes.csv
  }

Connect-ExchangeOnline -CertificateThumbprint $certThumbprint -AppId $appID -Organization $domain -ShowBanner:$false

# Retrieve output of Graph data to be used for retrieving license info
$graphOutput = C:\Scripts\Graph-Export.ps1 -ClientName $ClientName -AzureAppID $AzureAppID -AzureAppSecret $AzureAppSecret -AzureTenantDomain $AzureTenantDomain 

# Retrieve all mailbox statistics then output a list of large mailboxes as defined by $threshold
$allMailbox = Get-EXOMailbox -ResultSize Unlimited
$allMailboxStats = $allMailbox | Get-EXOMailboxStatistics
$allLargeMailbox = $allMailboxStats | Where-Object { [int64]($PSItem.TotalItemSize.Value -replace '.+\(|bytes\)') -gt "$threshold" } | Sort-Object TotalItemSize -Descending 

$results = @() # new array to be used for export of data
foreach ($m in $allLargeMailbox){
    # Walk through users and retrieve their licensed SKUs, then convert the SKU GUID to friendly names
    $UPN = (Get-Mailbox $m.DisplayName).UserPrincipalName
    $skuIDs = $graphOutput | Where-Object { $_.UserPrincipalName -like $UPN } | Select-Object -expand assignedlicenses | Select-Object -expand skuid
    $Licenses = @()
    foreach ($sku in $skuIDs) {
        $Licenses += (($licenseToFriendlyName | Where-Object { $_.guid -eq "$sku" } | Select-Object -expand Product_Display_Name -Unique  )) | Select-String -Pattern $excludedLicenses -NotMatch
    }
    $prohibitSendSize       = Get-Mailbox -Identity $m.DisplayName | select -ExpandProperty ProhibitSendQuota # mailbox max size
    $userExport = [PSCustomObject]@{
        UserPrincipalName           =   $UPN
        DisplayName                 =   $m.DisplayName   
        TotalItemSize               =   $m.TotalItemSize 
        ProhibitSendQuota           =   $prohibitSendSize
        Licenses                    =   $Licenses -join ";"
    }
    $results += $userExport
}
$results | Export-Csv $output\largeMailboxes.csv -NoTypeInformation

Disconnect-ExchangeOnline -Confirm:$false

#### Outbound email portion ####

# Retrieve attachment to check length
$attachment = Get-Item $output\largeMailboxes.csv -ErrorAction SilentlyContinue -WarningAction SilentlyContinue

# If report is 0Kb it has no content (no users with large mailbox). If the file is not empty, attach it to the email
if (Test-Path $attachment) {

    If ((Get-Item $attachment).length -gt 0kb) {
        # At least once user has a large mailbox
        $mailBody = "The users attached to this email have a mailbox larger than $threshold"
        Write-Output "sending email - Large mailboxes found"
        Send-MailMessage -To $mailTo -From $mailFrom -Subject $mailSubject -SmtpServer $mailSMTPServer -Body $mailBody -Attachments $attachment.FullName
    }
    Else {
        # No users with a large mailbox
        $mailbody = "There are no users with a mailbox larger than $threshold.`r`nThis email was sent for confirmation that the script is still running."
        Write-Output "sending email - No large mailboxes"  
        Send-MailMessage -To $mailTo -From $mailFrom -Subject $mailSubject -SmtpServer $mailSMTPServer -Body $mailBody
    }
}

###################