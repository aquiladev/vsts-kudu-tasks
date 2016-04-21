[CmdletBinding(DefaultParameterSetName = 'None')]
param
(
	[String] [Parameter(Mandatory = $true)]
	$ConnectedServiceName,

	[String] [Parameter(Mandatory = $true)]
	$WebsiteName,

	[String] [Parameter(Mandatory = $false)]
	$WebsiteLocation,

	[String] [Parameter(Mandatory = $false)]
	$Slot,

	[String] [Parameter(Mandatory = $true)]
	$Package,

	[String] [Parameter(Mandatory = $true)]
	$DestinationPath,

	[String] [Parameter(Mandatory = $false)]
	$StopWebsite
)

Function Get-KuduWebsiteName {
	param(
		[String] [Parameter(Mandatory = $true)] $Name,
		[String] $Slot
	)

	if([string]::IsNullOrWhiteSpace($Slot)) {
		return $Name
	}
	return "$Name-$Slot"
}

Function JoinParts {
	param (
		[String[]] $Parts,
		[String] $Separator = '/'
	)

	$search = '(?<!:)' + [regex]::Escape($Separator) + '+' #Replace multiples except in front of a colon for URLs.
	$replace = $Separator
	($Parts | ? {$_ -and $_.Trim().Length}) -join $Separator -replace $search, $replace
}

function Get-SingleFile($files, $pattern)
{
	if ($files -is [system.array])
	{
		throw "Found more than one file to deploy. There can be only one."
	}
	else
	{
		if (!$files)
		{
			throw "No files were found to deploy."
		}
		return $files
	}
}

[bool]$StopWebsite = [System.Convert]::ToBoolean($StopWebsite)

Write-Verbose "Entering script Upload.ps1"

Write-Host "ConnectedServiceName= $ConnectedServiceName"
Write-Host "WebSiteName= $WebsiteName"
Write-Host "Slot= $Slot"
Write-Host "Package= $Package"
Write-Host "DestinationPath= $DestinationPath"
Write-Host "StopWebsite= $StopWebsite"

Write-Host "PackageFile= Find-Files -SearchPattern $Package"
$packageFile = Find-Files -SearchPattern $Package
Write-Host "PackageFile= $packageFile"

$packageFile = Get-SingleFile $packageFile $Package

$extraParameters = @{ }
if ($Slot) { $extraParameters['Slot'] = $Slot }

$azureWebSiteError = $null

Write-Host "Get-AzureWebSite -Name $WebsiteName -ErrorAction SilentlyContinue -ErrorVariable azureWebSiteError $(if ($Slot) { "-Slot $Slot" })"  
$website = Get-AzureWebSite -Name $WebsiteName -ErrorAction SilentlyContinue -ErrorVariable azureWebSiteError @extraParameters

if($azureWebSiteError) {
	$azureWebSiteError | ForEach-Object { Write-Warning $_.Exception.ToString() }
}

if($website) {
	$timeout = 600

	$username = $website.PublishingUsername
	$password = $website.PublishingPassword
	$base64AuthInfo = [Convert]::ToBase64String([Text.Encoding]::ASCII.GetBytes(("{0}:{1}" -f $username, $password)))

	$kuduWebsiteName = Get-KuduWebsiteName -Name $WebsiteName -Slot $Slot
	$baseUrl = [string]::Format("https://{0}.scm.azurewebsites.net", $kuduWebsiteName)
	$apiUrl = JoinParts ($baseUrl, "api/zip", $DestinationPath) '/'

	Write-Host "KuduApiUrl= $apiUrl"
	
	if($StopWebsite) {
		$stopAzureWebSiteError = $null
		Stop-AzureWebsite -Name $WebsiteName -ErrorAction SilentlyContinue -ErrorVariable stopAzureWebSiteError @extraParameters
		
		if($stopAzureWebSiteError) {
			$stopAzureWebSiteError | ForEach-Object { Write-Warning $_.Exception.ToString() }
		}

		Write-Host "Stopped website $WebsiteName $(if ($Slot) { "-Slot $Slot" })"
	}

	try {
		Invoke-RestMethod -Uri $apiUrl -Headers @{Authorization=("Basic {0}" -f $base64AuthInfo)} -Method PUT -InFile $packageFile -ContentType "multipart/form-data" -TimeoutSec $timeout
	} catch {
		Write-Verbose $_.Exception.ToString()
		$response = $_.Exception.Response
		$responseStream =  $response.GetResponseStream()
		$streamReader = New-Object System.IO.StreamReader($responseStream)
		$streamReader.BaseStream.Position = 0
		$streamReader.DiscardBufferedData()
		$responseBody = $streamReader.ReadToEnd()
		$streamReader.Close()
		Write-Error $responseBody
	} finally {
		if($StopWebsite) {
			$startAzureWebSiteError = $null
			Start-AzureWebsite -Name $WebsiteName -ErrorAction SilentlyContinue -ErrorVariable startAzureWebSiteError @extraParameters

			if($startAzureWebSiteError) {
				$startAzureWebSiteError | ForEach-Object { Write-Warning $_.Exception.ToString() }
			}

			Write-Host "Started website $WebsiteName $(if ($Slot) { "-Slot $Slot" })"
		}
	}
} else {
	Write-Warning "Cannot get website."
}

Write-Verbose "Leaving script Upload.ps1"