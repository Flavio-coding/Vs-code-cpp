# VSCode C/C++ IDE - Windows Installer
# Scarica VS Code Portable + MinGW-w64 + estensioni e crea un IDE completo
# Eseguire come utente normale (NON come amministratore)

param(
    [string]$InstallDir = "$env:LOCALAPPDATA\VSCodeCPP",
    [switch]$Silent
)

Set-StrictMode -Version Latest
$ErrorActionPreference = 'Stop'

$VSCODE_VERSION   = "1.90.2"
$MINGW_VERSION    = "13.2.0"
# winlibs.com — GCC 13.2.0 MinGW-w64 10.0.0 UCRT, POSIX, without LLVM/Clang/LLD/LLDB
$MINGW_URL        = "https://github.com/brechtsanders/winlibs_mingw/releases/download/13.2.0posix-17.0.6-11.0.1-msvcrt-r5/winlibs-x86_64-posix-seh-gcc-13.2.0-mingw-w64msvcrt-11.0.1-r5.zip"
$VSCODE_URL       = "https://update.code.visualstudio.com/$VSCODE_VERSION/win32-x64-archive/stable"
# Extension IDs to pre-install
$EXTENSIONS = @(
    "ms-vscode.cpptools",
    "ms-vscode.cpptools-themes"
)

$WIDTH = 60

function Write-Banner {
    $line = "=" * $WIDTH
    Write-Host ""
    Write-Host $line -ForegroundColor Cyan
    Write-Host "  ⚡  VS Code C/C++ IDE  —  Installazione" -ForegroundColor Cyan
    Write-Host $line -ForegroundColor Cyan
    Write-Host ""
}

function Write-Step([int]$n, [int]$total, [string]$text) {
    Write-Host "  [$n/$total] $text" -ForegroundColor Yellow
}

function Write-Ok([string]$text) {
    Write-Host "        ✓ $text" -ForegroundColor Green
}

function Write-Info([string]$text) {
    Write-Host "        → $text" -ForegroundColor Gray
}

function Download-File([string]$url, [string]$dest, [string]$label) {
    Write-Info "Download: $label"
    $tmpPath = "$dest.part"
    try {
        $wc = New-Object System.Net.WebClient
        $wc.Headers.Add("User-Agent", "VSCodeCPP-Installer/1.0")

        # Progress reporting
        $wc.DownloadProgressChanged += {
            param($s, $e)
            $mb = [math]::Round($e.BytesReceived / 1MB, 1)
            $tot = if ($e.TotalBytesToReceive -gt 0) { " / " + [math]::Round($e.TotalBytesToReceive / 1MB, 1) + " MB" } else { " MB" }
            Write-Host -NoNewline "`r        Scaricato: $mb$tot  ($($e.ProgressPercentage)%)    "
        }

        $wc.DownloadFileAsync([uri]$url, $tmpPath)
        while ($wc.IsBusy) { Start-Sleep -Milliseconds 200 }
        Write-Host ""

        if ($LASTEXITCODE -ne $null -and $LASTEXITCODE -ne 0) {
            throw "Download failed"
        }
    } catch {
        # Fallback: use Invoke-WebRequest
        Write-Host ""
        Write-Info "Uso metodo alternativo di download..."
        Invoke-WebRequest -Uri $url -OutFile $tmpPath -UseBasicParsing
    }
    Move-Item -Path $tmpPath -Destination $dest -Force
}

function Expand-ZipFast([string]$zip, [string]$dest) {
    Write-Info "Estrazione in corso..."
    Add-Type -AssemblyName System.IO.Compression.FileSystem
    [System.IO.Compression.ZipFile]::ExtractToDirectory($zip, $dest)
}

function Install-VscodeExtension([string]$codeExe, [string]$extId) {
    Write-Info "Installo estensione: $extId"
    $proc = Start-Process -FilePath $codeExe -ArgumentList "--install-extension $extId --force" -Wait -PassThru -NoNewWindow
    if ($proc.ExitCode -ne 0) {
        Write-Host "        ⚠ Attenzione: impossibile installare $extId (verrà installata al primo avvio)" -ForegroundColor Yellow
    }
}

# ─── Main ────────────────────────────────────────────────────────────────────

Write-Banner

