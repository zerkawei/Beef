import * as vscode from "vscode";
import { LanguageClient } from "vscode-languageclient/node";

type Project = {
    name: string;
    dir: string;
};

export function registerSettingsView(context: vscode.ExtensionContext, client: LanguageClient, name: string, projectSpecific: boolean) {
    context.subscriptions.push(vscode.commands.registerCommand("beeflang." + name + "Settings", () => {
        if (projectSpecific) {
            getProject(client).then(project => openView(context, client, name, project));
        }
        else openView(context, client, name, null);
    }));
}

function getProject(client: LanguageClient): Promise<string> {
    const editor = vscode.window.activeTextEditor;

    if (editor !== undefined && editor.document.fileName.endsWith(".toml")) {
        return new Promise((resolve, reject) => {
            client.sendRequest<string>("beef/fileProject", { textDocument: { uri: editor.document.uri.toString() } })
                .then(project => {
                    if (project === "") getProjectByQuickPick(client).then(resolve).catch(reject);
                    else resolve(project);
                })
                .catch(reject);
        });
    }

    return getProjectByQuickPick(client);
}

function getProjectByQuickPick(client: LanguageClient): Promise<string> {
    return new Promise((resolve, reject) => {
        client.sendRequest<Project[]>("beef/projects")
            .then(projects => {
                let names = projects.map(project => project.name);

                vscode.window.showQuickPick(names)
                    .then(name => {
                        if (name !== undefined) resolve(name);
                    }, reject);
            });
    });
}

function capitalize(str: string) {
    return str.charAt(0).toUpperCase() + str.slice(1);
  }

function openView(context: vscode.ExtensionContext, client: LanguageClient, name: string, project: string | null) {
    let title = capitalize(name) + " Settings";
    if (project !== null) title += ": " + project;
    
    const panel = vscode.window.createWebviewPanel("beeflang." + name + "Settings", title, vscode.ViewColumn.Active, {
        enableScripts: true,
        retainContextWhenHidden: true
    });

    panel.iconPath = {
        dark: vscode.Uri.joinPath(context.extensionUri, "images", "gear-light.svg"),
        light: vscode.Uri.joinPath(context.extensionUri, "images", "gear-dark.svg")
    };

    const cssUri = panel.webview.asWebviewUri(vscode.Uri.joinPath(context.extensionUri, "out", "settings.css"));
    const jsUri = panel.webview.asWebviewUri(vscode.Uri.joinPath(context.extensionUri, "out", "settings.js"));

    panel.webview.html = `
    <!DOCTYPE html>
    <html lang="en">
    <head>
        <meta charset="UTF-8">
        <meta http-equiv="X-UA-Compatible" content="IE=edge">
        <meta name="viewport" content="width=device-width, initial-scale=1.0">
        <link rel="stylesheet" href="${cssUri}">
        <title>Beef ${capitalize(name)}</title>
    </head>
    <body>
        <div id="app"></div>
        <script src="${jsUri}"></script>
    </body>
    `;

    sendSchema(panel, client, name, project);
    handleMessages(panel, client, project);
}

function sendSchema(panel: vscode.WebviewPanel, client: LanguageClient, name: string, project: string | null) {
    let options: any = {
        id: name
    };

    if (project !== null) options.project = project;

    client.sendRequest<any>("beef/settingsSchema", options)
        .then(schema => {
            panel.webview.postMessage({
                message: "schema",
                schema: schema
            });
        });
}

function handleMessages(panel: vscode.WebviewPanel, client: LanguageClient, project: string | null) {
    panel.webview.onDidReceiveMessage(message => {
        let options: any = {
            id: message.id,
            configuration: message.configuration,
            platform: message.platform
        };
        if (project != null) options.project = project;

        if (message.type === "values") {
            client.sendRequest<any>("beef/getSettingsValues", options)
                .then(values => {
                    panel.webview.postMessage({
                        message: "values",
                        values: values
                    });
                });
        }
        else if (message.type === "set-values") {
            options.groups = message.groups;

            client.sendNotification("beef/setSettingsValues", options);
        }
    });
}