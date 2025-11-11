function Write-OutputWithTimestamp {
    <#
.SYNOPSIS
    Writes a message to output with a timestamp and log level.
.DESCRIPTION
    This function formats a message with the current timestamp and a specified log level (INFO, WARNING, ERROR).
.PARAMETER Message
    The message to be logged.
.PARAMETER Level
    The log level of the message. Valid values are "INFO", "WARNING", and "ERROR". Default is "INFO".
.EXAMPLE
    Write-OutputWithTimestamp -Message "Successfully updated object $($obj.DisplayName)." -Level "INFO"
.EXAMPLE
    Write-OutputWithTimestamp -Message "Update failed. Error: $($_.Exception.Message)" -Level "ERROR"
#>

    param (
        [String]
        $Message,

        [String]
        [ValidateSet("INFO", "WARNING", "ERROR")]
        $Level = "INFO"
    )
    $timeStamp = Get-Date -Format "yyyy-MM-ddTHH:mm:ssK"
    Write-Output "$timeStamp [$level] $message"
}