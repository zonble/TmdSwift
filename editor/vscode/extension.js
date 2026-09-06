const vscode = require('vscode');
const { execFile } = require('child_process');
const path = require('path');
const fs = require('fs');

/**
 * Get configured or discovered path to tmd binary.
 */
function getTmdExecutable() {
    const config = vscode.workspace.getConfiguration('tmd');
    const customPath = config.get('executablePath');
    if (customPath && customPath.trim().length > 0) {
        return customPath.trim();
    }
    return 'tmd';
}

/**
 * Get active editor's file path, ensuring it is a .tmd file.
 */
function getActiveTmdFilePath() {
    const editor = vscode.window.activeTextEditor;
    if (!editor) {
        vscode.window.showErrorMessage('No active editor found. Please open a .tmd file.');
        return null;
    }
    const doc = editor.document;
    if (doc.isUntitled) {
        vscode.window.showErrorMessage('Please save the file before exporting.');
        return null;
    }
    const ext = path.extname(doc.fileName).toLowerCase();
    if (ext !== '.tmd') {
        vscode.window.showWarningMessage('The active file does not appear to be a .tmd file.');
    }
    return doc.fileName;
}

/**
 * Runs a tmd command with arguments.
 */
function runTmdExport(args, successMessage, outputFilePath) {
    const tmdBin = getTmdExecutable();
    const activeDoc = vscode.window.activeTextEditor?.document;

    // Save document if dirty before running export
    const savePromise = (activeDoc && activeDoc.isDirty) ? activeDoc.save() : Promise.resolve(true);

    savePromise.then(() => {
        vscode.window.withProgress({
            location: vscode.ProgressLocation.Notification,
            title: 'TMD: Exporting...',
            cancellable: false
        }, () => {
            return new Promise((resolve) => {
                execFile(tmdBin, args, (error, stdout, stderr) => {
                    if (error) {
                        const errMsg = (stderr && stderr.trim().length > 0) ? stderr.trim() : error.message;
                        vscode.window.showErrorMessage(`TMD Export Failed: ${errMsg}`);
                        resolve();
                        return;
                    }

                    if (outputFilePath && fs.existsSync(outputFilePath)) {
                        vscode.window.showInformationMessage(successMessage, 'Reveal in Finder', 'Open')
                            .then(selection => {
                                if (selection === 'Reveal in Finder') {
                                    vscode.commands.executeCommand('revealFileInOS', vscode.Uri.file(outputFilePath));
                                } else if (selection === 'Open') {
                                    vscode.commands.executeCommand('vscode.open', vscode.Uri.file(outputFilePath));
                                }
                            });
                    } else {
                        vscode.window.showInformationMessage(successMessage);
                    }
                    resolve();
                });
            });
        });
    });
}

function activate(context) {
    // 1. Export to MIDI (.mid)
    context.subscriptions.push(vscode.commands.registerCommand('tmd.exportMIDI', () => {
        const filePath = getActiveTmdFilePath();
        if (!filePath) return;
        const outputPath = filePath.replace(/\.[^/.]+$/, '') + '.mid';
        runTmdExport([filePath, '-m', outputPath], `Exported to MIDI: ${path.basename(outputPath)}`, outputPath);
    }));

    // 2. Export to MusicXML (.musicxml)
    context.subscriptions.push(vscode.commands.registerCommand('tmd.exportMusicXML', () => {
        const filePath = getActiveTmdFilePath();
        if (!filePath) return;
        const outputPath = filePath.replace(/\.[^/.]+$/, '') + '.musicxml';
        runTmdExport([filePath, '-x', outputPath], `Exported to MusicXML: ${path.basename(outputPath)}`, outputPath);
    }));

    // 3. Export to ABC (.abc)
    context.subscriptions.push(vscode.commands.registerCommand('tmd.exportABC', () => {
        const filePath = getActiveTmdFilePath();
        if (!filePath) return;
        const outputPath = filePath.replace(/\.[^/.]+$/, '') + '.abc';
        runTmdExport([filePath, '-a', outputPath], `Exported to ABC notation: ${path.basename(outputPath)}`, outputPath);
    }));

    // 4. Export to LilyPond (.ly)
    context.subscriptions.push(vscode.commands.registerCommand('tmd.exportLilyPond', () => {
        const filePath = getActiveTmdFilePath();
        if (!filePath) return;
        const outputPath = filePath.replace(/\.[^/.]+$/, '') + '.ly';
        runTmdExport([filePath, '-l', outputPath], `Exported to LilyPond: ${path.basename(outputPath)}`, outputPath);
    }));

    // 5. Render to PDF via LilyPond (.pdf)
    context.subscriptions.push(vscode.commands.registerCommand('tmd.renderPDF', () => {
        const filePath = getActiveTmdFilePath();
        if (!filePath) return;
        const outputPath = filePath.replace(/\.[^/.]+$/, '') + '.pdf';
        runTmdExport([filePath, '--pdf-output', outputPath], `Rendered to PDF: ${path.basename(outputPath)}`, outputPath);
    }));

    // 6. Render to WAV Audio (.wav)
    context.subscriptions.push(vscode.commands.registerCommand('tmd.renderWAV', () => {
        const filePath = getActiveTmdFilePath();
        if (!filePath) return;
        const outputPath = filePath.replace(/\.[^/.]+$/, '') + '.wav';
        runTmdExport([filePath, '-w', outputPath], `Rendered to WAV Audio: ${path.basename(outputPath)}`, outputPath);
    }));

    // 7. Play Audio in Terminal Preview
    context.subscriptions.push(vscode.commands.registerCommand('tmd.playAudio', () => {
        const filePath = getActiveTmdFilePath();
        if (!filePath) return;
        const tmdBin = getTmdExecutable();
        const termName = 'TMD Audio Playback';
        let term = vscode.window.terminals.find(t => t.name === termName);
        if (!term) {
            term = vscode.window.createTerminal(termName);
        }
        term.show();
        term.sendText(`"${tmdBin}" "${filePath}" -p`);
    }));

    // 8. Install AI Skills
    context.subscriptions.push(vscode.commands.registerCommand('tmd.installSkills', () => {
        const tmdBin = getTmdExecutable();
        vscode.window.withProgress({
            location: vscode.ProgressLocation.Notification,
            title: 'TMD: Installing AI Agent Skills...',
            cancellable: false
        }, () => {
            return new Promise((resolve) => {
                execFile(tmdBin, ['--install-skills'], (error, stdout, stderr) => {
                    if (error) {
                        const errMsg = (stderr && stderr.trim().length > 0) ? stderr.trim() : error.message;
                        vscode.window.showErrorMessage(`Failed to install skills: ${errMsg}`);
                    } else {
                        vscode.window.showInformationMessage('Successfully installed TMD AI Skills for Codex, Claude, Antigravity, and Gemini.');
                    }
                    resolve();
                });
            });
        });
    }));
}

function deactivate() {}

module.exports = {
    activate,
    deactivate
};
