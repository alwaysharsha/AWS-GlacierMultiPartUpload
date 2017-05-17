<#
.SYNOPSIS
Uploads an archive in parts to an Amazon Web Services Glacier vault.

.DESCRIPTION
Execute-AwsGlacierMultipartUpload splits a file into parts and uploads them to an AWS Glaicer vault, which then assembles those parts into an archive.
Individual part failures are automatically retried up to -RetriesPerPart times.

.PARAMETER VaultName
Name of the vault in which the archive will be uploaded.

.PARAMETER UploadId
Specifies the upload id under which the archive is to be uploaded.

.PARAMETER ArchivePath
Path to the file that will be uploaded as an archive.

.PARAMETER PartSize
Size of individual chunks used to upload the archive. Must be the same as was specified when initiating the multipart upload request.

.PARAMETER ContinueFromPart
When resuming an upload, specifies the next part number that should be uploaded. Uploading a part that has already been uploaded will overwrite that part.

.PARAMETER RetriesPerPart
Number of times to retry each part before stopping in the event of a failure during upload. Defaults to 3

.PARAMETER LogFile
Path to a log file.

.PARAMETER Client
The Amazon Glacier client to use when creating the upload request. Encapsulates access credentials and the region endpoint.

.INPUTS
Amazon.Glacier.AmazonGlacier. The client may be passed in as a named parameter or through the pipeline.

.OUTPUTS
System.String[]. A list of the hashes for each part of the archive.

.LINK
http://docs.amazonwebservices.com/amazonglacier/latest/dev/api-upload-part.html

.LINK
http://docs.amazonwebservices.com/sdkfornet/latest/apidocs/?topic=html/T_Amazon_Glacier_Model_UploadMultipartUploadRequest.htm

.LINK
New-AwsGlacierClient

