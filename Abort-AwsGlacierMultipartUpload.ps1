<#
.SYNOPSIS
Aborts a multipart upload to an Amazon Web Services Glacier vault.

.DESCRIPTION
Abort-AwsGlacierUpload aborts a multipart upload to an AWS Glacier vault.  After an upload is successfully aborted no further parts may be uploaded for that upload request.

.PARAMETER VaultName
Name of the Glacier vault in which the upload was initiated.

.PARAMETER UploadId
Specifies the upload id to be aborted.

.PARAMETER FailIfUploadNotFound
Normally, if an upload id is not found in the specified vault, the failure is swallowed silently. When this switch is true, the failure is propogated.

.PARAMETER LogFile
Path to a log file.

.PARAMETER Client
The Amazon Glacier client to use when creating the upload request. Encapsulates access credentials and the region endpoint.

.INPUTS
Amazon.Glacier.AmazonGlacier. The client may be passed in as a named parameter or through the pipeline.

.OUTPUTS
None.

.LINK
http://docs.amazonwebservices.com/amazonglacier/latest/dev/api-multipart-abort-upload.html

.LINK
http://docs.amazonwebservices.com/sdkfornet/latest/apidocs/?topic=html/T_Amazon_Glacier_Model_AbortMultipartUploadRequest.htm

.LINK
New-AwsGlacierClient
#>
param(
      [Parameter(Position=0, Mandatory=$true)]
      [string]$VaultName=$(throw "VaultName Required"),
      [Parameter(Position=1, Mandatory=$true)]
      [string]$UploadId=$(throw "Upload Id to abort Required"),
	  [switch]$FailIfUploadNotFound,
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
		$message | Log
	}
}

$abortMpuRequest = New-Object Amazon.Glacier.Model.AbortMultipartUploadRequest
$abortMpuRequest.UploadId = $UploadId
$abortMpuRequest.VaultName = $VaultName

"Abort Multipart Upload Request" | Log
$abortMpuRequest | Format-List | Out-String | Log

Try
{
	[Void] $Client.AbortMultipartUpload($abortMpuRequest)
}
Catch [Amazon.Glacier.Model.ResourceNotFoundException]
{
	#This is often safe to ignore
	if ($FailIfUploadNotFound)
	{
		$Error[0].Exception.ToString() | Log
		throw
	}
}
Catch [System.Exception]
{
	$Error[0].Exception.ToString() | Log
	throw
}

"Abort Multipart Upload Response" | Log
$abortMpuResponse | Format-List | Out-String | Log
if ($abortMpuResponse.AbortMultipartUploadResult)
{
	"Abort Multipart Upload Result" | Log
	$abortMpuResponse.AbortMultipartUploadResult | Format-List | Out-String | Log
}
