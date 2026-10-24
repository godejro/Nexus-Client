$ErrorActionPreference='Stop'
. (Join-Path $PSScriptRoot 'Update-Library.ps1')
# Older installed launchers accept only these updater filenames. Keep new modes
# inside them; a new helper file would make the whole bootstrap update fail.
foreach($path in @('updater/Start-Nexus.ps1','updater/Update-Library.ps1')) {
    if(!(Test-NexusProgramPath $path)){throw "Legacy-compatible updater path rejected: $path"}
}
if(Test-NexusProgramPath 'updater/InClient-Update.ps1'){throw 'New helper path would break old launchers'}
foreach($bad in @('../secret','modules/../../secret','C:/secret','/modules/x.lua','modules\x.lua','modules//x.lua','modules/CON.lua','CWELBOT/lua scripts/test.lua','CWELBOT/nexus_bot/storage.json','config.ini','profiles/server/profile.json','data/things/1525/assets.zip')) {
    if(Test-NexusProgramPath $bad){throw "Allowed private/traversal path: $bad"}
}
$root=Join-Path ([IO.Path]::GetTempPath()) ('NexusUpdateTest-'+[Guid]::NewGuid().ToString('N'))
$source=Join-Path $root 'source'; $target=Join-Path $root 'target'
New-Item -ItemType Directory -Path "$source\modules\test","$target\modules\test","$target\CWELBOT\lua scripts" -Force | Out-Null
[IO.File]::WriteAllText("$source\modules\test\test.lua",'return 2')
[IO.File]::WriteAllText("$target\modules\test\test.lua",'return 1')
[IO.File]::WriteAllText("$target\CWELBOT\lua scripts\private.lua",'private')
[IO.File]::WriteAllText("$source\config.ini",'must not be published')
& "$PSScriptRoot\Build-Update.ps1" -ClientRoot $source -Output "$root\output" -Version 'test-1'
$manifest=Get-Content "$root\output\update.json" -Raw | ConvertFrom-Json
if(@($manifest.files).Count -ne 1){throw 'Private data included in package'}
$script:seenProgress=@()
$verified=Install-NexusPackage $target "$root\output\nexus-update.zip" $manifest "$root\validate-only" -ValidateOnly -Progress {param($done,$total,$file) $script:seenProgress+=@{done=$done;total=$total;file=$file}}
if($verified -ne 1 -or $script:seenProgress.Count -ne 1 -or $script:seenProgress[0].file -ne 'modules/test/test.lua'){throw 'Missing file progress'}
if((Get-Content "$target\modules\test\test.lua" -Raw) -ne 'return 1'){throw 'Download validation modified running client'}
$changed=Install-NexusPackage $target "$root\output\nexus-update.zip" $manifest "$root\backup"
if($changed -ne 1 -or (Get-Content "$target\modules\test\test.lua" -Raw) -ne 'return 2'){throw 'Install failed'}
if((Get-Content "$root\backup\previous\modules\test\test.lua" -Raw) -ne 'return 1'){throw 'Missing backup'}
if((Get-Content "$target\CWELBOT\lua scripts\private.lua" -Raw) -ne 'private'){throw 'Private script modified'}
$manifest.sha256='0'*64; $rejected=$false
try {Install-NexusPackage $target "$root\output\nexus-update.zip" $manifest "$root\bad"} catch {$rejected=$true}
if(!$rejected){throw 'Corrupt hash accepted'}
[IO.File]::WriteAllText("$source\modules\test\z.lua",'new file')
[IO.File]::WriteAllText("$target\modules\test\test.lua",'return 1')
New-Item -ItemType Directory -Path "$target\modules\test\z.lua" | Out-Null
& "$PSScriptRoot\Build-Update.ps1" -ClientRoot $source -Output "$root\rollback-output" -Version 'test-2'
$manifest=Get-Content "$root\rollback-output\update.json" -Raw | ConvertFrom-Json
$rejected=$false
try {Install-NexusPackage $target "$root\rollback-output\nexus-update.zip" $manifest "$root\rollback"} catch {$rejected=$true}
if(!$rejected -or (Get-Content "$target\modules\test\test.lua" -Raw) -ne 'return 1'){throw 'Partial install did not roll back'}
Write-Output "PASS: allowlist, traversal rejection, private data preserved, SHA256, installation, backup, rollback after partial failure; evidence=$root"
