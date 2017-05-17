<#
.SYNOPSIS
Completes a multipart upload request for an Amazon Web Services Glacier vault.

.DESCRIPTION
Complete-AwsGlacierMultipartUpload finishes uploading an archive to an AWS Glacier vault. After an upload is successfully completed no further parts may be uploaded for that upload request.

.PARAMETER VaultName
Name of the vault in which the archive will be uploaded.

.PARAMETER UploadId
Specifies the upload id under which the archive is to be uploaded.

.PARAMETER ArchiveSize
Size of the uploaded archive.

.PARAMETER Checksum
The root of the SHA256 tree hash of the uploaded archive. One of Checksum or PartChecksumList is required.

.PARAMETER PartChecksumList
A list of the SHA256 tree hashes for each part of the uploaded archive. One of Checksum or PartChecksumList is required.

.PARAMETER LogFile
Path to a log file.

.PARAMETER Client
The Amazon Glacier client to use when creating the upload request. Encapsulates access credentials and the region endpoint.

.INPUTS
Amazon.Glacier.AmazonGlacier. The client may be passed in as a named parameter or through the pipeline.

.OUTPUTS
System.String. The archive id for the successfully uploaded archive.

.LINK
http://docs.amazonwebservices.com/amazonglacier/latest/dev/api-multipart-complete-upload.html

.LINK
http://docs.amazonwebservices.com/sdkfornet/latest/apidocs/?topic=html/T_Amazon_Glacier_Model_CompleteMultipartUploadRequest.htm

.LINK
New-AwsGlacierClient

.LINK
Initiate-AwsGlacierMultipartUpload
#>
param(
      [Parameter(Position=0, Mandatory=$true)]
      [string]$VaultName=$(throw "VaultName is required"),
	  [Parameter(Position=1, Mandatory=$true)]
      [string]$UploadId=$(throw "UploadId is required"),
	  [Parameter(Position=2, Mandatory=$true)]
      [long]$ArchiveSize=$(throw "ArchiveSize is required"),
	  [Parameter(Position=3, Mandatory=$false)]
      [string]$Checksum,
	  [Parameter(ValueFromRemainingArguments=$true, Mandatory=$false)]
	  [array]$PartChecksumList,
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

if (!$Checksum)
{
	if (!$PartChecksumList)
	{
		throw "Either a whole-archive checksum or a list of checksums from each part is required"
	}
	$Checksum = [Amazon.Glacier.TreeHashGenerator]::CalculateTreeHash([String[]]$PartChecksumList)
}

$completeMpuRequest = New-Object Amazon.Glacier.Model.CompleteMultipartUploadRequest
$completeMpuRequest.VaultName = $VaultName
$completeMpuRequest.UploadId = $UploadId
$completeMpuRequest.ArchiveSize = $ArchiveSize
$completeMpuRequest.Checksum = $Checksum

"Complete Multipart Upload Request" | Log
$completeMpuRequest | Format-List | Out-String | Log

Try
{
	$completeMpuResponse = $Client.CompleteMultipartUpload($completeMpuRequest)
}
Catch [System.Exception]
{
	$Error[0].Exception.ToString() | Log
	throw
}

"Complete Multipart Upload Response" | Log
$completeMpuResponse | Format-List | Out-String | Log
if ($completeMpuResponse.CompleteMultipartUploadResult)
{
	"Complete Multipart Upload Result" | Log
	$completeMpuResponse.CompleteMultipartUploadResult | Format-List | Out-String | Log
}

$completeMpuResponse.CompleteMultipartUploadResult.ArchiveId