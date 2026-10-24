Set-StrictMode -Version Latest
function Invoke-NexusInClientUpdate {
param(
    [ValidateSet('Check','Download','Apply')][string]$Mode='Check',
    [ValidatePattern('^[a-zA-Z0-9-]{1,64}$')][string]$Session,
    [ValidatePattern('^v?[0-9.]{1,40}$')][string]$CurrentVersion,
    [int]$WaitPid=0,
    [ValidatePattern('^[a-zA-Z0-9_.-]*$')][string]$Profile=''
)
$ErrorActionPreference='Stop'
$clientRoot=Split-Path -Parent $PSScriptRoot
$repository='godejro/Nexus-Client'
$stateRoot=Join-Path $PSScriptRoot ('sessions\'+$Session)
$null=[IO.Directory]::CreateDirectory($stateRoot)
$statusPath=Join-Path $stateRoot 'status.json'
$requestPath=Join-Path $stateRoot 'request.json'
$zip=Join-Path $stateRoot 'nexus-update.zip'
$manifestPath=Join-Path $stateRoot 'update.json'
$headers=@{'User-Agent'='Nexus-InClient-Updater';'Accept'='application/vnd.github+json'}
[Net.ServicePointManager]::SecurityProtocol=[Net.SecurityProtocolType]::Tls12
$lock=$null
function Write-State([string]$Phase,[string]$Message,[long]$Done=0,[long]$Total=0,[string]$File='',[string]$Version='') {
    $value=@{phase=$Phase;message=$Message;done=$Done;total=$Total;file=$File;version=$Version}
    $tmp=$statusPath+'.tmp'
    [IO.File]::WriteAllText($tmp,($value | ConvertTo-Json -Compress),[Text.UTF8Encoding]::new($false))
    if([IO.File]::Exists($statusPath)){[IO.File]::Replace($tmp,$statusPath,(Join-Path $stateRoot 'status.previous.json'))}
    else{[IO.File]::Move($tmp,$statusPath)}
}
function Check-ReleaseUrl([string]$Url) {
    if(!$Url.StartsWith("https://github.com/$repository/releases/download/",[StringComparison]::Ordinal)) {throw 'Unexpected release URL.'}
}
function Start-Client {
    $exe=Join-Path $clientRoot 'Nexus Client.exe'
    if([IO.File]::Exists($exe)) {
        if($Profile){Start-Process -FilePath $exe -WorkingDirectory $clientRoot -WindowStyle Hidden -ArgumentList @('--profile',$Profile)}
        else{Start-Process -FilePath $exe -WorkingDirectory $clientRoot -WindowStyle Hidden}
    }
}
try {
    if(!$Session){throw 'Missing updater session.'}
    $lock=[IO.File]::Open((Join-Path $stateRoot 'worker.lock'),[IO.FileMode]::OpenOrCreate,[IO.FileAccess]::ReadWrite,[IO.FileShare]::None)
    if($Mode -eq 'Check') {
        $lastError=Join-Path $PSScriptRoot 'last-error.txt'
        if([IO.File]::Exists($lastError)) {
            $previousError=[IO.File]::ReadAllText($lastError)
            if($previousError) {
                [IO.File]::WriteAllText($lastError,'')
                Write-State 'error' ('Previous update was not installed: '+$previousError)
                exit 0
            }
        }
        Write-State 'checking' 'Checking for updates...'
        $release=Invoke-RestMethod "https://api.github.com/repos/$repository/releases/latest" -Headers $headers -TimeoutSec 20
        if($release.tag_name -notmatch '^v?[0-9.]{1,40}$'){throw 'Invalid release version.'}
        $latest=[version]$release.tag_name.TrimStart('v')
        $current=[version]$CurrentVersion.TrimStart('v')
        if($latest -le $current){Write-State 'current' 'Nexus Client is up to date.'; exit 0}
        $asset=@($release.assets | Where-Object name -eq 'nexus-update.zip')
        $manifest=@($release.assets | Where-Object name -eq 'update.json')
        if($asset.Count -ne 1 -or $manifest.Count -ne 1){throw 'Release package is incomplete.'}
        Check-ReleaseUrl $asset[0].browser_download_url
        Check-ReleaseUrl $manifest[0].browser_download_url
        if($asset[0].size -le 0 -or $asset[0].size -gt 536870912){throw 'Invalid update size.'}
        $request=@{version=$release.tag_name;url=$asset[0].browser_download_url;manifest=$manifest[0].browser_download_url;size=$asset[0].size}
        [IO.File]::WriteAllText($requestPath,($request | ConvertTo-Json),[Text.UTF8Encoding]::new($false))
        Write-State 'available' 'A new version is available.' 0 $asset[0].size 'nexus-update.zip' $release.tag_name
    } elseif($Mode -eq 'Download') {
        $request=Get-Content -LiteralPath $requestPath -Raw | ConvertFrom-Json
        Check-ReleaseUrl $request.url; Check-ReleaseUrl $request.manifest
        Write-State 'downloading' 'Downloading the update package...' 0 $request.size 'nexus-update.zip' $request.version
        $manifest=Invoke-RestMethod $request.manifest -Headers $headers -TimeoutSec 30
        if($manifest.version -ne $request.version){throw 'Manifest version mismatch.'}
        [IO.File]::WriteAllText($manifestPath,($manifest | ConvertTo-Json -Depth 12),[Text.UTF8Encoding]::new($false))
        $web=[Net.WebClient]::new(); $web.Headers['User-Agent']='Nexus-InClient-Updater'
        try {
            $download=$web.DownloadFileTaskAsync([Uri]$request.url,$zip)
            $deadline=[DateTime]::UtcNow.AddMinutes(5)
            while(!$download.IsCompleted) {
                if([DateTime]::UtcNow -gt $deadline){$web.CancelAsync(); throw 'Download timed out.'}
                $length=if([IO.File]::Exists($zip)){([IO.FileInfo]$zip).Length}else{0}
                if($length -gt 536870912){$web.CancelAsync(); throw 'Download exceeds size limit.'}
                Write-State 'downloading' 'Downloading the update package...' $length $request.size 'nexus-update.zip' $request.version
                Start-Sleep -Milliseconds 200
            }
            $download.GetAwaiter().GetResult()
        } finally {$web.Dispose()}
        if(([IO.FileInfo]$zip).Length -ne $request.size){throw 'Download size mismatch.'}
        $validation=Join-Path $stateRoot ('validation-'+[Guid]::NewGuid().ToString('N'))
        $progress={param($done,$total,$file) Write-State 'verifying' 'Checking downloaded files...' $done $total $file $request.version}
        $count=Install-NexusPackage $clientRoot $zip $manifest $validation -ValidateOnly -Progress $progress
        Write-State 'ready' 'Update downloaded. Restart to install.' $count $count '' $request.version
    } else {
        if($WaitPid -le 0){throw 'Missing client process ID.'}
        Write-State 'waiting' 'Waiting for Nexus Client to exit...'
        $process=Get-Process -Id $WaitPid -ErrorAction SilentlyContinue
        if($process -and !$process.WaitForExit(120000)){throw 'Client is still running; no files were replaced.'}
        $installLock=[IO.File]::Open((Join-Path $PSScriptRoot 'update.lock'),[IO.FileMode]::OpenOrCreate,[IO.FileAccess]::ReadWrite,[IO.FileShare]::None)
        try {
            $exe=Join-Path $clientRoot 'Nexus Client.exe'
            $other=Get-Process -ErrorAction SilentlyContinue | Where-Object {try {$_.Path -eq $exe}catch {$false}}
            if($other){throw 'Another Nexus Client is running from this folder. Close it before updating.'}
            $request=Get-Content -LiteralPath $requestPath -Raw | ConvertFrom-Json
            $manifest=Get-Content -LiteralPath $manifestPath -Raw | ConvertFrom-Json
            if($manifest.version -ne $request.version){throw 'Manifest version mismatch.'}
            $backup=Join-Path $PSScriptRoot ('backups\ingame-'+[Guid]::NewGuid().ToString('N'))
            $count=Install-NexusPackage $clientRoot $zip $manifest $backup
            [IO.File]::WriteAllText((Join-Path $PSScriptRoot 'installed-version.txt'),$request.version)
            Write-State 'installed' 'Update installed.' $count $count '' $request.version
        } finally {$installLock.Dispose()}
        Start-Client
    }
} catch {
    Write-State 'error' $_.Exception.Message
    if($Mode -eq 'Apply') {
        [IO.File]::WriteAllText((Join-Path $PSScriptRoot 'last-error.txt'),$_.Exception.Message)
        Start-Client
    }
    exit 1
} finally {if($lock){$lock.Dispose()}}
}
function Get-NexusSHA256([string]$Path) {
    $stream=[IO.File]::OpenRead($Path)
    $hash=[Security.Cryptography.SHA256]::Create()
    try { return [BitConverter]::ToString($hash.ComputeHash($stream)).Replace('-','').ToLowerInvariant() }
    finally { $hash.Dispose(); $stream.Dispose() }
}
function Test-NexusProgramPath([string]$Name) {
    if (!$Name -or $Name.Contains('\') -or $Name -match '(^/|:|(^|/)\.\.?(/|$)|[<>|?*\x00-\x1f])' -or $Name -match '(^|/)[^/]*[. ](/|$)') { return $false }
    if ($Name -match '//|(?i)(^|/)(CON|PRN|AUX|NUL|COM[0-9]|LPT[0-9])([.]|/|$)') { return $false }
    if ($Name -match '(?i)(^|/)(storage|config|credentials|accounts)\.(json|ini|otml)$|(^|/)(setups|lua scripts|scripts|settings|profiles|server_profiles)/') { return $false }
    if ($Name -in @('Nexus Client.exe','init.lua','LICENSE','cacert.pem','Nexus.ico','Nexus-256.png','URUCHOM_NEXUS.cmd')) { return $true }
    if ($Name -match '^updater/(Start-Nexus|Update-Library)\.ps1$') { return $true }
    if ($Name -match '^data/(cursors|fonts|images|styles|particles)/.+\.(lua|otui|png|otfont|otps|cur|ani|css)$') { return $true }
    if ($Name -match '^modules/.+\.(lua|otui|otmod|html|css|png|otfont|glsl|vert|frag|json)$') { return $true }
    if ($Name -match '^mods/(client_mods|client_profiles|client_textedit|game_buttons|game_itemselector|game_tasks)/.+\.(lua|otui|otmod|png|html|css|json)$') { return $true }
    if ($Name -match '^CWELBOT/nexus_bot/(core|ui|assets)/.+\.(lua|otui|png|ogg|wav|mp3|otfont|json)$') { return $true }
    if ($Name -match '^CWELBOT/nexus_bot/[^/]+\.(lua|otmod)$') { return $true }
    return $false
}
function Get-NexusChildPath([string]$Root,[string]$Name) {
    if (!(Test-NexusProgramPath $Name)) { throw "Forbidden update path: $Name" }
    $base=[IO.Path]::GetFullPath($Root).TrimEnd('\')+'\'
    $path=[IO.Path]::GetFullPath((Join-Path $base $Name))
    if (!$path.StartsWith($base,[StringComparison]::OrdinalIgnoreCase)) { throw 'Update path escaped client directory.' }
    $check=$path
    while ($check.Length -ge $base.TrimEnd('\').Length) {
        try {
            if ([IO.File]::GetAttributes($check) -band [IO.FileAttributes]::ReparsePoint) { throw "Junction/symlink not allowed: $check" }
        } catch [IO.FileNotFoundException] {} catch [IO.DirectoryNotFoundException] {}
        $check=[IO.Path]::GetDirectoryName($check)
        if (!$check) { break }
    }
    return $path
}
function Install-NexusPackage([string]$ClientRoot,[string]$Zip,[object]$Manifest,[string]$BackupRoot,[switch]$ValidateOnly,[scriptblock]$Progress) {
    $ErrorActionPreference='Stop'
    if ($Manifest.schema -ne 1 -or @($Manifest.files).Count -eq 0 -or @($Manifest.files).Count -gt 20000) { throw 'Unsupported/empty manifest.' }
    if ($Manifest.sha256 -notmatch '^[a-fA-F0-9]{64}$' -or (Get-NexusSHA256 $Zip) -ne $Manifest.sha256) { throw 'Package SHA256 mismatch.' }
    $expected=@{}; [long]$size=0
    foreach($file in $Manifest.files) {
        $null=Get-NexusChildPath $ClientRoot $file.path
        if ($expected.ContainsKey($file.path) -or $file.sha256 -notmatch '^[a-fA-F0-9]{64}$' -or $file.size -lt 0 -or $file.size -gt 134217728) { throw 'Invalid manifest entry.' }
        $expected[$file.path]=$file; $size+=$file.size
    }
    if ($size -gt 536870912) { throw 'Update exceeds 512 MB.' }
    $stage=Join-Path $BackupRoot 'stage'
    $null=[IO.Directory]::CreateDirectory($stage)
    Add-Type -AssemblyName System.IO.Compression,System.IO.Compression.FileSystem
    $archive=[IO.Compression.ZipFile]::OpenRead($Zip)
    try {
        $seen=@{}
        foreach($entry in $archive.Entries) {
            if (!$expected.ContainsKey($entry.FullName) -or $seen.ContainsKey($entry.FullName)) { throw "Unexpected/duplicate ZIP entry: $($entry.FullName)" }
            $file=$expected[$entry.FullName]; $seen[$entry.FullName]=$true
            if ($entry.Length -ne $file.size) { throw 'ZIP length mismatch.' }
            $dest=Get-NexusChildPath $stage $file.path
            $null=[IO.Directory]::CreateDirectory([IO.Path]::GetDirectoryName($dest))
            [IO.Compression.ZipFileExtensions]::ExtractToFile($entry,$dest,$false)
            if ((Get-NexusSHA256 $dest) -ne $file.sha256) { throw "File SHA256 mismatch: $($file.path)" }
            if ($Progress) { & $Progress $seen.Count $expected.Count $file.path }
        }
        if ($seen.Count -ne $expected.Count) { throw 'Incomplete package.' }
    } finally { $archive.Dispose() }
    if ($ValidateOnly) { return $expected.Count }
    # Every entry is verified BEFORE modifying any installed file.
    $legacy=Join-Path ([IO.Path]::GetFullPath($ClientRoot)) 'mods\game_bot'
    if((Test-Path -LiteralPath $legacy) -and ((Get-Item -LiteralPath $legacy).Attributes -band [IO.FileAttributes]::ReparsePoint)) { throw 'Legacy bot is a junction; move it manually.' }
    $done=[Collections.Generic.List[object]]::new()
    try {
        foreach($file in $Manifest.files) {
            $dest=Get-NexusChildPath $ClientRoot $file.path
            if ([IO.File]::Exists($dest) -and (Get-NexusSHA256 $dest) -eq $file.sha256) { continue }
            $old=Get-NexusChildPath (Join-Path $BackupRoot 'previous') $file.path
            if ([IO.Directory]::Exists($dest)) { throw "A directory occupies the update file path: $($file.path)" }
            $existed=[IO.File]::Exists($dest)
            if ($existed) { $null=[IO.Directory]::CreateDirectory([IO.Path]::GetDirectoryName($old)); [IO.File]::Copy($dest,$old,$false) }
            $done.Add(@{Path=$file.path;Existed=$existed})
            $null=[IO.Directory]::CreateDirectory([IO.Path]::GetDirectoryName($dest))
            [IO.File]::Copy((Get-NexusChildPath $stage $file.path),$dest,$true)
            if ((Get-NexusSHA256 $dest) -ne $file.sha256) { throw "Installed hash mismatch: $($file.path)" }
        }
        # Archive, never delete, the retired bot and its private configuration.
        if(Test-Path -LiteralPath $legacy) {
            Move-Item -LiteralPath $legacy -Destination (Join-Path $BackupRoot 'retired-game_bot')
        }
    } catch {
        $failure=$_; $rollbackErrors=@()
        for($i=$done.Count-1;$i -ge 0;$i--) {
            try {
                $entry=$done[$i]; $dest=Get-NexusChildPath $ClientRoot $entry.Path
                if($entry.Existed) {
                    $old=Get-NexusChildPath (Join-Path $BackupRoot 'previous') $entry.Path
                    if(!(Test-Path -LiteralPath $dest) -or (Get-NexusSHA256 $dest) -ne (Get-NexusSHA256 $old)) {
                        Copy-Item -LiteralPath $old -Destination $dest -Force
                    }
                } elseif(Test-Path -LiteralPath $dest) { Remove-Item -LiteralPath $dest }
            } catch { $rollbackErrors+=$_.Exception.Message }
        }
        if($rollbackErrors.Count) { throw "Update failed: $($failure.Exception.Message). Restore backup $BackupRoot manually: $($rollbackErrors -join '; ')" }
        throw $failure
    }
    return $done.Count
}
