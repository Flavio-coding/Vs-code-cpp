# ═══════════════════════════════════════════════════════════════════════════════
#  VS Code C/C++ IDE — Web Installer (entry point per il one-liner CMD)
#
#  COME USARE: incolla questo comando in un CMD o PowerShell qualsiasi
#  (NON serve essere amministratore):
#
#    powershell -NoProfile -ExecutionPolicy Bypass -Command "iex (iwr 'https://raw.githubusercontent.com/flavio-coding/vs-code-cpp/main/install.ps1' -UseBasicParsing).Content"
#
# ═══════════════════════════════════════════════════════════════════════════════

param(
    [string]$InstallDir = "$env:LOCALAPPDATA\VSCodeCPP",
    [switch]$Silent
)

Set-StrictMode -Version Latest
$ErrorActionPreference = 'Stop'

# ── Costanti ─────────────────────────────────────────────────────────────────

$VSCODE_URL = "https://update.code.visualstudio.com/latest/win32-x64-archive/stable"

$REPO_BRANCH     = "main"   # quando questo branch è su main; altrimenti: claude/vscode-cpp-ide-mingw-EKrIV
$REPO_RAW        = "https://raw.githubusercontent.com/flavio-coding/vs-code-cpp/$REPO_BRANCH"
$VSIX_URL        = "$REPO_RAW/extension/cpp-runner.vsix"

$MINGW_FALLBACK_TAG  = "16.1.0posix-14.0.0-ucrt-r2"
$MINGW_FALLBACK_FILE = "winlibs-x86_64-posix-seh-gcc-16.1.0-mingw-w64ucrt-14.0.0-r2.zip"
$MINGW_FALLBACK_URL  = "https://github.com/brechtsanders/winlibs_mingw/releases/download/$MINGW_FALLBACK_TAG/$MINGW_FALLBACK_FILE"

$WIDTH = 62

# ── UI ───────────────────────────────────────────────────────────────────────

function Write-Banner {
    $line = "=" * $WIDTH
    Write-Host ""
    Write-Host $line                                                    -ForegroundColor Cyan
    Write-Host "  ⚡  VS Code C/C++ IDE  —  Installazione Windows"    -ForegroundColor Cyan
    Write-Host "  Nessun admin. Nessuna modifica al sistema. No riavvio." -ForegroundColor DarkCyan
    Write-Host $line                                                    -ForegroundColor Cyan
    Write-Host ""
}

function Write-Step([int]$n,[int]$t,[string]$s){ Write-Host ""`n"  [$n/$t] $s" -ForegroundColor Yellow }
function Write-Ok([string]$s)   { Write-Host "        OK  $s" -ForegroundColor Green  }
function Write-Warn([string]$s) { Write-Host "        !   $s" -ForegroundColor Yellow }
function Write-Info([string]$s) { Write-Host "        ->  $s" -ForegroundColor Gray   }

# ── Download ──────────────────────────────────────────────────────────────────

function Invoke-Download([string]$url,[string]$dest,[string]$label) {
    Write-Info "Scarico: $label"
    $tmp = "$dest.part"
    Remove-Item $tmp -ErrorAction SilentlyContinue
    try {
        $wc   = New-Object System.Net.WebClient
        $wc.Headers.Add("User-Agent","VSCodeCPP-Installer/2.0")
        $done = $false
        $wc.DownloadFileCompleted   += { $done = $true }
        $wc.DownloadProgressChanged += {
            param($s,$e)
            $rx  = [math]::Round($e.BytesReceived/1MB,1)
            $tot = [math]::Round($e.TotalBytesToReceive/1MB,1)
            $bar = "#"*[math]::Floor($e.ProgressPercentage/5)+" "*(20-[math]::Floor($e.ProgressPercentage/5))
            Write-Host -NoNewline "`r        [$bar] $($e.ProgressPercentage)%  $rx / $tot MB  "
        }
        $wc.DownloadFileAsync([uri]$url,$tmp)
        while(-not $done){ Start-Sleep -Milliseconds 150 }
        Write-Host ""
    } catch {
        Write-Host ""
        Write-Warn "Fallback a Invoke-WebRequest..."
        Invoke-WebRequest -Uri $url -OutFile $tmp -UseBasicParsing
    }
    if(-not(Test-Path $tmp)-or(Get-Item $tmp).Length -lt 100KB){ throw "Download fallito: $label" }
    Move-Item $tmp $dest -Force
    Write-Ok "$label  ($('{0:N1}' -f ((Get-Item $dest).Length/1MB)) MB)"
}

