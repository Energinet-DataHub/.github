<#
.SYNOPSIS
Prepares the Az Module for use with an OIDC credential much more quickly than azure/login action
#>
param (
    $applicationId = $env:AZURE_CLIENT_ID,
    $tenantId = $env:AZURE_TENANT_ID,
    $subscription = $env:AZURE_SUBSCRIPTION_ID,
    $resourceGroup = $env:AZURE_RESOURCEGROUP
)

# The default Github color for verbose is very orangeish which implies warning
$psstyle.Formatting.Verbose = $psstyle.Foreground.BrightCyan
$ErrorActionPreference = 'stop'

function Get-GitHubOIDCToken {
    $oidcTokenParams = @{
        Uri            = $env:ACTIONS_ID_TOKEN_REQUEST_URL
        Body           = @{
            audience = 'api://AzureADTokenExchange'
        }
        Authentication = 'Bearer'
        Token          = $env:ACTIONS_ID_TOKEN_REQUEST_TOKEN | ConvertTo-SecureString -AsPlainText
    }
  (Invoke-RestMethod @oidcTokenParams).value
}

function Set-GhEnvVar($Name, $Value) { "$Name=$Value" >> $env:GITHUB_ENV }

function Add-AzModuleToPath {
    if ($isMacOS) { throw 'Not supported on MacOS' }
    $azBasePath = $isLinux ? '/usr/share' : 'C:\Modules'
    $azModule = Get-ChildItem -Directory "$azBasePath/az*" -ErrorAction Stop | Select-Object -Last 1
    $newPSModulePath = $azModule.FullName, $env:PSModulePath -join [io.path]::PathSeparator
    $env:PSModulePath = $newPSModulePath
}


#region Main
$token = Get-GitHubOIDCToken
Add-AzModuleToPath
#Export to additional steps in the job
Set-GhEnvVar 'PSModulePath' $env:PSModulePath

Clear-AzContext -Force #This is only necessary on self-hosted runners
$connectAzAccountParams = @{
    ServicePrincipal = $true
    ApplicationId    = $applicationId
    TenantId         = $tenantId
    Subscription     = $subscription
    FederatedToken   = $token
    Environment      = 'azurecloud'
    Scope            = 'CurrentUser' #Future steps can use this context, it will be thrown away at the end of run
    WarningAction    = 'SilentlyContinue' #Suppresses a warning about the client assertion saved in AzureRmContext.json
}
$context = Connect-AzAccount @connectAzAccountParams
if (-not $context) { throw 'Connect-AzAccount ran but no context was returned. This is probably a bug.' }
"Connected to $($context.Context.Account)"
#endregion Main
