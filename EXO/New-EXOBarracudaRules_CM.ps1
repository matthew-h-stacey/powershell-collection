function New-EXOBarracudaRules {

    param (
        [SkyKickParameter(
            DisplayName = "Configure Barracuda inbound connector?"
        )]
        [boolean]
        $ConfigureInboundConnector,

        [SkyKickParameter(
            DisplayName = "Configure transport rule to restrict inbound email to Barracuda?"
        )]
        [boolean]
        $ConfigureInboundRestrictTransportRule,

        [SkyKickParameter(
            DisplayName = "Configure Barracuda outbound connector?"
        )]
        [boolean]
        $ConfigureOutboundConnector,

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
        $ConfigureArchiving,

        [SkyKickConditionalVisibility({
                param( $ConfigureArchiving )
                return (
                ( $ConfigureArchiving -eq $true )
                )
            },
            IsMandatoryWhenVisible = $true
        )]
        [SkyKickParameter(
            DisplayName = "Archiver tenant ID (without @domain.com)"
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
            if ( $inboundRestrictRule.Enabled -eq $enabled ) {
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
                    Enabled                = $false
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
        # Script pulled from Barracuda Archiver service
        function Set-BCASJournaling($RuleName, $BarracudaDomain, $ArchiverTenantId, $Enabled) {
            $BarracudaAddress = "$ArchiverTenantId@$BarracudaDomain"

            ### Configure remote domain
            $RemoteDomains = Get-RemoteDomain
            $SetNewRemoteDomain = $true
            $RemoteDomainToUpdate = $RuleName
            foreach ($Domain in $RemoteDomains) {
                if ($Domain.DomainName -eq $BarracudaDomain) {
                    $SetNewRemoteDomain = $false
                    $RemoteDomainToUpdate = $Domain.Name
                    Break
                }
            }
            $task = "Create new Barracuda remote domain (Archiver)"
            try {
                New-RemoteDomain -Name $RuleName -DomainName $BarracudaDomain
                Set-RemoteDomain $RemoteDomainToUpdate -AutoReplyEnabled $false
                Set-RemoteDomain $RemoteDomainToUpdate -AllowedOOFType None
                Set-RemoteDomain $RemoteDomainToUpdate -AutoForwardEnabled $true
                Set-RemoteDomain $RemoteDomainToUpdate -DeliveryReportEnabled $false
                Set-RemoteDomain $RemoteDomainToUpdate -DisplaySenderName $false
                Set-RemoteDomain $RemoteDomainToUpdate -NDREnabled $false
                Set-RemoteDomain $RemoteDomainToUpdate -TNEFEnabled $false

                $message = if ($SetNewRemoteDomain) {
                    "Configured new Barracuda remote domain"
                } else {
                    "Updated configuration of current Barracuda remote domain"
                }
                $status = "Success"
                $message = "Configured new Barracuda remote domain"
                Add-Result -Status $status -Task $task -Message $message
            } catch {
                $status = "Failure"
                $message = "Failed to configured Barracuda remote domain. Error: $($_.Exception.Message)"
                Add-Result -Status $status -Task $task -Message $message
            }

            ### Configure outbound connector
            $OutboundConnectors = Get-OutboundConnector
            $SetNewConnector = $true
            foreach ($Connector in $OutboundConnectors) {
                if ($Connector.RecipientDomains -eq $BarracudaDomain -and $Connector.UseMXRecord -and $Connector.Enabled) {
                    $SetNewConnector = $false
                    Break
                }
            }

            if ($SetNewConnector) {
                $task = "Create outbound connector (Archiver)"
                try {
                    New-OutboundConnector -Name $RuleName `
                        -RecipientDomains $BarracudaDomain  `
                        -Comment "This connector is used to send journaling messages to the Barracuda Cloud Archiving Service." `
                        -ConnectorType Partner `
                        -TlsSettings EncryptionOnly `
                        -Enabled $Enabled

                    $status = "Success"
                    $message = "Successfully created new connector for journaling"
                    Add-Result -Status $status -Task $task -Message $message

                } catch {
                    $status = "Failure"
                    $message = "Failed to created new connector for journaling. Error: $($_.Exception.Message)"
                    Add-Result -Status $status -Task $task -Message $message
                }
            }

            ### Configure undeliverable journal reports address
            $Config = Get-TransportConfig
            $CurrentAddress = $Config.JournalingReportNdrTo
            if ($CurrentAddress -and $CurrentAddress -ne "<>") {
                #Write-Output "[INFO][Archiver] Using previously configured undeliverable journal address."
            } else {
                ### Create a mailbox and set it as JournalingReportNdrTo
                $DefaultAcceptedDomain = Get-AcceptedDomain | Where-Object { $_.Default -eq $true }
                $NDRAlias = "BarracudaNDR"
                $NDREmail = "$NDRAlias@$($DefaultAcceptedDomain.DomainName)"

                $ExistingNDRMailbox = Get-Mailbox -Filter "EmailAddresses -eq '$NDREmail'"
                if (-not $ExistingNDRMailbox) {
                    New-Mailbox -Shared -Name "Barracuda NDR" -Alias $NDRAlias -PrimarySmtpAddress $NDREmail
                    Set-TransportConfig -JournalingReportNdrTo $NDREmail
                    Write-Output "[INFO][Archiver] Created mailbox '$NDREmail' and set as JournalingReportNdrTo"
                } else {
                    Set-TransportConfig -JournalingReportNdrTo $NDREmail
                    Write-Output "[INFO][Archiver] Set mailbox '$NDREmail' as JournalingReportNdrTo"
                }
            }

            ### Set up journal rule
            $JournalRules = Get-JournalRule
            $SetNewRule = $true
            foreach ($Rule in $JournalRules) {
                if ($Rule.JournalEmailAddress -eq $BarracudaAddress -and $Rule.Enabled) {
                    $SetNewRule = $false
                    Break
                }
            }

            if ($SetNewRule) {
                Write-Output "[INFO][Archiver] Configuring new Barracuda journal rule."
                New-JournalRule -Name $RuleName `
                    -Scope Global `
                    -JournalEmailAddress $BarracudaAddress `
                    -Enabled $Enabled
            } else {
                Write-Output "[INFO][Archiver] Using previously configured Barracuda journal rule."
            }
        }

        Try {
            Set-BCASJournaling -BarracudaDomain $BarracudaDomain -RuleName "Barracuda Cloud Archiving Service" -TenantId $ArchiverTenantId -Enabled $Enabled
        } Catch {
            Write-Output "Error caught in Set-BCASJournaling: $($_.Exception.Message)"
        }
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