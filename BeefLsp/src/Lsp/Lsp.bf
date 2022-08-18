using System;
using System.Collections;
using System.Diagnostics;

using IDE;
using IDE.ui;
using IDE.Compiler;

namespace BeefLsp {
	class Lsp : ILspHandler {
		private Connection connection = new .(this) ~ delete _;
		private LspApp app = new .() ~ delete _;

		private DocumentManager documents = new .() ~ delete _;
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

			cap["foldingRangeProvider"] = .Bool(true);

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
			Json j = args["textDocument"];

			// Get path
			String path = scope .();
			if (!GetPath(j["uri"].AsString, path)) return;

			// Add
			String contents = new .();
			j["text"].AsString.Unescape(contents);

			Document document = documents.Add(path, (.) j["version"].AsNumber, contents);

			// Parse
			ParseDocument(document);
		}

		private void OnDidChange(Json args) {
			// Get path
			String path = scope .();
			if (!GetPath(args["textDocument"]["uri"].AsString, path)) return;

			// Get contents
			StringView contentsRaw;
			Json jsonContents = args["contentChanges"][0];
			if (jsonContents.IsString) contentsRaw = jsonContents.AsString;
			else contentsRaw = jsonContents["text"].AsString;

			String contents = scope .(contentsRaw.Length);
			contentsRaw.Unescape(contents);

			// Update document
			Document document = documents.Get(path);
			document.SetContents((.) args["textDocument"]["version"].AsNumber, contents);

			// Parse
			ParseDocument(document);
		}

		private void ParseDocument(Document document) {
			app.mBfBuildSystem.Lock(0);
			defer app.mBfBuildSystem.Unlock();

			ProjectSource source = app.FindProjectSourceItem(document.path);
			BfParser parser = app.mBfBuildSystem.CreateParser(source);

			BfPassInstance pass = app.mBfBuildSystem.CreatePassInstance("Parse");
			defer delete pass;

			parser.SetSource(document.contents, document.path, -1);
			parser.Parse(pass, false);
			parser.Reduce(pass);
			parser.BuildDefs(pass, null, false);

			// Classify
			BfResolvePassData passData = .Create(.None);
			defer delete passData;

			app.compiler.ClassifySource(pass, passData);

			// Publish diagnostics
			PublishDiagnostics(pass);
		}

		private bool GetPath(StringView uri, String buffer) {
			if (!uri.StartsWith("file:///")) {
				Console.WriteLine("Invalid URI, only file:/// URIs are supported: %s", uri);
				return false;
			}

			buffer.Set(uri[8...]);
			buffer.Replace("%3A", ":");
			IDEUtils.FixFilePath(buffer);
			if (buffer[1] == ':' && buffer[2] == '\\' && buffer[3] != '\\') buffer.Insert(2, '\\');

			return true;

		}

		private void OnDidClose(Json args) {
			// Get path
			String path = scope .();
			if (!GetPath(args["textDocument"]["uri"].AsString, path)) return;

			// Remove
			documents.Remove(path);
		}

		private Result<Json> OnFoldingRange(Json args) {
			// Get path
			String path = scope .();
			if (!GetPath(args["textDocument"]["uri"].AsString, path)) return Json.Null();

			// Get folding range data
			app.mBfBuildSystem.Lock(0);
			defer app.mBfBuildSystem.Unlock();

			Document document = documents.Get(path);
			ProjectSource source = app.FindProjectSourceItem(path);
			BfParser parser = app.mBfBuildSystem.FindParser(source);

			var resolvePassData = parser.CreateResolvePassData(.None);
			defer delete resolvePassData;

			String collapseData = app.compiler.GetCollapseRegions(parser, resolvePassData, "", .. scope .());

			// Parse data to json
			Json ranges = .Array();

			for (var line in collapseData.Split('\n', .RemoveEmptyEntries)) {
				let original = line;

				// Parse folding range
				SourceEditWidgetContent.CollapseEntry.Kind kind = (.) line[0];
				line.RemoveFromStart(1);

				var it = line.Split(',');
				int start = int.Parse(it.GetNext().Value);
				int end = int.Parse(it.GetNext().Value);

				if (it.HasMore) {
					Console.WriteLine("Unknown folding range data '{}'", original);
					continue;
				}

				LineInfo startLine = document.GetLineInfo(start);
				LineInfo endLine = document.GetLineInfo(end);

				// Create json
				Json json = .Object();
				ranges.Add(json);

				json["startLine"] = .Number(startLine.line - 1);
				//json["startCharacter"] = .Number(startLine.start - start);
				json["endLine"] = .Number(endLine.line - 2);
				//json["endCharacter"] = .Number(endLine.start - end);

				switch (kind) {
				case .Comment: json["kind"] = .String("comment");
				case .Region:  json["kind"] = .String("region");
				default:       json["kind"] = .String(kind.ToString(.. scope .()));
				}
			}

			return ranges;
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
			case "initialize":                HandleRequest(json, OnInitialize(args));
			case "initialized":               OnInitialized();
			case "shutdown":                  HandleRequest(json, OnShutdown());
			case "exit":                      OnExit();

			case "textDocument/didOpen":      OnDidOpen(args);
			case "textDocument/didChange":    OnDidChange(args);
			case "textDocument/didClose":     OnDidClose(args);

			case "textDocument/foldingRange": HandleRequest(json, OnFoldingRange(args));
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