Requires -Version 5

function Write-ChildItemHash {
  <#
  .SYNOPSIS
  Create hashes of each file found in a given path.
  
  .DESCRIPTION
  This Cmdlet will find all child items of a specified path and write the hash of
  each child item to its own file. Calling `Write-ChildItemHash -Path C:\foo` where
  C:\foo contains bar1.txt, bar2.txt, and bar3.txt will result in new files 
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
      $LogFile = "$Path\Write-ChildItemHash.$(get-date -Format o).log",
      $Algorithm = 'sha256',
      [Switch]$Recurse = $false
  )  
  $Algorithm = $Algorithm.ToLower()
  $starttime = get-date
  $children = Get-ChildItem -Path $Path -Recurse:$Recurse
  Foreach($child in $children) {
    Write-Debug "Analyzing: $($child.PSPath)"
    if (Test-Path "$($child.PSPath).$Algorithm"){
      Write-Debug "Existing hash for: $($child.PSPath)"
      continue
    }
    if ((Get-Item $child.PSPath) -is [System.IO.DirectoryInfo]) {
      Write-Debug "Directory detected: $($child.PSPath)"
      continue
    }
    if ($child.Name -match "\.$Algorithm$") {
      Write-Debug "Hash file not hashed: $($child.PSPath)"
      continue
    }
    $itemstart = Get-Date
    $hash = (Get-FileHash -Algorithm $Algorithm $child.PSPath ).hash
    try {
      $hash | Out-File "$($child.pspath).$Algorithm"
    }
    catch {
      Write-Error $_
      $_ | Out-File -FilePath $LogFile -Append
    }
    $message = @("Filename: $($child.name)",
                 "Hash: $hash",
                 "Time to hash: $($(get-date) - $itemstart)"
                 )
    Write-Verbose $($message -join "`n")
    $message | Out-File -FilePath $LogFile -Append
  }
  $endtime = get-date
  Write-Host "Total time elapsed: $($endtime - $starttime)"
}