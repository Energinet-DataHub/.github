# Copyright 2020 Energinet DataHub A/S
#
# Licensed under the Apache License, Version 2.0 (the "License2");
# you may not use this file except in compliance with the License.
# You may obtain a copy of the License at
#
#     http://www.apache.org/licenses/LICENSE-2.0
#
# Unless required by applicable law or agreed to in writing, software
# distributed under the License is distributed on an "AS IS" BASIS,
# WITHOUT WARRANTIES OR CONDITIONS OF ANY KIND, either express or implied.
# See the License for the specific language governing permissions and
# limitations under the License.

<#
    .SYNOPSIS
    Send emails using SendGrid.

    .DESCRIPTION
    The script sends emails using SendGrid. It supports sending to one or multiple recipients.
#>
function Send-EMail {
    param (
        # The value of the GitHub repository variable.
        [Parameter(Mandatory = $true)]
        [string]
        $GitHubRepository,
        # The value of the GitHub run id variable.
        [Parameter(Mandatory = $true)]
        [string]
        $GitHubRunId,
        # A valid SendGrid API key.
        [Parameter(Mandatory = $true)]
        [string]
        $SendGridApiKey,
        # The name of the team who should receive the email. When sending to multiple recipients this name will be used for all of them.
        [Parameter(Mandatory = $true)]
        [string]
        $TeamName,
        # The email to-address. Must contain either a single email or a list of comma separated emails.
        [Parameter(Mandatory = $true)]
        [string]
        $To,
        # The email from-address.
        [Parameter(Mandatory = $true)]
        [string]
        $From,
        # The email subject. Should contain environment information when possible.
        [Parameter(Mandatory = $true)]
        [string]
        $Subject,
        # Additional content for the email body. Apart from this the email body will also always contain a link to the failed build.
        [Parameter(Mandatory = $false)]
        [string]
        $Content = ""
    )

    Write-Host "Sending email from '$GitHubRepository' for build with run id '$GitHubRunId'"

    $finalTo = Build-ToEMail -TeamName $TeamName -To $To
    $finalContent = "<a href=https://github.com/$GitHubRepository/actions/runs/$GitHubRunId target=_blank>Link to Github job run</a> $Content"

    $body = @"
    {
        "personalizations": [
            {
                "to": $finalTo
            }
        ],
        "from": {
            "email": "$From",
            "name": "DataHub Github"
        },
        "subject": "$Subject",
        "content": [
            {
                "type": "text/html",
                "value": "$finalContent"
            }
        ]
    }
"@
    Write-Host "Body: $body"

    try {
        $response = Invoke-WebRequest -Uri 'https://api.sendgrid.com/v3/mail/send' -Method Post `
            -Headers @{Authorization = "Bearer $SendgridApiKey" } `
            -ContentType 'application/json' -Body $body

        Write-Host "Response: $response"
    }
    catch {
        $errorMessage = $_.Exception.Message
        throw "Could not send email. Error: $errorMessage"
    }

    Write-Host "Sent email"
}

<#
    .SYNOPSIS
    Build the 'to' part of the JSON body for the SendGrid 'send mail' request.
#>
function Build-ToEMail {
    param (
        # The name of the team who should receive the email. When sending to multiple recipients this name will be used for all of them.
        [Parameter(Mandatory = $true)]
        [string]
        $TeamName,
        # The email to-address. Must contain either a single email or a list of comma separated emails.
        [Parameter(Mandatory = $true)]
        [string]
        $To
    )

    $emails = $To.Split(',').Trim()
    $eMailAndNameArray = $emails | ForEach-Object { [PSCustomObject]@{
            email = $PSItem
            name  = $TeamName
        } }

    $eMailAndNameArrayAsJson = ConvertTo-Json $eMailAndNameArray -AsArray

    # Minified JSON is easier to compare in tests
    $eMailAndNameArrayAsJson = ($eMailAndNameArrayAsJson
        | ConvertFrom-Json
        | ConvertTo-Json -Depth 10 -Compress)

    return ($eMailAndNameArrayAsJson)
}
