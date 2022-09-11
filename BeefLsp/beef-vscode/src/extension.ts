import * as vscode from "vscode";
import * as net from "net";
import { LanguageClient, LanguageClientOptions, ServerOptions, StreamInfo } from "vscode-languageclient/node";
import { register } from "./workspaceSettings";

type InitializedArgs = {
	configuration: string;
	configurations: string[];
};

let barItem: vscode.StatusBarItem;
let buildBarItem: vscode.StatusBarItem;
let client: LanguageClient;

let initialized = false;
let configurations: string[];

const tcp = true;

export function activate(context: vscode.ExtensionContext) {
	let serverOptions: ServerOptions = {
		command: "BeefLsp"
	};

	if (tcp) {
		serverOptions = () => {
			let socket = net.createConnection({
				port: 5556
			});
	
			let result: StreamInfo = {
				writer: socket,
				reader: socket
			};
	
			return Promise.resolve(result);
		};
	}

	let clientOptions: LanguageClientOptions = {
		documentSelector: [{ scheme: "file", language: "bf" }]
	};

	client = new LanguageClient(
		"beeflang",
		"Beef Lang",
		serverOptions,
		clientOptions
	);

	barItem = vscode.window.createStatusBarItem("beef-lsp", vscode.StatusBarAlignment.Left, 2);
	barItem.name = "Beef Lsp Status";
	barItem.text = "$(loading~spin) Beef Lsp";
	barItem.tooltip = "Status: Starting";
	barItem.command = "beeflang.changeConfiguration";
	barItem.show();

	buildBarItem = vscode.window.createStatusBarItem("beef-lsp", vscode.StatusBarAlignment.Left);
	buildBarItem.name = "Beef Build";
	buildBarItem.text = "$(loading~spin) Building";
	
	client.start();

	context.subscriptions.push(vscode.commands.registerCommand("beeflang.changeConfiguration", onChangeConfiguration));
	context.subscriptions.push(vscode.commands.registerCommand("beeflang.build", onBuild));
	register(context);

	vscode.languages.setLanguageConfiguration()

	client.onReady().then(onReady);
}

function onReady() {
	client.onNotification("beef/initialized", (args: InitializedArgs) => {
		barItem.text = "$(check) Beef Lsp: " + args.configuration;
		barItem.tooltip = "Status: Running";

		initialized = true;
		configurations = args.configurations;
	});
}

function onChangeConfiguration() {
	if (!initialized) return;

	vscode.window.showQuickPick(configurations, { title: "Beef Configuration" })
		.then(value => {
			if (value) {
				barItem.text = "$(loading~spin) Beef Lsp: " + value;

				client.sendRequest<any>("beef/changeConfiguration", { configuration: value })
					.then(args => {
						barItem.text = "$(check) Beef Lsp: " + args.configuration;
					});
			}
		});
}

function onBuild() {
	if (!initialized) return;

	buildBarItem.show();

	client.sendRequest("beef/build")
		.catch(() => vscode.window.showErrorMessage("Beef: Failed to build workspace"))
		.finally(() => buildBarItem.hide());
}

export async function deactivate() {
	barItem.hide();
	barItem.dispose();

	await client.stop();
}
