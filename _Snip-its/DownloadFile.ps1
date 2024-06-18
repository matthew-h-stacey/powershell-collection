# Example: Public download

$Url = "https://portableapps.com/redir2/?a=FirefoxPortable&s=s&d=pa&f=FirefoxPortable_122.0_English.paf.exe"
$LocalPath = "C:\TempPath"
$FileName = "FirefoxPortable_120.0.1_English.paf.exe"
$FilePath = "$LocalPath\$FileName"
(New-Object System.Net.WebClient).DownloadFile($Url, $FilePath)

# Example: Private download with authentication

$username = "serviceadmin"
$uri = "http://localhost/reports/example.aspx"
$securePassword = ConvertTo-SecureString "XXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXX"
$outputFile = "C:\Scripts\htmlResponse.txt"

$credentials = New-Object System.Management.Automation.PSCredential($username, $securepassword)
$response = Invoke-WebRequest -Uri $Uri -Credential $credentials
$response.RawContent | Out-File $outputFile