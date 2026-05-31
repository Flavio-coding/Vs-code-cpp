# ⚡ VS Code C/C++ IDE

Un ambiente di sviluppo C/C++ completo basato su VS Code, con compilatore GCC/MinGW
già incluso e un'interfaccia di output pensata per i principianti — simile a Dev-C++.

---

## Caratteristiche principali

| Funzione | Dettaglio |
|---|---|
| **Compilatore incluso** | GCC via MinGW-w64 (Windows) / GCC di sistema (Linux/Mac) |
| **Un tasto per tutto** | **F5** compila ed esegue in un unico click |
| **Output personalizzato** | Pannello laterale con log compilazione + output programma |
| **Errori colorati** | Errori in rosso, warning in giallo, puntatori in blu |
| **Input interattivo** | Campo stdin integrato nel pannello (come Dev-C++) |
| **IntelliSense** | Autocompletamento, suggerimenti, analisi statica via ms-vscode.cpptools |
| **Nessuna configurazione** | Funziona subito, senza `tasks.json` o `launch.json` |

---

## Installazione

### Windows (raccomandata)

1. Scarica o clona questo repository
2. Doppio clic su `installer\windows\install.bat`
3. Segui le istruzioni a schermo (scarica VS Code + MinGW + estensioni automaticamente)
4. Usa il collegamento **"VS Code C++ IDE"** sul desktop

> L'installer scarica **~150 MB** (VS Code Portable + MinGW-w64 GCC 13).

### Linux / macOS

```bash
chmod +x installer/linux/install.sh
./installer/linux/install.sh
```

### Installazione manuale dell'estensione

Se hai già VS Code installato con GCC disponibile nel PATH:

```bash
# 1. Compila l'estensione
./build.sh

# 2. Installa il VSIX
code --install-extension extension/cpp-runner.vsix
```

---

## Utilizzo

1. Apri VS Code C++ IDE
2. Crea un nuovo file (`Ctrl+N`) o apri un file `.c` / `.cpp`
3. Scrivi il codice
4. Premi **F5** — il pannello di output si apre automaticamente a destra

### Tasti rapidi

| Tasto | Azione |
|---|---|
| **F5** | Compila ed esegui |
| **Ctrl+Shift+B** | Solo compila |
| **Shift+F5** | Ferma l'esecuzione |

### Barra di stato

Il pulsante in basso a sinistra mostra lo stato attuale:
- `▶ Esegui (F5)` — pronto
- `⚙ Compilazione...` — sta compilando
- `▶ In esecuzione... [Stop]` — programma in esecuzione
- `✗ Errore` — errore di compilazione

---

## Pannello di output

```
┌─────────────────────────────────────────────┐
│ ⚡ C/C++ IDE   [✓ Compilato]      [✕ Pulisci]│
├─────────────────────────────────────────────┤
│ 🔧 LOG DI COMPILAZIONE                       │
│                                             │
│  ✓ Compilato con successo in 0.31s           │
│                                             │
│ ▶ OUTPUT DEL PROGRAMMA                       │
│                                             │
│  Inserisci un numero: 42                     │
│  Il quadrato è: 1764                         │
│                                             │
├─────────────────────────────────────────────┤
│ Processo terminato  Codice uscita: 0  0.08s │
├─────────────────────────────────────────────┤
│ Input (stdin): [ ___________________ ][Invia]│
└─────────────────────────────────────────────┘
```

**In caso di errore:**
```
│ ✗ Errore di compilazione (0.12s)             │
│                                             │
│  main.c:5:10: error: expected ';'            │
│      before 'return'                         │
│    5 │   return 0                            │
│      │          ^                            │
```

---

## Configurazione

Apri `File > Preferenze > Impostazioni` e cerca `C/C++ Runner`.

| Impostazione | Descrizione | Default |
|---|---|---|
| `cpp-runner.compilerPath` | Cartella bin del compilatore | auto-detect |
| `cpp-runner.cCompiler` | Nome eseguibile C | `gcc` |
| `cpp-runner.cppCompiler` | Nome eseguibile C++ | `g++` |
| `cpp-runner.compileArgs` | Argomenti aggiuntivi | `["-Wall", "-Wextra", "-g"]` |
| `cpp-runner.showTimings` | Mostra tempi di compilazione | `true` |

---

## Build dell'estensione (sviluppatori)

Richiede **Node.js 18+**:

```bash
./build.sh
# Output: extension/cpp-runner.vsix
```

---

## Struttura del progetto

```
vs-code-cpp/
├── extension/              # Sorgente estensione VS Code (TypeScript)
│   ├── src/
│   │   ├── extension.ts    # Punto di ingresso, comandi, barra di stato
│   │   ├── compiler.ts     # Logica di compilazione ed esecuzione
│   │   └── outputPanel.ts  # Pannello WebView (UI output)
│   ├── out/                # JavaScript compilato
│   └── cpp-runner.vsix     # Pacchetto pronto all'installazione
├── installer/
│   ├── windows/
│   │   ├── install.bat     # Avvia l'installer (doppio clic)
│   │   └── install.ps1     # Installer PowerShell completo
│   └── linux/
│       └── install.sh      # Installer Linux/macOS
├── vscode-config/
│   └── settings.json       # Impostazioni VS Code pre-configurate
└── build.sh                # Script di build dell'estensione
```

---

## Licenza

MIT
