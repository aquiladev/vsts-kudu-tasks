[CmdletBinding(DefaultParameterSetName = 'None')]
param
(
    [String] [Parameter(Mandatory = $true)]
    $ConnectedServiceName,

    [String] [Parameter(Mandatory = $true)]
    $WebSiteName,

    [String] [Parameter(Mandatory = $false)]
    $Slot,

    [String] [Parameter(Mandatory = $true)]
    $Package,

    [String] [Parameter(Mandatory = $true)]
    $DestinationPath
)

Write-Verbose "Entering script Upload.ps1"

Write-Host "ConnectedServiceName= $ConnectedServiceName"
Write-Host "WebSiteName= $WebSiteName"
Write-Host "Slot= $Slot"
Write-Host "Package= $Package"
Write-Host "DestinationPath= $DestinationPath"

Write-Host "packageFile= Find-Files -SearchPattern $Package"
$packageFile = Find-Files -SearchPattern $Package
Write-Host "packageFile= $packageFile"