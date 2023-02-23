<#
    .SYNOPSIS
    Send emails using SendGrid.

    .DESCRIPTION
    The script sends emails using SendGrid. The input can either be a single email
    or a list of comma separated emails.
#>

param (
    # Should contain either a single email or a list of comma separated emails.
    [Parameter(Mandatory = $true)]
    [string]
    $EMail
)

Write-Host "Email: '$EMail'"
