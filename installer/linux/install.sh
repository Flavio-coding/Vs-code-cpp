#!/usr/bin/env bash
# VS Code C/C++ IDE — Linux Installer
# Installa VS Code + GCC + estensione cpp-runner

set -euo pipefail

INSTALL_DIR="${HOME}/.local/vscodecpp"
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"

GREEN='\033[0;32m'
YELLOW='\033[1;33m'
CYAN='\033[0;36m'
NC='\033[0m'

banner() {
  echo ""
  echo -e "${CYAN}============================================================${NC}"
  echo -e "${CYAN}  ⚡  VS Code C/C++ IDE  —  Linux Installer${NC}"
  echo -e "${CYAN}============================================================${NC}"
  echo ""
}

step() { echo -e "  ${YELLOW}[$1/$2] $3${NC}"; }
ok()   { echo -e "        ${GREEN}✓ $1${NC}"; }
info() { echo -e "        → $1"; }

check_deps() {
  local missing=()
  for cmd in curl unzip; do
    command -v "$cmd" >/dev/null 2>&1 || missing+=("$cmd")
  done
  if [ ${#missing[@]} -gt 0 ]; then
    echo "  ✗ Dipendenze mancanti: ${missing[*]}"
    echo "  Installa con: sudo apt install ${missing[*]}"
    exit 1
  fi
}

install_gcc() {
  if command -v gcc >/dev/null 2>&1; then
    ok "GCC già installato: $(gcc --version | head -1)"
    return
  fi
  info "Installazione di GCC tramite package manager..."
  if command -v apt-get >/dev/null 2>&1; then
    sudo apt-get update -qq && sudo apt-get install -y build-essential
  elif command -v dnf >/dev/null 2>&1; then
    sudo dnf install -y gcc gcc-c++ make
  elif command -v pacman >/dev/null 2>&1; then
    sudo pacman -Sy --noconfirm gcc make
  else
    echo "  ✗ Package manager non riconosciuto. Installa GCC manualmente."
    exit 1
  fi
  ok "GCC installato: $(gcc --version | head -1)"
}

install_vscode() {
  if command -v code >/dev/null 2>&1; then
    ok "VS Code già installato: $(code --version | head -1)"
    CODE_EXE="code"
    return
  fi

  info "Download VS Code .deb..."
  local deb="$INSTALL_DIR/tmp/vscode.deb"
  mkdir -p "$INSTALL_DIR/tmp"
  curl -fsSL "https://update.code.visualstudio.com/latest/linux-deb-x64/stable" -o "$deb"
  info "Installazione VS Code..."
  sudo dpkg -i "$deb" || sudo apt-get install -f -y
  ok "VS Code installato"
  CODE_EXE="code"
}

banner
check_deps

echo -e "  Cartella di installazione: ${INSTALL_DIR}"
echo ""
read -r -p "  Continuare? [S/n] " confirm
[[ "$confirm" =~ ^[nN]$ ]] && exit 0
echo ""

mkdir -p "$INSTALL_DIR"

# Step 1: GCC
step 1 3 "Installazione del compilatore GCC..."
install_gcc

# Step 2: VS Code
step 2 3 "Installazione di VS Code..."
CODE_EXE=""
install_vscode

# Step 3: Extensions and config
step 3 3 "Configurazione estensioni..."

info "Installo ms-vscode.cpptools (IntelliSense)..."
"$CODE_EXE" --install-extension ms-vscode.cpptools --force 2>/dev/null || true

# Install our VSIX if built
VSIX="$SCRIPT_DIR/../../extension/cpp-runner.vsix"
if [ -f "$VSIX" ]; then
  info "Installo estensione cpp-runner..."
  "$CODE_EXE" --install-extension "$VSIX" --force
  ok "Estensione cpp-runner installata"
else
  echo "        ⚠ cpp-runner.vsix non trovato. Compila prima l'estensione con build.sh"
fi

# Write settings
USER_CFG_DIR="${HOME}/.config/Code/User"
mkdir -p "$USER_CFG_DIR"
cat > "$USER_CFG_DIR/settings.json" << 'EOF'
{
  "cpp-runner.cCompiler": "gcc",
  "cpp-runner.cppCompiler": "g++",
  "cpp-runner.compileArgs": ["-Wall", "-Wextra", "-g", "-std=c17"],
  "cpp-runner.showTimings": true,
  "editor.fontSize": 14,
  "editor.fontFamily": "'Fira Code', 'Consolas', monospace",
  "editor.minimap.enabled": false,
  "editor.tabSize": 4,
  "workbench.colorTheme": "Default Dark Modern",
  "workbench.startupEditor": "newUntitledFile",
  "files.defaultLanguage": "c",
  "files.autoSave": "onFocusChange",
  "C_Cpp.default.cStandard": "c17",
  "C_Cpp.default.cppStandard": "c++17"
}
EOF
ok "Impostazioni configurate"

# Desktop shortcut
DESKTOP="${HOME}/Desktop"
if [ -d "$DESKTOP" ]; then
  cat > "$DESKTOP/VSCode-CPP.desktop" << EOF
[Desktop Entry]
Name=VS Code C/C++ IDE
Exec=code
Icon=vscode
Terminal=false
Type=Application
Categories=Development;IDE;
EOF
  chmod +x "$DESKTOP/VSCode-CPP.desktop"
  ok "Collegamento sul desktop creato"
fi

echo ""
echo -e "${GREEN}============================================================${NC}"
echo ""
echo -e "${GREEN}  ✓  Installazione completata!${NC}"
echo ""
echo -e "  Come usarlo:"
echo -e "    1. Apri VS Code dal desktop o eseguendo 'code'"
echo -e "    2. Crea o apri un file .c o .cpp"
echo -e "    3. Premi ${CYAN}F5${NC} (o il pulsante ▶) per compilare ed eseguire"
echo -e "    4. L'output appare nel pannello a destra"
echo ""
echo -e "${GREEN}============================================================${NC}"
echo ""

read -r -p "  Aprire VS Code adesso? [S/n] " launch
[[ "$launch" =~ ^[nN]$ ]] || code &
