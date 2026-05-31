# ⚡ VS Code C/C++ IDE

Un IDE C/C++ completo basato su VS Code, con compilatore GCC bundled e interfaccia
di output stile Dev-C++ — pensato per chi inizia a programmare.

---

## Installazione rapida — Windows

### Opzione A: Un comando (copia e incolla in CMD o PowerShell)

> **Non serve essere amministratore. Non si modifica il PATH di sistema. Non serve riavvio.**

Apri **CMD** o **PowerShell** e incolla:

```
powershell -NoProfile -ExecutionPolicy Bypass -Command "iex (iwr 'https://raw.githubusercontent.com/flavio-coding/vs-code-cpp/main/install.ps1' -UseBasicParsing).Content"
```

Il comando:
1. Scarica VS Code Portable (~90 MB)
2. Scarica GCC/MinGW-w64 da winlibs.com — sempre l'ultima versione (~180 MB)
3. Installa le estensioni (IntelliSense + pannello di output)
4. Crea il collegamento **"VS Code C++ IDE"** sul desktop
5. Verifica che `gcc --version` risponda correttamente

Download totale: **~300–400 MB** · Tempo stimato: ~5 minuti

### Opzione B: Script locale

```
git clone https://github.com/flavio-coding/vs-code-cpp.git
cd vs-code-cpp
powershell -ExecutionPolicy Bypass -File installer\windows\install.ps1
```

---

## Domande frequenti

### Serve il riavvio di Windows?

**No.** Il compilatore è configurato tramite le impostazioni di VS Code
(`settings.json`) — non viene toccato il PATH di sistema. Apri il collegamento
sul desktop e funziona subito.

### Serve essere amministratore?

**No.** Tutto viene installato in `%LOCALAPPDATA%\VSCodeCPP` (cartella personale
dell'utente).

### Quale compilatore viene installato?

[**WinLibs MinGW-w64**](https://winlibs.com) — una distribuzione standalone di GCC
per Windows, senza bisogno di MSYS2. L'installer scarica sempre l'ultima versione
stabile tramite GitHub API (fallback verificato: GCC 16.1.0 + MinGW-w64 14.0.0 UCRT,
giugno 2026).

> La guida ufficiale VS Code usa MSYS2 per installare GCC. WinLibs offre lo stesso
> GCC in formato ZIP standalone — risultato identico, installazione più semplice.

### Dove viene installato tutto?

```
%LOCALAPPDATA%\VSCodeCPP\
├── vscode\         → VS Code Portable (con data\ per la modalità portabile)
├── mingw64\        → GCC, G++, GDB e tutto il toolchain
│   └── bin\
│       ├── gcc.exe
│       ├── g++.exe
│       └── gdb.exe
└── VSCodeCPP.bat   → Launcher alternativo (aggiunge mingw64\bin al PATH della sessione)
```

---

## Utilizzo

1. Apri **VS Code C++ IDE** dal desktop
2. Crea un file `.c` o `.cpp` (`Ctrl+N`, poi salva con `Ctrl+S`)
3. Scrivi il codice
4. Premi **F5** — si apre automaticamente il pannello di output a destra

### Tasti rapidi

| Tasto | Azione |
|---|---|
| **F5** | Salva, compila ed esegui |
| **Ctrl+Shift+B** | Solo compila |
| **Shift+F5** | Ferma l'esecuzione |

---

## Pannello di output (non il terminale)

L'output non usa il terminale integrato di VS Code. Viene aperto un pannello
laterale dedicato con:

```
┌────────────────────────────────────────────────────┐
│ ⚡ C/C++ IDE   [✓ Compilato]             [✕ Pulisci]│
├────────────────────────────────────────────────────┤
│ 🔧 LOG DI COMPILAZIONE                              │
│  ✓ Compilato con successo in 0.31s                  │
│                                                    │
│ ▶ OUTPUT DEL PROGRAMMA                              │
│  Inserisci un numero: 42                            │
│  Il quadrato è: 1764                                │
│                                                    │
├────────────────────────────────────────────────────┤
│  Processo terminato · Codice uscita: 0 · 0.08s     │
├────────────────────────────────────────────────────┤
│  Input (stdin): [_________________________] [Invia] │
└────────────────────────────────────────────────────┘
```

**Errori di compilazione** vengono evidenziati in rosso con il numero di riga,
warning in giallo — facile capire dove correggere senza leggere output grezzo.

---

## Installazione Linux / macOS

```bash
chmod +x installer/linux/install.sh
./installer/linux/install.sh
```

Installa GCC tramite il package manager del sistema (`apt`, `dnf`, `pacman`).

---

## Configurazione avanzata

`File → Preferenze → Impostazioni` → cerca `C/C++ Runner`:

| Impostazione | Default | Descrizione |
|---|---|---|
| `cpp-runner.compilerPath` | auto | Cartella bin del compilatore |
| `cpp-runner.cCompiler` | `gcc` | Nome eseguibile per file `.c` |
| `cpp-runner.cppCompiler` | `g++` | Nome eseguibile per file `.cpp` |
| `cpp-runner.compileArgs` | `["-Wall","-Wextra","-g"]` | Flag aggiuntivi |
| `cpp-runner.showTimings` | `true` | Mostra tempi di compilazione |

---

## Struttura del repository

```
vs-code-cpp/
├── install.ps1              ← entry point per il one-liner CMD
├── extension/
│   ├── src/
│   │   ├── extension.ts     ← comandi, barra di stato (F5 / Stop)
│   │   ├── compiler.ts      ← trova GCC, compila, esegue, cattura output
│   │   └── outputPanel.ts   ← pannello WebView stile Dev-C++
│   └── cpp-runner.vsix      ← pacchetto pronto all'installazione
├── installer/
│   ├── windows/
│   │   ├── install.bat      ← doppio clic per installare (alternativo)
│   │   └── install.ps1      ← installer PowerShell completo
│   └── linux/
│       └── install.sh
├── vscode-config/
│   └── settings.json        ← template impostazioni pre-configurate
└── build.sh                 ← compila l'estensione TypeScript → VSIX
```

---

## Build dell'estensione (sviluppatori)

Richiede Node.js 18+:

```bash
./build.sh
# Output: extension/cpp-runner.vsix
```

---

## Licenza

MIT
