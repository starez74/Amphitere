# Download NetHackWiki XML, build an offline SQLite FTS4 index, install it in
# the existing debug app without touching the GGUF model or NetHack save files.
# This is a prototype: pages contain version-specific text and unrendered markup.
param([switch]$Install)
$ErrorActionPreference = 'Stop'
$Root = 'C:\Projects\NetHack-AI-Edition\Amphitere'
$Work = Join-Path $Root 'offline-wiki'
$Branch = 'feature/offline-ondevice-ai'
$Pkg = 'ca.b_ark.amphitere'
$ADB = Join-Path $env:LOCALAPPDATA 'Android\Sdk\platform-tools\adb.exe'
$Dump = Join-Path $Work 'nethackwiki_current.xml.gz'
$DB = Join-Path $Work 'wiki-index.sqlite'
$Builder = Join-Path $Root 'scripts\Build-OfflineWikiIndex.py'
$URL = 'https://archive.alt.org/nethackwiki/nethackwiki_current.xml.gz'
function Assert($condition, $message) { if (-not $condition) { throw $message } }

try {
    Assert $Install 'Run with -Install to approve downloading the wiki dump and installing the index.'
    Assert (Test-Path $ADB) "ADB not found: $ADB"
    Assert (Test-Path $Builder) "Builder missing: $Builder. Update your offline AI development branch first."
    $branchNow = (& git.exe -C $Root branch --show-current).Trim()
    Assert ($branchNow -eq $Branch) "Expected development branch $Branch, found $branchNow"
    $python = @()
    if (Get-Command py.exe -ErrorAction SilentlyContinue) { $python = @('py.exe', '-3') }
    elseif (Get-Command python.exe -ErrorAction SilentlyContinue) { $python = @('python.exe') }
    Assert ($python.Count -gt 0) 'Python 3 not found. Install Python 3 and retry; no app changes were made.'
    $versionArgs = @($python | Select-Object -Skip 1) + @('--version')
    $version = & $python[0] @versionArgs 2>&1
    Assert ($LASTEXITCODE -eq 0 -and "$version" -match 'Python 3\.') 'A working Python 3 is required.'
    $devices = @(& $ADB devices | Where-Object { $_ -match '^\S+\s+device\s*$' })
    Assert ($devices.Count -eq 1) 'Connect and authorize exactly one tablet'
    $serial = ($devices[0] -split '\s+')[0]
    $installed = @(& $ADB -s $serial shell pm path $Pkg)
    Assert ($installed -match 'package:') 'NetHack AI Edition is not installed'
    New-Item -ItemType Directory -Force -Path $Work | Out-Null
    if (-not (Test-Path $Dump) -or (Get-Item $Dump).Length -lt 1048576) {
        Write-Host 'Downloading official NetHackWiki current-page XML dump...' -ForegroundColor Cyan
        Invoke-WebRequest -Uri $URL -OutFile "$Dump.download"
        Assert ((Get-Item "$Dump.download").Length -gt 1048576) 'Wiki download looks incomplete'
        Move-Item -Force "$Dump.download" $Dump
    }
    Write-Host 'Building SQLite full-text wiki index with Python...' -ForegroundColor Cyan
    $buildArgs = @($python | Select-Object -Skip 1) + @($Builder, $Dump, $DB)
    & $python[0] @buildArgs
    Assert ($LASTEXITCODE -eq 0) 'Wiki index build failed. Existing app was not modified.'
    Assert (Test-Path $DB) 'Index missing after build'
    Write-Host 'Uploading index to a temporary Android location...' -ForegroundColor Cyan
    $remote = '/data/local/tmp/nethack-wiki-index.sqlite'
    & $ADB -s $serial push $DB $remote
    Assert ($LASTEXITCODE -eq 0) 'ADB upload failed'
    # run-as is permitted for this debug build. Preserve existing GGUF and game saves.
    & $ADB -s $serial shell run-as $Pkg mkdir -p files/offline-ai
    Assert ($LASTEXITCODE -eq 0) 'Could not access app storage'
    & $ADB -s $serial shell run-as $Pkg chmod 700 files/offline-ai
    Assert ($LASTEXITCODE -eq 0) 'Could not fix index-directory permissions'
    & $ADB -s $serial shell run-as $Pkg cp $remote files/offline-ai/wiki-index.sqlite.tmp
    Assert ($LASTEXITCODE -eq 0) 'Could not copy index into app private storage'
    & $ADB -s $serial shell run-as $Pkg chmod 600 files/offline-ai/wiki-index.sqlite.tmp
    Assert ($LASTEXITCODE -eq 0) 'Could not set index permissions'
    & $ADB -s $serial shell run-as $Pkg mv -f files/offline-ai/wiki-index.sqlite.tmp files/offline-ai/wiki-index.sqlite
    Assert ($LASTEXITCODE -eq 0) 'Could not finish index installation'
    & $ADB -s $serial shell rm -f $remote
    $remoteSize = & $ADB -s $serial shell run-as $Pkg ls -l files/offline-ai/wiki-index.sqlite
    Write-Host $remoteSize
    Write-Host 'Offline wiki index installed. No GGUF or saved game was deleted.' -ForegroundColor Green
    Write-Host 'NOTE: A debug APK built from the updated development branch is required to USE the index.'
    Write-Host 'Run Benchmark-OfflineCompanion.ps1 -Install to rebuild and verify wiki-backed answers.'
    Write-Host 'Wiki content attribution: https://nethackwiki.com/wiki/NetHackWiki:Copyrights'
} catch {
    Write-Host ("STOPPED: " + $_.Exception.Message) -ForegroundColor Red
    exit 1
}
