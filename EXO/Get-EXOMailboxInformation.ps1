<#
.SYNOPSIS
This script creates a mailbox property report

.PARAMETER Scope
This filters the report either to all mailboxes, shared mailboxes only

.EXAMPLE
Get-EXOMailboxInformation -Scope SharedMailboxes

.NOTES
[ ] Merge $LargeMailboxesdOnly and $Threshold back into the main parameterset after finding a way to make $Threshold a requirement ONLY if $Scope="LargeMailboxesOnly"

#>

function Get-EXOMailboxInformation {

    param (
        [Parameter(Mandatory = $true, ParameterSetName = "Standard")]
        [string]
        [ValidateSet("All", "ForwardingMailboxes", "SharedMailboxes", "UserMailboxes")]
        $Scope,

        [Parameter(Mandatory = $true, ParameterSetName = "Size-based")]
        [switch]
        $LargeMailboxesOnly,

        [Parameter(Mandatory = $true, ParameterSetName = "Size-based")]
        [ValidatePattern(
            '^\d+GB$',
            ErrorMessage = "Please enter the threshold in the following format: XGB/XXGB/XXXGB."
        )]
        [String]$Threshold = "40GB"
    )

    # Empty list to store results
    $results = New-Object System.Collections.Generic.List[System.Object]
    $properties = @(
        "DisplayName",
        "PrimarySmtpAddress",
        "WhenMailboxCreated",
        "IsMailboxEnabled",
        "RecipientTypeDetails",
        "HiddenFromAddressListsEnabled",
        "ForwardingAddress",
        "ForwardingSmtpAddress",
        "RetentionPolicy",
        "RetentionHoldEnabled",
        "ArchiveStatus",
        "AutoExpandingArchiveEnabled"
    )

    # Retrieve mailboxes based on the scope
    switch ( $Scope ) {
        "All" {
            $mailboxes = Get-EXOMailbox -ResultSize Unlimited -Properties $properties
        }
        "ForwardingMailboxes" {
            $mailboxes = Get-EXOMailbox -Filter "(ForwardingAddress -ne `$null) -or (ForwardingSMTPAddress -ne `$null)" -Properties $properties
        }
        "SharedMailboxes" {
            $mailboxes = Get-EXOMailbox -Filter "RecipientTypeDetails -eq 'SharedMailbox'" -Properties $properties
        }
        "UserMailboxes" {
            $mailboxes = Get-EXOMailbox -Filter "RecipientTypeDetails -eq 'UserMailbox'" -Properties $properties
        }
    }
    if ( $LargeMailboxesOnly ) {
        $mailboxes = Get-EXOMailbox -ResultSize Unlimited -Properties $properties
    }

    # Begin processing all mailboxes
    foreach ( $mailbox in $mailboxes ) {

        # Determine additional mailbox property values
        $mailboxSize = ($mailbox | Get-EXOMailboxStatistics | Select-Object -ExpandProperty TotalItemSize)
        $hasArchive = $mailbox.ArchiveStatus -eq "Active"
        switch ( $hasArchive ) {
            True {
                $ArchiveSize = $mailbox | Get-EXOMailboxStatistics -Archive | Select-Object -ExpandProperty TotalItemSize | Select-Object -ExpandProperty Value
            }
            False {
                $ArchiveSize = "N/A"
            }
        }

        # Construct an object to output
        $mailboxOutput = [PSCustomObject]@{
            DisplayName                   = $mailbox.DisplayName
            PrimarySmtpAddress            = $mailbox.PrimarySmtpAddress
            WhenMailboxCreated            = $mailbox.WhenMailboxCreated
            IsMailboxEnabled              = $mailbox.IsMailboxEnabled
            RecipientTypeDetails          = $mailbox.RecipientTypeDetails
            HiddenFromAddressListsEnabled = $mailbox.HiddenFromAddressListsEnabled
            ForwardingAddress             = $mailbox.ForwardingAddress
            ForwardingSmtpAddress         = $mailbox.ForwardingSmtpAddress
            RetentionPolicy               = $mailbox.RetentionPolicy
            RetentionHoldEnabled          = $mailbox.RetentionHoldEnabled
            MailboxSize                   = $mailboxSize
            ArchiveStatus                 = $mailbox.ArchiveStatus
            AutoExpandingArchiveEnabled   = $mailbox.AutoExpandingArchiveEnabled
            ArchiveSize                   = $ArchiveSize
        }

        $results.Add($mailboxOutput)

    }
    
    if ( $LargeMailboxesOnly ) {
        return ($results | Where-Object { [int64]($_.MailboxSize.Value -replace '.+\(|bytes\)') -gt $Threshold })
    } return $results

}