import * as vscode from 'vscode';
import * as path from 'path';

type PanelMessage =
    | { type: 'start-compile'; file: string }
    | { type: 'compile-ok'; elapsed: string }
    | { type: 'compile-error'; output: string; elapsed: string }
    | { type: 'start-run' }
    | { type: 'output'; text: string; isErr: boolean }
    | { type: 'run-done'; code: number; elapsed: string }
    | { type: 'run-stopped' };

export class OutputPanel {
    private panel: vscode.WebviewPanel | undefined;
    private _stdinEmitter = new vscode.EventEmitter<string>();
    readonly onStdinInput = this._stdinEmitter.event;

    constructor(private readonly context: vscode.ExtensionContext) {}

    private getOrCreatePanel(): vscode.WebviewPanel {
        if (this.panel) {
            this.panel.reveal(vscode.ViewColumn.Two, true);
            return this.panel;
        }

        this.panel = vscode.window.createWebviewPanel(
            'cppOutput',
            '⚡ C/C++ Output',
            { viewColumn: vscode.ViewColumn.Two, preserveFocus: true },
            {
                enableScripts: true,
                retainContextWhenHidden: true,
            }
        );

        this.panel.webview.html = this.getHtml();

        this.panel.webview.onDidReceiveMessage(msg => {
            if (msg.type === 'stdin') {
                this._stdinEmitter.fire(msg.text);
            }
        });

        this.panel.onDidDispose(() => {
            this.panel = undefined;
        });

        return this.panel;
    }

    private post(msg: PanelMessage) {
        this.getOrCreatePanel().webview.postMessage(msg);
    }

    startCompilation(fileName: string) {
        this.post({ type: 'start-compile', file: fileName });
    }
    compilationSuccess(elapsed: string) {
        this.post({ type: 'compile-ok', elapsed });
    }
    compilationError(output: string, elapsed: string) {
        this.post({ type: 'compile-error', output, elapsed });
    }
    startExecution() {
        this.post({ type: 'start-run' });
    }
    appendOutput(text: string, isErr = false) {
        this.post({ type: 'output', text, isErr });
    }
    executionFinished(code: number, elapsed: string) {
        this.post({ type: 'run-done', code, elapsed });
    }
    executionStopped() {
        this.post({ type: 'run-stopped' });
    }

