<#PSScriptInfo
	.VERSION 1.0.0
	.GUID 48950c67-924e-4114-a542-e54f83accadc
	.AUTHOR thomas.illiet
	.COMPANYNAME netboot.fr
	.COPYRIGHT (c) 2017 Netboot. All rights reserved.
	.TAGS Tools
	.LICENSEURI https://raw.githubusercontent.com/Netboot-France/Invoke-PowershellGallerySync/master/LICENSE
	.PROJECTURI https://github.com/Netboot-France/Invoke-PowershellGallerySync
#>

<#  
    .DESCRIPTION  
        This script can synchronize your scripts & module of your github on the powershell gallery

    .NOTES  
        File Name    : Invoke-PowershellGallerySync.ps1
        Author       : Thomas ILLIET, contact@thomas-illiet.fr
        Date	     : 2018-01-06
        Last Update  : 2018-01-06
        Tested Date  : 2018-01-06
        Version	     : 1.0.0
        
    .REQUIRE
        Software :
            + PowershellGet
                - https://www.powershellgallery.com/packages/PowerShellGet/
        
    .PARAMETER database
        json database file

        #----------------------
        # Database.json
        #----------------------
        {
            "ApiKey":"",
            "Author":"thomas.illiet",
            "Items":[
                {
                    "Name":"Invoke-PowershellGallerySync",
                    "Type":"Script",
                    "Repository":"Netboot-France/Invoke-PowershellGallerySync"
                }
            ]
        }
    
   .EXAMPLE
        Invoke-PowershellGallerySync -database database.json
 
#>

[CmdletBinding()]
Param(
    [Parameter(ParameterSetName='Database',Mandatory=$true)]
    [String]$Database
)

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
# ++++++++++++++++++++++++++
if(Test-Path $Database) { 
    Try {
        $Data = Get-Content -Raw -Path $Database | ConvertFrom-Json
    } Catch {
        throw "Unable to load configuration file : $_"
    }
} else {
    throw "Database file not found"
}

# ++++++++++++++++++++++++++
# + Setup Variable
# ++++++++++++++++++++++++++
$ApiKey = $Data.ApiKey
$Author = $Data.Author
$Items = $Data.Items

# ++++++++++++++++++++++++++
# + Item Process
# ++++++++++++++++++++++++++
$Return = @()
foreach($Item in $Items) {

    # ++++++++++++++++++++++++++
    # + Check Version   
    # ++++++++++++++++++++++++++
    [Version]$GithubVersion = Invoke-RestMethod -Uri "https://raw.githubusercontent.com/$($Item.Repository)/master/VERSION"
    
    $Gallery = Find-Script -Name $Item.Name -ErrorAction SilentlyContinue | Where-Object {$_.Author -eq $Author}
    [Version]$GalleryVersion = $Gallery.Version


    if(($GithubVersion) -or ($GithubVersion -and $GalleryVersion -eq $null)){

        if(($GithubVersion -gt $GalleryVersion) -or ( $GalleryVersion -eq $null)){

            if($Item.Type -eq "Script"){
                Try{
                    $TmpFolder = New-TemporaryFolder
                    $SrcFile = "https://raw.githubusercontent.com/$($Item.Repository)/master/$($Item.Name).ps1"
                    $TmpFile = "$TmpFolder\$($Item.Name).ps1"

                    $wc = New-Object System.Net.WebClient
                    $wc.Encoding = [System.Text.Encoding]::UTF8
                    $Content = $wc.DownloadString($SrcFile)
                    $Content -replace "`n", "`r`n" | Out-File $TmpFile

                    # Send to Gallery
                    Publish-Script -path $TmpFile -NuGetApiKey $ApiKey -Verbose

                    $Status = "Success"
                    $Message = "Update"
                } Catch {
                    $Status = "Error"
                    $Message = $_.Exception.Message
                } Finally {
                    Remove-Item $TmpFolder -Confirm:$false -Force -Recurse
                }
            } elseif ($Item.Type -eq "Module") {
                Try{
                    # Create Temporary folder
                    $TmpFolder = New-TemporaryFolder

                    # Download Project
                    $wc = New-Object System.Net.WebClient
                    $wc.Encoding = [System.Text.Encoding]::UTF8
                    $Content = $wc.DownloadString("https://github.com/$($Item.Repository)/$($Item.Name)/archive/master.zip")
                    $Content | Out-File "$TmpFolder\master.zip"

                    # Expand Archive
                    expand-archive -path "$TmpFolder\master.zip" -destinationpath "$TmpFolder\master"

                    # Send to Gallery
                    Publish-Module -path "$TmpFolder\master" -NuGetApiKey $ApiKey -Verbose

                    $Status = "Success"
                    $Message = "Update"
                } Catch {
                    $Status = "Error"
                    $Message = $_.Exception.Message
                } Finally {
                    Remove-Item $TmpFolder -Confirm:$false -Force -Recurse
                }
            }
        } else {
            $Status = "Success"
            $Message = "No Update"
        }
    } else {
        $Status = "Error"
        $Message = "Version Error"
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
