# ex: https://www.alitajran.com/unable-to-install-nuget-provider-for-powershell/
# Also PS reporting modules like "AzureADPreview" cannot be found

# 1-off (?)
[Net.ServicePointManager]::SecurityProtocol = [Net.SecurityProtocolType]::Tls12

# OR, registry approach. Force .NET to use secure encryption. 32 and 64-bit

Set-ItemProperty -Path 'HKLM:\SOFTWARE\Wow6432Node\Microsoft\.NetFramework\v4.0.30319' -Name 'SchUseStrongCrypto' -Value '1' -Type DWord
Set-ItemProperty -Path 'HKLM:\SOFTWARE\Microsoft\.NetFramework\v4.0.30319' -Name 'SchUseStrongCrypto' -Value '1' -Type DWord