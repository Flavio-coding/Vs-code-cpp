# ═══════════════════════════════════════════════════════════════════════════════
#  VS Code C/C++ IDE — Windows Installer
#  Scarica: VS Code Portable + GCC/MinGW-w64 (winlibs) + estensioni
#  NON richiede admin. NON modifica il PATH di sistema. NON serve riavvio.
# ═══════════════════════════════════════════════════════════════════════════════
#
#  USO:
#    .\install.ps1                          # interattivo
#    .\install.ps1 -InstallDir D:\IDE       # cartella personalizzata
#    .\install.ps1 -Silent                  # senza conferme
#
# ═══════════════════════════════════════════════════════════════════════════════

param(
    [string]$InstallDir = "$env:LOCALAPPDATA\VSCodeCPP",
    [switch]$Silent
)

Set-StrictMode -Version Latest
$ErrorActionPreference = 'Stop'

# ── Costanti ─────────────────────────────────────────────────────────────────

# URL per il download di VS Code Portable (sempre aggiornato all'ultima stable)
$VSCODE_URL = "https://update.code.visualstudio.com/latest/win32-x64-archive/stable"

# URL VSIX dell'estensione cpp-runner dal repo GitHub
$REPO_BRANCH = "claude/vscode-cpp-ide-mingw-EKrIV"
$REPO_RAW    = "https://raw.githubusercontent.com/flavio-coding/vs-code-cpp/$REPO_BRANCH"
$VSIX_URL    = "$REPO_RAW/extension/cpp-runner.vsix"

# URL fallback GCC (winlibs GCC 16.1.0 + MinGW-w64 14.0.0 UCRT, POSIX, SEH)
# Fonte: https://winlibs.com  —  release verificata maggio 2026
$MINGW_FALLBACK_TAG  = "16.1.0posix-14.0.0-ucrt-r2"
$MINGW_FALLBACK_FILE = "winlibs-x86_64-posix-seh-gcc-16.1.0-mingw-w64ucrt-14.0.0-r2.zip"
$MINGW_FALLBACK_URL  = "https://github.com/brechtsanders/winlibs_mingw/releases/download/$MINGW_FALLBACK_TAG/$MINGW_FALLBACK_FILE"

$WIDTH = 62

# ── UI helpers ────────────────────────────────────────────────────────────────

function Write-Banner {
    $line = "=" * $WIDTH
    Write-Host ""
    Write-Host $line                                     -ForegroundColor Cyan
    Write-Host "  ⚡  VS Code C/C++ IDE  —  Installazione Windows"  -ForegroundColor Cyan
    Write-Host "  Non richiede admin. Nessun riavvio necessario."    -ForegroundColor DarkCyan
    Write-Host $line                                     -ForegroundColor Cyan
    Write-Host ""
}

function Write-Step([int]$n, [int]$total, [string]$text) {
    Write-Host ""
    Write-Host "  [$n/$total] $text" -ForegroundColor Yellow
}

function Write-Ok([string]$text)   { Write-Host "        OK  $text" -ForegroundColor Green }
function Write-Warn([string]$text) { Write-Host "        !   $text" -ForegroundColor Yellow }
function Write-Info([string]$text) { Write-Host "        ->  $text" -ForegroundColor Gray }
function Write-Err([string]$text)  { Write-Host "        ERR $text" -ForegroundColor Red }

# ── Download con barra di avanzamento ─────────────────────────────────────────

