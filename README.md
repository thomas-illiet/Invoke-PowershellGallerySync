# Invoke-PowershellGallerySync

![Demo](Resource/Demo.gif)

## DESCRIPTION
This script can synchronize your modules & scripts from GitHub to the PowerShell Gallery

## NOTES  
  - **File Name**    : Invoke-PowershellGallerySync.ps1
  - **Author**       : Thomas ILLIET, contact@thomas-illiet.fr
  - **Date**         : 2018-01-06
  - **Last Update**  : 2018-01-07
  - **Tested Date**  : 2018-01-08
  - **Version**      : 1.0.2

## INSTALL
```
Install-Script -Name Invoke-PowershellGallerySync
``` 

## PARAMETER database
Json database file ( you can find example file in my repository )

## EXAMPLE
```
PS> Invoke-PowershellGallerySync -Database Database.json | ft

Name                         Github Gallery Type   Status  Message
----                         ------ ------- ----   ------  -------
Invoke-PowershellGallerySync 1.0.0  1.0.0   Script Success No Update
```

```
PS> Invoke-PowershellGallerySync -Database Database.json -debug | ft

DEBUG: Debug Output activated
DEBUG: This script was called with the -Debug parameter.
DEBUG: Loading the configuration from the file : Database.json
DEBUG: Item Processing (1) :
DEBUG: + Invoke-PowershellGallerySync
DEBUG: - Github  : 1.0.0
DEBUG: - Gallery : 1.0.0
DEBUG: - Result : Success - No Update

Name                         Github Gallery Type   Status  Message
----                         ------ ------- ----   ------  -------
Invoke-PowershellGallerySync 1.0.0  1.0.0   Script Success No Update
```