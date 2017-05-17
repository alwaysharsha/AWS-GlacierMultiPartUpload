param(
      [Parameter(Mandatory=$true)]
      [string]$ArchivePath
    )

if(Test-Path $ArchivePath)
{
    $archiveSize = Get-ChildItem $ArchivePath | %{$_.Length}

    [long]$partSize = 4194304
    if($archiveSize -gt $partSize)
    {
        $noOfParts = $archiveSize / $partSize
        while($noOfParts -gt 9000)  #Max number of parts supported is 10000
        {
            $partSize = $partSize *2
            $noOfParts = $archiveSize / $partSize
        }
    }

    if($partSize -lt 3GB) #Max limit of a part size is 4GB
    {
        Write-Host "Calculated part size is $partSize [MB: "($partSize/(1024*1024))"MB] [GB:"($partSize/(1024*1024*1024))"GB]"
        return $partSize    
    }
    else 
    {
        throw "Part size $partSize [MB: "+($partSize/(1024*1024))+"MB] [GB:"+($partSize/(1024*1024*1024))+"GB] is greater than 3GB, which is not supported."    
    }
}
else 
{
    throw "Archive Path $ArchivePath doesn't exists."    
}
