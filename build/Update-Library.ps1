Set-StrictMode -Version Latest
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
        if ((Test-Path -LiteralPath $check) -and ((Get-Item -LiteralPath $check -Force).Attributes -band [IO.FileAttributes]::ReparsePoint)) { throw "Junction/symlink not allowed: $check" }
        $check=Split-Path -Parent $check
        if (!$check) { break }
    }
    return $path
}
function Install-NexusPackage([string]$ClientRoot,[string]$Zip,[object]$Manifest,[string]$BackupRoot) {
    $ErrorActionPreference='Stop'
    if ($Manifest.schema -ne 1 -or @($Manifest.files).Count -eq 0 -or @($Manifest.files).Count -gt 20000) { throw 'Unsupported/empty manifest.' }
    if ($Manifest.sha256 -notmatch '^[a-fA-F0-9]{64}$' -or (Get-FileHash -LiteralPath $Zip -Algorithm SHA256).Hash -ne $Manifest.sha256) { throw 'Package SHA256 mismatch.' }
    $expected=@{}; [long]$size=0
    foreach($file in $Manifest.files) {
        $null=Get-NexusChildPath $ClientRoot $file.path
        if ($expected.ContainsKey($file.path) -or $file.sha256 -notmatch '^[a-fA-F0-9]{64}$' -or $file.size -lt 0 -or $file.size -gt 134217728) { throw 'Invalid manifest entry.' }
        $expected[$file.path]=$file; $size+=$file.size
    }
    if ($size -gt 536870912) { throw 'Update exceeds 512 MB.' }
    $stage=Join-Path $BackupRoot 'stage'
    New-Item -ItemType Directory -Path $stage -Force | Out-Null
    Add-Type -AssemblyName System.IO.Compression,System.IO.Compression.FileSystem
    $archive=[IO.Compression.ZipFile]::OpenRead($Zip)
    try {
        $seen=@{}
        foreach($entry in $archive.Entries) {
            if (!$expected.ContainsKey($entry.FullName) -or $seen.ContainsKey($entry.FullName)) { throw "Unexpected/duplicate ZIP entry: $($entry.FullName)" }
            $file=$expected[$entry.FullName]; $seen[$entry.FullName]=$true
            if ($entry.Length -ne $file.size) { throw 'ZIP length mismatch.' }
            $dest=Get-NexusChildPath $stage $file.path
            New-Item -ItemType Directory -Path (Split-Path -Parent $dest) -Force | Out-Null
            [IO.Compression.ZipFileExtensions]::ExtractToFile($entry,$dest,$false)
            if ((Get-FileHash -LiteralPath $dest -Algorithm SHA256).Hash -ne $file.sha256) { throw "File SHA256 mismatch: $($file.path)" }
        }
        if ($seen.Count -ne $expected.Count) { throw 'Incomplete package.' }
    } finally { $archive.Dispose() }
    # Every entry is verified BEFORE modifying any installed file.
    $legacy=Join-Path ([IO.Path]::GetFullPath($ClientRoot)) 'mods\game_bot'
    if((Test-Path -LiteralPath $legacy) -and ((Get-Item -LiteralPath $legacy).Attributes -band [IO.FileAttributes]::ReparsePoint)) { throw 'Legacy bot is a junction; move it manually.' }
    $done=[Collections.Generic.List[object]]::new()
    try {
        foreach($file in $Manifest.files) {
            $dest=Get-NexusChildPath $ClientRoot $file.path
            if ((Test-Path -LiteralPath $dest) -and (Get-FileHash -LiteralPath $dest -Algorithm SHA256).Hash -eq $file.sha256) { continue }
            $old=Get-NexusChildPath (Join-Path $BackupRoot 'previous') $file.path
            $existed=Test-Path -LiteralPath $dest
            if ($existed) { New-Item -ItemType Directory -Path (Split-Path -Parent $old) -Force | Out-Null; Copy-Item -LiteralPath $dest -Destination $old }
            $done.Add(@{Path=$file.path;Existed=$existed})
            New-Item -ItemType Directory -Path (Split-Path -Parent $dest) -Force | Out-Null
            Copy-Item -LiteralPath (Get-NexusChildPath $stage $file.path) -Destination $dest -Force
            if ((Get-FileHash -LiteralPath $dest -Algorithm SHA256).Hash -ne $file.sha256) { throw "Installed hash mismatch: $($file.path)" }
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
                    if(!(Test-Path -LiteralPath $dest) -or (Get-FileHash -LiteralPath $dest -Algorithm SHA256).Hash -ne (Get-FileHash -LiteralPath $old -Algorithm SHA256).Hash) {
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
