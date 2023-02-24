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
    The script sends emails using SendGrid. The input can either be a single email
    or a list of comma separated emails.
#>

param (
    # A valid SendGrid API key.
    [Parameter(Mandatory = $true)]
    [string]
    $SendGridApiKey,
    # The name of the team who should receive the email. When sending to multiple recipients this name will be used for all of them.
    [Parameter(Mandatory = $true)]
    [string]
    $TeamName,
    # The email to-address. Should contain either a single email or a list of comma separated emails.
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

Write-Host "To: '$To'"

# #     curl -s -o /dev/null -w "HttpStatus: %{http_code}" -X POST  https://api.sendgrid.com/v3/mail/send \
# #       --header "Authorization: Bearer ${{ secrets.SENDGRID_INSTANCE_SYSTEM_NOTIFICATIONS_API_KEY }}" \
# #       --header "Content-Type: application/json" \
# #       --data '{"personalizations":[
# #         {"to":[{"email":"${{ steps.get_email.outputs.TEAM_EMAIL }}","name":"${{ inputs.TEAM_NAME }}"}]}],
# #         "from":{"email":"${{ secrets.EMAIL_SENDER }}","name":"DataHub Github"},
# #         "subject":"${{ inputs.SUBJECT }}",
# #         "content":[{"type":"text/html","value":"<a href=https://github.com/${{ github.repository }}/actions/runs/${{ github.run_id }} target=_blank>Link to Github job run</a>  ${{ inputs.BODY }}"}]}'
