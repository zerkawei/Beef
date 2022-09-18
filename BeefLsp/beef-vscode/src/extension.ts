import * as vscode from "vscode";
import * as net from "net";
import { LanguageClient, LanguageClientOptions, ServerOptions, StreamInfo } from "vscode-languageclient/node";
import { registerSettingsView } from "./settingsView";

type InitializedArgs = {
	configuration: string;
	configurations: string[];
};

let barItem: vscode.StatusBarItem;
let buildBarItem: vscode.StatusBarItem;
let client: LanguageClient;

let initialized = false;

let configuration: string;
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
	barItem.command = "beeflang.changeConfiguration";
	setBarItem("Starting", true);
	barItem.show();

	buildBarItem = vscode.window.createStatusBarItem("beef-lsp", vscode.StatusBarAlignment.Left);
	buildBarItem.name = "Beef Build";
	buildBarItem.text = "$(loading~spin) Building";
	
	client.start().then(onReady);

	context.subscriptions.push(vscode.commands.registerCommand("beeflang.changeConfiguration", onChangeConfiguration));
	context.subscriptions.push(vscode.commands.registerCommand("beeflang.build", onBuild));

	registerSettingsView(context, client, "workspace", false);
	registerSettingsView(context, client, "project", true);
}

function onReady() {
	client.onNotification("beef/initialized", (args: InitializedArgs) => {
		initialized = true;

		configuration = args.configuration;
		configurations = args.configurations;

		updateBarItem();
	});

	client.onNotification("beef/classifyBegin", () => setBarItem("Classifying", true));
	client.onNotification("beef/classifyEnd", () => setBarItem("Running", false));
}

function setBarItem(status: string, spin: boolean) {
	barItem.text = "$(" + (spin ? "loading~spin" : "check") + ") Beef Lsp";
	barItem.tooltip = "Status: " + status;

	if (configuration !== undefined) barItem.text += ": " + configuration;
}

function updateBarItem() {
	if (barItem.text.includes(":")) barItem.text = barItem.text.substring(0, barItem.text.indexOf(":")) + ": " + configuration;
	else barItem.text += ": " + configuration;
}

function onChangeConfiguration() {
	if (!initialized) return;

	vscode.window.showQuickPick(configurations, { title: "Beef Configuration" })
		.then(value => {
			if (value) {
				client.sendRequest<any>("beef/changeConfiguration", { configuration: value })
					.then(args => {
						configuration = args.configuration;
						updateBarItem();
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