function Invoke-Download([string]$url, [string]$dest, [string]$label) {
    Write-Info "Scarico: $label"
    $tmp = "$dest.part"

    # Rimuovi file parziali precedenti
    Remove-Item $tmp -ErrorAction SilentlyContinue

    try {
        # Metodo 1: WebClient asincrono con progress
        $wc = New-Object System.Net.WebClient
        $wc.Headers.Add("User-Agent", "VSCodeCPP-Installer/2.0")
        $done = $false
        $err  = $null

        $wc.DownloadFileCompleted   += { $done = $true }
        $wc.DownloadProgressChanged += {
            param($s, $e)
            $rx  = [math]::Round($e.BytesReceived     / 1MB, 1)
            $tot = [math]::Round($e.TotalBytesToReceive / 1MB, 1)
            $pct = $e.ProgressPercentage
            $bar = "#" * [math]::Floor($pct / 5)
            $spc = " " * (20 - $bar.Length)
            Write-Host -NoNewline "`r        [$bar$spc] $pct%  $rx / $tot MB   "
        }

        $wc.DownloadFileAsync([uri]$url, $tmp)
        while (-not $done) { Start-Sleep -Milliseconds 150 }
        Write-Host ""   # newline dopo la barra

        if ($wc.IsBusy) { $wc.CancelAsync() }

    } catch {
        Write-Host ""
        Write-Warn "Metodo WebClient fallito ($($_.Exception.Message)). Riprovo con Invoke-WebRequest..."
        Invoke-WebRequest -Uri $url -OutFile $tmp -UseBasicParsing
    }

    if (-not (Test-Path $tmp) -or (Get-Item $tmp).Length -lt 100KB) {
        throw "Download fallito o file troppo piccolo: $label"
    }

    Move-Item -Path $tmp -Destination $dest -Force
    Write-Ok "$label scaricato ($('{0:N1}' -f ((Get-Item $dest).Length / 1MB)) MB)"
}

# ── Risoluzione URL MinGW (dinamica, con fallback) ────────────────────────────

