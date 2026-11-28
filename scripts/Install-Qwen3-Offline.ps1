# Install Qwen3-0.6B Q4_K_M into the existing debug app without touching saves.
# ADB temporary files and partial PC downloads are cleaned up on success.
# Requires exactly one authorized tablet and explicit -Install.
param([switch]$Install, [switch]$KeepPcCopy)
$ErrorActionPreference = 'Stop'
$Root = 'C:\Projects\NetHack-AI-Edition'
$OutDir = Join-Path $Root 'offline-companion-test\models'
$ModelName = 'Qwen_Qwen3-0.6B-Q4_K_M.gguf'
$LocalModel = Join-Path $OutDir $ModelName
$Download = "$LocalModel.download"
$ModelUrl = 'https://huggingface.co/bartowski/Qwen_Qwen3-0.6B-GGUF/resolve/main/Qwen_Qwen3-0.6B-Q4_K_M.gguf?download=true'
$Adb = Join-Path $env:LOCALAPPDATA 'Android\Sdk\platform-tools\adb.exe'
$Package = 'ca.b_ark.amphitere'
$Target = 'files/offline-ai/offline-companion.gguf'
$TempTarget = 'files/offline-ai/qwen3-import.tmp'
$Remote = '/data/local/tmp/nethack-qwen3-06b.gguf'
$MinSize = 400000000L
$MaxSize = 650000000L
$ExpectedSha256 = '9acfc1e001311f34b4252001b626f2e466d592a42065f66571bff3790d4e1b14'
$Serial = $null
$Pushed = $false
$Finished = $false

function Check([bool]$ok, [string]$message) {
    if (-not $ok) { throw $message }
}
function Device([string[]]$argsList) {
    & $Adb -s $Serial @argsList
    Check ($LASTEXITCODE -eq 0) ("ADB command failed: " + ($argsList -join ' '))
}
try {
    Check $Install 'Pass -Install to approve downloading and installing Qwen3.'
    Check (Test-Path $Adb) "ADB not found: $Adb"
    $devices = @(& $Adb devices | Where-Object { $_ -match '^\S+\s+device\s*$' })
    Check ($devices.Count -eq 1) 'Connect and authorize exactly one tablet.'
    $Serial = ($devices[0] -split '\s+')[0]
    $existing = @(& $Adb -s $Serial shell pm path $Package)
    Check ((($existing -join "`n") -match 'package:')) 'Existing NetHack debug app not installed.'
    Device -argsList @('shell','run-as',$Package,'test','-d','files')
    New-Item -ItemType Directory -Force -Path $OutDir | Out-Null

    if ((Test-Path $LocalModel) -and (Get-Item $LocalModel).Length -ge $MinSize -and
        (Get-Item $LocalModel).Length -le $MaxSize) {
        Write-Host 'Using verified-size local Qwen3 GGUF file.' -ForegroundColor Cyan
    } else {
        Write-Host '=== DOWNLOAD QWEN3-0.6B Q4_K_M TO PC ===' -ForegroundColor Cyan
        if (Test-Path $Download) { Remove-Item -LiteralPath $Download -Force }
        Invoke-WebRequest -Uri $ModelUrl -OutFile $Download -UseBasicParsing
        $size = (Get-Item $Download).Length
        Check ($size -ge $MinSize -and $size -le $MaxSize) "Unexpected model size: $size bytes"
        Move-Item -Force -LiteralPath $Download -Destination $LocalModel
    }
    # Read just 4 bytes, not the complete 480 MB file.
    $handle = [System.IO.File]::OpenRead($LocalModel)
    try {
        $header = New-Object byte[] 4
        Check ($handle.Read($header,0,4) -eq 4) 'GGUF header could not be read'
        Check ([System.Text.Encoding]::ASCII.GetString($header) -eq 'GGUF') 'Invalid GGUF header'
    } finally { $handle.Dispose() }
    $localSize = (Get-Item $LocalModel).Length
    Check ($localSize -ge $MinSize -and $localSize -le $MaxSize) 'GGUF size outside expected range'
    $localHash = (Get-FileHash -Algorithm SHA256 -LiteralPath $LocalModel).Hash.ToLowerInvariant()
    Check ($localHash -eq $ExpectedSha256) 'Downloaded model checksum does not match the published SHA256; refusing installation.'
    Write-Host ("Qwen3 file: {0:N1} MiB, SHA256 {1}" -f ($localSize/1MB), $localHash)
    Write-Host '=== UPLOAD MODEL TO TABLET ===' -ForegroundColor Cyan
    Device -argsList @('shell','am','force-stop',$Package)
    Device -argsList @('push',$LocalModel,$Remote)
    $Pushed = $true
    Device -argsList @('shell','run-as',$Package,'mkdir','-p','files/offline-ai')
    Device -argsList @('shell','run-as',$Package,'chmod','700','files/offline-ai')
    Device -argsList @('shell','run-as',$Package,'cp',$Remote,$TempTarget)
    Device -argsList @('shell','run-as',$Package,'chmod','600',$TempTarget)
    $tabletHash = (& $Adb -s $Serial shell run-as $Package sha256sum $TempTarget)
    Check ($LASTEXITCODE -eq 0) 'Could not calculate tablet model SHA256'
    $tabletHashText = ($tabletHash -join "`n")
    $tabletHashMatch = [regex]::Match($tabletHashText.Trim(), '^([0-9a-fA-F]{64})\s')
    Check $tabletHashMatch.Success 'Unexpected tablet SHA256 response'
    Check ($tabletHashMatch.Groups[1].Value.ToLowerInvariant() -eq $localHash) 'SHA256 mismatch! Existing model has not been replaced.'
    Write-Host 'Verified identical SHA256 hashes on PC and tablet.' -ForegroundColor Green
    # Atomic rename replaces only the model filename, not wiki or game saves.
    Device -argsList @('shell','run-as',$Package,'mv','-f',$TempTarget,$Target)
    Device -argsList @('shell','run-as',$Package,'test','-f',$Target)
    $Finished = $true
    Write-Host 'Qwen3 model successfully installed in private app storage.' -ForegroundColor Green
} catch {
    Write-Host ("STOPPED SAFELY: " + $_.Exception.Message) -ForegroundColor Red
    exit 1
} finally {
    if ($Serial) {
        & $Adb -s $Serial shell rm -f $Remote 2>$null | Out-Null
        & $Adb -s $Serial shell run-as $Package rm -f $TempTarget 2>$null | Out-Null
    }
    if ($Finished -and -not $KeepPcCopy -and (Test-Path $LocalModel)) {
        Remove-Item -LiteralPath $LocalModel -Force
        Write-Host 'Removed temporary PC copy to conserve storage.'
    }
}
