[CmdletBinding()]
param (
    [Parameter()][string]$Site,
    [Parameter()][string]$Port
)

$Site = "sapprodproxy1.swtx.com"
$Port = "443"
$siteFull = "${siteURL}:${sitePort}"
openssl s_client -connect $siteFull -servername $Site 2> $null | openssl x509 -noout  -dates