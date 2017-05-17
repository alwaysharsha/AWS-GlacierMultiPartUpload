<#
.SYNOPSIS
Creates an AWS Glacier Client

.DESCRIPTION
New-AwsGlacierClient creates a new AWS Glacier Client.

.PARAMETER SystemName
System name of the region endpoint to use. Defaults to "us-east-1".

.PARAMETER AwsKeyFile
The path to a file which contains AWS access credentials. The Access Key should be on the first line of the file, and the second should be the Secret Access Key.

.PARAMETER AwsAccessKeyId
The AWS access key to use for upload. Required if AwsKeyFile is not specified.

.PARAMETER AwsSecretAccessKeyId
The AWS secret access key to use to upload. Required if AwsKeyFile is not specified.

.INPUTS
None. Abort-AwsGlacierUpload does not accept piped objects.

.OUTPUTS
Amazon.Glacier.AmazonGlacier. The Amazon Glacier Client.

.LINK
http://docs.amazonwebservices.com/amazonglacier/latest/dev/amazon-glacier-accessing.html

.LINK
http://docs.amazonwebservices.com/sdkfornet/latest/apidocs/?topic=html/N_Amazon_Glacier.htm
#>
param(
	  [Parameter(Mandatory=$false)]
	  [string]$SystemName="us-east-1",
      [Parameter(ParameterSetName="UsingKeyFile", Mandatory=$true)]
      [string]$AwsKeyFile,
      [Parameter(ParameterSetName="NotUsingKeyFile", Mandatory=$true)]
      [string]$AwsAccessKeyId=$(if (!$awsKeyFile) {throw "AWS Access Key is required"}),
      [Parameter(ParameterSetName="NotUsingKeyFile", Mandatory=$true)]
      [string]$AwsSecretAccessKeyId=$(if (!$awsKeyFile) {throw "AWS Secret Access Key is required"}))

if (Test-Path -LiteralPath ${env:ProgramFiles}"\AWS SDK for .NET\bin\AWSSDK.dll") {
    Write-Host "${env:ProgramFiles}\AWS SDK for .NET\bin\AWSSDK.dll imported successfully."
    Add-Type -Path ${env:ProgramFiles}"\AWS SDK for .NET\bin\AWSSDK.dll"
} elseif (Test-Path -LiteralPath ${env:ProgramFiles(x86)}"\AWS SDK for .NET\bin\AWSSDK.dll") {
    Write-Host "${env:ProgramFiles(x86)}\AWS SDK for .NET\bin\AWSSDK.dll imported successfully."
    Add-Type -Path ${env:ProgramFiles(x86)}"\AWS SDK for .NET\bin\AWSSDK.dll"
} elseif (Test-Path -LiteralPath ${env:ProgramFiles(x86)}"\AWS SDK for .NET\past-releases\Version-2\Net35\AWSSDK.dll") {
    Write-Host "${env:ProgramFiles(x86)}\AWS SDK for .NET\past-releases\Version-2\Net35\AWSSDK.dll imported successfully."
    Add-Type -Path ${env:ProgramFiles(x86)}"\AWS SDK for .NET\past-releases\Version-2\Net35\AWSSDK.dll"
} elseif (Test-Path -LiteralPath ${env:ProgramFiles(x86)}"\AWS SDK for .NET\past-releases\Version-1\AWSSDK.dll") {
    Write-Host "${env:ProgramFiles(x86)}\AWS SDK for .NET\past-releases\Version-1\AWSSDK.dll imported successfully."
    Add-Type -Path ${env:ProgramFiles(x86)}"\AWS SDK for .NET\past-releases\Version-1\AWSSDK.dll"
}
else {
    throw "Cannot find AWSSDK.dll to import"
}

if ($awsSecretAccessKeyId -and $awsAccessKeyId -and $awsKeyFile)
{
	throw "Provide either an AWS Access and Secret Access Key pair or specify a file where those credentials can be found, but not both."
}
elseif (!($awsAccessKeyId -and $awsSecretAccessKeyId) -and !$awsKeyFile)
{
	throw "AWS Access and Secret Access Keys required or specify a file where those credentials can be found."
}
elseif (!($awsAccessKeyId -and $awsSecretAccessKeyId))
{
	$content = Get-Content $awsKeyFile
	$awsAccessKeyId = $content[0]
	$awsSecretAccessKeyId = $content[1]
}

$RegionEndpoint = [Amazon.RegionEndpoint]::GetBySystemName($SystemName)

New-Object Amazon.Glacier.AmazonGlacierClient($awsAccessKeyId, $awsSecretAccessKeyId, $RegionEndpoint)