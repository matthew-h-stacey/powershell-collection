<#
TO-DO:
Add comments
Add checks for rules/connectors that already exist
#>

function New-EXOBarracudaRules {

    param (
        [SkyKickParameter(
            DisplayName = "Configure Barracuda inbound connector?",
            HintText = "To be filled later"
        )]
        [boolean]
        $ConfigureInboundConnector,

        [SkyKickParameter(
            DisplayName = "Configure Barracuda outbound connector?",
            HintText = "To be filled later"
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
            DisplayName = "Outbound connector smarthost",
            HintText = "To be filled later"
        )]
        [String]
        $OutboundSmarthost,

        [SkyKickParameter(
            DisplayName = "Configure Barracuda Archiving?",
            HintText = "To be filled later"
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
            DisplayName = "Archiver tenant ID (without @domain.com)",
            HintText = "To be filled later"
        )]
        [String]
        $ArchiverTenantId,

        [SkyKickParameter(
            DisplayName = "Enable connectors and rules after creation?",
            HintText = "To be filled later"
        )]
        [boolean]
        $Enabled

    )

    if ( $ConfigureInboundConnector ) {
        # Check to see if the SLC bypass rule already exists. If it does, skip. If it doesn't, create it        
        try {
            $ruleExists = Get-Transportrule -Identity "Barracuda spam bypass" -ErrorAction Stop
        } catch {
            $ruleExists = $false
        }
        if ( $ruleExists ) {
            Write-Output "[INFO][TransportRule] SKIPPED: SCL bypass rule already present"
        } else {
            try {
                New-TransportRule -Name "Barracuda spam bypass" -SenderIpRanges 209.222.80.0/21 -SetSCL -1 -Priority 0 -Enabled $Enabled | Out-Null
                Write-Output "[INFO][TransportRule] Successfully created SCL bypass rule"
            } catch {
                Write-Output "[INFO][TransportRule] Failed to create SCL bypass rule. Error: $($_.Exception.Message)"
            }
        }
        # Check to see if the inbound connector already exists. If it does, skip. If it doesn't, create it        
        try {
            $connectorExists = Get-InboundConnector -Identity "Inbound from Barracuda" -ErrorAction Stop
        } catch {
            $connectorExists = $false
        }
        if ( $connectorExists ) {
            Write-Output "[INFO][Inbound connector] SKIPPED: Inbound connector already present"
        } else {
            try {
                New-InboundConnector -ConnectorType Partner -Name "Inbound from Barracuda" -RequireTls $true -SenderDomains * -SenderIPAddresses 209.222.80.0/24, 209.222.81.0/24, 209.222.82.0/24, 209.222.83.0/24, 209.222.84.0/24, 209.222.85.0/24, 209.222.86.0/24, 209.222.87.0/24 -RestrictDomainstoIPAddresses $true -Enabled $Enabled  | Out-Null
                Write-Output "[INFO][Inbound connector] Successfully created inbound connector"
            } catch {
                Write-Output "[INFO][Inbound connector] Failed to create inbound connector. Error: $($_.Exception.Message)"
            }
        }
    } else {
        Write-Output "[INFO][Inbound connector] SKIPPED: Option not selected"
    }

    if ( $ConfigureOutboundConnector ) {
        # Create Outbound connector to restrict Outbound email to Barracuda only
        try {
            New-OutboundConnector -Name "Outbound to Barracuda" -Comment "Send all external outbound email through Barracuda" -RecipientDomains * -SmartHosts $OutboundSmarthost -TlsSettings EncryptionOnly -UseMXRecord $false -Enabled $Enabled  | Out-Null
            Write-Output "[INFO][Outbound connector] Successfully created outbound connector"
        } catch {
            Write-Output "[INFO][Outbound connector] Failed to create outbound connector. Error: $($_.Exception.Message)"
        }
    } else {
        Write-Output "[INFO][Outbound connector] SKIPPED: Option not selected"
    }

    if ( $ConfigureArchiving ) {
        # Script pulled from Barracuda Archiver service
        $ErrorActionPreference = "Stop"

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

            if ($SetNewRemoteDomain) {
                Write-Output "[INFO][Archiver] Configuring new Barracuda remote domain."
                New-RemoteDomain -Name $RuleName -DomainName $BarracudaDomain
            } else {
                Write-Output "[INFO][Archiver] Updating configuration of current Barracuda remote domain."
            }

            Set-RemoteDomain $RemoteDomainToUpdate -AutoReplyEnabled $false
            Set-RemoteDomain $RemoteDomainToUpdate -AllowedOOFType None
            Set-RemoteDomain $RemoteDomainToUpdate -AutoForwardEnabled $true
            Set-RemoteDomain $RemoteDomainToUpdate -DeliveryReportEnabled $false
            Set-RemoteDomain $RemoteDomainToUpdate -DisplaySenderName $false
            Set-RemoteDomain $RemoteDomainToUpdate -NDREnabled $false
            Set-RemoteDomain $RemoteDomainToUpdate -TNEFEnabled $false

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
                Write-Output "[INFO][Archiver] Configuring new Barracuda outbound connector."

                New-OutboundConnector -Name $RuleName `
                    -RecipientDomains $BarracudaDomain  `
                    -Comment "This connector is used to send journaling messages to the Barracuda Cloud Archiving Service." `
                    -ConnectorType Partner `
                    -TlsSettings EncryptionOnly `
                    -Enabled $Enabled
            } else {
                Write-Output "[INFO][Archiver] Using previously configured Barracuda outbound connector."
            }

            ### Configure undeliverable journal reports address
            $Config = Get-TransportConfig
            $CurrentAddress = $Config.JournalingReportNdrTo
            if ($CurrentAddress -and $CurrentAddress -ne "<>") {
                Write-Output "[INFO][Archiver] Using previously configured undeliverable journal address."
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
    } else {
        Write-Output "[INFO][Archiver] SKIPPED: Option not selected"
    }

}