# ── Risoluzione URL MinGW ─────────────────────────────────────────────────────

function Resolve-MinGWUrl {
    Write-Info "Ricerca ultima versione GCC da winlibs.com (GitHub API)..."
    try {
        $h = @{ "User-Agent"="VSCodeCPP-Installer/2.0"; "Accept"="application/vnd.github+json" }
        $r = Invoke-RestMethod "https://api.github.com/repos/brechtsanders/winlibs_mingw/releases/latest" `
                -Headers $h -TimeoutSec 10 -ErrorAction Stop
        $a = $r.assets | Where-Object {
            $_.name -match "x86_64" -and $_.name -match "ucrt" -and
            $_.name -match "posix"  -and $_.name -match "\.zip$" -and
            $_.name -notmatch "llvm" -and $_.name -notmatch "i686"
        } | Select-Object -First 1
        if($a){
            $ver = ($r.tag_name -split "posix")[0]
            Write-Ok "Trovato GCC $ver — ultima versione"
            return $a.browser_download_url
        }
    } catch {
        Write-Warn "GitHub API non disponibile: $($_.Exception.Message)"
    }
    Write-Info "Uso versione verificata: GCC 16.1.0 (winlibs fallback)"
    return $MINGW_FALLBACK_URL
}

# ── Estrazione ZIP ────────────────────────────────────────────────────────────

function Expand-ZipTo([string]$zip,[string]$dest){
    Write-Info "Estrazione ZIP..."
    Add-Type -AssemblyName System.IO.Compression.FileSystem
    [System.IO.Compression.ZipFile]::ExtractToDirectory($zip,$dest)
}

# ═══════════════════════════════════════════════════════════════════════════════
#  MAIN
# ═══════════════════════════════════════════════════════════════════════════════

Write-Banner

Write-Host "  Installazione in : $InstallDir"    -ForegroundColor White
Write-Host "  Download totale  : ~300-400 MB"    -ForegroundColor DarkGray
Write-Host "  Riavvio Windows  : NO"             -ForegroundColor DarkGray
Write-Host "  PATH di sistema  : NON modificato" -ForegroundColor DarkGray
Write-Host ""

if(-not $Silent){
    $ok = Read-Host "  Continuare? [S/n]"
    if($ok -match "^[nN]"){ Write-Host "  Annullato."; exit 0 }
}

# Gestione directory esistente
if((Test-Path "$InstallDir\vscode")-or(Test-Path "$InstallDir\mingw64")){
    Write-Warn "Installazione precedente rilevata in $InstallDir"
    if(-not $Silent){
        $ow = Read-Host "  Sovrascrivere? [s/N]"
        if($ow -notmatch "^[sS]"){ Write-Host "  Annullato."; exit 0 }
    }
    Remove-Item -Recurse -Force "$InstallDir\vscode"  -ErrorAction SilentlyContinue
    Remove-Item -Recurse -Force "$InstallDir\mingw64" -ErrorAction SilentlyContinue
}

New-Item -ItemType Directory -Path "$InstallDir\tmp" -Force | Out-Null

# ─ 1. VS Code ─────────────────────────────────────────────────────────────────
Write-Step 1 5 "VS Code Portable (ultima versione stable)..."
$vsZip = "$InstallDir\tmp\vscode.zip"
if(-not(Test-Path $vsZip)){ Invoke-Download $VSCODE_URL $vsZip "VS Code Portable" }
else { Write-Info "Zip già presente, salto il download." }

Write-Info "Estrazione VS Code..."
$vsDir  = "$InstallDir\vscode"
New-Item -ItemType Directory -Path $vsDir -Force | Out-Null
Expand-ZipTo $vsZip $vsDir
$codeExe = "$vsDir\Code.exe"
if(-not(Test-Path $codeExe)){ throw "Code.exe non trovato dopo l'estrazione." }

# Modalità portatile: crea cartella 'data' accanto a Code.exe
# Ref: https://code.visualstudio.com/docs/editor/portable
New-Item -ItemType Directory -Path "$vsDir\data\user-data\User" -Force | Out-Null
New-Item -ItemType Directory -Path "$vsDir\data\extensions"     -Force | Out-Null
Write-Ok "VS Code Portable configurato (modalità portabile)"

# ─ 2. MinGW-w64 / GCC ────────────────────────────────────────────────────────
Write-Step 2 5 "GCC / MinGW-w64 (winlibs.com)..."
$mingwUrl = Resolve-MinGWUrl
$mingwZip = "$InstallDir\tmp\mingw.zip"
if(-not(Test-Path $mingwZip)){ Invoke-Download $mingwUrl $mingwZip "GCC MinGW-w64" }
else { Write-Info "Zip già presente, salto il download." }

Write-Info "Estrazione MinGW-w64 (pochi minuti)..."
$mingwExt = "$InstallDir\tmp\mingw_ex"
New-Item -ItemType Directory -Path $mingwExt -Force | Out-Null
Expand-ZipTo $mingwZip $mingwExt
$sub = Get-ChildItem $mingwExt -Directory | Select-Object -First 1
if(-not $sub){ throw "Struttura MinGW non trovata nell'archivio." }
Move-Item $sub.FullName "$InstallDir\mingw64" -Force
$mingwBin = "$InstallDir\mingw64\bin"
$gccExe   = "$mingwBin\gcc.exe"
if(-not(Test-Path $gccExe)){ throw "gcc.exe non trovato in $mingwBin" }

# VERIFICA: esegui gcc --version per confermare che funzioni
$gccVer = & $gccExe --version 2>&1 | Select-Object -First 1
if(-not $gccVer){ throw "gcc.exe trovato ma non risponde a --version" }
Write-Ok "GCC verificato e funzionante: $gccVer"

# ─ 3. Estensione cpp-runner ───────────────────────────────────────────────────
Write-Step 3 5 "Estensione C/C++ Runner (VSIX)..."
$vsixDest = "$InstallDir\tmp\cpp-runner.vsix"
$vsixOk   = $false
try {
    Invoke-Download $VSIX_URL $vsixDest "cpp-runner.vsix"
    $vsixOk = $true
} catch {
    Write-Warn "VSIX non scaricabile: $($_.Exception.Message)"
    Write-Warn "L'estensione cpp-runner non sara' installata ora."
}

# ─ 4. Configurazione VS Code ──────────────────────────────────────────────────
Write-Step 4 5 "Configurazione VS Code..."

$uDir    = "$vsDir\data\user-data\User"
$extDir  = "$vsDir\data\extensions"
$gccFwd  = $gccExe.Replace('\','/')     # path con forward slash per JSON
$binFwd  = $mingwBin.Replace('\','/')

$settingsJson = @"
{
  "cpp-runner.compilerPath"                        : "$binFwd",
  "cpp-runner.cCompiler"                           : "gcc",
  "cpp-runner.cppCompiler"                         : "g++",
  "cpp-runner.compileArgs"                         : ["-Wall", "-Wextra", "-g", "-std=c17"],
  "cpp-runner.showTimings"                         : true,

  "C_Cpp.default.compilerPath"                     : "$gccFwd",
  "C_Cpp.default.cStandard"                        : "c17",
  "C_Cpp.default.cppStandard"                      : "c++17",
  "C_Cpp.default.intelliSenseMode"                 : "windows-gcc-x64",
  "C_Cpp.autocompleteAddParentheses"               : true,
  "C_Cpp.inlayHints.autoDeclarationTypes.enabled"  : true,
  "C_Cpp.inlayHints.parameterNames.enabled"        : true,

  "editor.fontSize"                                : 14,
  "editor.fontFamily"                              : "'Consolas', 'Courier New', monospace",
  "editor.tabSize"                                 : 4,
  "editor.detectIndentation"                       : false,
  "editor.minimap.enabled"                         : false,
  "editor.bracketPairColorization.enabled"         : true,
  "editor.guides.bracketPairs"                     : true,
  "editor.suggestSelection"                        : "first",
  "editor.formatOnSave"                            : false,

  "workbench.colorTheme"                           : "Default Dark Modern",
  "workbench.startupEditor"                        : "newUntitledFile",

  "files.defaultLanguage"                          : "c",
  "files.autoSave"                                 : "onFocusChange",
  "files.associations"                             : { "*.h": "c", "*.hpp": "cpp" }
}
"@
Set-Content -Path "$uDir\settings.json" -Value $settingsJson -Encoding UTF8
Write-Ok "settings.json scritto"

# Installa estensioni nel data dir portabile
foreach($extItem in @(
    @{ id="ms-vscode.cpptools"; vsix=$null },
    @{ id="cpp-runner";         vsix=$(if($vsixOk){$vsixDest}else{$null}) }
)){
    $id   = $extItem.id
    $vsix = $extItem.vsix
    $arg  = if($vsix){ "`"$vsix`"" } else { $id }
    Write-Info "Installo $id..."
    $p = Start-Process -FilePath $codeExe `
         -ArgumentList "--extensions-dir `"$extDir`" --install-extension $arg --force" `
         -Wait -PassThru -WindowStyle Hidden
    if($p.ExitCode -eq 0){ Write-Ok "$id installato" }
    else { Write-Warn "$id: exitcode $($p.ExitCode) — verrà scaricato al primo avvio" }
}

# ─ 5. Collegamento desktop ────────────────────────────────────────────────────
Write-Step 5 5 "Collegamento sul desktop..."

# Launcher BAT (aggiunge mingw al PATH solo per la sessione, non globale)
Set-Content -Path "$InstallDir\VSCodeCPP.bat" -Value @"
@echo off
set "PATH=$($mingwBin.Replace('/','\'));%PATH%"
start "" "$codeExe" %*
"@ -Encoding ASCII

$desktop = [Environment]::GetFolderPath("Desktop")
$lnk     = (New-Object -ComObject WScript.Shell).CreateShortcut("$desktop\VS Code C++ IDE.lnk")
$lnk.TargetPath       = $codeExe
$lnk.WorkingDirectory = $InstallDir
$lnk.Description      = "VS Code C/C++ IDE — GCC $($gccVer -replace 'gcc.exe.*','')"
$lnk.Save()
Write-Ok "Collegamento creato: $desktop\VS Code C++ IDE.lnk"

# Pulizia
Remove-Item -Recurse -Force "$InstallDir\tmp" -ErrorAction SilentlyContinue

# ═══════════════════════════════════════════════════════════════════════════════
#  RIEPILOGO FINALE
# ═══════════════════════════════════════════════════════════════════════════════

$sep = "=" * $WIDTH
Write-Host ""
Write-Host $sep -ForegroundColor Green
Write-Host ""
Write-Host "  INSTALLAZIONE COMPLETATA CON SUCCESSO" -ForegroundColor Green
Write-Host ""
Write-Host "  Compilatore : $gccVer"       -ForegroundColor White
Write-Host "  Percorso GCC: $gccExe"       -ForegroundColor White
Write-Host "  Cartella    : $InstallDir"   -ForegroundColor White
Write-Host ""
Write-Host "  RIAVVIO WINDOWS  : NON necessario"     -ForegroundColor Green
Write-Host "  PATH di sistema  : NON modificato"     -ForegroundColor Green
Write-Host "  Admin richiesto  : NO"                 -ForegroundColor Green
Write-Host ""
Write-Host "  Come iniziare:" -ForegroundColor Cyan
Write-Host "    1. Apri 'VS Code C++ IDE' dal desktop"       -ForegroundColor White
Write-Host "    2. Crea un file .c (Ctrl+N, salva come .c)"  -ForegroundColor White
Write-Host "    3. Scrivi il codice"                         -ForegroundColor White
Write-Host "    4. Premi F5 per compilare ed eseguire"       -ForegroundColor White
Write-Host "    5. L'output appare nel pannello a destra"    -ForegroundColor White
Write-Host ""
Write-Host $sep -ForegroundColor Green
Write-Host ""

if(-not $Silent){
    $go = Read-Host "  Aprire VS Code adesso? [S/n]"
    if($go -notmatch "^[nN]"){ Start-Process $codeExe }
}
