<#
.SYNOPSIS
Creates a new multipart upload request for an Amazon Web Services Glacier vault.

.DESCRIPTION
Initiate-AwsGlacierMultipartUpload creates a new upload request to put an archive to an existing vault in an AWS Glacier account.

.PARAMETER VaultName
Name of the vault in which the archive will be uploaded.

.PARAMETER PartSize
Size of individual chunks used to upload the archive. Must be in multiples of a power of 2 times 1MB (e.g., 1MB, 2MB, 4MB, 8MB.) up to 4GB.

.PARAMETER ArchiveDescription
Description of the archive for use in inventory.

.PARAMETER LogFile
Path to a log file.

.PARAMETER Client
The Amazon Glacier client to use when creating the upload request. Encapsulates access credentials and the region endpoint.

.INPUTS
Amazon.Glacier.AmazonGlacier. The client may be passed in as a named parameter or through the pipeline.

.OUTPUTS
System.String. The upload id for the multipart archive upload request.

.LINK
http://docs.amazonwebservices.com/amazonglacier/latest/dev/api-multipart-initiate-upload.html

.LINK
http://docs.amazonwebservices.com/sdkfornet/latest/apidocs/?topic=html/T_Amazon_Glacier_Model_InitiateMultipartUploadRequest.htm

.LINK
New-AwsGlacierClient
#>
param(
      [Parameter(Position=0, Mandatory=$true)]
      [string]$VaultName=$(throw "VaultName Required"),
	  [Parameter(Position=1, Mandatory=$true)]
      [long]$PartSize=$(throw "PartSize Required"),
	  [Parameter(Position=2, Mandatory=$true)]
      [Object]$ArchiveDescription=$(throw "ArchiveDescription Required"),
	  [Parameter(Mandatory=$false)]
	  [string]$LogFile,
	  [Parameter(ValueFromPipeline=$true, Mandatory=$true)]
	  #[Amazon.Glacier.AmazonGlacier]
	  $Client)

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
	  
Function Log
{
	param([Parameter(ValueFromPipeline=$true,Mandatory=$true,Position=0)]$message)
	if ($LogFile)
	{
		$message | Out-File $LogFile "UTF8" -NoClobber -Append
	}
}

$JsonArchiveDescription = $ArchiveDescription | ConvertTo-Json -Compress

$initiateMpuRequest = New-Object Amazon.Glacier.Model.InitiateMultipartUploadRequest
$initiateMpuRequest.VaultName = $VaultName
$initiateMpuRequest.PartSize = $PartSize
$initiateMpuRequest.ArchiveDescription = $JsonArchiveDescription

"Initiate Multipart Upload Request" | Log
$initiateMpuRequest | Format-List | Out-String | Log

Try
{
	$initiateMpuResponse = $Client.InitiateMultipartUpload($initiateMpuRequest)
}
Catch [System.Exception]
{
	$Error[0].Exception.ToString() | Log
	throw
}

"Initiate Multipart Upload Response" | Log
$initiateMpuResponse | Format-List | Out-String | Log
if ($initiateMpuResponse.InitiateMultipartUploadResult)
{
	"Initiate Multipart Upload Result" | Log
	$initiateMpuResponse.InitiateMultipartUploadResult | Format-List | Out-String | Log
}

$initiateMpuResponse.InitiateMultipartUploadResult.UploadId
