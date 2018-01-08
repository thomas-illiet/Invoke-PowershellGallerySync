<#PSScriptInfo
    .VERSION 1.0.2
    .GUID 48950c67-924e-4114-a542-e54f83accadc
    .AUTHOR thomas.illiet
    .COMPANYNAME netboot.fr
    .COPYRIGHT (c) 2017 Netboot. All rights reserved.
    .TAGS Tools
    .LICENSEURI https://raw.githubusercontent.com/Netboot-France/Invoke-PowershellGallerySync/master/LICENSE
    .PROJECTURI https://github.com/Netboot-France/Invoke-PowershellGallerySync
    .ICONURI https://raw.githubusercontent.com/Netboot-France/Invoke-PowershellGallerySync/master/Resource/Icon.png
    .EXTERNALMODULEDEPENDENCIES PowershellGet
    .REQUIREDSCRIPTS 
    .EXTERNALSCRIPTDEPENDENCIES 
    .RELEASENOTES
#>

<#  
    .DESCRIPTION
        This script can synchronize your modules & scripts from GitHub to the PowerShell Gallery

    .NOTES  
        File Name    : Invoke-PowershellGallerySync.ps1
        Author       : Thomas ILLIET, contact@thomas-illiet.fr
        Date         : 2018-01-06
        Last Update  : 2018-01-07
        Tested Date  : 2018-01-08
        Version      : 1.0.2
  
    .PARAMETER database
        Json database file ( you can find example file in my repository )

        {
            "Gallery":{
                "ApiKey":"XXXXXXXX-XXXX-XXXX-XXXX-XXXXXXXXXXXX",
                "Author":"thomas.illiet"
            },
            "Items":[
                {
                    "Name":"Get-O365IPAddress",
                    "Type":"Script",
                    "Owner":"Netboot-France",
                    "Repository":"Get-O365IPAddress",
                    "Branch":"master",
                    "VersionFile":"Resource/VERSION"
                }
            ]
        }

    .EXAMPLE
        PS> Invoke-PowershellGallerySync -Database Database.json | ft

        Name                         Github Gallery Type   Status  Message
        ----                         ------ ------- ----   ------  -------
        Invoke-PowershellGallerySync 1.0.0  1.0.0   Script Success No Update

    .EXAMPLE
        PS> Invoke-PowershellGallerySync -Database Database.json -debug  | ft

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

#>

[CmdletBinding()]
Param(
    # Database
    [Parameter(Mandatory=$true)]
    [String]$Database
)

# Debug
If ($PSCmdlet.MyInvocation.BoundParameters["Debug"].IsPresent){
     $DebugPreference="Continue"
     Write-Debug "Debug Output activated"
     Write-Debug "This script was called with the -Debug parameter."
} Else {
     $DebugPreference="SilentlyContinue"
}

# ++++++++++++++++++++++++++
# + Internal Function
# ++++++++++++++++++++++++++
function New-TemporaryFolder {
    $TmpFolder = "$([System.IO.Path]::GetTempPath())$([string][System.Guid]::NewGuid())"
    New-Item -ItemType Directory -Path $TmpFolder | Out-Null
    return $TmpFolder
}

# ++++++++++++++++++++++++++
# + Load configuration
if(Test-Path $Database) { 
    Try {
        Write-Debug "Loading the configuration from the file : $Database"
        $Data = Get-Content -Raw -Path $Database | ConvertFrom-Json
    } Catch {
        throw "Unable to load configuration file : $_"
    }
} else {
    throw "Database file not found ! "
}

# ++++++++++++++++++++++++++
# + Setup Variable
$ApiKey = $Data.Gallery.ApiKey
$Author = $Data.Gallery.Author
$Items = $Data.Items

# ++++++++++++++++++++++++++
# + Item Processing
Write-Debug "Item Processing ($($Items.count)) : "
$Return = @()
foreach($Item in $Items) {

    write-debug "+ $($Item.Name)"

    # ++++++++++++++++++++++++++
    # + Check Version   
    [Version]$GithubVersion = Invoke-RestMethod -Uri "https://github.com/$($Item.Owner)/$($Item.Repository)/raw/$($Item.Branch)/$($Item.VersionFile)"
    $Gallery = Find-Script -Name $Item.Name -ErrorAction SilentlyContinue | Where-Object {$_.Author -eq $Author} 
    [Version]$GalleryVersion = $Gallery.Version

    Write-Debug "- Github  : $GithubVersion"
    Write-Debug "- Gallery : $GalleryVersion" 

    # If GithubVersion is defined or
    if(($GithubVersion) -or ($GithubVersion -and $GalleryVersion -eq $null)){

        if(($GithubVersion -gt $GalleryVersion) -or ( $GalleryVersion -eq $null)){

            Write-Debug "- Type : $($Item.Type)"

            if($Item.Type -eq "Script"){
                Try{
                    $TmpFolder = New-TemporaryFolder
                    $SrcFile = "https://github.com/$($Item.Owner)/$($Item.Repository)/raw/$($Item.Branch)/$($Item.Name).ps1"
                    $TmpFile = "$TmpFolder\$($Item.Name).ps1"
                    Write-Debug "- Download Link : $SrcFile"

                    # Download Script
                    $wc = New-Object System.Net.WebClient
                    $wc.Encoding = [System.Text.Encoding]::UTF8
                    $Content = $wc.DownloadString($SrcFile)
                    $Content -replace "`n", "`r`n" | Out-File $TmpFile

                    # Send to Gallery
                    Publish-Script -path $TmpFile -NuGetApiKey $ApiKey

                    $Status = "Success"
                    $Message = "Update"
                } Catch {
                    $Status = "Error"
                    $Message = $_.Exception.Message
                } Finally {
                    Remove-Item $TmpFolder -Confirm:$false -Force -Recurse
                    Write-Debug "- Result : $Status - $Message"
                }
            } elseif ($Item.Type -eq "Module") {
                Try{
                    $TmpFolder = New-TemporaryFolder
                    $SrcFile = "https://github.com/$($Item.Repository)/$($Item.Name)/archive/master.zip"
                    Write-Debug "- Download Link : $SrcFile"

                    # Download Project
                    $wc = New-Object System.Net.WebClient
                    $wc.Encoding = [System.Text.Encoding]::UTF8
                    $Content = $wc.DownloadString($SrcFile)
                    $Content | Out-File "$TmpFolder\master.zip"

                    # Expand Archive
                    expand-archive -path "$TmpFolder\master.zip" -destinationpath "$TmpFolder\master"

                    # Send to Gallery
                    Publish-Module -path "$TmpFolder\master" -NuGetApiKey $ApiKey

                    $Status = "Success"
                    $Message = "Update"
                } Catch {
                    $Status = "Error"
                    $Message = $_.Exception.Message
                } Finally {
                    Remove-Item $TmpFolder -Confirm:$false -Force -Recurse
                    Write-Debug "- Result : $Status - $Message"
                }
            }
        } else {
            $Status = "Success"
            $Message = "No Update"
            Write-Debug "- Result : $Status - $Message"
        }
    } else {
        $Status = "Error"
        $Message = "Version Error"
        Write-Debug "- Result : $Status - $Message"
    }
    

    # Return Management
    $ReturnObject = [PSCustomObject]@{
        Name    = $Item.name
        Github  = $GithubVersion
        Gallery = $GalleryVersion
        Type    = $Item.Type
        Status  = $Status
        Message = $Message
    }
    
    $Return += $ReturnObject
}

# Return Object
Return $Return
