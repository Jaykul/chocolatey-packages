#Requires -Version 5.0
#Requires -Modules AU
[cmdletbinding()]
param (
    [switch]$Force
)
$ErrorActionPreference = 'Stop'
Push-Location $PSScriptRoot -StackName Update

# See https://checkpoint.hashicorp.com/ and https://www.hashicorp.com/blog/hashicorp-fastly/#json-api
$gitHubOwner = "gruntwork-io"
$gitHubProject = "terragrunt"
$gitHubReleasesUri = "https://api.github.com/repos/$gitHubOwner/$gitHubProject/releases"

$checkpointUrl = "https://github.com/gruntwork-io/terragrunt/tags"

$releaseNotesTemplate = @'
{0}
## Previous Releases
For more information on previous releases, check out the changelogs on [GitHub](https://github.com/gruntwork-io/terragrunt/tags).
'@

function Set-ReleaseNotes($nuspec, $releaseNotes) {
    [xml]$xml = Get-Content $nuspec
    $xml.package.metadata.releaseNotes = $releaseNotes
    $xml.Save($nuspec)
}
function global:au_AfterUpdate {
    Set-ReleaseNotes $Latest.Changelog
}

function global:au_GetLatest {
    $releases = Invoke-RestMethod $gitHubReleasesUri
    $release = $releases[0]

    return @{
        Version      = $release.name -replace "^\D([\d\.]+)$", '$1'
        # URL32        = $build32.url
        URL64        = $release.assets.where{ $_.name -match "amd64.exe$" }.browser_download_url
        # Checksum32   = $shasums[$build32.filename]
        # Checksum64   = $shasums[$build64.filename]
        ChangelogUrl = $release.html_url
        Changelog    = $release.body
    }
}

function global:au_SearchReplace {
    @{
        ".\tools\VERIFICATION.txt" = @{
          # "(?i)(\s+x32:).*"        = "`${1} $($Latest.URL32)"
          "(?i)(\s+x64:).*"        = "`${1} $($Latest.URL64)"
          # "(?i)(checksum32:).*"    = "`${1} $($Latest.Checksum32)"
          "(?i)(checksum64:).*"    = "`${1} $($Latest.Checksum64)"
        }
    }
}

function global:au_BeforeUpdate {
    $Verification = Get-Content $PSScriptRoot\tools\VERIFICATION.txt
    # Downloads the $Latest.URL64 in tools directory and remove any older files
    Get-RemoteFiles -Purge -FileNameBase terragrunt -NoSuffix

    Set-Content $PSScriptRoot\tools\VERIFICATION.txt $Verification
}

try {
    # TLS 1.2 required by terraform's apis
    [System.Net.ServicePointManager]::SecurityProtocol = [System.Net.SecurityProtocolType]::Tls12

    Update-Package -NoCheckUrl -NoCheckChocoVersion -NoReadme -ChecksumFor none -Force:$Force

} catch {
    $ignore = 'Unable to connect to the remote server'
    if ($_ -match $ignore) { Write-Host $ignore; 'ignore' }  else { throw $_ }
}

Pop-Location -StackName Update