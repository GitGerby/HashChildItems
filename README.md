- [Descendent Hashes](#descendent-hashes)
    - [Exported Cmdlets](#exported-cmdlets)
        - [Write-ChildItemHash](#write-childitemhash)
            - [Parameters](#parameters)
        - [Compare-ChildItemHash](#compare-childitemhash)
            - [Parameters](#parameters)

# Descendent Hashes
This module is designed to generate hashes of all files in a directory and 
optionally its descendant directories. This module is compatible with Powershell
5 or later, and should work equally well on Powershell Core. There are no 
platform specific items in this module; Windows and Posix environments should 
work equally well.

These functions were written with bulk file transfers in mind; running
`Write-ChildItemHash` on a path before transferring the entire directory structure
to a remote endpoint and then validating that files transferred unmolested by
executing `Compare-ChildItemHash` on the destination path once the transfer is
complete.  This process would not detect additional files, nor would it detect
files that were not transferred at all, it would validate that files that were
transferred match their transferred hashes.

## Exported Cmdlets
### Write-ChildItemHash
This Cmdlet will find all child items of a specified path and write the hash of
each child item to its own file. Calling `Write-ChildItemHash -Path C:\foo` where
C:\foo contains bar1.txt, bar2.txt, and bar3.txt will result in new files 
C:\foo\bar1.txt.sha256, C:\foo\bar2.txt.sha256, and C:\foo\bar3.txt.sha256.

Write-ChildItemHash will skip hashing files for which there already exists a hash
file; the Cmdlet will also skip hashing hash files for the targeted algorithm.
#### Parameters 
* `-Path` Path to directory containing files to be hashed; defaults to `.\`
* `-LogFile` Path to log file to be written; default to automatically named file
in directory specified in `-Path`
* `-Algorithm` Specifies the hashing algorithm to use; this supports any hashing
function supported by Get-FileHash.  Changing the algorithm will change the
extension of the created files as well, using `-Algorithm MD5` will create .md5
files when generating child hashes; defaults to sha256.
* `-Recurse` If passed specifies that Write-ChildItemHash should traverse all 
descendant directories and hash all files found.

### Compare-ChildItemHash
Iterates through all children of a directory (and optionally recurses through
child directories) validating that the current hash of a file matches the value
stored in the associated hash file. Files that do not match their stored hash
are written to the log file.

Compare-ChildItemHash is designed to validate that files previously hashed by
Write-ChildItemHash still match their stored hash. This can be used to validate
that transferred files have not been manipulated in transit. Files that do not 
have an associated hash file will be ignored. This will not detect missing files
, nor will it detect extra files.

#### Parameters
* `-Path` Path to directory containing files to be validated; defaults to `.\`.
* `-LogFile` Path to log file to be written; default to automatically named 
file in directory specified in `-Path`.  This log will contain all files that do
not match their stored hash.
* `-Algorithm` Specifies the hashing algorithm to use; this supports any hashing
function supported by Get-FileHash.  Changing the algorithm will change the
extension of the hash files as well, using `-Algorithm MD5` will look for .md5
files when validating child hashes; defaults to sha256.
* `-Recurse` If passed specifies that Compare-ChildItemHash should traverse all 
descendant directories and validate all files found.