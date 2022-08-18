using System;
using System.Collections;
using System.Diagnostics;

using IDE;
using IDE.Compiler;

namespace BeefLsp {
	class Lsp : ILspHandler {
		private Connection connection = new .(this) ~ delete _;
		private LspApp app = new .() ~ delete _;

		private List<String> sentDiagnosticsUris = new .() ~ DeleteContainerAndItems!(_);

		public void Start() {
			app.Init();
			connection.Start();
		}

		private Result<Json> OnInitialize(Json args) {
			StringView workspacePath = args["rootPath"].AsString; // TODO: Also check rootUri which should have higher priority
			app.LoadWorkspace(workspacePath);

			// Response
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

		private void OnInitialized() {
			app.mBfBuildSystem.Lock(0);
			defer app.mBfBuildSystem.Unlock();

			// Generate initial diagnostics
			BfPassInstance pass = app.mBfBuildSystem.CreatePassInstance("IntialParse");
			defer delete pass;

			app.InitialParse(pass);

			BfResolvePassData passData = .Create(.None);
			defer delete passData;

			app.compiler.ClassifySource(pass, passData);

			PublishDiagnostics(pass);
		}

		private void PublishDiagnostics(BfPassInstance pass) {
			// Get json errors
			int32 count = pass.GetErrorCount();
			Dictionary<String, List<Json>> files = new .();

			for (int32 i < count) {
				BfPassInstance.BfError error = scope .();
				pass.GetErrorData(i, error, true);

				List<Json> diagnostics = files.GetValueOrDefault(error.mFilePath);
				if (diagnostics == null) diagnostics = files[new .(error.mFilePath)] = new .();

				diagnostics.Add(GetDiagnostic(error));
			}

			// Send diagnostics
			List<String> uris = scope .();

			for (let file in files) {
				Json json = .Object();

				String uri = new $"file:///{file.key}";
				json["uri"] = .String(uri);

				Json diagnostics = .Array();
				json["diagnostics"] = diagnostics;
				file.value.CopyTo(diagnostics.AsArray);

				Send("textDocument/publishDiagnostics", json);
				uris.Add(uri);
			}

			// Clear diagnostics for URIs that were sent last time but not this time
			for (let uri in sentDiagnosticsUris) {
				if (uris.Contains(uri)) continue;

				Json json = .Object();
				json["uri"] = .String(uri);
				json["diagnostics"] = .Array();

				Send("textDocument/publishDiagnostics", json);
			}

			sentDiagnosticsUris.ClearAndDeleteItems();
			uris.CopyTo(sentDiagnosticsUris);

			// Cleanup
			DeleteDictionaryAndKeysAndValues!(files);
		}

		private Json GetDiagnostic(BfPassInstance.BfError error) {
			Json json = .Object();

			json["range"] = Range(error.mLine, error.mColumn, error.mLine, error.mColumn); // TODO: Find the correct range
			json["severity"] = .Number(error.mIsWarning ? 2 : 1);
			json["code"] = .Number(error.mCode);
			json["message"] = .String(error.mError);

			return json;
		}

		private Json Range(int startLine, int startCharacter, int endLine, int endCharacter) {
			Json start = .Object();
			start["line"] = .Number(startLine);
			start["character"] = .Number(startCharacter);

			Json end = .Object();
			end["line"] = .Number(endLine);
			end["character"] = .Number(endCharacter);

			Json json = .Object();
			json["start"] = start;
			json["end"] = end;

			return json;
		}

		private void OnDidOpen(Json args) {

		}

		private void OnDidChange(Json args) {
			// Get path
			StringView uri = args["textDocument"]["uri"].AsString;
			if (!uri.StartsWith("file:///")) {
				Console.WriteLine("Invalid URI, only file:/// URIs are supported: %s", uri);
				return;
			}

			String path = scope .(uri[8...]);
			path.Replace("%3A", ":");
			IDEUtils.FixFilePath(path);
			if (path[1] == ':' && path[2] == '\\' && path[3] != '\\') path.Insert(2, '\\');

			// Get contents
			StringView contentsRaw;
			Json jsonContents = args["contentChanges"][0];
			if (jsonContents.IsString) contentsRaw = jsonContents.AsString;
			else contentsRaw = jsonContents["text"].AsString;

			String contents = scope .(contentsRaw.Length);
			contentsRaw.Unescape(contents);

			// Parse
			app.mBfBuildSystem.Lock(0);
			defer app.mBfBuildSystem.Unlock();

			ProjectSource source = app.FindProjectSourceItem(scope .(path));

			BfParser parser = app.mBfBuildSystem.CreateParser(source);

			BfPassInstance pass = app.mBfBuildSystem.CreatePassInstance("Parse");
			defer delete pass;

			parser.SetSource(contents, path, -1);
			parser.Parse(pass, false);
			parser.Reduce(pass);
			parser.BuildDefs(pass, null, false);

			// Classify
			BfResolvePassData passData = .Create(.None);
			defer delete passData;

			app.compiler.ClassifySource(pass, passData);

			PublishDiagnostics(pass);
		}

		private void OnDidClose(Json args) {

		}

		private Result<Json> OnShutdown() {
			Console.WriteLine("Shutting down");

			app.Stop();
			app.Shutdown();

			return Json.Null();
		}

		private void OnExit() {
			connection.Stop();
		}

		public void OnMessage(Json json) {
			StringView method = json["method"].AsString;
			Console.WriteLine("Received: {}", method);

			Json args = json["params"];

			switch (method) {
			case "initialize":             HandleRequest(json, OnInitialize(args));
			case "initialized":            OnInitialized();
			case "shutdown":               HandleRequest(json, OnShutdown());
			case "exit":                   OnExit();

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

		private void Send(StringView method, Json json) {
			Json notification = .Object();

			notification["jsonrpc"] = .String("2.0");
			notification["method"] = .String(method);
			notification["params"] = json;

			connection.Send(notification);
			notification.Dispose();
		}
	}
}