function Resolve-MinGWUrl {
    Write-Info "Ricerca ultima versione GCC da winlibs.com..."
    try {
        $headers = @{ "User-Agent" = "VSCodeCPP-Installer/2.0"; "Accept" = "application/vnd.github+json" }
        $api  = Invoke-RestMethod "https://api.github.com/repos/brechtsanders/winlibs_mingw/releases/latest" `
                    -Headers $headers -TimeoutSec 10 -ErrorAction Stop

        # Cerca zip x86_64 + UCRT + POSIX (no LLVM, no 32-bit)
        $asset = $api.assets | Where-Object {
            $_.name -match "x86_64" -and
            $_.name -match "ucrt"   -and
            $_.name -match "posix"  -and
            $_.name -match "\.zip$" -and
            $_.name -notmatch "llvm" -and
            $_.name -notmatch "i686"
        } | Select-Object -First 1

        if ($asset) {
            $gccVer = ($api.tag_name -split "posix")[0]
            Write-Ok "Trovato GCC $gccVer (ultima versione da winlibs.com)"
            return $asset.browser_download_url
        }
    } catch {
        Write-Warn "GitHub API non raggiungibile ($($_.Exception.Message))"
    }

    Write-Info "Uso versione di fallback verificata: GCC 16.1.0 + MinGW-w64 14.0.0 UCRT"
    return $MINGW_FALLBACK_URL
}

# ── Estrazione ZIP ────────────────────────────────────────────────────────────

function Expand-ZipTo([string]$zip, [string]$dest) {
    Write-Info "Estrazione ZIP in corso (attendere)..."
    Add-Type -AssemblyName System.IO.Compression.FileSystem
    [System.IO.Compression.ZipFile]::ExtractToDirectory($zip, $dest)
}

# ═══════════════════════════════════════════════════════════════════════════════
#  MAIN
# ═══════════════════════════════════════════════════════════════════════════════

Write-Banner

Write-Host "  Cartella di installazione : $InstallDir"    -ForegroundColor White
Write-Host "  Dimensione download totale : ~300-400 MB"   -ForegroundColor DarkGray
Write-Host "  Riavvio Windows richiesto  : NO"            -ForegroundColor DarkGray
Write-Host "  Modifica PATH di sistema   : NO"            -ForegroundColor DarkGray
Write-Host ""

if (-not $Silent) {
    $ok = Read-Host "  Continuare con l'installazione? [S/n]"
    if ($ok -match "^[nN]") { Write-Host "  Annullato."; exit 0 }
    Write-Host ""
}

# Gestione directory esistente
if ((Test-Path "$InstallDir\vscode") -or (Test-Path "$InstallDir\mingw64")) {
    Write-Warn "Installazione precedente rilevata in $InstallDir"
    if (-not $Silent) {
        $ow = Read-Host "  Sovrascrivere? [s/N]"
        if ($ow -notmatch "^[sS]") { Write-Host "  Annullato."; exit 0 }
    }
    Write-Info "Rimozione installazione precedente..."
    Remove-Item -Recurse -Force "$InstallDir\vscode"  -ErrorAction SilentlyContinue
    Remove-Item -Recurse -Force "$InstallDir\mingw64" -ErrorAction SilentlyContinue
}

New-Item -ItemType Directory -Path "$InstallDir\tmp" -Force | Out-Null

# ── STEP 1: VS Code Portable ──────────────────────────────────────────────────
Write-Step 1 5 "Download VS Code Portable (ultima versione stable)..."

$vscodeZip = "$InstallDir\tmp\vscode.zip"
if (Test-Path $vscodeZip) {
    Write-Info "Zip VS Code già presente, salto il download."
} else {
    Invoke-Download $VSCODE_URL $vscodeZip "VS Code Portable"
}

Write-Info "Estrazione VS Code..."
$vscodeDir = "$InstallDir\vscode"
New-Item -ItemType Directory -Path $vscodeDir -Force | Out-Null
Expand-ZipTo $vscodeZip $vscodeDir
$codeExe = "$vscodeDir\Code.exe"
if (-not (Test-Path $codeExe)) { throw "Code.exe non trovato dopo l'estrazione." }

# Attiva la modalità portabile di VS Code (crea cartella 'data' accanto all'eseguibile)
# Documentazione: https://code.visualstudio.com/docs/editor/portable
$portableDataDir = "$vscodeDir\data"
New-Item -ItemType Directory -Path "$portableDataDir\user-data\User"  -Force | Out-Null
New-Item -ItemType Directory -Path "$portableDataDir\extensions"       -Force | Out-Null
Write-Ok "VS Code Portable estratto e configurato"

# ── STEP 2: MinGW-w64 / GCC ───────────────────────────────────────────────────
Write-Step 2 5 "Download GCC / MinGW-w64 (winlibs.com)..."

$mingwUrl = Resolve-MinGWUrl
$mingwZip = "$InstallDir\tmp\mingw.zip"

if (Test-Path $mingwZip) {
    Write-Info "Zip MinGW già presente, salto il download."
} else {
    Invoke-Download $mingwUrl $mingwZip "GCC MinGW-w64"
}

$mingwExtractDir = "$InstallDir\tmp\mingw_extracted"
New-Item -ItemType Directory -Path $mingwExtractDir -Force | Out-Null
Expand-ZipTo $mingwZip $mingwExtractDir

# winlibs estrae in una sottocartella (es. mingw64/)
$mingwSub = Get-ChildItem $mingwExtractDir -Directory | Select-Object -First 1
if (-not $mingwSub) { throw "Struttura MinGW non trovata nell'archivio." }
Move-Item $mingwSub.FullName "$InstallDir\mingw64" -Force
$mingwBin = "$InstallDir\mingw64\bin"

# Verifica che gcc.exe esista davvero
$gccExe = "$mingwBin\gcc.exe"
if (-not (Test-Path $gccExe)) { throw "gcc.exe non trovato in $mingwBin" }

# Verifica funzionamento: esegui gcc --version
$gccVer = & $gccExe --version 2>&1 | Select-Object -First 1
Write-Ok "GCC verificato: $gccVer"

# ── STEP 3: Estensione cpp-runner (VSIX) ──────────────────────────────────────
Write-Step 3 5 "Download estensione C/C++ Runner..."

$vsixDest = "$InstallDir\tmp\cpp-runner.vsix"
try {
    Invoke-Download $VSIX_URL $vsixDest "cpp-runner.vsix"
} catch {
    Write-Warn "Impossibile scaricare il VSIX dal repo: $($_.Exception.Message)"
    Write-Warn "L'estensione cpp-runner non verrà installata. Puoi installarla manualmente."
    $vsixDest = $null
}

# ── STEP 4: Configurazione VS Code ───────────────────────────────────────────
Write-Step 4 5 "Configurazione impostazioni VS Code..."

$userDataDir = "$vscodeDir\data\user-data\User"
$extDataDir  = "$vscodeDir\data\extensions"

# settings.json: tutto puntato al compilatore bundled
# NB: il percorso usa il path assoluto calcolato durante l'installazione.
#     Non si tocca il PATH di sistema, quindi NON serve riavvio.
$settings = [ordered]@{
    # ── cpp-runner: percorso al compilatore bundled ──────────────────────────
    "cpp-runner.compilerPath"                        = $mingwBin.Replace('\','\\')
    "cpp-runner.cCompiler"                           = "gcc"
    "cpp-runner.cppCompiler"                         = "g++"
    "cpp-runner.compileArgs"                         = @("-Wall", "-Wextra", "-g", "-std=c17")
    "cpp-runner.showTimings"                         = $true

    # ── cpptools IntelliSense ────────────────────────────────────────────────
    "C_Cpp.default.compilerPath"                     = $gccExe.Replace('\','\\')
    "C_Cpp.default.cStandard"                        = "c17"
    "C_Cpp.default.cppStandard"                      = "c++17"
    "C_Cpp.default.intelliSenseMode"                 = "windows-gcc-x64"
    "C_Cpp.autocompleteAddParentheses"               = $true
    "C_Cpp.inlayHints.autoDeclarationTypes.enabled"  = $true
    "C_Cpp.inlayHints.parameterNames.enabled"        = $true

    # ── Editor ───────────────────────────────────────────────────────────────
    "editor.fontSize"                                = 14
    "editor.fontFamily"                              = "'Consolas', 'Courier New', monospace"
    "editor.tabSize"                                 = 4
    "editor.detectIndentation"                       = $false
    "editor.minimap.enabled"                         = $false
    "editor.suggestSelection"                        = "first"
    "editor.bracketPairColorization.enabled"         = $true
    "editor.guides.bracketPairs"                     = $true
    "editor.renderWhitespace"                        = "selection"
    "editor.formatOnSave"                            = $false

    # ── Workbench ────────────────────────────────────────────────────────────
    "workbench.colorTheme"                           = "Default Dark Modern"
    "workbench.startupEditor"                        = "newUntitledFile"

    # ── Files ────────────────────────────────────────────────────────────────
    "files.defaultLanguage"                          = "c"
    "files.autoSave"                                 = "onFocusChange"
    "files.associations"                             = @{ "*.h" = "c"; "*.hpp" = "cpp" }
} | ConvertTo-Json -Depth 5

Set-Content -Path "$userDataDir\settings.json" -Value $settings -Encoding UTF8
Write-Ok "settings.json scritto"

# Installa le estensioni in modalità offline (--extensions-dir punta al portable data)
Write-Info "Installazione estensioni (potrebbe richiedere qualche minuto)..."

if ($vsixDest -and (Test-Path $vsixDest)) {
    Write-Info "Installo cpp-runner.vsix..."
    $p = Start-Process -FilePath $codeExe `
         -ArgumentList "--extensions-dir `"$extDataDir`" --install-extension `"$vsixDest`" --force" `
         -Wait -PassThru -WindowStyle Hidden
    if ($p.ExitCode -eq 0) { Write-Ok "Estensione cpp-runner installata" }
    else { Write-Warn "Installazione cpp-runner non riuscita (ExitCode $($p.ExitCode))" }
}

foreach ($extId in @("ms-vscode.cpptools")) {
    Write-Info "Installo $extId (IntelliSense)..."
    $p = Start-Process -FilePath $codeExe `
         -ArgumentList "--extensions-dir `"$extDataDir`" --install-extension $extId --force" `
         -Wait -PassThru -WindowStyle Hidden
    if ($p.ExitCode -eq 0) { Write-Ok "$extId installato" }
    else { Write-Warn "$extId: installazione non riuscita, verrà scaricato al primo avvio" }
}

# ── STEP 5: Collegamento desktop e launcher ───────────────────────────────────
Write-Step 5 5 "Creazione collegamento e file di avvio..."

# Launcher .bat: aggiunge il bin di MinGW al PATH di QUESTA sessione soltanto
# (non cambia il PATH globale del sistema)
$launcher = @"
@echo off
:: Avvia VS Code C/C++ IDE
:: MinGW bin e' nel PATH solo per questa finestra CMD, non per il sistema.
set "MINGW_BIN=%~dp0mingw64\bin"
set "PATH=%MINGW_BIN%;%PATH%"
start "" "%~dp0vscode\Code.exe" %*
"@
Set-Content -Path "$InstallDir\VSCodeCPP.bat" -Value $launcher -Encoding ASCII

# Collegamento .lnk sul desktop
$desktop = [Environment]::GetFolderPath("Desktop")
$lnkPath = "$desktop\VS Code C++ IDE.lnk"
$wsh = New-Object -ComObject WScript.Shell
$lnk = $wsh.CreateShortcut($lnkPath)
$lnk.TargetPath       = $codeExe
$lnk.WorkingDirectory = $InstallDir
$lnk.Description      = "VS Code C/C++ IDE con GCC MinGW-w64"
$lnk.Save()
Write-Ok "Collegamento creato: $lnkPath"

# ── Pulizia file temporanei ────────────────────────────────────────────────────
Write-Info "Pulizia file temporanei..."
Remove-Item -Recurse -Force "$InstallDir\tmp" -ErrorAction SilentlyContinue

# ═══════════════════════════════════════════════════════════════════════════════
#  COMPLETATO
# ═══════════════════════════════════════════════════════════════════════════════

$line = "=" * $WIDTH
Write-Host ""
Write-Host $line -ForegroundColor Green
Write-Host ""
Write-Host "  INSTALLAZIONE COMPLETATA" -ForegroundColor Green
Write-Host ""
Write-Host "  Cartella    : $InstallDir"                 -ForegroundColor White
Write-Host "  Compilatore : $gccExe"                     -ForegroundColor White
Write-Host "  GCC         : $gccVer"                     -ForegroundColor White
Write-Host "  Desktop     : VS Code C++ IDE"             -ForegroundColor White
Write-Host ""
Write-Host "  RIAVVIO WINDOWS: NON necessario"           -ForegroundColor Green
Write-Host "  PATH di sistema: NON modificato"           -ForegroundColor Green
Write-Host ""
Write-Host "  Come iniziare:" -ForegroundColor Cyan
Write-Host "    1. Apri 'VS Code C++ IDE' dal desktop"   -ForegroundColor White
Write-Host "    2. Crea un file .c o .cpp  (Ctrl+N)"     -ForegroundColor White
Write-Host "    3. Scrivi il codice"                     -ForegroundColor White
Write-Host "    4. Premi F5 per compilare ed eseguire"   -ForegroundColor White
Write-Host "    5. L'output compare nel pannello a destra" -ForegroundColor White
Write-Host ""
Write-Host $line -ForegroundColor Green
Write-Host ""

if (-not $Silent) {
    $launch = Read-Host "  Aprire VS Code adesso? [S/n]"
    if ($launch -notmatch "^[nN]") {
        Start-Process $codeExe
    }
}