    private getHtml(): string {
        return /* html */`<!DOCTYPE html>
<html lang="it">
<head>
<meta charset="UTF-8">
<meta name="viewport" content="width=device-width, initial-scale=1.0">
<title>C/C++ Output</title>
<style>
  *, *::before, *::after { box-sizing: border-box; margin: 0; padding: 0; }

  :root {
    --bg: #1e1e1e;
    --bg2: #252526;
    --bg3: #2d2d2d;
    --border: #3e3e3e;
    --fg: #d4d4d4;
    --fg2: #9d9d9d;
    --accent: #569cd6;
    --green: #4ec9b0;
    --red: #f44747;
    --yellow: #ffcc66;
    --orange: #ce9178;
    --input-bg: #3c3c3c;
    --radius: 4px;
    --font: 'Consolas', 'Courier New', monospace;
  }

  body {
    background: var(--bg);
    color: var(--fg);
    font-family: var(--font);
    font-size: 13px;
    display: flex;
    flex-direction: column;
    height: 100vh;
    overflow: hidden;
  }

  /* ── Header ─────────────────────────────── */
  #header {
    background: var(--bg3);
    border-bottom: 1px solid var(--border);
    padding: 6px 12px;
    display: flex;
    align-items: center;
    gap: 10px;
    flex-shrink: 0;
    user-select: none;
  }
  #header-title {
    font-weight: bold;
    color: var(--accent);
    font-size: 12px;
    letter-spacing: 0.05em;
  }
  #status-badge {
    font-size: 11px;
    padding: 2px 8px;
    border-radius: 10px;
    background: var(--bg2);
    color: var(--fg2);
    border: 1px solid var(--border);
    transition: all 0.2s;
  }
  #status-badge.compiling { background: #1e3a5f; color: var(--accent); border-color: var(--accent); }
  #status-badge.running   { background: #1e3a2a; color: var(--green);  border-color: var(--green); }
  #status-badge.error     { background: #3a1e1e; color: var(--red);    border-color: var(--red); }
  #status-badge.ok        { background: #1a3020; color: var(--green);  border-color: var(--green); }

  #clear-btn {
    margin-left: auto;
    background: transparent;
    border: 1px solid var(--border);
    color: var(--fg2);
    cursor: pointer;
    padding: 2px 8px;
    border-radius: var(--radius);
    font-size: 11px;
    font-family: var(--font);
  }
  #clear-btn:hover { background: var(--bg2); color: var(--fg); }

  /* ── Scrollable content ─────────────────── */
  #content {
    flex: 1;
    overflow-y: auto;
    overflow-x: hidden;
    padding: 0;
    scroll-behavior: smooth;
  }
  #content::-webkit-scrollbar { width: 8px; }
  #content::-webkit-scrollbar-track { background: var(--bg); }
  #content::-webkit-scrollbar-thumb { background: var(--border); border-radius: 4px; }

  /* ── Section headers ─────────────────────── */
  .section-header {
    display: flex;
    align-items: center;
    gap: 8px;
    padding: 6px 12px 4px;
    font-size: 10px;
    text-transform: uppercase;
    letter-spacing: 0.1em;
    color: var(--fg2);
    border-top: 1px solid var(--border);
    margin-top: 4px;
    user-select: none;
  }
  .section-header:first-child { border-top: none; margin-top: 0; }
  .section-header .icon { font-size: 14px; }

  /* ── Build log area ─────────────────────── */
  #build-log {
    padding: 4px 12px 8px;
    white-space: pre-wrap;
    word-break: break-all;
    line-height: 1.6;
  }

  .build-status-line {
    display: flex;
    align-items: center;
    gap: 8px;
    padding: 2px 0;
    color: var(--fg2);
    font-style: italic;
  }
  .build-status-line .spinner {
    display: inline-block;
    animation: spin 0.8s linear infinite;
  }
  @keyframes spin { from { transform: rotate(0deg); } to { transform: rotate(360deg); } }

  .compile-ok   { color: var(--green); }
  .compile-err  { color: var(--red); }
  .compile-warn { color: var(--yellow); }

  /* Error block */
  .error-summary {
    background: rgba(244, 71, 71, 0.08);
    border-left: 3px solid var(--red);
    padding: 8px 12px;
    margin: 4px 0;
    border-radius: 0 var(--radius) var(--radius) 0;
  }
  .error-summary .err-title {
    color: var(--red);
    font-weight: bold;
    margin-bottom: 6px;
  }
  .error-line    { color: var(--red);    line-height: 1.5; }
  .warning-line  { color: var(--yellow); line-height: 1.5; }
  .note-line     { color: var(--fg2);    line-height: 1.5; }
  .context-line  { color: var(--fg);     line-height: 1.5; }
  .pointer-line  { color: var(--accent); line-height: 1.5; }

  /* ── Output area ────────────────────────── */
  #output-area {
    padding: 4px 12px 8px;
    white-space: pre-wrap;
    word-break: break-all;
    line-height: 1.6;
    color: var(--fg);
  }
  .stderr-text { color: var(--orange); }

  /* ── Footer / stdin ─────────────────────── */
  #footer {
    border-top: 1px solid var(--border);
    background: var(--bg2);
    padding: 6px 10px;
    display: flex;
    align-items: center;
    gap: 8px;
    flex-shrink: 0;
  }
  #footer-label {
    font-size: 11px;
    color: var(--fg2);
    white-space: nowrap;
    user-select: none;
  }
  #stdin-input {
    flex: 1;
    background: var(--input-bg);
    border: 1px solid var(--border);
    color: var(--fg);
    font-family: var(--font);
    font-size: 13px;
    padding: 4px 8px;
    border-radius: var(--radius);
    outline: none;
  }
  #stdin-input:focus { border-color: var(--accent); }
  #stdin-input:disabled { opacity: 0.4; cursor: not-allowed; }
  #send-btn {
    background: var(--accent);
    color: #fff;
    border: none;
    padding: 4px 12px;
    border-radius: var(--radius);
    cursor: pointer;
    font-family: var(--font);
    font-size: 12px;
  }
  #send-btn:disabled { opacity: 0.4; cursor: not-allowed; }
  #send-btn:hover:not(:disabled) { opacity: 0.85; }

  /* ── Exit code bar ──────────────────────── */
  #exit-bar {
    display: none;
    padding: 5px 12px;
    font-size: 11px;
    border-top: 1px solid var(--border);
    background: var(--bg2);
    color: var(--fg2);
    flex-shrink: 0;
    user-select: none;
  }
  #exit-bar.show { display: flex; align-items: center; gap: 10px; }
  #exit-bar .exit-ok  { color: var(--green); }
  #exit-bar .exit-err { color: var(--red); }
</style>
</head>
<body>

<div id="header">
  <span id="header-title">⚡ C/C++ IDE</span>
  <span id="status-badge">Pronto</span>
  <button id="clear-btn" onclick="clearAll()">✕ Pulisci</button>
</div>

<div id="content">
  <div class="section-header"><span class="icon">🔧</span> Log di Compilazione</div>
  <div id="build-log"><span style="color:var(--fg2);font-style:italic">Premi F5 o il pulsante ▶ per compilare ed eseguire...</span></div>

  <div class="section-header" id="output-header" style="display:none"><span class="icon">▶</span> Output del Programma</div>
  <div id="output-area"></div>
</div>

<div id="exit-bar"></div>

<div id="footer">
  <span id="footer-label">Input (stdin):</span>
  <input id="stdin-input" type="text" placeholder="Digita input per il programma, poi premi Invio" disabled />
  <button id="send-btn" disabled onclick="sendStdin()">Invia</button>
</div>

<script>
const vscode = acquireVsCodeApi();

const buildLog = document.getElementById('build-log');
const outputArea = document.getElementById('output-area');
const outputHeader = document.getElementById('output-header');
const statusBadge = document.getElementById('status-badge');
const stdinInput = document.getElementById('stdin-input');
const sendBtn = document.getElementById('send-btn');
const exitBar = document.getElementById('exit-bar');

function setStatus(cls, text) {
  statusBadge.className = 'status-badge ' + cls;
  statusBadge.id = 'status-badge';
  statusBadge.setAttribute('class', cls ? cls : '');
  statusBadge.textContent = text;
}

function clearAll() {
  buildLog.innerHTML = '<span style="color:var(--fg2);font-style:italic">Log pulito. Premi F5 per compilare...</span>';
  outputArea.innerHTML = '';
  outputHeader.style.display = 'none';
  exitBar.className = '';
  exitBar.innerHTML = '';
  setStatus('', 'Pronto');
  setStdin(false);
}

function setStdin(enabled) {
  stdinInput.disabled = !enabled;
  sendBtn.disabled = !enabled;
  if (enabled) stdinInput.focus();
}

stdinInput.addEventListener('keydown', e => {
  if (e.key === 'Enter') sendStdin();
});

function sendStdin() {
  const val = stdinInput.value;
  stdinInput.value = '';
  // Echo to output
  appendOutput(val + '\\n', false, true);
  vscode.postMessage({ type: 'stdin', text: val });
}

function appendBuild(html) {
  // Remove placeholder if present
  const ph = buildLog.querySelector('span[style]');
  if (ph) ph.remove();
  buildLog.insertAdjacentHTML('beforeend', html);
  scrollToBottom();
}

function appendOutput(text, isErr, isEcho) {
  const cls = isEcho ? 'stdin-echo' : (isErr ? 'stderr-text' : '');
  const escaped = escHtml(text);
  if (cls) {
    outputArea.insertAdjacentHTML('beforeend', '<span class="' + cls + '">' + escaped + '</span>');
  } else {
    outputArea.insertAdjacentHTML('beforeend', escaped);
  }
  scrollToBottom();
}

function scrollToBottom() {
  const c = document.getElementById('content');
  c.scrollTop = c.scrollHeight;
}

function escHtml(s) {
  return s
    .replace(/&/g, '&amp;')
    .replace(/</g, '&lt;')
    .replace(/>/g, '&gt;');
}

function formatCompilerOutput(raw) {
  // Color-code GCC/Clang error output line by line
  const lines = raw.split('\\n');
  let html = '';
  for (const line of lines) {
    if (!line) { html += '\\n'; continue; }
    // file:line:col: error: ...
    if (/: error:/.test(line)) {
      html += '<span class="error-line">' + escHtml(line) + '</span>\\n';
    } else if (/: warning:/.test(line)) {
      html += '<span class="warning-line">' + escHtml(line) + '</span>\\n';
    } else if (/: note:/.test(line)) {
      html += '<span class="note-line">' + escHtml(line) + '</span>\\n';
    } else if (/^\\s*\\^/.test(line) || /^\\s*~/.test(line)) {
      html += '<span class="pointer-line">' + escHtml(line) + '</span>\\n';
    } else {
      html += '<span class="context-line">' + escHtml(line) + '</span>\\n';
    }
  }
  return html;
}

window.addEventListener('message', e => {
  const msg = e.data;

  switch (msg.type) {

    case 'start-compile':
      buildLog.innerHTML = '';
      outputArea.innerHTML = '';
      outputHeader.style.display = 'none';
      exitBar.className = '';
      exitBar.innerHTML = '';
      setStatus('compiling', '⚙ Compilazione...');
      setStdin(false);
      appendBuild(
        '<div class="build-status-line">' +
        '<span class="spinner">⟳</span> Compilazione di <strong>' + escHtml(msg.file) + '</strong>...</div>'
      );
      break;

    case 'compile-ok':
      setStatus('ok', '✓ Compilato');
      appendBuild(
        '<div class="compile-ok">✓ Compilato con successo in ' + escHtml(msg.elapsed) + 's</div>'
      );
      break;

    case 'compile-error':
      setStatus('error', '✗ Errore');
      appendBuild(
        '<div class="error-summary">' +
        '<div class="err-title">✗ Errore di compilazione (' + escHtml(msg.elapsed) + 's)</div>' +
        formatCompilerOutput(msg.output) +
        '</div>'
      );
      break;

    case 'start-run':
      setStatus('running', '▶ In esecuzione...');
      outputHeader.style.display = 'flex';
      setStdin(true);
      break;

    case 'output':
      appendOutput(msg.text, msg.isErr);
      break;

    case 'run-done': {
      setStdin(false);
      const ok = msg.code === 0;
      setStatus(ok ? 'ok' : 'error', ok ? '✓ Terminato' : '✗ Terminato (errore)');
      exitBar.className = 'show';
      exitBar.innerHTML =
        '<span>Processo terminato</span>' +
        '<span class="' + (ok ? 'exit-ok' : 'exit-err') + '">' +
        'Codice uscita: ' + msg.code +
        '</span>' +
        '<span style="margin-left:auto;color:var(--fg2)">Tempo: ' + msg.elapsed + 's</span>';
      scrollToBottom();
      break;
    }

    case 'run-stopped':
      setStdin(false);
      setStatus('', 'Fermato');
      exitBar.className = 'show';
      exitBar.innerHTML = '<span style="color:var(--yellow)">⏹ Esecuzione interrotta dall\'utente</span>';
      break;
  }
});
</script>
</body>
</html>`;
    }
}
