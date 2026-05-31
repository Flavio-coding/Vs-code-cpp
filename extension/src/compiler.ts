import * as vscode from 'vscode';
import * as cp from 'child_process';
import * as path from 'path';
import * as fs from 'fs';
import { OutputPanel } from './outputPanel';

type CompilerState = 'idle' | 'compiling' | 'running' | 'error';

export class Compiler {
    private _process: cp.ChildProcess | undefined;
    private _state: CompilerState = 'idle';
    private _onStateChange = new vscode.EventEmitter<CompilerState>();
    readonly onStateChange = this._onStateChange.event;

    constructor(
        private readonly context: vscode.ExtensionContext,
        private readonly panel: OutputPanel
    ) {}

    async compileAndRun() {
        const filePath = this.getActiveFilePath();
        if (!filePath) {
            vscode.window.showWarningMessage('Nessun file C/C++ aperto.');
            return;
        }

        // Save file before compiling
        const doc = vscode.window.activeTextEditor?.document;
        if (doc?.isDirty) {
            await doc.save();
        }

        const outPath = await this.compile(filePath);
        if (outPath) {
            await this.runExecutable(outPath);
        }
    }

    async compile(filePath: string | undefined): Promise<string | undefined> {
        if (!filePath) {
            vscode.window.showWarningMessage('Nessun file C/C++ aperto.');
            return undefined;
        }

        const compilerExe = await this.findCompiler(filePath);
        if (!compilerExe) return undefined;

        const cfg = vscode.workspace.getConfiguration('cpp-runner');
        const extraArgs: string[] = cfg.get('compileArgs') ?? ['-Wall', '-g'];
        const outputDir: string = cfg.get('outputDir') ?? '';

        const fileDir = path.dirname(filePath);
        const baseName = path.basename(filePath, path.extname(filePath));
        const outDir = outputDir || fileDir;
        const outExt = process.platform === 'win32' ? '.exe' : '';
        const outPath = path.join(outDir, baseName + outExt);

        const args = [...extraArgs, '-o', outPath, filePath];
        const compileCmd = `${compilerExe} ${args.map(a => `"${a}"`).join(' ')}`;

        this.setState('compiling');
        await vscode.commands.executeCommand('setContext', 'cpp-runner.isRunning', false);

        this.panel.startCompilation(path.basename(filePath));

        const start = Date.now();
        return new Promise(resolve => {
            const proc = cp.spawn(compilerExe, args, { shell: false });
            let stderr = '';

            proc.stderr.on('data', (data: Buffer) => {
                stderr += data.toString();
            });
            proc.stdout.on('data', (data: Buffer) => {
                stderr += data.toString();
            });

            proc.on('close', code => {
                const elapsed = ((Date.now() - start) / 1000).toFixed(2);
                if (code === 0) {
                    this.panel.compilationSuccess(elapsed);
                    this.setState('idle');
                    resolve(outPath);
                } else {
                    this.panel.compilationError(stderr, elapsed);
                    this.setState('error');
                    resolve(undefined);
                }
            });

            proc.on('error', err => {
                this.panel.compilationError(`Impossibile avviare il compilatore: ${err.message}\n\nPercorso: ${compilerExe}\n\nVerifica le impostazioni in File > Preferenze > Impostazioni > "C/C++ Runner".`, '0');
                this.setState('error');
                resolve(undefined);
            });
        });
    }

    async runExecutable(exePath: string) {
        if (!fs.existsSync(exePath)) {
            vscode.window.showErrorMessage(`File eseguibile non trovato: ${exePath}`);
            return;
        }

        this.setState('running');
        await vscode.commands.executeCommand('setContext', 'cpp-runner.isRunning', true);

        const workDir = path.dirname(exePath);
        this.panel.startExecution();

        const start = Date.now();
        this._process = cp.spawn(exePath, [], {
            cwd: workDir,
            shell: false
        });

        this._process.stdout?.on('data', (data: Buffer) => {
            this.panel.appendOutput(data.toString());
        });
        this._process.stderr?.on('data', (data: Buffer) => {
            this.panel.appendOutput(data.toString(), true);
        });

        // Forward stdin from the panel
        this.panel.onStdinInput(line => {
            this._process?.stdin?.write(line + '\n');
        });

        this._process.on('close', code => {
            const elapsed = ((Date.now() - start) / 1000).toFixed(2);
            this.panel.executionFinished(code ?? -1, elapsed);
            this.setState('idle');
            vscode.commands.executeCommand('setContext', 'cpp-runner.isRunning', false);
            this._process = undefined;
        });

        this._process.on('error', err => {
            this.panel.appendOutput(`\nErrore: impossibile avviare il programma: ${err.message}`, true);
            this.setState('error');
            vscode.commands.executeCommand('setContext', 'cpp-runner.isRunning', false);
            this._process = undefined;
        });
    }

