& {
[Console]::OutputEncoding = [System.Text.Encoding]::UTF8

$confirm = Read-Host '  Veut-tu vraiment réparer le problème Pas de connexion internet ? Oui ou non'
if ($confirm -notin @('O','o','Oui','oui','Y','y','Yes','yes')) {
    Write-Host ''
    Write-Host '  Opération annulée.' -ForegroundColor Red
    exit
}

cls

Write-Host ''
Write-Host "  ____  _   _ ____   ____ _____ ____  " -ForegroundColor Blue
Write-Host " | __ )| | | |  _ \ / ___| ____|  _ \ " -ForegroundColor Blue
Write-Host " |  _ \| | | | |_) | |  _|  _| | |_) |" -ForegroundColor Blue
Write-Host " | |_) | |_| |  _ <| |_| | |___|  _ < " -ForegroundColor Blue
Write-Host " |____/ \___/|_| \_\\____|_____|_| \_\" -ForegroundColor Blue
Write-Host ''
Write-Host '  Manifest Fix for SteamTools' -ForegroundColor Gray
Write-Host '  https://steamproof.net' -ForegroundColor DarkGray
Write-Host ''

$UA = 'Mozilla/5.0 (Windows NT 10.0; Win64; x64) AppleWebKit/537.36 (KHTML, like Gecko) Chrome/134.0.0.0 Safari/537.36'
$ok = [char]0x2713

function Fail($msg) {
    Write-Host "  X $msg" -ForegroundColor Red
    Write-Host ''; Write-Host '  Appuie sur une touche pour quitter...' -ForegroundColor DarkGray
    try { $null = $Host.UI.RawUI.ReadKey('NoEcho,IncludeKeyDown') } catch { Start-Sleep 10 }
    exit
}

function CloseSteam {
    if (-not (Get-Process -Name steam -EA SilentlyContinue)) { return }
    $steamExe = Join-Path $steamPath 'steam.exe'
    if (Test-Path $steamExe) { Start-Process $steamExe -ArgumentList '-shutdown' -EA SilentlyContinue }
    for ($i = 0; $i -lt 15; $i++) {
        if (-not (Get-Process -Name steam -EA SilentlyContinue)) { break }
        Start-Sleep 1
    }
    Get-Process -Name steam,steamwebhelper,steamservice -EA SilentlyContinue | Stop-Process -Force -EA SilentlyContinue
    Start-Sleep 2
    if (Get-Process -Name steam -EA SilentlyContinue) { Fail 'Impossible de fermer Steam. Ferme-le manuellement puis recommence.' }
    Write-Host "  $ok Steam fermé" -ForegroundColor Green
}

$steamPath = $null
foreach ($reg in @('HKCU:\Software\Valve\Steam','HKLM:\Software\Valve\Steam','HKLM:\Software\WOW6432Node\Valve\Steam')) {
    $p = (Get-ItemProperty -Path $reg -EA SilentlyContinue).SteamPath
    if ($p -and (Test-Path ($p -replace '/','\'))){ $steamPath = $p -replace '/','\\'; break }
}
if (-not $steamPath) { Fail 'Steam introuvable' }
Write-Host "  $ok Steam trouvé" -ForegroundColor Green

$steamExe = Join-Path $steamPath 'steam.exe'
try {
    $bytes = [System.IO.File]::ReadAllBytes($steamExe)
    $peOffset = [BitConverter]::ToInt32($bytes, 0x3C)
    $machine = [BitConverter]::ToUInt16($bytes, $peOffset + 4)
    if ($machine -ne 0x8664) {
        Write-Host "  ! Steam est en 32 bits, tentative de correction..." -ForegroundColor Yellow
        Remove-Item (Join-Path $steamPath 'steam.cfg') -Force -EA SilentlyContinue
        Remove-Item (Join-Path $steamPath 'package\beta') -Force -Recurse -EA SilentlyContinue
        CloseSteam
        Start-Process (Join-Path $steamPath 'steam.exe')
        Fail 'Fichiers bloquant la mise à jour supprimés. Steam devrait maintenant passer en 64 bits. Relance ce script après la mise à jour.'
    }
} catch {
    Fail "Impossible de vérifier Steam : $($_.Exception.Message)"
}
Write-Host "  $ok Steam est en 64 bits" -ForegroundColor Green

$dest = Join-Path $steamPath 'wtsapi32.dll'
$cleanup = @(
    (Join-Path $steamPath 'version.dll'),
    (Join-Path $steamPath 'config\manifests.dll'),
    (Join-Path $steamPath 'config\.mfx_init'),
    (Join-Path $steamPath 'config\.stfix_init')
)
$needsUpdate = $true

if (Test-Path $dest) {
    try {
        $req = [System.Net.HttpWebRequest]::Create('https://r2.steamproof.net/update')
        $req.Method = 'HEAD'
        $req.UserAgent = $UA
        $resp = $req.GetResponse()
        $remoteEtag = $resp.Headers['ETag'] -replace '"',''
        $resp.Close()
        $localHash = (Get-FileHash $dest -Algorithm MD5).Hash.ToLower()
        if ($remoteEtag -and $localHash -eq $remoteEtag) {
            Write-Host "  $ok Vérifié" -ForegroundColor Green
            $needsUpdate = $false
            Write-Host ''
            Write-Host '  [R] Redémarrer Steam  [U] Désinstaller  [Entrée] Quitter' -ForegroundColor DarkGray
            $key = $Host.UI.RawUI.ReadKey('NoEcho,IncludeKeyDown')
            if ($key.Character -eq 'u' -or $key.Character -eq 'U') {
                CloseSteam
                Remove-Item $dest -Force -EA SilentlyContinue
                $cleanup | ForEach-Object { Remove-Item $_ -Force -EA SilentlyContinue }
                Write-Host "  $ok Désinstallé" -ForegroundColor Green
                Write-Host ''
                Write-Host '  Appuie sur une touche pour quitter...' -ForegroundColor DarkGray
                try { $null = $Host.UI.RawUI.ReadKey('NoEcho,IncludeKeyDown') } catch { Start-Sleep 10 }
                exit
            }
            if ($key.Character -eq 'r' -or $key.Character -eq 'R') {
                CloseSteam
                Start-Process (Join-Path $steamPath 'steam.exe')
                Write-Host "  $ok Steam redémarré" -ForegroundColor Green
                Write-Host ''
                Write-Host '  Appuie sur une touche pour quitter...' -ForegroundColor DarkGray
                try { $null = $Host.UI.RawUI.ReadKey('NoEcho,IncludeKeyDown') } catch { Start-Sleep 10 }
            }
            exit
        }
    } catch {}
}

if ($needsUpdate) {
    CloseSteam
    $cleanup | ForEach-Object { Remove-Item $_ -Force -EA SilentlyContinue }
    Remove-Item $dest -Force -EA SilentlyContinue
    try {
        $req = [System.Net.HttpWebRequest]::Create('https://r2.steamproof.net/update')
        $req.UserAgent = $UA
        $resp = $req.GetResponse()
        $total = $resp.ContentLength
        $stream = $resp.GetResponseStream()
        $fs = [System.IO.File]::Create($dest)
        $buf = New-Object byte[] 65536
        $dl = 0
        while (($n = $stream.Read($buf, 0, $buf.Length)) -gt 0) {
            $fs.Write($buf, 0, $n); $dl += $n
            if ($total -gt 0) {
                $filled = [math]::Floor(($dl / $total) * 25)
                $bar = "$([char]0x2588)" * $filled + "$([char]0x2591)" * (25 - $filled)
                Write-Host "`r  Téléchargement  $bar  $('{0:N1}' -f ($dl/1MB))/$('{0:N1}' -f ($total/1MB)) MB" -NoNewline -ForegroundColor White
            }
        }
        $fs.Close(); $stream.Close(); $resp.Close()
        Write-Host "`r  $ok Correctif de manifeste téléchargé$(' ' * 40)" -ForegroundColor Green
    } catch {
        Fail "Échec du téléchargement : $($_.Exception.Message)"
    }
    if (-not (Test-Path $dest)) { Fail 'Le fichier n’a pas été enregistré' }
}

Start-Process (Join-Path $steamPath 'steam.exe')
Write-Host "  $ok Steam lancé" -ForegroundColor Green

Write-Host ''
if ($needsUpdate) {
    Write-Host "  $ok Le correctif de manifeste est installé !" -BackgroundColor Green -ForegroundColor Black
} else {
    Write-Host "  $ok Le correctif de manifeste est déjà à jour !" -BackgroundColor Green -ForegroundColor Black
}
Write-Host ''
Write-Host '  Appuie sur une touche pour quitter...' -ForegroundColor DarkGray
try { $null = $Host.UI.RawUI.ReadKey('NoEcho,IncludeKeyDown') } catch { Start-Sleep 10 }
}
