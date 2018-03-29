# Descendent Hashes
This module is designed to make hash generation of many files in descendent
directories easy to generate and verify.  This module is compatible with Powershell
5 or later, and should work equally well on Powershell Core.  There are no platform
specific items in this module; Windows and Posix environments should work equally
well.

## Exported Cmdlets
### Write-ChildItemHash
This Cmdlet will find all child items of a specified path and write the hash of
each child item to its own file. Calling `Write-ChildItemHash -Path C:\foo` where
C:\foo contains bar1.txt, bar2.txt, and bar3.txt will result in new files 
c:\foo\bar1.txt.sha256, c:\foo\bar2.txt.sha256, and c:\foo\bar3.txt.sha256.  
#### Parameters 
* `-Path` Path to directory containing files to be hashed; defaults to `.\`
* `-LogFile` Path to log file to be written; default to automatically named file
in directory specified in `-Path`
* `-Algorithm` Specifies the hashing algorithm to use; this supports any hashing
functino supported by Get-FileHash.  Changing the algorithm will change the
extension of the created files as well, using `-Algorithm MD5` will create .md5
files when generating child hashes.
* `-Recurse` Specifies that Write-ChildItemHash should traverse all descendant 
directories and hash all files found.