    stop() {
        if (this._process) {
            if (process.platform === 'win32') {
                cp.exec(`taskkill /pid ${this._process.pid} /T /F`);
            } else {
                this._process.kill('SIGTERM');
            }
            this._process = undefined;
        }
        this.setState('idle');
        vscode.commands.executeCommand('setContext', 'cpp-runner.isRunning', false);
        this.panel.executionStopped();
    }

    private setState(state: CompilerState) {
        this._state = state;
        this._onStateChange.fire(state);
    }

    private getActiveFilePath(): string | undefined {
        const editor = vscode.window.activeTextEditor;
        if (!editor) return undefined;
        const lang = editor.document.languageId;
        if (lang !== 'c' && lang !== 'cpp') {
            vscode.window.showWarningMessage('Il file attivo non è un file C/C++.');
            return undefined;
        }
        return editor.document.uri.fsPath;
    }

    private async findCompiler(filePath: string): Promise<string | undefined> {
        const isCpp = filePath.endsWith('.cpp') || filePath.endsWith('.cxx') || filePath.endsWith('.cc');
        const cfg = vscode.workspace.getConfiguration('cpp-runner');
        const customPath: string = cfg.get('compilerPath') ?? '';
        const cCompiler: string = cfg.get('cCompiler') ?? 'gcc';
        const cppCompiler: string = cfg.get('cppCompiler') ?? 'g++';
        const compilerName = isCpp ? cppCompiler : cCompiler;

        // 1. Custom path from settings
        if (customPath) {
            const full = path.join(customPath, compilerName + (process.platform === 'win32' ? '.exe' : ''));
            if (fs.existsSync(full)) return full;
            // Maybe customPath already IS the full path to the compiler
            if (fs.existsSync(customPath)) return customPath;
        }

        // 2. Bundled MinGW next to the VS Code portable installation
        const bundledPaths = this.getBundledCompilerPaths(compilerName);
        for (const p of bundledPaths) {
            if (fs.existsSync(p)) return p;
        }

        // 3. System PATH
        const fromPath = await this.findInPath(compilerName);
        if (fromPath) return fromPath;

        // Not found — help the user
        const choice = await vscode.window.showErrorMessage(
            `Compilatore non trovato: ${compilerName}.\n\nInstalla MinGW-w64 oppure imposta il percorso nelle impostazioni.`,
            'Apri Impostazioni',
            'Download MinGW'
        );
        if (choice === 'Apri Impostazioni') {
            vscode.commands.executeCommand('workbench.action.openSettings', 'cpp-runner.compilerPath');
        } else if (choice === 'Download MinGW') {
            vscode.env.openExternal(vscode.Uri.parse('https://winlibs.com/#package-versions-win64'));
        }
        return undefined;
    }

    private getBundledCompilerPaths(compilerName: string): string[] {
        const ext = process.platform === 'win32' ? '.exe' : '';
        const exe = compilerName + ext;

        // Possible locations relative to VS Code installation
        const vscodeExe = process.execPath; // path to code.exe or electron
        const vscodeDir = path.dirname(vscodeExe);

        return [
            // Next to VSCode portable: ..\mingw64\bin\
            path.join(vscodeDir, '..', '..', 'mingw64', 'bin', exe),
            path.join(vscodeDir, '..', 'mingw64', 'bin', exe),
            // Standard installation by our installer
            path.join('C:', 'vscodecpp', 'mingw64', 'bin', exe),
            path.join(process.env.LOCALAPPDATA ?? '', 'vscodecpp', 'mingw64', 'bin', exe),
        ];
    }

    private findInPath(name: string): Promise<string | undefined> {
        return new Promise(resolve => {
            const cmd = process.platform === 'win32' ? `where ${name}` : `which ${name}`;
            cp.exec(cmd, (err, stdout) => {
                if (!err && stdout.trim()) {
                    resolve(stdout.trim().split('\n')[0].trim());
                } else {
                    resolve(undefined);
                }
            });
        });
    }
}
