<#
.SYNOPSIS

    This script sets workgroup name on PC's. Designed to be deployed through Intune -> Scripts. Change the Changme to an identifiable name for client.

    Max characters for the name is 15 characters.

.NOTES

    Author: CJ Tarbox
    Date:   3/23/23

.TAGS
    #intunesetup

#>

Add-Computer -WorkGroupName "CLIENT-AZUREAD"