if (-not $Silent) {
    Write-Host "  Cartella di installazione: $InstallDir" -ForegroundColor White
    Write-Host "  (Modifica con: .\install.ps1 -InstallDir 'C:\altroPercorso')" -ForegroundColor DarkGray
    Write-Host ""
    $confirm = Read-Host "  Continuare? [S/n]"
    if ($confirm -eq 'n' -or $confirm -eq 'N') {
        Write-Host "  Annullato." -ForegroundColor Red
        exit 0
    }
    Write-Host ""
}

# Create directories
if (Test-Path $InstallDir) {
    Write-Host "  ⚠ La cartella $InstallDir esiste già." -ForegroundColor Yellow
    if (-not $Silent) {
        $ow = Read-Host "  Sovrascrivere? [s/N]"
        if ($ow -ne 's' -and $ow -ne 'S') { exit 0 }
    }
    Remove-Item -Recurse -Force "$InstallDir\vscode" -ErrorAction SilentlyContinue
    Remove-Item -Recurse -Force "$InstallDir\mingw64" -ErrorAction SilentlyContinue
}

New-Item -ItemType Directory -Path $InstallDir -Force | Out-Null
New-Item -ItemType Directory -Path "$InstallDir\tmp"    -Force | Out-Null

# ── Step 1: Download VS Code portable ────────────────────────────────────────
Write-Step 1 4 "Download di VS Code Portable..."
$vscodeZip = "$InstallDir\tmp\vscode.zip"
if (-not (Test-Path $vscodeZip)) {
    Download-File $VSCODE_URL $vscodeZip "VS Code $VSCODE_VERSION"
} else {
    Write-Info "Già scaricato, salto il download."
}
Write-Ok "VS Code scaricato"

# ── Step 2: Extract VS Code ───────────────────────────────────────────────────
Write-Step 2 4 "Estrazione di VS Code..."
$vscodeDir = "$InstallDir\vscode"
New-Item -ItemType Directory -Path $vscodeDir -Force | Out-Null
Expand-ZipFast $vscodeZip $vscodeDir

# Create portable data directory (enables portable mode)
New-Item -ItemType Directory -Path "$vscodeDir\data"                      -Force | Out-Null
New-Item -ItemType Directory -Path "$vscodeDir\data\user-data"            -Force | Out-Null
New-Item -ItemType Directory -Path "$vscodeDir\data\user-data\User"       -Force | Out-Null
New-Item -ItemType Directory -Path "$vscodeDir\data\extensions"           -Force | Out-Null
Write-Ok "VS Code estratto in modalità portatile"

# ── Step 3: Download MinGW-w64 ───────────────────────────────────────────────
Write-Step 3 4 "Download di MinGW-w64 (GCC $MINGW_VERSION)..."
$mingwZip = "$InstallDir\tmp\mingw.zip"
if (-not (Test-Path $mingwZip)) {
    Download-File $MINGW_URL $mingwZip "MinGW-w64 GCC $MINGW_VERSION"
} else {
    Write-Info "Già scaricato, salto il download."
}

Write-Info "Estrazione MinGW-w64 (può richiedere qualche minuto)..."
Expand-ZipFast $mingwZip "$InstallDir\tmp\mingw_extracted"

# Find the actual mingw64 subfolder
$mingwSrc = Get-ChildItem "$InstallDir\tmp\mingw_extracted" -Directory | Select-Object -First 1
if (-not $mingwSrc) {
    throw "Struttura MinGW non trovata dopo l'estrazione."
}
Move-Item $mingwSrc.FullName "$InstallDir\mingw64" -Force
Write-Ok "MinGW-w64 installato"

# ── Step 4: Configure VS Code ─────────────────────────────────────────────────
Write-Step 4 4 "Configurazione di VS Code..."

$codeExe    = "$vscodeDir\Code.exe"
$userDataDir = "$vscodeDir\data\user-data\User"
$extDataDir  = "$vscodeDir\data\extensions"
$mingwBin   = "$InstallDir\mingw64\bin"

