param([string]$Profile='', [switch]$CheckOnly)
$ErrorActionPreference='Stop'
. (Join-Path $PSScriptRoot 'Update-Library.ps1')
$clientRoot=Split-Path -Parent $PSScriptRoot
$exe=Join-Path $clientRoot 'Nexus Client.exe'
$repository='godejro/Nexus-Client'
$log=Join-Path $PSScriptRoot 'update.log'
$lock=$null; $ready=$true
try {
    $lock=[IO.File]::Open((Join-Path $PSScriptRoot 'update.lock'),[IO.FileMode]::OpenOrCreate,[IO.FileAccess]::ReadWrite,[IO.FileShare]::None)
    $running=Get-Process -ErrorAction SilentlyContinue | Where-Object {
        try { $_.Path -and [IO.Path]::GetDirectoryName($_.Path) -eq $clientRoot } catch { $false }
    }
    if (!$running) {
        [Net.ServicePointManager]::SecurityProtocol=[Net.SecurityProtocolType]::Tls12
        $headers=@{'User-Agent'='Nexus-Updater';'Accept'='application/vnd.github+json'}
        $release=Invoke-RestMethod -Uri "https://api.github.com/repos/$repository/releases/latest" -Headers $headers -TimeoutSec 15
        $asset=@($release.assets | Where-Object name -eq 'nexus-update.zip')
        $manifestAsset=@($release.assets | Where-Object name -eq 'update.json')
        if($asset.Count -ne 1 -or $manifestAsset.Count -ne 1) { throw 'Release has no complete Nexus update.' }
        $installed=Join-Path $PSScriptRoot 'installed-version.txt'
        $version=if(Test-Path -LiteralPath $installed){(Get-Content -LiteralPath $installed -Raw).Trim()}else{''}
        if($version -ne $release.tag_name) {
            foreach($entry in @($asset[0],$manifestAsset[0])) {
                if(!$entry.browser_download_url.StartsWith("https://github.com/$repository/releases/download/",[StringComparison]::Ordinal)) { throw 'Unexpected download host/repository.' }
            }
            $manifest=Invoke-RestMethod -Uri $manifestAsset[0].browser_download_url -Headers $headers -TimeoutSec 20
            if($manifest.version -ne $release.tag_name -or $asset[0].size -gt 536870912) { throw 'Release version/size mismatch.' }
            $backup=Join-Path $PSScriptRoot ('backups\'+[DateTime]::UtcNow.ToString('yyyyMMdd-HHmmss')+'-'+[Guid]::NewGuid().ToString('N'))
            New-Item -ItemType Directory -Path $backup -Force | Out-Null
            $zip=Join-Path $backup 'nexus-update.zip'
            Invoke-WebRequest -Uri $asset[0].browser_download_url -Headers $headers -OutFile $zip -UseBasicParsing -TimeoutSec 180
            $ready=$false
            $count=Install-NexusPackage $clientRoot $zip $manifest $backup
            $ready=$true
            [IO.File]::WriteAllText($installed,$release.tag_name)
            Add-Content -LiteralPath $log -Value "$(Get-Date -Format o) Installed $($release.tag_name); changed files=$count; backup=$backup"
        }
    }
} catch {
    Add-Content -LiteralPath $log -Value "$(Get-Date -Format o) Update skipped/rolled back: $($_.Exception.Message)"
    # Download/validation failures preserve the installed client and allow offline play.
} finally { if($lock){$lock.Dispose()} }
if(!$lock) { exit 2 } # Another launcher owns the update; never start mid-install.
if(!$ready) { exit 3 }
if(!$CheckOnly -and (Test-Path -LiteralPath $exe)) {
    if($Profile -and $Profile -notmatch '^[a-zA-Z0-9_.-]+$'){throw 'Invalid profile name.'}
    $argsList=if($Profile){@('--profile',$Profile)}else{@()}
    if($argsList.Count){Start-Process -FilePath $exe -WorkingDirectory $clientRoot -ArgumentList $argsList}
    else {Start-Process -FilePath $exe -WorkingDirectory $clientRoot}
}
