import * as vscode from "vscode";
import { Extension } from "./extension";
import { Project } from "./types";

export function registerSettingsView(ext: Extension, name: string, projectSpecific: boolean) {
    ext.registerCommand("beeflang." + name + "Settings", ext => {
        if (projectSpecific) {
            getProject(ext).then(project => openView(ext, name, project));
        }
        else openView(ext, name, null);
    });
}

function getProject(ext: Extension): Promise<string> {
    const editor = vscode.window.activeTextEditor;

    if (editor !== undefined && editor.document.fileName.endsWith(".toml")) {
        return new Promise((resolve, reject) => {
            ext.sendLspRequest<string>("beef/fileProject", { textDocument: { uri: editor.document.uri.toString() } })
                .then(project => {
                    if (project === "") getProjectByQuickPick(ext).then(resolve).catch(reject);
                    else resolve(project);
                })
                .catch(reject);
        });
    }

    return getProjectByQuickPick(ext);
}

function getProjectByQuickPick(ext: Extension): Promise<string> {
    return new Promise((resolve, reject) => {
        ext.sendLspRequest<Project[]>("beef/projects")
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

function openView(ext: Extension, name: string, project: string | null) {
    let title = capitalize(name) + " Settings";
    if (project !== null) title += ": " + project;
    
    const panel = vscode.window.createWebviewPanel("beeflang." + name + "Settings", title, vscode.ViewColumn.Active, {
        enableScripts: true,
        retainContextWhenHidden: true
    });

    panel.iconPath = {
        dark: ext.uri("images", "gear-light.svg"),
        light: ext.uri("images", "gear-dark.svg")
    };
    const cssUri = panel.webview.asWebviewUri(ext.uri("out", "settings.css"));
    const jsUri = panel.webview.asWebviewUri(ext.uri("out", "settings.js"));

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

    sendSchema(ext, panel, name, project);
    handleMessages(ext, panel, project);
}

function sendSchema(ext: Extension, panel: vscode.WebviewPanel, name: string, project: string | null) {
    let options: any = {
        id: name
    };

    if (project !== null) options.project = project;

    ext.sendLspRequest<any>("beef/settingsSchema", options)
        .then(schema => {
            panel.webview.postMessage({
                message: "schema",
                schema: schema
            });
        });
}

function handleMessages(ext: Extension, panel: vscode.WebviewPanel, project: string | null) {
    panel.webview.onDidReceiveMessage(message => {
        let options: any = {
            id: message.id,
            configuration: message.configuration,
            platform: message.platform
        };
        if (project != null) options.project = project;

        if (message.type === "values") {
            ext.sendLspRequest<any>("beef/getSettingsValues", options)
                .then(values => {
                    panel.webview.postMessage({
                        message: "values",
                        values: values
                    });
                });
        }
        else if (message.type === "set-values") {
            options.groups = message.groups;

            ext.sendLspNotification("beef/setSettingsValues", options);
        }
    });
}