# Write VS Code user settings
$settings = @{
    "cpp-runner.compilerPath"          = $mingwBin
    "cpp-runner.cCompiler"             = "gcc"
    "cpp-runner.cppCompiler"           = "g++"
    "cpp-runner.compileArgs"           = @("-Wall", "-Wextra", "-g", "-std=c17")
    "cpp-runner.showTimings"           = $true
    "editor.fontSize"                  = 14
    "editor.fontFamily"                = "'Consolas', 'Courier New', monospace"
    "editor.minimap.enabled"           = $false
    "editor.suggestSelection"          = "first"
    "editor.wordWrap"                  = "off"
    "editor.tabSize"                   = 4
    "editor.renderWhitespace"          = "selection"
    "workbench.colorTheme"             = "Default Dark Modern"
    "workbench.startupEditor"          = "newUntitledFile"
    "files.defaultLanguage"            = "c"
    "files.autoSave"                   = "onFocusChange"
    "terminal.integrated.defaultProfile.windows" = "PowerShell"
    "C_Cpp.default.compilerPath"       = "$mingwBin\gcc.exe"
    "C_Cpp.default.cStandard"          = "c17"
    "C_Cpp.default.cppStandard"        = "c++17"
    "C_Cpp.default.includePath"        = @('${workspaceFolder}/**', "$InstallDir\mingw64\include")
    "C_Cpp.autocompleteAddParentheses" = $true
    "C_Cpp.inlayHints.autoDeclarationTypes.enabled" = $true
} | ConvertTo-Json -Depth 5

Set-Content -Path "$userDataDir\settings.json" -Value $settings -Encoding UTF8
Write-Ok "Impostazioni VS Code configurate"

# Install the cpp-runner extension (VSIX from our repo)
$vsixPath = Join-Path $PSScriptRoot "..\..\extension\cpp-runner.vsix"
if (Test-Path $vsixPath) {
    Write-Info "Installo estensione C/C++ IDE Runner..."
    & $codeExe --extensions-dir $extDataDir --install-extension $vsixPath --force 2>&1 | Out-Null
    Write-Ok "Estensione cpp-runner installata"
} else {
    Write-Host "        ⚠ cpp-runner.vsix non trovato. Compilare prima l'estensione." -ForegroundColor Yellow
}

# Install Microsoft C/C++ extension (IntelliSense, etc.)
foreach ($ext in $EXTENSIONS) {
    Install-VscodeExtension $codeExe $ext
}
Write-Ok "Estensioni installate"

# ── Create launcher ───────────────────────────────────────────────────────────
$launcherContent = @"
@echo off
set VSCODE_DIR=%~dp0vscode
set MINGW_BIN=%~dp0mingw64\bin
set PATH=%MINGW_BIN%;%PATH%
start "" "%VSCODE_DIR%\Code.exe" %*
"@
Set-Content -Path "$InstallDir\VSCodeCPP.bat" -Value $launcherContent -Encoding ASCII

# Create desktop shortcut
$desktopPath = [Environment]::GetFolderPath("Desktop")
$shortcut = "$desktopPath\VS Code C++ IDE.lnk"
$wsh = New-Object -ComObject WScript.Shell
$lnk = $wsh.CreateShortcut($shortcut)
$lnk.TargetPath   = $codeExe
$lnk.WorkingDirectory = $InstallDir
$lnk.Description  = "VS Code C/C++ IDE"
$lnk.Save()
Write-Ok "Collegamento sul desktop creato"

# Cleanup temp files
Remove-Item -Recurse -Force "$InstallDir\tmp" -ErrorAction SilentlyContinue

# ── Done ──────────────────────────────────────────────────────────────────────
$line = "=" * $WIDTH
Write-Host ""
Write-Host $line -ForegroundColor Green
Write-Host ""
Write-Host "  ✓  Installazione completata!" -ForegroundColor Green
Write-Host ""
Write-Host "  📁 Installato in: $InstallDir" -ForegroundColor White
Write-Host "  🖥  Collegamento sul Desktop: 'VS Code C++ IDE'" -ForegroundColor White
Write-Host ""
Write-Host "  Come usarlo:" -ForegroundColor Cyan
Write-Host "    1. Apri VS Code C++ IDE dal desktop" -ForegroundColor White
Write-Host "    2. Crea o apri un file .c o .cpp" -ForegroundColor White
Write-Host "    3. Premi F5 (o il pulsante ▶) per compilare ed eseguire" -ForegroundColor White
Write-Host "    4. L'output appare nel pannello a destra" -ForegroundColor White
Write-Host ""
Write-Host $line -ForegroundColor Green
Write-Host ""

if (-not $Silent) {
    $launch = Read-Host "  Aprire VS Code adesso? [S/n]"
    if ($launch -ne 'n' -and $launch -ne 'N') {
        Start-Process $codeExe
    }
}
