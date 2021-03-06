#Requires -Version 5

function Get-Threads {
  [CmdletBinding()]
  param (
  )
  try {
    (Get-CimInstance -ClassName CIM_Processor -ErrorAction SilentlyContinue).NumberOfLogicalProcessors
  }
  catch {
    return 1
  }
}

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

  param (
    $Path = ((Get-Location).Path),
    $LogFile = "$($Path)\Write-ChildItemHash.$(get-date -Format FileDateTime).log",
    $Algorithm = 'sha256',
    [Switch]$Recurse = $false,
    $Threads = (Get-Threads),
    [Switch]$Force = $false
  )  
  
  Write-Verbose "Running with $Threads threads."

  # Normalize to lower case
  $Algorithm = $Algorithm.ToLower()
  # Get start time for duration tracking.
  $starttime = get-date
  # Get items to hash
  $children = Get-ChildItem -Path $Path -Recurse:$Recurse

  # Stage log file
  if (Test-Path $LogFile) {
    Write-Verbose "Log file found at: $LogFile"
  }
  else {
    Write-Verbose "Creating log file $LogFile"
    New-Item -Path $LogFile -ItemType File -Force -Confirm:$false | Out-Null
  }

  $tohash = @()
  # Iterate through child items determine files to hash.
  Foreach($child in $children) {
    # Skip files that already have a corresponding hash file.
    Write-Verbose "Analyzing: $($child.PSPath)"
    if ((Test-Path "$($child.PSPath).$Algorithm") -and (-not ($Force))){
      Write-Verbose "Existing hash for: $($child.PSPath)"
      continue
    }
    # Skip directories.
    if ((Get-Item $child.PSPath) -is [System.IO.DirectoryInfo]) {
      Write-Verbose "Directory detected: $($child.PSPath)"
      continue
    }
    # Skip hash files.
    if ($child.Name -match "\.$Algorithm$") {
      Write-Verbose "Hash file not hashed: $($child.PSPath)"
      continue
    }
    $tohash += $child
  }

  foreach ($file in $tohash) {
    while ((Get-Job | Where-Object State -eq 'Running').count -eq $Threads) {
      Write-Progress -Activity 'Hashing Files'`
        -Status "$($(Get-Job | Where-Object State -eq 'Running').Name)"`
        -PercentComplete ($($(Get-Job | Where-Object State -eq 'Completed').count / $tohash.count) * 100)
      Start-Sleep 1
    }
    Write-Verbose "Launching thread for $($file.name)"
    Start-Job -Name $($file.name) -ArgumentList @($Algorithm,$file,$LogFile) -ScriptBlock {
      # Get start time for individual files
      $itemstart = Get-Date
      # Hash the file, output result to file.
      try {
        $hash = (Get-FileHash -Algorithm $args[0] -Path $args[1].PSPath).hash
        $hash | Out-File "$($args[1].pspath).$($args[0])"
      }
      catch {
        # Try to log any errors
        Write-Error $_
        $_ | Out-File  $args[2] -Append
      }
      # Build a message for logging
      $message = @("Filename: $($args[1].name) ",
                  "Hash: $hash ",
                  "Time to hash: $($(get-date) - $itemstart)"
                  )
      # Log success information and run time. 
      $message -join "`n" | Out-File -FilePath $args[2] -Append
    } | Out-Null
  } 
  while ((Get-Job | Where-Object State -eq 'Running').count -ne 0) {
    Write-Progress -Activity 'Hashing Files'`
      -Status "$($(Get-Job | Where-Object State -eq 'Running').Name)"`
      -PercentComplete ($($(Get-Job | Where-Object State -eq 'Completed').count / $tohash.count) * 100)
    Start-Sleep 1
  }

  # Clean up jobs
  Get-Job | Remove-Job

  # Log total time taken.
  $endtime = get-date
  Write-Verbose "Total time elapsed: $($endtime - $starttime)"
  "Total time elapsed: $($endtime - $starttime)" | Out-File -Force -FilePath $LogFile -Append
}

function Compare-ChildItemHash  {
  <#
  .SYNOPSIS
  Compares hashes previously computed and stored using Write-ChildItemHash and
  logs files whose current hash does not match their stored hash.
  .DESCRIPTION
  Iterates through all children of a directory (and optionally recurses through
  child directories) validating that the current hash of a file matches the value
  stored in the associated hash file. Files that do not match their stored hash
  are written to the log file.

  .PARAMETER Path
  Path to directory containing files to be validated.

  .PARAMETER LogFile
  Path to logfile to write files which do not match their stored hash to.

  .PARAMETER Algorithm
  Hashing algorithm to use for laidation; also used to detect stored hashes.
  Defaults to sha256.

  .PARAMETER Recurse
  If specified will traverse entire directory structure rooted at -Path.
  #>
  [CmdletBinding()]

  param(
    $Path = ((Get-Location).Path),
    $LogFile = "$($Path)\Compare-ChildItemHash.$(get-date -Format FileDateTime).log",
    $Algorithm = 'sha256',
    [Switch]$Recurse = $false
  )

  # Normalize to lower case
  $Algorithm = $Algorithm.ToLower()
  # Get start time for duration tracking.
  $starttime = Get-Date
  # Get items to hash
  $children = Get-ChildItem -Path $Path -Recurse:$Recurse | 
  Where-Object Name -NotLike ".$Algorithm"

 # Iterate through child items and verify hash.
 foreach ($child in $children) {
   # Only check files for which we have a stored hash.
   if (Test-Path -Path "$($child.PSPath).$Algorithm") {
     Write-Verbose "Comparing hash of $($child.Name) with hash stored in $($child.Name).$Algorithm"
     # Retrieve stored hash and compute current hash; normalize to lowercase.
     $storedhash = (Get-Content -Path "$($child.PSPath).$Algorithm").ToLower()
     $hash = (Get-FileHash -Algorithm $Algorithm $child.PSPath).hash.ToLower()
     # If the hash doesn't match write to log file.
     if ($storedhash -ne $hash) {
       $message = @( "Failed to validate file: $($child.Name)",
                     "Stored hash: $storedhash",
                     "Computed hash: $hash"
       )
       $message -join "`n" | Out-File -Force -FilePath $LogFile -Append
       Write-Verbose $($message -join "`n")
     }
   }
   else {
     continue
   }
 }
 $endtime = Get-Date
 Write-Verbose "Total time elapsed: $($endtime - $starttime)"
 "Total time elapsed: $($endtime - $starttime)" | Out-File -Force -FilePath $LogFile -Append
}