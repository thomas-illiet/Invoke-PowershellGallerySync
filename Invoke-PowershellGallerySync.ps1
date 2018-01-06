[CmdletBinding()]
Param(
    [Parameter(ParameterSetName='Database',Mandatory=$true)][String]$Database
)

function New-TemporaryFolder {
    $TmpFolder = "$([System.IO.Path]::GetTempPath())$([string][System.Guid]::NewGuid())"
    New-Item -ItemType Directory -Path $TmpFolder | Out-Null
    return $TmpFolder
}

# ++++++++++++++++++++++++++
# + Load configuration file
# ++++++++++++++++++++++++++
if(Test-Path $Database) { 
    Try {
        Write-Debug "Load Configuration file"
        $Data = Get-Content -Raw -Path $Database | ConvertFrom-Json
    } Catch {
        throw "Unable to load configuration file"
    }
} else {
    throw "Database file not found"
}
# ++++++++++++++++++++++++++
# + Setup Variable
# ++++++++++++++++++++++++++
Write-Debug "Setup Variable"
$ApiKey = $Data.ApiKey
$Author = $Data.Author
$Items = $Data.Items

# ++++++++++++++++++++++++++
# + Item Process
# ++++++++++++++++++++++++++
Write-Debug "Item Process"

foreach($Item in $Items) {

    Write-Host $Item.name

    # ++++++++++++++++++++++++++
    # + Check Version
    # ++++++++++++++++++++++++++
    Try {
        $GithubVersion = Invoke-RestMethod -Uri "https://raw.githubusercontent.com/$($Item.Repository)/master/VERSION"
        $Gallery = Find-Script -Name $Item.Name -ErrorAction SilentlyContinue | Where-Object {$_.Author -eq $Author}
        $GalleryVersion = $Gallery.Version
    } Catch {
        throw "Unable to get version : $_"
    }

    if(([Version]$GithubVersion) -or ([Version]$GithubVersion -and $GalleryVersion -eq $null)){

        if(($GithubVersion -gt $GalleryVersion) -or ( $GalleryVersion -eq $null)){

            Write-Host "update...."

            if($Item.Type -eq "Script"){
                Try{
                    $TmpFolder = New-TemporaryFolder

                    # Download script
                    $wc = New-Object System.Net.WebClient
                    $wc.Encoding = [System.Text.Encoding]::UTF8
                    $Content = $wc.DownloadString("https://raw.githubusercontent.com/$($Item.Repository)/master/$($Item.Name).ps1")
                    $Content -replace "`n", "`r`n" | Out-File "$TmpFolder\$($Item.Name).ps1"

                    # Send to Gallery
                    Publish-Script -path "$TmpFolder\$($Item.Name).ps1" -NuGetApiKey $ApiKey -Verbose

                } Catch {
                    Write-Error "Unable tu update : $_"
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

                } Catch {
                    Write-Error "Unable tu update : $_"
                } Finally {
                    Remove-Item $TmpFolder -Confirm:$false -Force -Recurse
                }
            } else {
                throw "Not type selected for this"
            }   
        }
    } else {
        throw "Error with version : $_"
    }
}
