param([Parameter(Mandatory=$true)][string]$ClientRoot,[Parameter(Mandatory=$true)][string]$Output,[Parameter(Mandatory=$true)][string]$Version)
$ErrorActionPreference='Stop'
. (Join-Path $PSScriptRoot 'Update-Library.ps1')
Add-Type -AssemblyName System.IO.Compression,System.IO.Compression.FileSystem
$clientRoot=[IO.Path]::GetFullPath($ClientRoot).TrimEnd('\')
New-Item -ItemType Directory -Path $Output -Force | Out-Null
$zip=Join-Path $Output 'nexus-update.zip'
if(Test-Path -LiteralPath $zip){throw 'Choose an unused output directory.'}
$archive=[IO.Compression.ZipFile]::Open($zip,[IO.Compression.ZipArchiveMode]::Create)
$files=@()
try {
    foreach($file in Get-ChildItem -LiteralPath $clientRoot -Recurse -File | Sort-Object FullName) {
        $name=$file.FullName.Substring($clientRoot.Length+1).Replace('\','/')
        if(!(Test-NexusProgramPath $name)){continue}
        $null=Get-NexusChildPath $clientRoot $name
        $files+=@{path=$name;size=$file.Length;sha256=(Get-FileHash -LiteralPath $file.FullName -Algorithm SHA256).Hash.ToLowerInvariant()}
        $null=[IO.Compression.ZipFileExtensions]::CreateEntryFromFile($archive,$file.FullName,$name,[IO.Compression.CompressionLevel]::Optimal)
    }
} finally {$archive.Dispose()}
$manifest=@{schema=1;version=$Version;sha256=(Get-FileHash -LiteralPath $zip -Algorithm SHA256).Hash.ToLowerInvariant();files=$files}
[IO.File]::WriteAllText((Join-Path $Output 'update.json'),($manifest|ConvertTo-Json -Depth 6),[Text.UTF8Encoding]::new($false))
Write-Output "Prepared $($files.Count) program files. No server assets or player configurations."
