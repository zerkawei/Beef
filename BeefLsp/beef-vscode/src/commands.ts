import * as vscode from "vscode";
import { Extension } from "./extension";

export function registerCommands(ext: Extension) {
    ext.registerCommand("beeflang.changeConfiguration", onChangeConfiguration);
    ext.registerCommand("beeflang.restart", onRestart, false);
};

function onChangeConfiguration(ext: Extension) {
    vscode.window.showQuickPick(ext.getConfigurations(), { title: "Beef Configuration" })
        .then(value => {
            if (value) {
                ext.sendLspRequest<any>("beef/changeConfiguration", { configuration: value })
                    .then(args => ext.setConfiguration(args.configuration));
            }
        });
}

async function onRestart(ext: Extension) {
    await ext.stop();
    ext.start();
}