#!/usr/bin/env bash
# Build script: compila l'estensione TypeScript e la impacchetta in VSIX
set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
EXT_DIR="$SCRIPT_DIR/extension"

echo ""
echo "=== Build: VS Code C/C++ IDE Extension ==="
echo ""

# Check Node.js
if ! command -v node >/dev/null 2>&1; then
  echo "✗ Node.js non trovato. Installalo da https://nodejs.org"
  exit 1
fi
echo "✓ Node.js $(node --version)"

# Install deps
echo "→ Installazione dipendenze npm..."
cd "$EXT_DIR"
npm install --silent

# Compile TypeScript
echo "→ Compilazione TypeScript..."
npm run compile

echo "✓ TypeScript compilato"

# Package VSIX
echo "→ Creazione pacchetto VSIX..."
if ! command -v vsce >/dev/null 2>&1; then
  npx @vscode/vsce package --no-dependencies -o cpp-runner.vsix
else
  vsce package --no-dependencies -o cpp-runner.vsix
fi

echo ""
echo "✓ Creato: $EXT_DIR/cpp-runner.vsix"
echo ""
echo "Per installare manualmente in VS Code:"
echo "  code --install-extension $EXT_DIR/cpp-runner.vsix"
echo ""
echo "Per eseguire l'installer completo (Windows):"
echo "  installer\\windows\\install.bat"
echo ""
