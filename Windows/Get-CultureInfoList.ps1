<#
.SYNOPSIS
Provide an array with worldwide culture objects

.DESCRIPTION
This script utilize the .NET class [System.Globalization.CultureInfo] to retrieve a list of all cultures and helpful properties that can be used for a variety of reasons.
For example, the array can be used to parse country code input based on the English name or ISO 3166 two-letter region name

.LINK
https://www.leedesmond.com/2018/02/powershell-get-list-of-two-letter-country-iso-3166-code-alpha-2-currency-language-and-more/

.EXAMPLE
Example use case - Return two-digit country code based on input from a user:

$cultureInfo = Get-CultureInfoList
$country = "Senegal"
$countryCode = ($cultureInfo | Where-Object {$_.EnglishName -like $country -or $_.TwoLetterISORegionName -like $country}).TwoLetterISORegionName | select -Unique 

#>

function Get-CultureInfoList {

    $allCultures = [System.Globalization.CultureInfo]::GetCultures([System.Globalization.CultureTypes]::SpecificCultures)
    $cultures = @()
    $allCultures | ForEach-Object {
        $dn = $_.DisplayName.Split("(|)");
        $regionInfo = New-Object System.Globalization.RegionInfo $PsItem.name;
        $cultures += [PSCustomObject]@{
            Name                   = $regionInfo.Name;
            EnglishName            = $regionInfo.EnglishName;
            TwoLetterISORegionName = $regionInfo.TwoLetterISORegionName;
            GeoId                  = $regionInfo.GeoId;
            ISOCurrencySymbol      = $regionInfo.ISOCurrencySymbol;
            CurrencySymbol         = $regionInfo.CurrencySymbol;
            LCID                   = $_.LCID;
            Lang                   = $dn[0].Trim();
            Country                = $dn[1].Trim();
        }
    }

    return $cultures
    
}