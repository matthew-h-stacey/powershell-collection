function New-Output {
    <#
    .SYNOPSIS
        Create a standardized output object for logging.
    .EXAMPLE
        New-Output -ClientName "Contoso" -Status "Success" -Message "Operation completed successfully."

        Client   Status  Message
        ------   ------  -------
        Contoso Success Operation completed successfully.
    #>
    param (
        [string]
        $ClientName,

        [string]
        $Status,

        [string]
        $Message
    )
    return [PSCustomObject]@{
        Client  = $ClientName
        Status  = $Status
        Message = $Message
    }
}