.LINK
Initiate-AwsGlacierMultipartUpload
#>
param(
      [Parameter(Position=0, ValueFromPipelineByPropertyName=$true, Mandatory=$true)]
      [string]$VaultName=$(throw "VaultName is required"),
	  [Parameter(Position=1, ValueFromPipelineByPropertyName=$true, Mandatory=$true)]
      [string]$UploadId=$(throw "UploadId is required"),
	  [Parameter(Position=2, ValueFromPipelineByPropertyName=$true, Mandatory=$true)]
      [string]$ArchivePath=$(throw "ArchivePath is required"),
	  [Parameter(Position=3, ValueFromPipelineByPropertyName=$true, Mandatory=$true)]
      [long]$PartSize=$(throw "PartSize is required"),
	  [Parameter(Mandatory=$false)]
      [int]$ContinueFromPart=1,
	  [Parameter(Mandatory=$false)]
	  [int]$RetriesPerPart=5,
	  [Parameter(Mandatory=$false)]
	  [string]$LogFile,
	  [Object]$ArchiveDescription,
	  [Parameter(ValueFromPipeline=$true, ValueFromPipelineByPropertyName=$true, Mandatory=$true)]
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

$Progress = $true

Function Log
{
	param([Parameter(ValueFromPipeline=$true,Mandatory=$true,Position=0)]$message)
	if ($LogFile)
	{
		$message | Out-File $LogFile "UTF8" -NoClobber -Append
	}
}

Function Abort-UploadId
{
    $abortMpuRequest = New-Object Amazon.Glacier.Model.AbortMultipartUploadRequest
    $abortMpuRequest.VaultName = $VaultName
    $abortMpuRequest.UploadId = $UploadId

    Write-Host "Abort Multipart UploadId - $UploadId" 
    " " | Log
    "Abort Multipart UploadId Request" | Log
    $abortMpuRequest | Format-List | Out-String | Log

    Try
    {
        $abortMpuResponse = $Client.AbortMultipartUpload($abortMpuRequest)
    }
    Catch [System.Exception]
    {
        $Error[0].Exception.ToString() | Log
        throw
    }
}

Function Write-UploadProgress
{
	param([switch]$CalculatingHash)
	if ($Progress)
	{
		$title = "Uploading {0} to {1}/{2}" -f $ArchivePath,$VaultName,$ArchiveDescription.Path
		
		$time = [System.DateTimeOffset]::Now
											
		$percentDone = ($currentPosition + $e.TransferredBytes)/$archiveSize
		$timeDiff = $time - $startTime
		$secondsRemaining = -1
		$kBps = [double]::NaN
		if ($currentPosition -gt $startingPosition)
		{
			if ($timeDiff.TotalSeconds -ge 60)
			{
				$secondsRemaining = [int]($timeDiff.TotalSeconds * (($archiveSize - ($currentPosition + $partTransferredBytes))/($currentPosition + $partTransferredBytes - $startingPosition)))
			}
			if ($timeDiff.TotalSeconds -gt 0)
			{
				$kBps = ($currentPosition + $partTransferredBytes - $startingPosition)/1KB/$timeDiff.TotalSeconds
			}
		}
		
		$status = "{0:N2} of {1:N2} GB transferred ({2:P2}) at {3:N0} kBps avg" -f (($currentPosition + $partTransferredBytes)/1GB),($archiveSize/1GB),$percentDone,$kBps

		if ($attempt -le 1)
		{
			$attemptMsg = ""
		}
		else
		{
			$attemptMsg = "[attempt {0}]" -f $attempt
		}
		
		if (!$CalculatingHash)
		{
			$task = "Uploading"
		}
		else
		{
			$task = "Calculating SHA256 for"
		}
		$partTitle = "{3} part {0} of {1} {2}" -f $currentPart,$totalParts,$attemptMsg,$task
		if($partTotalBytes -eq 0)
		{
			$partPercentDone = 0	
		}
		else 
		{
			$partPercentDone = $partTransferredBytes/$partTotalBytes
		}
		$partTimeDiff = $time - $partStartTime
		$partSecondsRemaining = -1
		$partKBps = [double]::NaN
		if ($partTransferredBytes -gt 0)
		{
			if ($timeDiff.TotalSeconds -ge 60)
			{
				$partSecondsRemaining = [int]($partTimeDiff.TotalSeconds * (($partTotalBytes - $partTransferredBytes)/$partTransferredBytes))
			}
			if ($partTimeDiff.TotalSeconds -gt 0)
			{
				$partKBps = $partTransferredBytes/1KB/$partTimeDiff.TotalSeconds
			}
		}
		$partStatus = "{0:N2} of {1:N0} MB transferred ({2:P2}) at {3:N0} kBps avg" -f ($partTransferredBytes/1MB),($partTotalBytes/1MB),$partPercentDone,$partKBps

		Write-Host $title 
		Write-Host "  $partTitle"

		Write-Progress $title -id 1 -status $status -PercentComplete $([int]($PercentDone * 100)) -SecondsRemaining $secondsRemaining
		Write-Progress $partTitle -id 2 -status $partStatus -PercentComplete $([int]($partPercentDone * 100)) -ParentId 1 -SecondsRemaining $partSecondsRemaining
	}
}

Function Trap-ControlC
{
	param([switch]$Throw)
	
	if ([System.Console]::KeyAvailable)
	{
		$key = [System.Console]::ReadKey($true)
		if (($key.Modifiers -band [System.ConsoleModifiers]::Control) -and ($key.Key -eq "C"))
		{
			$halt = $true
			$retVal.Cancelled = $true
			"Halting on Control+C" | Log
			if ($Throw)
			{
				throw (New-Object System.OperationCanceledException)
			}
		}
	}
}

$retVal = @{}
$retVal.PartChecksumList = @()
$retVal.Client = $Client

$startingPosition = $currentPosition = [long]0
if ($ContinueFromPart)
{
	$startingPosition = $PartSize * ($ContinueFromPart - 1)
}
$retVal.TransferredBytes = $currentPosition
$retVal.TransferredParts = $ContinueFromPart - 1

$archiveSize = (Get-Item $ArchivePath | Measure-Object -Property Length -Sum).Sum
$retVal.TotalBytes = $archiveSize

$totalParts = [int][System.Math]::Ceiling($archiveSize / $PartSize)
$retVal.TotalParts = $totalParts

if ($ContinueFromPart -gt $totalParts)
{
	throw "Can't continue from a part that doesn't exist. Max part: $totalParts"
}

$fileStream = New-Object System.IO.FileStream($ArchivePath, [System.IO.FileMode]::Open, [System.IO.FileAccess]::Read)

if($archiveSize -ne $fileStream.Length)
{
	throw "Archive size $archiveSize doesn't match with File stream length $($fileStream.Length)"
}
else 
{
	Write-Host "Archive size $archiveSize matches with File stream length $($fileStream.Length)"    
}

Try
{
	if($ENV:TEAMCITY_VERSION -eq $null)
	{
		[System.Console]::TreatControlCAsInput = $true
	}

	$startTime = $partStartTime = [System.DateTimeOffset]::Now

	"Upload of '$ArchivePath' in $totalParts parts to $VaultName started at $startTime" | Log
	"Upload Id: $UploadId" | Log

	while ($currentPosition -lt $archiveSize -and !$halt)
	{
		$currentPart = [int]($currentPosition / $PartSize) + 1
		$attempt = 1
		$success = $false
		
		"Part $currentPart of $totalParts, Attempt 1" | Log
		$uploadPartStream = [Amazon.Glacier.GlacierUtils]::CreatePartStream($fileStream, $PartSize)
		
        if(($archiveSize - $currentPosition) -lt $PartSize)
        {
            Write-Host "Part $currentPart is final part. Calculate part size."
            "Part $currentPart is final part. Calculate part size." | Log 
            $PartSize = ($archiveSize - $currentPosition)
        }

		$partTransferredBytes = 0
		$partTotalBytes = $uploadPartStream.Length

		Write-Host "Current Part = $currentPart"
		Write-Host "Current Position = $currentPosition"
		Write-Host "UploadPartStream.Length = $($uploadPartStream.Length)"
		#Write-Host "UploadPartStream.Position = $($uploadPartStream.Position)"
		Write-Host "FileStream.Position = $($fileStream.Position)"
		Write-Host "PartSize = $PartSize"

		. Write-UploadProgress -CalculatingHash

		$checksum = [Amazon.Glacier.TreeHashGenerator]::CalculateTreeHash($uploadPartStream)

		if ($currentPosition -ge $startingPosition)
		{
			Do
			{
				if ($attempt -gt 1)
				{
                    Write-Host "Retry Attempt $attempt"
					"Part $currentPart of $totalParts, Attempt $attempt" | Log

                    #No need to create part stream twice, then it will basically skip to next chunk
					#$uploadPartStream = [Amazon.Glacier.GlacierUtils]::CreatePartStream($fileStream, $PartSize)

					####### reset the fileStream Position to currentPosition and do a uploadPartStream
					if($($fileStream.Position) -ne $currentPosition)
					{
						Write-Host "Resetting the fileStream to current position $currentPosition"
						$fileStream.Seek($currentPosition, [System.IO.SeekOrigin]::Begin)
						Write-Host "FileStream.Position = $($fileStream.Position)"
						$uploadPartStream = [Amazon.Glacier.GlacierUtils]::CreatePartStream($fileStream, $PartSize)
					}
					else 
					{
						$uploadPartStream = [Amazon.Glacier.GlacierUtils]::CreatePartStream($fileStream, $PartSize)    
					}

					$partTransferredBytes = 0
					$partTotalBytes = $uploadPartStream.Length
					. Write-UploadProgress -CalculatingHash

					$checksum = [Amazon.Glacier.TreeHashGenerator]::CalculateTreeHash($uploadPartStream)
				}
			
				"Checksum : $checksum" | Log
				Write-Host "Part Checksum = $checksum"
				
				Try
				{
					$uploadMpuRequest = New-Object Amazon.Glacier.Model.UploadMultipartPartRequest
					$uploadMpuRequest.VaultName = $VaultName
					$uploadMpuRequest.Body = $uploadPartStream
					$uploadMpuRequest.Checksum = $checksum
					$uploadMpuRequest.UploadId = $UploadId
					$uploadMpuRequest.StreamTransferProgress += `
						[System.EventHandler[Amazon.Runtime.StreamTransferProgressArgs]] `
						{
							param($sender,[Amazon.Runtime.StreamTransferProgressArgs]$e)
							
							if ($count -eq 0 -or $e.PercentDone -eq 100)
							{
								$partTransferredBytes = $e.TransferredBytes
								$partTotalBytes = $e.TotalBytes
								. Write-UploadProgress
							}

							if($ENV:TEAMCITY_VERSION -eq $null)
							{
								. Trap-ControlC -Throw
							}

							$count = ($count + 1) % 100
						}
					
					[Amazon.Glacier.AmazonGlacierExtensions]::SetRange($uploadMpuRequest,$currentPosition, $currentPosition + $uploadPartStream.Length - 1)
					$temp = $currentPosition + $uploadPartStream.Length - 1
					Write-Host "currentPosition = $currentPosition , till = $temp"

					"Upload Multipart Part Request" | Log
					$uploadMpuRequest | Format-List | Out-String | Log
					
					$partStartTime = [System.DateTimeOffset]::Now
					$uploadMpuResponse = $Client.UploadMultipartPart($uploadMpuRequest)
					$success = $true
					
					"Upload Multipart Part Response" | Log
					$uploadMpuResponse | Format-List | Out-String | Log
					if ($uploadMpuResponse.UploadMultipartPartResult)
					{
						"Upload Multipart Part Result" | Log
						$uploadMpuResponse.UploadMultipartPartResult | Format-List | Out-String | Log
					}
				}
				Catch [System.Exception]
				{
					if (!$halt)
					{
						$err = $Error[0].Exception
						Write-Host "Error [System.Exception] while sending part $currentPart, attempt $attempt"
						Write-Host $($Error[0]) -ForegroundColor Red
						$err.ToString() | Log
						$attempt += 1
					}
				}
				Catch
				{
					$err = $Error[0].Exception
					Write-Host "Error while sending part $currentPart, attempt $attempt"
					Write-Host $($Error[0]) -ForegroundColor Red
					$err.ToString() | Log
					$attempt += 1
				}
			} Until ($success -or $attempt -gt $retriesPerPart -or $halt)
		}
		else
		{
			$currentPosition = $currentPosition + $uploadPartStream.Length
			$retVal.PartChecksumList += $checksum
			
			if($ENV:TEAMCITY_VERSION -eq $null)
			{
				. Trap-ControlC
			}
		}
		
		if ($success)
		{
			"Part $currentPart of $totalParts sent" | Log
			Write-Verbose "Successfully sent part $currentPart"
			
			Write-Host "~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~"

			$currentPosition = $currentPosition + $uploadPartStream.Length
			$retVal.TransferredBytes = $currentPosition
			$retVal.TransferredParts = $currentPart
			$retVal.PartChecksumList += $checksum
		}
		elseif ($attempt -gt $retriesPerPart)
		{
			"Part $currentPart of $totalParts failed!" | Log
			$halt = $true
		}
	}
	
	$retVal.Success = !$halt
}
Catch
{
	$err = $Error[0].Exception
	Write-Host "Error details"
	Write-Host $($Error[0]) -ForegroundColor Red
	$err.ToString() | Log
	Write-Host "DEBUG: Executing catch in Execute-AwsGlacierMultipartUpload script."
    Abort-UploadId
}
Finally
{
	if($ENV:TEAMCITY_VERSION -eq $null)
	{
		[System.Console]::TreatControlCAsInput = $false
	}
	$fileStream.Close()
	#Write-Host "DEBUG: Executing finally in Execute-AwsGlacierMultipartUpload script."
}

"`r`n`r`nFinished upload of '$ArchivePath' to $VaultName at $([System.DateTimeOffset]::Now)" | Log
$retVal | Format-List | Out-String | Log

$retVal