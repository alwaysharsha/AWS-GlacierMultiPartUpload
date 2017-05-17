<#
.SYNOPSIS
Uploads an archive (possibly in parts) to an Amazon Web Services Glacier vault.

.DESCRIPTION
Do-AwsGlacierUpload uploads a file to an AWS Glaicer vault as an archive.

.PARAMETER VaultName
Name of the vault in which the archive will be uploaded.

.PARAMETER ArchivePath
Path to the file that will be uploaded as an archive.

.PARAMETER ArchiveDescription
Description of the archive for use in inventory.

.PARAMETER PartSize
Size of individual chunks used to upload the archive. Defaults to the size that will provide between 5000 and 10000 parts between 1MB and 4GB.

.PARAMETER ResumeUploadId
Resumes an in-progress upload. Specifies the upload id to resume.

.PARAMETER ContinueFromPart
When resuming an upload, specifies the next part number that should be uploaded. Uploading a part that has already been uploaded will overwrite that part.

.PARAMETER LogFile
Path to a log file.

.PARAMETER Client
The Amazon Glacier client to use when creating the upload request. Encapsulates access credentials and the region endpoint.

.INPUTS
Amazon.Glacier.AmazonGlacier. The client may be passed in as a named parameter or through the pipeline.

.OUTPUTS
System.String. The archive id of the completed upload

.LINK
http://docs.amazonwebservices.com/amazonglacier/latest/dev/api-upload-part.html

.LINK
New-AwsGlacierClient
#>[CmdletBinding(DefaultParameterSetName="Initial")]
param(
      [Parameter(Position=0, Mandatory=$true)]
      [string]$VaultName=$(throw "VaultName Required"),
      [Parameter(Position=1, Mandatory=$true)]
      [string]$ArchivePath=$(throw "ArchivePath is required"),
      [Parameter(Position=2, ParameterSetName="Resume", Mandatory=$true)]
      [Parameter(Position=2, ParameterSetName="Initial", Mandatory=$false)]
      [Object]$ArchiveDescription,
      [Parameter(Mandatory=$false)]
      [long]$PartSize=$(.\Get-AwsGlacierMultipartUploadPartSize $ArchivePath), #4MB default value (Min 1MB, max 4GB.  Value must be power of 2)
      [Parameter(ParameterSetName="Resume", Mandatory=$true)]
      [string]$ResumeUploadId,
      [Parameter(ParameterSetName="Resume", Mandatory=$true)]
      [int]$ContinueFromPart,
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
	  
Function IsPowerOfTwo
{
	param([long]$value)
	($value -ne 0) -and (($value -band ($value - 1)) -eq 0)
}

if ($PartSize -gt 4GB -or !(IsPowerOfTwo $($PartSize/1MB)))
{
	throw "Part size must be a power of 2 between 1 and $(4GB/1MB)MB"
}

$ArchiveSize = Get-ChildItem $ArchivePath | %{$_.Length}
$sizeInMB = [math]::Round(($ArchiveSize/(1024*1024)),2)
$sizeInGB = [math]::Round(($ArchiveSize/(1024*1024*1024)),2)
Write-Host "Archive Size is $ArchiveSize [MB: $sizeInMB MB] [GB: $sizeInGB GB]"

if (!$ResumeUploadId)
{
	Write-Host "Initiating upload"
	$uploadId = $Client | .\Initiate-AwsGlacierMultipartUpload -VaultName:$VaultName -PartSize:$PartSize -ArchiveDescription:$ArchiveDescription -LogFile:$LogFile
	Write-Host "Received upload id: $uploadId"
}
else
{
	Write-Host "Continuing upload id: $ResumeUploadId"
	Write-Host "from part $ContinueFromPart"
	$uploadId = $ResumeUploadId
}

if (!$ContinueFromPart)
{
	$ContinueFromPart = 1
}

$result = $Client | .\Execute-AwsGlacierMultipartUpload -VaultName:$VaultName -UploadId:$uploadId -ArchivePath:$ArchivePath -PartSize:$PartSize -ContinueFromPart:$ContinueFromPart -LogFile:$LogFile -ArchiveDescription:$ArchiveDescription

#"Capture result data" | Out-File $LogFile -Append -Encoding ASCII
#$result | Out-File $LogFile -Append -Encoding ASCII

if ($result.Cancelled)
{
	Write-Host "Cancelling upload"
	Write-Host "Be sure to abort upload if you wish to abandon this session"
	$message = "Cancelled upload to Glacier Vault '{1}'.{0}Total data transferred {2:N2} GB ({3:P2}). Last successful part: {4}" -f [System.Environment]::NewLine,$VaultName,($result.TransferredBytes/1GB),($result.TransferredBytes/$result.TotalBytes),$result.TransferredParts
}
elseif ($result.Success)
{
	Write-Host "Completing upload"
  $archiveId = $Client | .\Complete-AwsGlacierMultipartUpload -VaultName:$VaultName -UploadId:$uploadId -ArchiveSize:$($result.TotalBytes) -PartChecksumList:$($result.PartChecksumList) -LogFile:$LogFile
	$message = "Completed upload as archive (ID: {1}){0}To Glacier Vault '{2}'. Total data transferred: {3:N2} GB in {4} parts" -f [System.Environment]::NewLine,$archiveId,$VaultName,($result.TransferredBytes/1GB),$result.TransferredParts
}
else
{
	Write-Host "Upload Failed"
	$message = "Failed upload to Glacier Vault '{1}'.{0}Total data transferred {2:N2} GB ({3:P2}). Last successful part: {4}" -f [System.Environment]::NewLine,$VaultName,($result.TransferredBytes/1GB),($result.TransferredBytes/$result.TotalBytes),$result.TransferredParts
}

Write-Host "`n`r`n`r"	
Write-Host $message
Write-Host "`n`r`n`r"

$archiveId