using System;

namespace BeefLsp {
	class Lsp : ILspHandler {
		private Connection connection = new .(this) ~ delete _;

		public void Start() {
			connection.Start();
		}

		private Result<Json> OnInitialize(Json args) {
			Json res = .Object();

			Json cap = .Object();
			res["capabilities"] = cap;

			Json documentSync = .Object();
			cap["textDocumentSync"] = documentSync;
			documentSync["openClose"] = .Bool(true);
			documentSync["change"] = .Number(1); // Full sync

			Json info = .Object();
			res["serverInfo"] = info;
			info["name"] = .String("beef-lsp");
			info["version"] = .String("0.1.0");

			return res;
		}

		private void OnDidOpen(Json args) {

		}

		private void OnDidChange(Json args) {

		}

		private void OnDidClose(Json args) {

		}

		public void OnMessage(Json json) {
			StringView method = json["method"].AsString;
			Console.WriteLine("Received: {}", method);

			Json args = json["params"];

			switch (method) {
			case "initialize":             HandleRequest(json, OnInitialize(args));
			case "textDocument/didOpen":   OnDidOpen(args);
			case "textDocument/didChange": OnDidChange(args);
			case "textDocument/didClose":  OnDidClose(args);
			}
		}

		private void HandleRequest(Json json, Result<Json> result) {
			Json response = .Object();

			response["jsonrpc"] = .String("2.0");
			response["id"] = json["id"];

			response["result"] = result;

			connection.Send(response);
			response.Dispose();
		}
	}
}