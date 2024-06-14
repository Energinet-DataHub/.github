<#
.SYNOPSIS
Prepares the Az Module for use with an OIDC credential much more quickly than azure/login action
#>
param (
    $ClientId,
    $TenantId,
    $SubscriptionId
)

function Set-GhEnvVar($Name, $Value) {

}

$azBasePath = $isLinux ? '/usr/share' : 'C:\Modules'
Write-Host 'azBasePath: ', $azBasePath
$azModule = Get-ChildItem -Directory "$azBasePath/az*" -ErrorAction Stop | Select-Object -Last 1
$newPSModulePath = $azModule.FullName, $env:PSModulePath -join [io.path]::PathSeparator
$env:PSModulePath = $newPSModulePath

# #Export to additional steps in the job
"$PSModulePath=$env:PSModulePath" >> $env:GITHUB_ENV

$oidcTokenParams = @{
    Uri            = $env:ACTIONS_ID_TOKEN_REQUEST_URL
    Body           = @{
        audience = 'api://AzureADTokenExchange'
    }
    Authentication = 'Bearer'
    Token          = $env:ACTIONS_ID_TOKEN_REQUEST_TOKEN | ConvertTo-SecureString -AsPlainText
}
$token = (Invoke-RestMethod @oidcTokenParams).value

Clear-AzContext -Force #This is only necessary on self-hosted runners
$connectAzAccountParams = @{
    ServicePrincipal = $true
    ApplicationId    = $ClientId
    TenantId         = $TenantId
    Subscription     = $SubscriptionId
    FederatedToken   = $token
    Environment      = 'azurecloud'
    Scope            = 'CurrentUser' #Future steps can use this context, it will be thrown away at the end of run
    WarningAction    = 'SilentlyContinue' #Suppresses a warning about the client assertion saved in AzureRmContext.json
}
$context = Connect-AzAccount @connectAzAccountParams
if (-not $context) {
    throw 'Connect-AzAccount ran but no context was returned. This is probably a bug.'
}
Write-Host "Connected to $($context.Context.Account)"

Write-Host 'Logging in to Azure CLI...'
az login --service-principal --tenant $TenantId --username $ClientId --federated-token $token | Out-Null
#endregion Main
