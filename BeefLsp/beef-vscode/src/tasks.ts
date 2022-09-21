import * as vscode from "vscode";
import { Extension } from "./extension";

type BuildResult = {
    error?: string;

    exitCode?: number;
    lines?: string[];
};

type RunResult = {
    target: string;
    arguments: string;
    workingDir: string;
    env: string[];
};

interface BuildDefinition extends vscode.TaskDefinition {
    clean: boolean;
}

interface RunDefinition extends vscode.TaskDefinition {
    project: string;
}

class BuildTerminal implements vscode.Pseudoterminal {
    private ext: Extension;
    private clean: boolean;

    private writeEmitter = new vscode.EventEmitter<string>();
    private closeEmitter = new vscode.EventEmitter<number>();

    onDidWrite = this.writeEmitter.event;
    onDidClose? = this.closeEmitter.event;

    constructor(ext: Extension, clean: boolean) {
        this.ext = ext;
        this.clean = clean;
    }

    open(_initialDimensions: vscode.TerminalDimensions | undefined): void {
        this.ext.sendLspRequest<BuildResult>("beef/build", { clean: this.clean })
            .then(result => {
                result.lines?.forEach(line => {
                    let prefix = "\x1b[0m";

                    if (line.startsWith("ERROR")) prefix = "\x1b[31m";
                    else if (line.startsWith("WARNING")) prefix = "\x1b[93m";
                    else if (line.startsWith("Compile ")) prefix = "\x1b[1m";

                    this.writeEmitter.fire(prefix + line + "\r\n");
                });

                if (result.error) vscode.window.showErrorMessage(result.error);
                this.closeEmitter.fire(result.exitCode ?? 0);
            })
            .catch(() => this.closeEmitter.fire(0));
    }

    close(): void {}
}

export function registerTasks(ext: Extension) {
    ext.disposable(vscode.tasks.registerTaskProvider("beef-build", {
        provideTasks: () => undefined,
        resolveTask: task => new vscode.Task(
            task.definition,
            task.scope ?? vscode.TaskScope.Workspace,
            task.name,
            "beef",
            new vscode.CustomExecution(() => Promise.resolve(new BuildTerminal(ext, (task.definition as BuildDefinition).clean)))
        )
    }));

    ext.disposable(vscode.tasks.registerTaskProvider("beef-run", {
        provideTasks: () => undefined,
        resolveTask: task => new Promise((resolve, reject) => {
            task.definition.type
            ext.sendLspRequest<RunResult>("beef/run", { project: (task.definition as RunDefinition).project })
                .then(result => {
                    const env: { [key: string]: string } = {};

                    result.env.forEach(variable => env[variable] = "TRUE");

                    resolve(new vscode.Task(
                        task.definition,
                        task.scope ?? vscode.TaskScope.Workspace,
                        task.name,
                        "beef",
                        new vscode.ShellExecution(result.target + " " + result.arguments, {
                            cwd: result.workingDir,
                            env: env
                        })
                    ));
                })
                .catch(reject)
        })
    }));
}