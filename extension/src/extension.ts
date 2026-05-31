import * as vscode from 'vscode';
import { Compiler } from './compiler';
import { OutputPanel } from './outputPanel';

let compiler: Compiler | undefined;
let statusBarItem: vscode.StatusBarItem;

export function activate(context: vscode.ExtensionContext) {
    const outputPanel = new OutputPanel(context);
    compiler = new Compiler(context, outputPanel);

    statusBarItem = vscode.window.createStatusBarItem(vscode.StatusBarAlignment.Left, 100);
    statusBarItem.command = 'cpp-runner.run';
    context.subscriptions.push(statusBarItem);

    context.subscriptions.push(
        vscode.commands.registerCommand('cpp-runner.run', async () => {
            await compiler!.compileAndRun();
        }),
        vscode.commands.registerCommand('cpp-runner.build', async () => {
            await compiler!.compile(getCurrentFilePath());
        }),
        vscode.commands.registerCommand('cpp-runner.stop', () => {
            compiler!.stop();
        })
    );

    // Update status bar when active editor changes
    context.subscriptions.push(
        vscode.window.onDidChangeActiveTextEditor(() => updateStatusBar()),
        compiler.onStateChange(state => {
            updateStatusBarState(state);
        })
    );

    updateStatusBar();
}

function getCurrentFilePath(): string | undefined {
    return vscode.window.activeTextEditor?.document.uri.fsPath;
}

function updateStatusBar() {
    const editor = vscode.window.activeTextEditor;
    const lang = editor?.document.languageId;
    if (lang === 'c' || lang === 'cpp') {
        statusBarItem.show();
        updateStatusBarState('idle');
    } else {
        statusBarItem.hide();
    }
}

function updateStatusBarState(state: string) {
    switch (state) {
        case 'compiling':
            statusBarItem.text = '$(loading~spin) Compilazione...';
            statusBarItem.tooltip = 'Compilazione in corso...';
            statusBarItem.backgroundColor = undefined;
            break;
        case 'running':
            statusBarItem.text = '$(stop-circle) Stop (Shift+F5)';
            statusBarItem.tooltip = 'Programma in esecuzione — clicca per fermare';
            statusBarItem.command = 'cpp-runner.stop';
            statusBarItem.backgroundColor = new vscode.ThemeColor('statusBarItem.warningBackground');
            break;
        case 'error':
            statusBarItem.text = '$(error) Errore — F5 per riprovare';
            statusBarItem.tooltip = 'Compilazione fallita. Premi F5 per riprovare.';
            statusBarItem.command = 'cpp-runner.run';
            statusBarItem.backgroundColor = new vscode.ThemeColor('statusBarItem.errorBackground');
            break;
        default:
            statusBarItem.text = '$(play) Esegui (F5)';
            statusBarItem.tooltip = 'Compila ed esegui (F5)';
            statusBarItem.command = 'cpp-runner.run';
            statusBarItem.backgroundColor = undefined;
    }
}

export function deactivate() {
    compiler?.stop();
}
