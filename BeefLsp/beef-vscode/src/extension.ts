import * as vscode from "vscode";
import * as net from "net";
import { LanguageClient, LanguageClientOptions, StreamInfo } from "vscode-languageclient/node";

let barItem: vscode.StatusBarItem;
let client: LanguageClient;

export function activate(context: vscode.ExtensionContext) {
	let serverOptions = () => {
		let socket = net.createConnection({
			port: 5556
		});

		let result: StreamInfo = {
			writer: socket,
			reader: socket
		};

		return Promise.resolve(result);
	};

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
	barItem.show();
	
	console.log("Trying to connect on localhost:5556");
	client.start();

	client.onReady().then(onReady);
}

function onReady() {
	client.onNotification("beef/initialized", () => {
		barItem.text = "$(check) Beef Lsp";
		barItem.tooltip = "Status: Running";
	});
}

export async function deactivate() {
	barItem.hide();
	barItem.dispose();

	await client.stop();
}
