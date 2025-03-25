$currentDomain = "contoso.com"
$newDomain = "fabrikam.com"
$newAddressType = "Alias"
$ErrorActionPreference = "Stop"

# Retrieve all matching recipients
$filter = "EmailAddresses -like '*$currentDomain*'"
$recipients = Get-Recipient -Filter $filter

# Switch to set the alias type
switch ( $newAddressType ) {
    "Alias" {
        $addressPrefix = "smtp:"
    }
    "Primary" {
        $addressPrefix = "SMTP:"
    }
}

# Empty list to store results
$results = [System.Collections.Generic.List[System.Object]]::new()
# Process each recipient. Add the new address and the results to the final output
foreach ($recipient in $recipients) {
    $recipientType = $recipient.RecipientType
    # The new address will be the same as the PrimarySmtpAddress, with the exception of changing the domain
    $newAddress = $addressPrefix + ($recipient.PrimarySmtpAddress -replace "@.*", "@$newDomain")
    if ( $recipient.EmailAddresses -notcontains $newAddress) {
        switch ( $recipientType ) {
            "UserMailbox" {
                try {
                    Set-Mailbox $recipient.Identity -EmailAddresses @{add = $newAddress }
                    $status = "Success"
                    $errorMessage = ""
                } catch {
                    $status = "Failure"
                    $errorMessage = $_.Exception.Message
                }
            }
            "MailUniversalDistributionGroup" {
                try {
                    Set-DistributionGroup $recipient.Identity -EmailAddresses @{add = $newAddress }
                    $status = "Success"
                    $errorMessage = ""
                } catch {
                    $status = "Failure"
                    $errorMessage = $_.Exception.Message
                }
            }
            default {
                $status = "Skipped"
                $errorMessage = "Not currently supported by this script: $recipientType"
            }
        }
    } else {
        $status = "Skipped"
        $errorMessage = "Address already present: $newAddress"
    }
    # Add the results to final output
    $results.Add([PSCustomObject]@{
            Status         = $status
            Recipient      = "$($recipient.Identity) ($($recipient.PrimarySmtpAddress))"
            NewAddressType = $newAddressType
            NewAddress     = $newAddress
            ErrorMessage   = $errorMessage
        })
}
return $results
