import * as vscode from "vscode";
import * as net from "net";
import { LanguageClient, LanguageClientOptions, StreamInfo } from "vscode-languageclient/node";

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

	console.log("Trying to connect on localhost:5556");
	client.start();
}

export async function deactivate() {
	await client.stop();
}
