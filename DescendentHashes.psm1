#Requires -Version 5

function Write-ChildItemHash {
  <#
  .SYNOPSIS
  Create hashes of each file found in a given path.
  
  .DESCRIPTION
  This Cmdlet will find all child items of a specified path and write the hash 
  of each child item to its own file. Calling `Write-ChildItemHash -Path C:\foo`
  where C:\foo contains bar1.txt, bar2.txt, and bar3.txt will result in new files 
  C:\foo\bar1.txt.sha256, C:\foo\bar2.txt.sha256, and C:\foo\bar3.txt.sha256.  
  
  .PARAMETER Path
  Path to directory containing files to be hashed.
  
  .PARAMETER LogFile
  Location log file to be written.
  
  .PARAMETER Algorithm
  Hashing Algorithm to use.
  
  .PARAMETER Recurse
  If specified will traverse entire directory structure rooted at -Path.
  #> 
   [CmdletBinding()]
    param(
      $Path = '.\',
      $LogFile = "$((Get-Item $Path).PSPath)\Write-ChildItemHash.$(get-date -Format FileDateTime).log",
      $Algorithm = 'sha256',
      [Switch]$Recurse = $false
  )  
  # Normalize to lower case
  $Algorithm = $Algorithm.ToLower()
  # Get start time for duration tracking.
  $starttime = get-date
  # Get items to hash
  $children = Get-ChildItem -Path $Path -Recurse:$Recurse

  # Iterate through child items and write out hash values.
  Foreach($child in $children) {
    # Skip files that already have a corresponding hash file.
    Write-Debug "Analyzing: $($child.PSPath)"
    if (Test-Path "$($child.PSPath).$Algorithm"){
      Write-Debug "Existing hash for: $($child.PSPath)"
      continue
    }
    # Skip directories.
    if ((Get-Item $child.PSPath) -is [System.IO.DirectoryInfo]) {
      Write-Debug "Directory detected: $($child.PSPath)"
      continue
    }
    # Skip hash files.
    if ($child.Name -match "\.$Algorithm$") {
      Write-Debug "Hash file not hashed: $($child.PSPath)"
      continue
    }
    # Get start time for individual files
    $itemstart = Get-Date
    # Hash the file, output result to file.
    try {
      $hash = (Get-FileHash -Algorithm $Algorithm $child.PSPath).hash
      $hash | Out-File "$($child.pspath).$Algorithm"
    }
    catch {
      # Try to log any errors
      Write-Error $_
      $_ | Out-File -FilePath $LogFile -Append
    }
    # Build a message for logging
    $message = @("Filename: $($child.name)",
                 "Hash: $hash",
                 "Time to hash: $($(get-date) - $itemstart)"
                 )
    Write-Verbose $($message -join "`n")
    # Log success information and run time. 
    $message -join "`n" | Out-File -FilePath $LogFile -Append
  }
  
  # Log total time taken.
  $endtime = get-date
  Write-Verbose "Total time elapsed: $($endtime - $starttime)"
  "Total time elapsed: $($endtime - $starttime)" | Out-File -FilePath $LogFile -Append
}

function Compare-ChildItemHash  {
  param(
    $Path = '.\',
    $LogFile = "$((Get-Item $Path).PSPath)\Compare-ChildItemHash.$(get-date -Format FileDateTime).log",
    $Algorithm = 'sha256',
    [Switch]$Recurse = $false
  )

  # Normalize to lower case
  $Algorithm = $Algorithm.ToLower()
  # Get start time for duration tracking.
  $starttime = Get-Date
  # Get items to hash
  $children = Get-ChildItem -Path $Path -Recurse:$Recurse | Where-Object Name -NotLike ".$Algorithm"

 # Iterate through child items and verify hash.
 foreach ($child in $children) {
   if (Test-Path -Path "$($child.PSPath).$Algorithm") {
     $storedhash = Get-Content -Path "$($child.PSPath).$Algorithm"
     $hash = (Get-FileHash -Algorithm $Algorithm $child.PSPath).hash
     if ($originalhash -ne $hash) {
       $message = @( "Failed to validate file: $($child.Name)",
                     "Stored hash: $storedhash",
                     "Computed hash: $hash"
       )
       $message -join "`n" | Out-File -FilePath $LogFile -Append
       Write-Verbose $($message -join "`n")
     }
   }
   else {
     continue
   }
 }
 $endtime = Get-Date
 Write-Verbose "Total time elapsed: $($endtime - $starttime)"
 "Total time elapsed: $($endtime - $starttime)" | Out-File -FilePath $LogFile -Append
}