function Get-BarracudaDeploymentStatus {

    param (
        [Parameter(Mandatory = $true)]
        [CustomerContext[]]
        $Clients
    )

    function Get-BarracudaTransportRule {
        <#
        .SYNOPSIS
            Locate the inbound transport rule used to restrict inbound emails to Barracuda IPs.
        .DESCRIPTION
            This function searches for the transport rule that restricts inbound emails to Barracuda IPs.
            Get-TransportRule only supports filtering by description, so it is required to retrieve all rules and then filter them.
            209.222.80.0/21 is the IP range used by Barracuda Email Gateway Defense.
            Ideally, this function will only return one rule (if configured) or null.
        .OUTPUTS
            TransportRule object(s) if found, otherwise null.
        .EXAMPLE
            $transportRule = Get-BarracudaTransportRule
        #>

        $transportRules = Get-TransportRule -ResultSize Unlimited
        $transportRule = $transportRules | Where-Object { $_.ExceptIfSenderIpRanges -eq "209.222.80.0/21" -and $_.DeleteMessage -eq $true }

        switch ( @($transportRule).Count ) {
            0 {
                Write-Verbose "[INFO] No Barracuda inbound transport rule found"
                return $null
            }
            1 {
                Write-Verbose "[INFO] Barracuda inbound transport rule found"
                return $transportRule
            }
            Default {
                Write-Verbose "[WARNING] Multiple Barracuda inbound transport rules found"
                return $transportRule
            }
        }

    }

    function Get-BarracudaInboundConnector {
        <#
        .SYNOPSIS
            Locate the Barracuda connector that inbound emails flow through.
        .DESCRIPTION
            This function searches for the connector that inbound email flows through.
            Get-InboundConnector does not support filtering, so it is required to retrieve connectors rules and then filter them.
            209.222.80.0/21 is the IP range used by Barracuda Email Gateway Defense.
            Ideally, this function will only return one connector (if configured) or null.
        .OUTPUTS
            Connector object(s) if found, otherwise null.
        .EXAMPLE
            $inConnector = Get-BarracudaInboundConnector
        #>

        $inboundConnectors = Get-InboundConnector -ResultSize Unlimited
        $barracudaInConnector = $inboundConnectors | Where-Object { $_.SenderIPAddresses -like "209.222.8*" }

        switch ( @($barracudaInConnector).Count ) {
            0 {
                Write-Verbose "[INFO] No Barracuda inbound connector found"
                return $null
            }
            1 {
                Write-Verbose "[INFO] Barracuda inbound connector found"
                return $barracudaInConnector
            }
            Default {
                Write-Verbose "[WARNING] Multiple Barracuda inbound connectors found"
                return $barracudaInConnector
            }
        }

    }

    function Get-BarracudaOutboundConnector {
        <#
        .SYNOPSIS
            Locate the Barracuda connector that outbound emails flow through.
        .DESCRIPTION
            This function searches for the connector that outbound email flows through.
            Get-OutboundConnector does not support filtering, so it is required to retrieve connectors rules and then filter them.
            Ideally, this function will only return one connector (if configured) or null.
        .OUTPUTS
            Connector object(s) if found, otherwise null.
        .EXAMPLE
            $outConnector = Get-BarracudaOutboundConnector
        #>

        $outboundConnectors = Get-OutboundConnector -IncludeTestModeConnectors:$false -ResultSize Unlimited -WarningAction SilentlyContinue
        $barracudaOutConnector = $outboundConnectors | Where-Object { $_.SmartHosts -like "*.ess.barracudanetworks.com" }

        switch ( @($barracudaOutConnector).Count ) {
            0 {
                Write-Verbose "[INFO] No Barracuda outbound connector found"
                return $null
            }
            1 {
                Write-Verbose "[INFO] Barracuda outbound connector found"
                return $barracudaOutConnector
            }
            Default {
                Write-Verbose "[WARNING] Multiple Barracuda outbound connectors found"
                return $barracudaOutConnector
            }
        }

    }

    function Get-BarracudaJournalRule {
        <#
        .SYNOPSIS
            Locate the Barracuda journal rule.
        .DESCRIPTION
            This function searches for the Barracuda Archiver journal rule.
            Get-JournalRule does not support filtering, so it is required to retrieve all rules and then filter them.
            Ideally, this function will only return one rule (if configured) or null.
        .OUTPUTS
            Rule object(s) if found, otherwise null.
        .EXAMPLE
            $journalRule = Get-BarracudaJournalRule
        #>

        $journalRule = Get-JournalRule | Where-Object { $_.JournalEmailAddress -match "mas.barracudanetworks.com"  }

        switch ( @($journalRule).Count ) {
            0 {
                Write-Verbose "[INFO] No Barracuda journal rule found"
                return $null
            }
            1 {
                Write-Verbose "[INFO] Barracuda journal rule found"
                return $journalRule
            }
            Default {
                Write-Verbose "[WARNING] Multiple Barracuda journal rules found"
                return $journalRule
            }
        }

    }

    $results = [System.Collections.Generic.List[System.Object]]::new()
    $htmlReportName = "Barracuda Deployment Status"
    $htmlReportFooter = "Report created using SkyKick Cloud Manager"
    $reportParams = @{
        IncludePartnerLogo = $true
        ReportTitle        = $htmlReportName
        ReportFooter       = $htmlReportFooter
        OutTo              = "NewTab"
    }

    $Clients | ForEach-Object -Process {

        ### Set the customer context to the selected customer
        Set-CustomerContext $_
        $clientName = (Get-CustomerContext).CustomerName

        $needsAttention = $false

        ### Inbound connector(s) - connectors with email coming from Barracuda networks
        $inConnector = Get-BarracudaInboundConnector
        switch ( @($inConnector).Count ) {
            0 {
                # Missing inbound connector
                $barracudaInConnectorFound = $false
                $barracudaInConnectorEnabled = "N/A"
                $needsAttention = $true
            }
            1 {
                # One connector found
                $barracudaInConnectorFound = $true
                $barracudaInConnectorEnabled = $inConnector.Enabled -eq $true
                if ( -not $barracudaInConnectorEnabled ) {
                    $needsAttention = $true
                }
            }
            Default {
                # Multiple connectors found
                $barracudaInConnectorFound = "Multiple Barracuda connectors found"
                $barracudaInConnectorEnabled = "-"
                $needsAttention = $true
            }
        }

        ### Inbound - restrict inbound emails to Barracuda IPs
        $transportRule = Get-BarracudaTransportRule
        switch ( @($transportRule).Count ) {
            0 {
                # Missing restrict email rule
                $transportRuleFound = $false
                $needsAttention = $true
            }
            1 {
                # Rule found
                $transportRuleFound = $true
                $transportRuleEnabled = $transportRule.State -eq "Enabled"
                if ( -not $transportRuleEnabled ) {
                    $needsAttention = $true
                }
            }
            Default {
                $transportRuleFound = "Multiple Barracuda inbound transport rules found"
                $transportRuleEnabled = "-"
                $transportRuleIpRestricted = "-"
                $needsAttention = $true
            }
        }

        ### Outbound connector(s) - connectors with email going to Barracuda networks
        $outConnector = Get-BarracudaOutboundConnector
        switch ( @($outConnector).Count ) {
            0 {
                # Missing outbound connector
                $barracudaOutConnectorFound = $false
                $barracudaOutConnectorEnabled = "N/A"
                $barracudaOutConnectorRuleScoped = "N/A"
                $needsAttention = $true
            }
            1 {
                # Outbound connector found
                $barracudaOutConnectorFound = $true
                $barracudaOutConnectorEnabled = $outConnector.Enabled -eq $true
                $barracudaOutConnectorRuleScoped = $outConnector.IsTransportRuleScoped
                if ( -not $barracudaOutConnectorEnabled -or $barracudaOutConnectorRuleScoped -eq $true ) {
                    $needsAttention = $true
                }
            }
            Default {
                $barracudaInConnectorFound = "Multiple Barracuda connectors found"
                $barracudaInConnectorEnabled = "-"
                $barracudaOutConnectorRuleScoped = "-"
                $needsAttention = $true
            }
        }

        ### Archiving
        # Remote domain
        $barracudaRemoteDomain = Get-RemoteDomain | Where-Object { $_.DomainName -eq "mas.barracudanetworks.com" -and $_.IsValid -eq $true }
        # Connector
        $barracudaArchiverConnector = Get-OutboundConnector | Where-Object { $_.RecipientDomains -eq "mas.barracudanetworks.com" -and $_.IsValid -eq $true }
        # Rule
        $barracudaArchiverRule = Get-BarracudaJournalRule
        if ( -not $barracudaRemoteDomain -or -not $barracudaArchiverConnector -or -not $barracudaArchiverRule -or $barracudaArchiverRule.Enabled -eq $false ) {
            $needsAttention = $true
        }

        # Build PSCustomObject for output
        $resultOutput = [PSCustomObject]@{
            Client                    = $clientName
            InboundConnectorEnabled = if ( $barracudaInConnectorFound -eq $true ) { $barracudaInConnectorEnabled } else { "N/A" }
            OutboundConnectorEnabled = if ( $barracudaOutConnectorFound -eq $true ) { $barracudaOutConnectorEnabled } else { "N/A" }
            RestrictRuleEnabled = if ( $transportRuleFound -eq $true ) { $transportRuleEnabled } else { "N/A" }
            ArchiverRemoteDomainFound = [bool]$barracudaRemoteDomain
            ArchiverConnectorFound    = [bool]$barracudaArchiverConnector
            ArchiverJournalRuleFound  = if ( $barracudaArchiverRule ) { $true } else { $false }
            NeedsAttention            = $needsAttention
        }
        $results.Add($resultOutput)

    }

    $results | Out-SkyKickTableToHtmlReport @reportParams

}