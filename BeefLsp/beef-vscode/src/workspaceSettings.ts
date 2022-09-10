import * as vscode from "vscode";

export function register(context: vscode.ExtensionContext) {
    context.subscriptions.push(vscode.commands.registerCommand("beeflang.workspaceSettings", () => handler(context)));
}

function handler(context: vscode.ExtensionContext) {
    const panel = vscode.window.createWebviewPanel("beeflang.workspaceSettings", "Workspace Settings", vscode.ViewColumn.Active, {
        enableScripts: true
    });

    const cssUri = panel.webview.asWebviewUri(vscode.Uri.joinPath(context.extensionUri, "out", "ui", "style.css"));
    const jsUri = panel.webview.asWebviewUri(vscode.Uri.joinPath(context.extensionUri, "out", "ui", "workspace.js"));

    panel.webview.html = `
    <!DOCTYPE html>
    <html lang="en">
    <head>
        <meta charset="UTF-8">
        <meta http-equiv="X-UA-Compatible" content="IE=edge">
        <meta name="viewport" content="width=device-width, initial-scale=1.0">
        <link rel="stylesheet" href="${cssUri}">
        <title>Beef Workspace</title>
    </head>
    <body>
        <div id="app"></div>
        <script src="${jsUri}"></script>
    </body>
    `;
}