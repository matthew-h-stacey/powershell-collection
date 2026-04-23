function New-EXOBarracudaDeployment {

    param (
        [SkyKickParameter(
            DisplayName = "Configure Barracuda SCL bypass rule?"
        )]
        [boolean]
        $ConfigureSclBypassRule = $false,

        [SkyKickParameter(
            DisplayName = "Configure Barracuda inbound connector?"
        )]
        [boolean]
        $ConfigureInboundConnector = $false,

        [SkyKickParameter(
            DisplayName = "Configure transport rule to restrict inbound email to Barracuda?"
        )]
        [boolean]
        $ConfigureInboundRestrictTransportRule = $false,

        [SkyKickParameter(
            DisplayName = "Configure Barracuda outbound connector?"
        )]
        [boolean]
        $ConfigureOutboundConnector = $false,

        [SkyKickConditionalVisibility({
                param( $ConfigureOutboundConnector )
                return (
                    ( $ConfigureOutboundConnector -eq $true )
                )
            },
            IsMandatoryWhenVisible = $true
        )]
        [SkyKickParameter(
            DisplayName = "Outbound connector smarthost"
        )]
        [String]
        $OutboundSmarthost,

        [SkyKickParameter(
            DisplayName = "Configure Barracuda Archiving?"
        )]
        [boolean]
        $ConfigureArchiving = $false,

        [SkyKickConditionalVisibility({
                param( $ConfigureArchiving )
                return (
                    ( $ConfigureArchiving -eq $true )
                )
            },
            IsMandatoryWhenVisible = $true
        )]
        [SkyKickParameter(
            DisplayName = "Journaling tenant ID (bma_****** without @mas.barracudanetworks.com)"
        )]
        [String]
        $ArchiverTenantId,

        [SkyKickParameter(
            DisplayName = "Set rules and connectors to enabled/disabled creation?"
        )]
        [string]
        [ValidateSet("Enabled", "Disabled")]
        $EnabledAfterCreation
    )

    function Add-Result {
        param (
            [string]$Status,
            [string]$Task,
            [string]$Message
        )
        $script:results.Add([PSCustomObject]@{
                Status  = $Status
                Task    = $Task
                Message = $Message
            })
    }

    function New-EXOSclRuleBarracudaBypass {
        # Check to see if the inbound connector already exists. If it does, skip. If it doesn't, create it
        $sclRule = Get-TransportRule | Where-Object { $_.SenderIpRanges -eq "209.222.80.0/21" -and $_.SetSCL -eq -1 }
        if ( $sclRule.Count -eq 1 ) {
            # found rule
            if ( $sclRule.State -eq $EnabledAfterCreation ) {
                # state matches provided parameter
                $status = "Skipped"
                $message = "Scl bypass rule already present and state set to: $EnabledAfterCreation"
                Add-Result -Status $status -Task $task -Message $message
            } else {
                # state does not match provided parameter, update it
                switch ( $EnabledAfterCreation ) {
                    "Enabled" {
                        try {
                            Enable-TransportRule -Identity $sclRule.Identity
                            $status = "Success"
                            $message = "Updated bypass SCL rule state to: $EnabledAfterCreation"
                        } catch {
                            $status = "Failure"
                            $message = "Failed to update bypass SCL rule state to: $EnabledAfterCreation. Error: $($_.Exception.Message)"
                        }
                    }
                    "Disabled" {
                        try {
                            Disable-TransportRule -Identity $sclRule.Identity
                            $status = "Success"
                            $message = "Updated bypass SCL rule state to: $EnabledAfterCreation"
                        } catch {
                            $status = "Failure"
                            $message = "Failed to update bypass SCL rule state to: $EnabledAfterCreation. Error: $($_.Exception.Message)"
                        }
                    }
                }
                Add-Result -Status $status -Task $task -Message $message
            }
        } else {
            # no rule found, create it
            try {
                $params = @{
                    Name           = "Barracuda spam bypass"
                    SenderIpRanges = "209.222.80.0/21"
                    SetSCL         = -1
                    Enabled        = $enabled
                    Priority       = 0
                }
                New-TransportRule @params | Out-Null
                $status = "Success"
                $message = "Successfully created SCL bypass rule"
            } catch {
                $status = "Failure"
                $message = "Failed to create inbound connector. Error: $($_.Exception.Message)"
            }
            Add-Result -Status $status -Task $task -Message $message
        }
    }

    function New-EXOInboundConnectorBarracuda {
        # Check to see if the inbound connector already exists. If it does, skip. If it doesn't, create it
        $inConnector = Get-InboundConnector | Where-Object { $_.Name -like "Inbound from Barracuda" }
        if ( $inConnector.Count -eq 1 ) {
            # found connector
            if ( $inConnector.Enabled -eq $enabled ) {
                # state matches provided parameter
                $status = "Skipped"
                $message = "Inbound connector is already present and state set to: $EnabledAfterCreation"
                Add-Result -Status $status -Task $task -Message $message
            } else {
                # state does not match provided parameter, update it
                try {
                    Set-InboundConnector -Identity $inConnector.Identity -Enabled $enabled
                    $status = "Success"
                    $message = "Updated inbound connector state to: $EnabledAfterCreation"
                    Add-Result -Status $status -Task $task -Message $message
                } catch {
                    $status = "Failure"
                    $message = "Failed to update inbound connector state to: $enabled. Error: $($_.Exception.Message)"
                    Add-Result -Status $status -Task $task -Message $message
                }
            }
        } else {
            # no connector found
            try {
                $params = @{
                    ConnectorType     = "Partner"
                    Name              = "Inbound from Barracuda"
                    Enabled           = $Enabled
                    RequireTls        = $true
                    SenderDomains     = "*"
                    SenderIPAddresses = @("209.222.80.0/24", "209.222.81.0/24", "209.222.82.0/24", "209.222.83.0/24", "209.222.84.0/24", "209.222.85.0/24", "209.222.86.0/24", "209.222.87.0/24")
                    EFSkipLastIP      = $true
                }
                New-InboundConnector @params | Out-Null
                $status = "Success"
                $message = "Successfully created Barracuda inbound connector"
                Add-Result -Status $status -Task $task -Message $message
            } catch {
                $status = "Failure"
                $message = "Failed to create inbound connector. Error: $($_.Exception.Message)"
                Add-Result -Status $status -Task $task -Message $message
            }
        }
    }

    function New-EXOOutboundConnectorBarracuda {
        # Check to see if the outbound connector already exists. If it does, skip. If it doesn't, create it
        $outConnector = Get-OutboundConnector | Where-Object { $_.Name -like "Outbound to Barracuda" }
        if ( $outConnector.Count -eq 1 ) {
            # found connector
            if ( $outConnector.Enabled -eq $enabled ) {
                # state matches provided parameter
                $status = "Skipped"
                $message = "Outbound connector is already present and state set to: $EnabledAfterCreation"
                Add-Result -Status $status -Task $task -Message $message
            } else {
                # state does not match provided parameter, update it
                try {
                    Set-OutboundConnector -Identity $outConnector.Identity -Enabled $enabled
                    $status = "Success"
                    $message = "Updated outbound connector state to: $EnabledAfterCreation"
                    Add-Result -Status $status -Task $task -Message $message
                } catch {
                    $status = "Failure"
                    $message = "Failed to update outbound connector state to: $enabled. Error: $($_.Exception.Message)"
                    Add-Result -Status $status -Task $task -Message $message
                }
            }
        } else {
            # no connector found
            try {
                $params = @{
                    Name             = "Outbound to Barracuda"
                    Comment          = "Send all external outbound email through Barracuda"
                    RecipientDomains = "*"
                    SmartHosts       = $OutboundSmarthost
                    TlsSettings      = "EncryptionOnly"
                    UseMXRecord      = $false
                    Enabled          = $Enabled
                }
                New-OutboundConnector @params | Out-Null
                $status = "Success"
                $message = "Successfully created outbound connector"
                Add-Result -Status $status -Task $task -Message $message
            } catch {
                $status = "Failure"
                $message = "Failed to create outbound connector. Error: $($_.Exception.Message)"
                Add-Result -Status $status -Task $task -Message $message
            }
        }

    }

    function New-EXOTransportRuleRestrictInbound {
        # Check to see if the email restrict rule already exists. If it does, skip. If it doesn't, create it
        $inboundRestrictRule = Get-TransportRule | Where-Object { $_.Name -like "Restrict inbound email to Barracuda Email Gateway Defense" }
        if ( $inboundRestrictRule.Count -eq 1) {
            # found rule
            if ( $inboundRestrictRule.State -eq $EnabledAfterCreation ) {
                $status = "Skipped"
                $message = "Inbound email restriction rule already present and state set to: $EnabledAfterCreation"
                Add-Result -Status $status -Task $task -Message $message
            } else {
                # state does not match provided parameter, update it
                switch ( $enabled ) {
                    $true {
                        try {
                            Enable-TransportRule -Identity $inboundRestrictRule.Identity
                            $status = "Success"
                            $message = "Updated inbound email restriction rule state to: $EnabledAfterCreation"
                        } catch {
                            $status = "Failure"
                            $message = "Failed to update inbound email restriction rule state to: $enabled. Error: $($_.Exception.Message)"
                        }
                    }
                    $false {
                        try {
                            Disable-TransportRule -Identity $inboundRestrictRule.Identity
                            $status = "Success"
                            $message = "Updated inbound email restriction rule state to: $EnabledAfterCreation"
                        } catch {
                            $status = "Failure"
                            $message = "Failed to update inbound email restriction rule state to: $enabled. Error: $($_.Exception.Message)"
                        }
                    }
                }
                Add-Result -Status $status -Task $task -Message $message
            }
        } else {
            try {
                $params = @{
                    Name                   = "Restrict inbound email to Barracuda Email Gateway Defense"
                    Enabled                = $enabled
                    Priority               = 0
                    FromScope              = "NotInOrganization"
                    SentToScope            = "InOrganization"
                    ExceptIfSenderIpRanges = "209.222.80.0/21"
                    DeleteMessage          = $true
                    StopRuleProcessing     = $false
                }
                New-TransportRule @params | Out-Null
                $status = "Success"
                $message = "Successfully created inbound email restriction rule"
                Add-Result -Status $status -Task $task -Message $message
            } catch {
                $status = "Failure"
                $message = "Failed to create inbound email restriction. Error: $($_.Exception.Message)"
                Add-Result -Status $status -Task $task -Message $message
            }
        }

    }

    function New-EXOJournalingConfigurationBarracuda {

        $barracudaDomain = "mas.barracudanetworks.com"
        $ruleName = "Barracuda Cloud Archiving Service"

        ### REMOTE DOMAIN
        # Create a new remote domain for the Barracuda Archiver if it doesn't already exist
        $task = "Create new Barracuda remote domain"
        $archiverRemoteDomain = Get-RemoteDomain | Where-Object { $_.DomainName -eq "mas.barracudanetworks.com" }
        if (-not $archiverRemoteDomain) {
            try {
                New-RemoteDomain -Name $ruleName -DomainName $barracudaDomain
                Set-RemoteDomain -Name $ruleName -AutoReplyEnabled $false
                Set-RemoteDomain -Name $ruleName -AllowedOOFType None
                Set-RemoteDomain -Name $ruleName -AutoForwardEnabled $true
                Set-RemoteDomain -Name $ruleName -DeliveryReportEnabled $false
                Set-RemoteDomain -Name $ruleName -DisplaySenderName $false
                Set-RemoteDomain -Name $ruleName -NDREnabled $false
                Set-RemoteDomain -Name $ruleName -TNEFEnabled $false
                $status = "Success"
                $message = "Created remote domain for Barracuda Archiver"
            } catch {
                $status = "Failure"
                $message = "Failed to create remote domain for Barracuda Archiver: $($_.Exception.Message)"
            }
        } else {
            $status = "Skipped"
            $message = "Remote domain for Barracuda Archiver already exists"
        }
        Add-Result -Status $status -Task $task -Message $message

        ### OUTBOUND CONNECTOR
        # Create outbound connector for Barracuda Archiver if it doesn't already exist
        # Otherwise, update the enabled status if necessary
        $task = "Create outbound connector for Barracuda Archiver"
        $barracudaOutConnector = Get-OutboundConnector | Where-Object { $_.RecipientDomains -eq $barracudaDomain -and $_.UseMXRecord -eq $true }
        if ( $barracudaOutConnector ) {
            if ( $barracudaOutConnector.Enabled -ne $enabled) {
                try {
                    Set-OutboundConnector -Identity $barracudaOutConnector.Identity -Enabled $enabled
                    $status = "Success"
                    $message = "Updated outbound connector for Barracuda Archiver to enabled = $enabled"
                } catch {
                    $status = "Failure"
                    $message = "Failed to update outbound connector for Barracuda Archiver: $($_.Exception.Message)"
                }
            } else {
                $status = "Skipped"
                $message = "Outbound connector for Barracuda Archiver already exists and enabled status is correct"
            }
        } else {
            try {
                $params = @{
                    Name             = $RuleName
                    RecipientDomains = $BarracudaDomain
                    Comment          = "This connector is used to send journaling messages to the Barracuda Cloud Archiving Service."
                    ConnectorType    = Partner
                    TlsSettings      = EncryptionOnly
                    Enabled          = $true
                }
                New-OutboundConnector @params
                $status = "Success"
                $message = "Created outbound connector for Barracuda Archiver"
            } catch {
                $status = "Failure"
                $message = "Failed to create outbound connector for Barracuda Archiver: $($_.Exception.Message)"
            }
        }
        Add-Result -Status $status -Task $task -Message $message

        ### NDR JOURNAL REPORTS ADDRESS
        # Check if an NDR mailbox exists for Barracuda Archiver journaling. If not, create it
        # Set the JournalingReportNdrTo address to the Barracuda NDR mailbox
        $task = "Create NDR mailbox for Barracuda Archiver journaling and set JournalingReportNdrTo address"
        $defaultAcceptedDomain = Get-AcceptedDomain | Where-Object { $_.Default -eq $true }
        $barracudaNdrAlias = "BarracudaNDR"
        $barracudaNdrMail = "$barracudaNdrAlias@$($defaultAcceptedDomain.DomainName)"
        $transportConfig = Get-TransportConfig
        $journalNdrAddress = $transportConfig.JournalingReportNdrTo
        $journalNdrAddressMatches = $journalNdrAddress -eq $barracudaNdrMail
        if ( -not $journalNdrAddressMatches ) {
            # Check to see if the Barracuda NDR mailbox already exists before trying to create it
            $barracudaNdrMailbox = Get-Mailbox -Filter "EmailAddresses -eq '$barracudaNdrMail'"
            if (-not $barracudaNdrMailbox) {
                try {
                    New-Mailbox -Shared -Name "Barracuda NDR" -Alias $barracudaNdrAlias -PrimarySmtpAddress $barracudaNdrMail
                    $status = "Success"
                    $message = "Created Barracuda NDR mailbox for journaling reports"
                    add-result -Status $status -Task $task -Message $message
                } catch {
                    $status = "Failure"
                    $message = "Failed to create Barracuda NDR mailbox: $($_.Exception.Message)"
                    Add-Result -Status $status -Task $task -Message $message
                    exit 1
                }
                try {
                    Set-TransportConfig -JournalingReportNdrTo $barracudaNdrMail
                    $status = "Success"
                    $message = "Set JournalingReportNdrTo address to Barracuda NDR mailbox"
                    Add-Result -Status $status -Task $task -Message $message
                } catch {
                    $status = "Failure"
                    $message = "Failed to set JournalingReportNdrTo address to Barracuda NDR mailbox: $($_.Exception.Message)"
                    Add-Result -Status $status -Task $task -Message $message
                    exit 1
                }
            }
        }

        ### JOURNALING RULE
        # Create a new journaling rule for the Barracuda Archiver if it doesn't already exist
        $task = "Create journaling rule for Barracuda Archiver"
        $journalRuleAddress = "$ArchiverTenantId@$barracudaDomain"
        $journalingRules = Get-JournalRule
        $barracudaJournalRule = $journalingRules | Where-Object { $_.JournalEmailAddress -eq $journalRuleAddress }
        if ( $barracudaJournalRule ) {
            # Journaling rule for Barracuda Archiver already exists
            # Set enablement status of journaling rule
            if ( $enabled -and $barracudaJournalRule.Enabled -eq $false) {
                Enable-JournalRule -Identity $barracudaJournalRule.Identity -Confirm:$false
                $status = "Success"
                $message = "Enabled journaling rule for Barracuda Archiver"
            } elseif ( -not $enabled -and $barracudaJournalRule.Enabled -eq $true) {
                $status = "Success"
                $message = "Disabled journaling rule for Barracuda Archiver"
                Disable-JournalRule -Identity $barracudaJournalRule.Identity -Confirm:$false
            }
        } else {
            # Journaling rule for Barracuda Archiver does not exist
            try {
                $params = @{
                    Name                = $ruleName
                    Scope               = "Global"
                    JournalEmailAddress = $journalRuleAddress
                    Enabled             = $enabled
                }
                New-JournalRule @params
                $status = "Success"
                $message = "Created journaling rule for Barracuda Archiver with enabled = $enabled"
            } catch {
                $status = "Failure"
                $message = "Failed to create journaling rule for Barracuda Archiver: $($_.Exception.Message)"
            }
        }
        Add-Result -Status $status -Task $task -Message $message
    }

    ### INITIAL VARIABLES
    $ErrorActionPreference = "Stop"
    ## Report variables
    $customerContext = Get-CustomerContext
    $clientName = $customerContext.CustomerName
    $reportTitle = "Barracuda EXO Configuration Report - $($clientName)"
    $reportFooter = "Report created using SkyKick Cloud Manager"
    ## Empty list to store results
    $script:results = [System.Collections.Generic.List[System.Object]]::new()
    ## $enabled is a boolean used to set/update the state of the rules, while $EnabledAfterCreation is used in output
    $script:enabled = $EnabledAfterCreation -eq "Enabled"

    ### EXECUTION
    ## SCL bypass rule
    $task = "Create/update bypass SCL rule"
    if ( $ConfigureSclBypassRule ) {
        New-EXOSclRuleBarracudaBypass
    } else {
        $status = "Skipped"
        $message = "Option not selected"
        Add-Result -Status $status -Task $task -Message $message
    }

    ## Inbound connector
    $task = "Create/update inbound connector"
    if ( $ConfigureInboundConnector ) {
        New-EXOInboundConnectorBarracuda
    } else {
        $status = "Skipped"
        $message = "Option not selected"
        Add-Result -Status $status -Task $task -Message $message
    }

    ## Outbound connector
    $task = "Create/update outbound connector"
    if ( $ConfigureOutboundConnector ) {
        New-EXOOutboundConnectorBarracuda
    } else {
        $status = "Skipped"
        $message = "Option not selected"
        Add-Result -Status $status -Task $task -Message $message
    }

    ## Transport rule for restricting inbound email
    $task = "Create/update inbound email restriction transport rule"
    if ( $ConfigureInboundRestrictTransportRule ) {
        New-EXOTransportRuleRestrictInbound
    } else {
        $status = "Skipped"
        $message = "Option not selected"
        Add-Result -Status $status -Task $task -Message $message
    }

    ## Archiving
    $task = "Configure archiving"
    if ( $ConfigureArchiving ) {
        New-EXOJournalingConfigurationBarracuda
    } else {
        $status = "Skipped"
        $message = "Option not selected"
        Add-Result -Status $status -Task $task -Message $message

    }

    ### OUTPUT
    if ( $results ) {
        Out-SKSolutionReport -Content $results -ReportTitle $reportTitle -ReportFooter $reportFooter -SeparateReportFileForEachCustomer
    }

}