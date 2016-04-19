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
	$DestinationPath
)

Function Get-AzureWebsiteName {
	param(
		[String] [Parameter(Mandatory = $true)] $Name,
		[String] $Slot
	)

	if([string]::IsNullOrWhiteSpace($Slot)) {
		return $Name
	}
	return "$Name($Slot)"
}

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

Write-Verbose "Entering script Upload.ps1"

Write-Host "ConnectedServiceName= $ConnectedServiceName"
Write-Host "WebSiteName= $WebsiteName"
Write-Host "Slot= $Slot"
Write-Host "Package= $Package"
Write-Host "DestinationPath= $DestinationPath"

Write-Host "PackageFile= Find-Files -SearchPattern $Package"
$packageFile = Find-Files -SearchPattern $Package
Write-Host "PackageFile= $packageFile"

$azureWebsiteName = Get-AzureWebsiteName -Name $WebsiteName -Slot $Slot
$website = Get-AzureWebsite -Name $azureWebsiteName

if($website) {
	$timeout = 600

	$username = $website.PublishingUsername
	$password = $website.PublishingPassword
	$base64AuthInfo = [Convert]::ToBase64String([Text.Encoding]::ASCII.GetBytes(("{0}:{1}" -f $username, $password)))

	$kuduWebsiteName = Get-KuduWebsiteName -Name $WebsiteName -Slot $Slot
	$baseUrl = [string]::Format("https://{0}.scm.azurewebsites.net", $kuduWebsiteName)
	$apiUrl = JoinParts ($baseUrl, "api/zip", $DestinationPath) '/'

	Write-Host "KuduApiUrl= $apiUrl"

	Invoke-RestMethod -Uri $apiUrl -Headers @{Authorization=("Basic {0}" -f $base64AuthInfo)} -Method PUT -InFile $packageFile -ContentType "multipart/form-data" -TimeoutSec $timeout

	try {
		Invoke-RestMethod -Uri $apiUrl -Headers @{Authorization=("Basic {0}" -f $base64AuthInfo)} -Method PUT -InFile $packageFile -ContentType "multipart/form-data" -TimeoutSec $timeout
	} catch {
		Write-Host -ForegroundColor:Red "StatusCode:" $_.Exception.Response.StatusCode.value__
		Write-Host -ForegroundColor:Red "StatusDescription:" $_.Exception.Response.StatusDescription

		$result = $_.Exception.Response.GetResponseStream()
		$reader = New-Object System.IO.StreamReader($result)
		$reader.BaseStream.Position = 0
		$responseBody = $reader.ReadToEnd();

		Write-Host -ForegroundColor:Red $responseBody
	}
} else {
	Write-Warning "Cannot get website, deployment status is not updated"
}