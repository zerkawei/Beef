import * as vscode from "vscode";
import * as toml from "toml";

export class WorkspaceEditorProvider implements vscode.CustomTextEditorProvider {
    public static register(context: vscode.ExtensionContext): vscode.Disposable {
        const provider = new WorkspaceEditorProvider(context);
        return vscode.window.registerCustomEditorProvider("beef.workspace", provider);
    }

    constructor(
        private readonly context: vscode.ExtensionContext
    ) {}

    resolveCustomTextEditor(document: vscode.TextDocument, webviewPanel: vscode.WebviewPanel, token: vscode.CancellationToken): void | Thenable<void> {
        const toolkitUri = webviewPanel.webview.asWebviewUri(vscode.Uri.joinPath(this.context.extensionUri, "node_modules", "@vscode", "webview-ui-toolkit", "dist", "toolkit.js"));

        const data = toml.parse(document.getText());

        webviewPanel.webview.options = {
            enableScripts: true
        };

        webviewPanel.webview.html = `
        <!DOCTYPE html>
        <html lang="en">
        <head>
            <meta charset="UTF-8">
            <meta http-equiv="X-UA-Compatible" content="IE=edge">
            <meta name="viewport" content="width=device-width, initial-scale=1.0">
            <script type="module" src="${toolkitUri}"></script>
            <title>Beef Workspace</title>
        </head>
        <body>
            <vscode-text-field id="startup">Startup Project</vscode-text-field>

            <vscode-divider></vscode-divider>
            <h2>Build</h2>
            <vscode-data-grid grid-template-columns="100px">
                <vscode-data-grid-row>
                    <vscode-data-grid-cell grid-column="1">
                        <span>Toolset</span>
                    </vscode-data-grid-cell>
                    <vscode-data-grid-cell grid-column="2">
                        <vscode-dropdown position="below">
                            <vscode-option>GNU</vscode-option>
                            <vscode-option>Microsoft</vscode-option>
                            <vscode-option>LLVM</vscode-option>
                        </vscode-dropdown>
                    </vscode-data-grid-cell>
                </vscode-data-grid-row>

                <vscode-data-grid-row>
                    <vscode-data-grid-cell grid-column="1">
                        <span>Build Type</span>
                    </vscode-data-grid-cell>
                    <vscode-data-grid-cell grid-column="2">
                        <vscode-dropdown position="below">
                            <vscode-option>Normal</vscode-option>
                            <vscode-option>Test</vscode-option>
                        </vscode-dropdown>
                    </vscode-data-grid-cell>
                </vscode-data-grid-row>
            </vscode-data-grid>

            <script>
                document.querySelector("#startup").value = "${data.Workspace.StartupProject}";
            </script>
        </body>
        </html>
        `;
    }
}