param(
    [ValidateSet('Check','Download','Apply')][string]$Mode='Check',
    [ValidatePattern('^[a-zA-Z0-9-]{1,64}$')][string]$Session,
    [ValidatePattern('^v?[0-9.]{1,40}$')][string]$CurrentVersion,
    [int]$WaitPid=0,
    [ValidatePattern('^[a-zA-Z0-9_.-]*$')][string]$Profile=''
)
$ErrorActionPreference='Stop'
. (Join-Path $PSScriptRoot 'Update-Library.ps1')
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
