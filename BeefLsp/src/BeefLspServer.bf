using System;
using System.IO;
using System.Collections;
using System.Diagnostics;

using IDE;
using IDE.ui;
using IDE.Compiler;
using Beefy.widgets;

namespace BeefLsp {
	enum TokenType {
		case Namespace;
		case Type;
		case Class;
		case Interface;
		case Struct;
		case TypeParameter;
		case Method;
		case Keyword;
		case Comment;
		case String;
		case Number;
		case Macro;

		public StringView Name { get {
			switch (this) {
			case .Namespace:     return "namespace";
			case .Type:          return "type";
			case .Class:         return "class";
			case .Interface:     return "interface";
			case .Struct:        return "struct";
			case .TypeParameter: return "typeParameter";
			case .Method:        return "method";
			case .Keyword:       return "keyword";
			case .Comment:       return "comment";
			case .String:        return "string";
			case .Number:        return "number";
			case .Macro:         return "macro";
			}
		} }
	}
	
	class BeefLspServer : LspServer {
		private LspApp app = new .() ~ delete _;

		private DocumentManager documents = new .() ~ delete _;
		private List<String> sentDiagnosticsUris = new .() ~ DeleteContainerAndItems!(_);

		private int[] tokenTypeIds = new .[Enum.GetCount<TokenType>()] ~ delete _;

		public void Start(String[] args) {
			app.Init();
			app.fileWatcher.parseCallback = new => PublishDiagnostics;

			int port = -1;

			for (let arg in args) {
				if (arg == "--logFile") Log.SetupFile();
				else if (arg.StartsWith("--port=")) {
					if (int.Parse(arg[7...]) case .Ok(let val)) port = val;
				}
			}

			if (port == -1) StartStdio();
			else StartTcp(port);
		}

		private Result<Json, Error> OnInitialize(Json args) {
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

			Json completionProvider = .Object();
			cap["completionProvider"] = completionProvider;
			completionProvider["triggerCharacters"] = .Array()..Add(.String("."));
			completionProvider["resolveProvider"] = .Bool(true);

			Json documentSymbolProvider = .Object();
			cap["documentSymbolProvider"] = documentSymbolProvider;
			documentSymbolProvider["label"] = .String("Beef Lsp");

			Json signatureHelpProvider = .Object();
			cap["signatureHelpProvider"] = signatureHelpProvider;
			signatureHelpProvider["triggerCharacters"] = .Array()..Add(.String("("));
			signatureHelpProvider["retriggerCharacters"] = .Array()..Add(.String(","));

			cap["hoverProvider"] = .Bool(true);
			cap["definitionProvider"] = .Bool(true);
			cap["referencesProvider"] = .Bool(true);
			cap["workspaceSymbolProvider"] = .Bool(true);

			Json renameProvider = .Object();
			cap["renameProvider"] = renameProvider;
			renameProvider["prepareProvider"] = .Bool(true);

			//     Semantic Tokens
			for (int i < tokenTypeIds.Count) tokenTypeIds[i] = -1;

			Json clientTokenTypes = args["capabilities"]["textDocument"]["semanticTokens"]["tokenTypes"];
			if (clientTokenTypes.IsArray) {
				int i = 0;

				for (let tokenType in Enum.GetValues<TokenType>()) {
					TokenType type = (.) -1;

					for (let clientTokenType in clientTokenTypes.AsArray) {
						if (tokenType.Name == clientTokenType.AsString) {
							type = tokenType;
							break;
						}
					}

					if (type != (.) -1) {
						tokenTypeIds[(.) type] = i++;
					}
				}
			}

			Json semanticTokensProvider = .Object();
			cap["semanticTokensProvider"] = semanticTokensProvider;
			semanticTokensProvider["full"] = .Bool(true);

			Json legend = .Object();
			semanticTokensProvider["legend"] = legend;
			legend["tokenModifiers"] = .Array();

			Json tokenTypes = .Array();
			legend["tokenTypes"] = tokenTypes;

			int i = 0;
			for (let tokenType in tokenTypeIds) {
				if (tokenType != -1) tokenTypes.Add(.String(((TokenType) i).Name));
				i++;
			}

			// Server Info
			Json info = .Object();
			res["serverInfo"] = info;
			info["name"] = .String("beef-lsp");
			info["version"] = .String("0.1.0");

			return res;
		}

		private void OnInitialized() {
			// Generate initial diagnostics
			ParseAll();

			// Send beef/initialized
			Json json = .Object();
			json["configuration"] = .String(app.mConfigName);

			Json configurations = .Array();
			json["configurations"] = configurations;

			for (let config in  app.mWorkspace.mConfigs.Keys) {
				configurations.Add(.String(config));
			}

			Send("beef/initialized", json);
		}

		private void ParseAll() {
			app.LockSystem!();

			BfPassInstance pass = app.mBfBuildSystem.CreatePassInstance("IntialParse");
			defer delete pass;

			app.InitialParse(pass);
			for (let document in documents) document.FetchParser();

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

				Json? json = GetDiagnostic(error);
				if (json.HasValue) diagnostics.Add(json.Value);
			}

			// Send diagnostics
			List<String> uris = scope .();

			for (let file in files) {
				String uri = Utils.GetUri!(file.key).GetValueOrLog!("");
				if (uri.IsEmpty) continue;

				Json json = .Object();

				json["uri"] = .String(uri);

				Json diagnostics = .Array();
				json["diagnostics"] = diagnostics;
				file.value.CopyTo(diagnostics.AsArray);

				Send("textDocument/publishDiagnostics", json);
				uris.Add(new .(uri));
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

		private Json? GetDiagnostic(BfPassInstance.BfError error) {
			Document document = documents.Get(error.mFilePath);
			if (document == null) return null;

			Json json = .Object();

			let (startLine, startColumn) = document.GetLine(error.mSrcStart);
			let (endLine, endColumn) = document.GetLine(error.mSrcEnd);

			json["range"] = Range(startLine, startColumn, endLine, endColumn);
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
			String path = Utils.GetPath!(args).GetValueOrLog!("");
			if (path.IsEmpty) return;

			ProjectSource source = app.FindProjectSourceItem(path);
			if (source == null) return;

			// Add
			String contents = new .();
			j["text"].AsString.Unescape(contents);

			Document document = documents.Add(path, (.) j["version"].AsNumber, contents, source);

			// Parse
			document.Parse(scope => PublishDiagnostics);
		}

		private void OnDidChange(Json args) {
			// Get path
			String path = Utils.GetPath!(args).GetValueOrLog!("");
			if (path.IsEmpty) return;

			Document document = documents.Get(path);
			if (document == null) return;

			// Get contents
			StringView contentsRaw;
			Json jsonContents = args["contentChanges"][0];
			if (jsonContents.IsString) contentsRaw = jsonContents.AsString;
			else contentsRaw = jsonContents["text"].AsString;

			String contents = scope .(contentsRaw.Length);
			contentsRaw.Unescape(contents);

			// Update document
			document.SetContents((.) args["textDocument"]["version"].AsNumber, contents);

			// Parse
			document.Parse(scope => PublishDiagnostics);
		}

		private void OnDidClose(Json args) {
			// Get path
			String path = Utils.GetPath!(args).GetValueOrLog!("");
			if (path.IsEmpty) return;

			// Remove
			documents.Remove(path);
		}

		private Result<Json, Error> OnFoldingRange(Json args) {
			// Get path
			String path = Utils.GetPath!(args).GetValueOrPassthrough!<Json>();

			Document document = documents.Get(path);
			if (document == null) return Json.Null();

			// Get folding range data
			String collapseData = document.GetFoldingData(.. scope .());

			// Parse data to json
			Json ranges = .Array();

			for (var line in Utils.Lines(collapseData)) {
				let original = line;

				// Parse folding range
				SourceEditWidgetContent.CollapseEntry.Kind kind = (.) line[0];
				line.RemoveFromStart(1);

				var it = line.Split(',');
				int start = int.Parse(it.GetNext().Value);
				int end = int.Parse(it.GetNext().Value);

				if (it.HasMore) {
					Log.Warning("Unknown folding range data '{}'", original);
					continue;
				}

				let (startLine, startColumn) = document.GetLine(start);
				let (endLine, endColumn) = document.GetLine(end);

				// Create json
				Json json = .Object();
				ranges.Add(json);

				json["startLine"] = .Number(startLine);
				//json["startCharacter"] = .Number(startLine.start - start);
				json["endLine"] = .Number(endLine - 1);
				//json["endCharacter"] = .Number(endLine.start - end);

				switch (kind) {
				case .Comment: json["kind"] = .String("comment");
				case .Region:  json["kind"] = .String("region");
				default:       json["kind"] = .String(kind.ToString(.. scope .()));
				}
			}

			return ranges;
		}

		private Result<Json, Error> OnCompletion(Json args) {
			// Get path
			String path = Utils.GetPath!(args).GetValueOrPassthrough!<Json>();

			Document document = documents.Get(path);
			if (document == null) return Json.Null();

			// Get completion data
			int cursor = document.GetPosition(args);
			String completionData = document.GetCompilerData(.Completions, cursor, .. scope .());
			
			// Parse data to json
			Json items = .Array();

			int start = -1;
			int end = -1;

			for (let line in Utils.Lines(completionData)) {
				// Parse completion item
				var it = line.Split('\t');
				StringView type = it.GetNext().Value;

				int kind = -1;

				switch (type) {
				case "method":      kind = 2;
				case "extmethod":   kind = 2;
				case "field":       kind = 5;
				case "property":    kind = 10;
				case "namespace":   kind = 9;
				case "class":       kind = 7;
				case "interface":   kind = 8;
				case "valuetype":   kind = 22;
				case "object":      kind = 5;
				case "pointer":     kind = 18;
				case "value":       kind = 12;
				case "payloadEnum": kind = 20;
				case "generic":     kind = 1;
				case "folder":      kind = 19;
				case "file":        kind = 17;
				case "mixin":       kind = 2;
				case "token":       kind = 14;
				}

				if (kind == -1) {
					switch (type) {
					case "insertRange":
						var it2 = it.GetNext().Value.Split(' ');
						start = int.Parse(it2.GetNext().Value);
						end = int.Parse(it2.GetNext().Value);
					case "invokeInfo", "invoke": // noop
					default: Log.Warning("Unknown completion type: {}", line);
					}

					continue;
				}

				if (start == -1) {
					Log.Warning("Tried to create completion item before 'insertRange' was detected");
					continue;
				}

				StringView text = it.GetNext().Value;

				int matchesPos = text.IndexOf('\x02');
				if (matchesPos != -1) {
					text = text[0...matchesPos - 1];
				}

				int docPos = text.IndexOf('\x03');
				if (docPos != -1) {
					text = text[0...docPos - 1];
				}

				// Create json
				Json json = .Object();
				items.Add(json);

				json["label"] = .String(text);
				json["kind"] = .Number(kind);

				Json data = .Object();
				json["data"] = data;
				data["path"] = .String(path);
				data["cursor"] = .Number(cursor);
			}

			return items;
		}

		private Result<Json, Error> OnCompletionResolve(Json args) {
			// Get path
			String path = IDEUtils.FixFilePath(.. scope .(args["data"]["path"].AsString));

			Document document = documents.Get(path);
			if (document == null) return Json.Null();

			// Get completion data
			int cursor = (.) args["data"]["cursor"].AsNumber;
			String completionData = document.GetCompilerData(.Completions, cursor, .. scope .(), args["label"].AsString);

			// Create json
			Json json = args.Copy();

			StringView detail = "";

			for (let line in Utils.Lines(completionData)) {
				if (line.StartsWith("class") || line.StartsWith("valuetype")) {
					StringView doc = line.Substring(line.IndexOf('\x03') + 1);
					detail = doc.Substring(doc.IndexOf(' ') + 1);
				}
				else if (line.StartsWith("method") || line.StartsWith("mixin")) {
					StringView doc = line.Substring(line.IndexOf('\x03') + 1);

					int sigI = doc.IndexOf('\x04');
					if (sigI == -1) {
						detail = doc;
					}
					else {
						int docI = doc.IndexOf('\x05');

						if (docI == -1) detail = doc[0...sigI - 1];
						else detail = scope:: String(doc[0...sigI - 1])..Append(doc.Substring(docI));
					}
				}
				else if (line.StartsWith("property") || line.StartsWith("object") || line.StartsWith("value")) {
					StringView doc = line.Substring(line.IndexOf('\x03') + 1);
					//detail = doc[0...doc.IndexOf(' ') - 1]; // TODO: Somehow only return the type and not the name
					detail = doc;
				}
				else if (line.StartsWith("interface")) {
					detail = line.Substring(line.IndexOf('\x03') + 1);
				}

				if (!detail.IsEmpty) break;
			}

			if (!detail.IsEmpty) {
				// Documentation
				int docI = detail.IndexOf('\x05');

				if (docI != -1) {
					String docs = Utils.CleanDocumentation(detail.Substring(docI + 1), .. scope:: .());
					detail = detail[0...docI - 1];

					Documentation documentation = scope .();
					documentation.Parse(docs);

					Json contents = .Object();
					json["documentation"] = contents;
					contents["kind"] = .String("markdown");
					contents["value"] = .String(documentation.ToString("", true, .. scope .()));
				}

				// Detail
				json["detail"] = .String(detail);
			}

			return json;
		}

		struct Symbol : this(StringView name, int kind, int line, int column) {}

		class SymbolGroup {
			public Symbol symbol;

			public List<SymbolGroup> groups = new .() ~ delete _;
			public List<Symbol> symbols = new .() ~ delete _;

			public this(Symbol symbol) {
				this.symbol = symbol;
			}
		}

		private Result<Json, Error> OnDocumentSymbol(Json args) {
			// Get path
			String path = Utils.GetPath!(args).GetValueOrPassthrough!<Json>();

			Document document = documents.Get(path);
			if (document == null) return Json.Null();

			// Get navigation data
			String navigationData = document.GetCompilerData(.Navigation, 0, .. scope .());

			// Parse data
			List<Symbol> symbols = scope .();

			for (let lineStr in Utils.Lines(navigationData)) {
				// Parse symbol
				var it = lineStr.Split('\t');

				StringView name = it.GetNext().Value;
				StringView type = it.GetNext().Value;
				int line = int.Parse(it.GetNext().Value);
				int column = int.Parse(it.GetNext().Value);

				int kind;

				switch (type) {
				case "method":    kind = 6;
				case "extmethod": kind = 6;
				case "field":     kind = 8;
				case "property":  kind = 7;
				case "class":     kind = 5;
				case "enum":      kind = 10;
				case "struct":    kind = 23;
				case "typealias": kind = 26; // TODO: Currently set to TypeParameter
				default:
					Log.Warning("Unknown navigation data: {}", lineStr);
					continue;
				}

				symbols.Add(.(name, kind, line, column));
			}

			// Create symbol hierarchy
			Dictionary<StringView, SymbolGroup> groups = scope .();
			defer { for (let group in groups.Values) delete group; }

			mixin GetSymbol(StringView name) {
				Symbol symbol = default;

				for (let sym in symbols) {
					if (sym.name == name) {
						symbol = sym;
						break;
					}
				}

				symbol
			}

			for (let symbol in symbols) {
				int index = SymbolGetLastDotIndex!(symbol);

				SymbolGroup prevGroup = null;
				bool first = true;
				
				while (index != -1) {
					StringView groupName = symbol.name[0...index - 1];

					SymbolGroup group = groups.GetValueOrDefault(groupName);
					if (group == null) groups[groupName] = group = new .(GetSymbol!(groupName));

					if (prevGroup != null && !group.groups.Contains(prevGroup)) {
						group.groups.Add(prevGroup);

						for (let sym in group.symbols) {
							if (sym.name == prevGroup.symbol.name) {
								@sym.Remove();
								break;
							}
						}
					}

					index = groupName.LastIndexOf('.');
					prevGroup = group;

					if (first) {
						group.symbols.Add(symbol);
						first = false;
					}
				}
			}

			// Create json
			Json jsonSymbols = .Array();

			for (let group in groups.Values) {
				if (group.symbol.name.Contains('.')) continue;

				jsonSymbols.Add(SymbolGroupToJson(group));
			}

			return jsonSymbols;
		}

		private mixin SymbolGetLastDotIndex(Symbol symbol) {
			int parenIndex = symbol.name.IndexOf('(');

			int index;
			if (parenIndex == -1) index = symbol.name.LastIndexOf('.');
			else index = symbol.name[0...parenIndex - 1].LastIndexOf('.');

			index
		}

		private Json SymbolGroupToJson(SymbolGroup group) {
			Json json = SymbolToJson(group.symbol);

			if (!group.groups.IsEmpty || !group.symbols.IsEmpty) {
				Json children = .Array();
				json["children"] = children;

				// Groups
				for (let childGroup in group.groups) {
					children.Add(SymbolGroupToJson(childGroup));
				}

				// Symbols
				for (let childSymbol in group.symbols) {
					children.Add(SymbolToJson(childSymbol));
				}
			}

			return json;
		}

		private Json SymbolToJson(Symbol symbol) {
			Json json = .Object();

			int index = SymbolGetLastDotIndex!(symbol);

			json["name"] = .String(index == -1 ? symbol.name : symbol.name.Substring(index + 1));
			json["kind"] = .Number(symbol.kind);
			json["range"] = Range(symbol.line, symbol.column, symbol.line, symbol.column);
			json["selectionRange"] = Range(symbol.line, symbol.column, symbol.line, symbol.column);

			return json;
		}

		private Result<Json, Error> OnSignatureHelp(Json args) {
			// Get path
			String path = Utils.GetPath!(args).GetValueOrPassthrough!<Json>();

			Document document = documents.Get(path);
			if (document == null) return Json.Null();

			// Get signature data
			int cursor = document.GetPosition(args);
			String signatureData = document.GetCompilerData(.Completions, cursor, .. scope .());

			// Parse data
			List<String> signatures = scope .();
			int activeSignature = -1;
			List<int> argumentPositions = scope .();

			defer signatures.ClearAndDeleteItems();

			loop: for (let line in Utils.Lines(signatureData)) {
				var it = line.Split('\t', .RemoveEmptyEntries);

				StringView type = it.GetNext().Value;
				StringView data = it.GetNext().Value;

				if (it.HasMore) {
					String str = scope:loop .(data);
					for (let more in it) str.Append(more);
					data = str;
				}

				switch (type) {
				case "invokeInfo":
					var it2 = data.Split(' ', .RemoveEmptyEntries);
					activeSignature = int.Parse(it2.GetNext().Value);

					for (let argumentPosition in it2) {
						argumentPositions.Add(int.Parse(argumentPosition));
					}
				case "invoke":
					signatures.Add(new .(data));
				}
			}

			if (signatures.IsEmpty || activeSignature == -1) return Json.Null();

			// Calculate active parameter
			int activeParameter = 0;

			for (int i = 1; i < argumentPositions.Count; i++) {
				if (cursor > argumentPositions[i - 1] && cursor <= argumentPositions[i]) {
					activeParameter = i - 1;
					break;
				}
			}

			// Create json
			Json json = .Object();

			Json jsonSignatures = .Array();
			json["signatures"] = jsonSignatures;

			loop: for (let signature in signatures) {
				Json jsonSignature = .Object();
				jsonSignatures.Add(jsonSignature);

				StringView label = scope String(signature)..Replace("\x01", "");

				// Documentation
				int docI = label.IndexOf('\x03');
				Documentation documentation = scope .();

				if (docI != -1) {
					String docs = Utils.CleanDocumentation(label.Substring(docI + 1), .. scope:loop .());
					label = label[0...docI - 1];
					
					documentation.Parse(docs);

					Json contents = .Object();
					jsonSignature["documentation"] = contents;
					contents["kind"] = .String("markdown");
					contents["value"] = .String(documentation.ToString("", true, .. scope .()));
				}

				// Label
				jsonSignature["label"] = .String(label);

				// Parameters
				Json jsonParameters = .Array();
				jsonSignature["parameters"] = jsonParameters;

				for (let parameter in signature[signature.IndexOf('(') + 1...signature.LastIndexOf(')') - 1].Split('\x01', .RemoveEmptyEntries)) {
					Json jsonParameter = .Object();
					jsonParameters.Add(jsonParameter);

					// Documentation
					StringView name = parameter.Substring(parameter.LastIndexOf(' ') + 1);
					if (name.EndsWith(',')) name.Length--;

					StringView doc = documentation.ToStringParameter(name, true, .. scope .());

					if (!doc.IsEmpty) {
						Json contents = .Object();
						jsonParameter["documentation"] = contents;
						contents["kind"] = .String("markdown");
						contents["value"] = .String(doc);
					}

					// Label
					jsonParameter["label"] = .String(parameter);
				}
			}

			json["activeSignature"] = .Number(activeSignature);
			json["activeParameter"] = .Number(activeParameter);

			return json;
		}

		private Result<Json, Error> OnHover(Json args) {
			// Get path
			String path = Utils.GetPath!(args).GetValueOrPassthrough!<Json>();

			Document document = documents.Get(path);
			if (document == null) return Json.Null();

			// Get hover data
			int cursor = document.GetPosition(args);
			String hoverData = document.GetCompilerData(.Hover, cursor, .. scope .());

			// Parse data
			if (hoverData.IsEmpty) return Json.Null();

			StringView hover = Utils.Lines(hoverData).GetNext().Value;
			if (!hover.StartsWith(':')) return Json.Null();

			hover.Adjust(1);
			if (hover.StartsWith("class ")) hover.Adjust(6);

			int documentationIndex = hover.IndexOf('\x03');
			Documentation documentation = scope .();

			if (documentationIndex != -1) {
				String docs = Utils.CleanDocumentation(hover.Substring(documentationIndex + 1), .. scope:: .());
				documentation.Parse(docs);

				hover = hover[0...documentationIndex - 1];
			}

			// Create json
			Json json = .Object();

			Json contents = .Object();
			json["contents"] = contents;
			contents["kind"] = .String("markdown");
			contents["value"] = .String(documentation.ToString(hover, true, .. scope .()));

			return json;
		}

		private Result<Json, Error> OnDefinition(Json args) {
			// Get path
			String path = Utils.GetPath!(args).GetValueOrPassthrough!<Json>();

			Document document = documents.Get(path);
			if (document == null) return Json.Null();

			// Get definition data
			int cursor = document.GetPosition(args);
			String definitionData = document.GetCompilerData(.GoToDefinition, cursor, .. scope .());

			// Parse data
			StringView file = "";
			int line = 0;
			int column = 0;

			for (let data in Utils.Lines(definitionData)) {
				var it = data.Split('\t', .RemoveEmptyEntries);

				StringView type = it.GetNext().Value;
				if (type != "defLoc") continue;

				file = it.GetNext().Value;
				line = int.Parse(it.GetNext().Value);
				column = int.Parse(it.GetNext().Value);

				break;
			}

			// Create json
			if (file.IsEmpty) return Json.Null();

			Json json = .Object();

			json["uri"] = .String(Utils.GetUri!(file).GetValueOrPassthrough!<Json>());
			json["range"] = Range(line, column, line, column);

			return json;
		}

		private Result<Json, Error> OnReferences(Json args) {
			// Get path
			String path = Utils.GetPath!(args).GetValueOrPassthrough!<Json>();

			Document document = documents.Get(path);
			if (document == null) return Json.Null();

			// Get symbol data
			int cursor = document.GetPosition(args);
			String symbolData = document.GetCompilerData(.SymbolInfo, cursor, .. scope .());

			// Get references data
			LspApp.APP.LockSystem!();

			BfParser parser = scope .(null);

			BfPassInstance pass = app.mBfBuildSystem.CreatePassInstance("GetSymbolReferences");
			defer delete pass;

			BfResolvePassData passData = parser.CreateResolvePassData(.ShowFileSymbolReferences);
			defer delete passData;

			ParseSymbolData(symbolData, passData);

			String referencesData = app.compiler.GetSymbolReferences(pass, passData, .. scope .());

			// Parse data
			if (referencesData.IsEmpty) return Json.Null();

			Json references = .Array();

			for (let line in Utils.Lines(referencesData)) {
				var it = line.Split('\t', .RemoveEmptyEntries);

				StringView file = it.GetNext().Value;
				StringView data = it.GetNext().Value;

				ProjectSource fileSource = app.FindProjectSourceItem(scope .(file));
				if (fileSource == null) continue;

				BfParser fileParser = app.mBfBuildSystem.FindParser(fileSource);
				if (fileParser == null) continue;

				for (let posStr in data.Split(' ', .RemoveEmptyEntries)) {
					int startChar = int.Parse(posStr);
					int length = int.Parse(@posStr.GetNext().Value);

					let (startLine, startColumn) = fileParser.GetLineCharAtIdx(startChar);
					let (endLine, endColumn) = fileParser.GetLineCharAtIdx(startChar + length);

					// Create json
					Json json = .Object();
					references.Add(json);

					json["uri"] = .String(Utils.GetUri!(file).GetValueOrPassthrough!<Json>());
					json["range"] = Range(startLine, startColumn, endLine, endColumn);
				}
			}

			return references;
		}

		private void ParseSymbolData(String data, BfResolvePassData passData) {
			bool typeDef = false;

			for (let line in Utils.Lines(data)) {
				var lineDataItr = line.Split('\t');
				var dataType = lineDataItr.GetNext().Get();

				switch (dataType) {
				case "localId":
					int32 localId = int32.Parse(lineDataItr.GetNext().Get());
					passData.SetLocalId(localId);
				case "typeRef":
					passData.SetSymbolReferenceTypeDef(scope .(lineDataItr.GetNext().Get()));
					typeDef = true;
				case "fieldRef":
					passData.SetSymbolReferenceTypeDef(scope .(lineDataItr.GetNext().Get()));
					passData.SetSymbolReferenceFieldIdx(int32.Parse(lineDataItr.GetNext().Get()));
					typeDef = true;
				case "methodRef", "ctorRef":
					passData.SetSymbolReferenceTypeDef(scope .(lineDataItr.GetNext().Get()));
					passData.SetSymbolReferenceMethodIdx(int32.Parse(lineDataItr.GetNext().Get()));
					typeDef = true;
				case "invokeMethodRef":
					if (!typeDef) {
						passData.SetSymbolReferenceTypeDef(scope .(lineDataItr.GetNext().Get()));
						passData.SetSymbolReferenceMethodIdx(int32.Parse(lineDataItr.GetNext().Get()));
						typeDef = true;
					}
				case "propertyRef":
					passData.SetSymbolReferenceTypeDef(scope .(lineDataItr.GetNext().Get()));
					passData.SetSymbolReferencePropertyIdx(int32.Parse(lineDataItr.GetNext().Get()));
					typeDef = true;
				case "typeGenericParam":
					passData.SetTypeGenericParamIdx(int32.Parse(lineDataItr.GetNext().Get()));
				case "methodGenericParam":
					passData.SetMethodGenericParamIdx(int32.Parse(lineDataItr.GetNext().Get()));
				case "namespaceRef":
					passData.SetSymbolReferenceNamespace(scope .(lineDataItr.GetNext().Get()));
				}
			}
		}

		private Result<Json, Error> OnWorkspaceSymbol(Json args) {
			// Get symbol data
			String symbolData = app.compiler.GetTypeDefMatches(args["query"].AsString, .. scope .(), true);

			// Parse data and create json
			Json symbols = .Array();

			for (let line in Utils.Lines(symbolData)) {
				var it = line.Split('\t', .RemoveEmptyEntries);

				StringView name = it.GetNext().Value;

				char8 type = name[0];
				name.Adjust(1);

				if (type == '>') {
					type = name[0];
					name.Adjust(1);

					while (type.IsDigit) {
						type = name[0];
						name.Adjust(1);
					}

					type = name[0];
					name.Adjust(1);
				}

				if (type == ':') {
					type = name[0];
					name.Adjust(1);
				}

				int kind = -1;

				switch (type) {
				case 'v':      kind = 23;
				case 'c':      kind = 5;
				case 'i':      kind = 11;

				case 'F':      kind = 8;
				case 'P':      kind = 7;
				case 'M', 'o': kind = 6;
				}

				if (kind == -1) continue;

				for (int i < name.Length) {
					if (name[i] == '+') name[i] = '.';
				}

				StringView containerName = "";

				int parenIndex = name.IndexOf('(');
				int lastDotIndex;
				if (parenIndex == -1) lastDotIndex = name.LastIndexOf('.');
				else lastDotIndex = name[0...parenIndex - 1].LastIndexOf('.');

				if (lastDotIndex != -1) {
					containerName = name[0...lastDotIndex - 1];
					name = name.Substring(lastDotIndex + 1);
				}

				StringView file = it.GetNext().Value;
				int line = int.Parse(it.GetNext().Value);
				int column = int.Parse(it.GetNext().Value);

				// Create json
				Json symbol = .Object();
				symbols.Add(symbol);

				symbol["name"] = .String(name);
				symbol["kind"] = .Number(kind);
				if (!containerName.IsEmpty) symbol["containerName"] = .String(containerName);

				Json location = .Object();
				symbol["location"] = location;
				location["uri"] = .String(Utils.GetUri!(file).GetValueOrPassthrough!<Json>());
				location["range"] = Range(line, column, line, column);
			}

			return symbols;
		}

		private Result<Json, Error> OnRename(Json args) {
			// Get path
			String path = Utils.GetPath!(args).GetValueOrPassthrough!<Json>();

			Document document = documents.Get(path);
			if (document == null) return Json.Null();

			// Get symbol data
			int cursor = document.GetPosition(args);
			String symbolData = document.GetCompilerData(.SymbolInfo, cursor, .. scope .());

			// Get references data
			LspApp.APP.LockSystem!();

			BfParser parser = scope .(null);

			BfPassInstance pass = app.mBfBuildSystem.CreatePassInstance("GetSymbolReferences");
			defer delete pass;

			BfResolvePassData passData = parser.CreateResolvePassData(.ShowFileSymbolReferences);
			defer delete passData;

			ParseSymbolData(symbolData, passData);

			String referencesData = app.compiler.GetSymbolReferences(pass, passData, .. scope .());

			// Parse data
			if (referencesData.IsEmpty) return .Err(new .(0, "Could not rename this symbol."));

			Json workspaceEdit = .Object();

			Json changes = .Object();
			workspaceEdit["changes"] = changes;

			for (let line in Utils.Lines(referencesData)) {
				var it = line.Split('\t', .RemoveEmptyEntries);

				StringView file = it.GetNext().Value;
				StringView data = it.GetNext().Value;

				String uri = Utils.GetUri!(file).GetValueOrLog!("");
				if (uri == "") continue;

				ProjectSource fileSource = app.FindProjectSourceItem(scope .(file));
				if (fileSource == null) continue;

				BfParser fileParser = app.mBfBuildSystem.FindParser(fileSource);
				if (fileParser == null) continue;

				Json edits = .Array();
				changes[uri] = edits;

				for (let posStr in data.Split(' ', .RemoveEmptyEntries)) {
					int startChar = int.Parse(posStr);
					int length = int.Parse(@posStr.GetNext().Value);

					let (startLine, startColumn) = fileParser.GetLineCharAtIdx(startChar);
					let (endLine, endColumn) = fileParser.GetLineCharAtIdx(startChar + length);

					// Create json
					Json edit = .Object();
					edits.Add(edit);

					edit["range"] = Range(startLine, startColumn, endLine, endColumn);
					edit["newText"] = .String(args["newName"].AsString);
				}
			}

			return workspaceEdit;
		}

		private Result<Json, Error> OnPrepareRename(Json args) {
			// Get path
			String path = Utils.GetPath!(args).GetValueOrPassthrough!<Json>();

			Document document = documents.Get(path);
			if (document == null) return Json.Null();

			// Get symbol data
			int cursor = document.GetPosition(args);
			String symbolData = document.GetCompilerData(.SymbolInfo, cursor, .. scope .());

			// Parse data
			if (symbolData.IsEmpty) return Json.Null();

			int start = -1;
			int end = -1;

			for (let line in Utils.Lines(symbolData)) {
				if (line.StartsWith("insertRange")) {
					StringView data = line[12...];
					int spaceI = data.IndexOf(' ');

					start = int.Parse(data[0...spaceI - 1]);
					end = int.Parse(data.Substring(spaceI + 1));
				}
				else if (line.StartsWith("token")) {
					return Json.Null();
				}
			}

			if (start == -1) return Json.Null();

			// Create json
			let (startLine, startColumn) = document.GetLine(start);
			let (endLine, endColumn) = document.GetLine(end);

			return Range(startLine, startColumn, endLine, endColumn);
		}

		private Result<Json, Error> OnSemanticTokensFull(Json args) {
			// Get path
			String path = Utils.GetPath!(args).GetValueOrPassthrough!<Json>();

			Document document = documents.Get(path);
			if (document == null) return Json.Null();

			// Create tokens
			String tokens = GetSemanticTokens(document, .. new .(1024));

			// Create json
			Json json = .Object();
			json["data"] = .DirectWrite(tokens);

			return json;
		}

		private void GetSemanticTokens(Document document, String buffer) {
			Span<EditWidgetContent.CharData> data = document.GetCharData();

			buffer.Append('[');

			int line = 0;
			int column = 0;

			char8 lastChar = '\0';
			SourceElementType lastType = (.) data[0].mDisplayTypeId;
			int lastTokenEnd = 0;

			int lastTokenLine = 0;
			int lastTokenStart = 0;

			void AddToken(SourceElementType type, int line, int start, int end) {
				if (start >= end) return;

				int typeI;
				StringView token = "";

				mixin GetToken() {
					if (token.IsEmpty) {
						int lineI = document.[Friend]parser.GetIndexAtLine(line);
						token = document.contents[lineI + start + 1...lineI + end];
					}

					token
				}

				switch (type) {
				case .Comment:      typeI = tokenTypeIds[(.) TokenType.Comment];
				case .Method:       typeI = tokenTypeIds[(.) TokenType.Method];
				case .Namespace:    typeI = tokenTypeIds[(.) TokenType.Namespace];
				case .Keyword:      typeI = tokenTypeIds[(.) TokenType.Keyword];
				case .Type:         typeI = tokenTypeIds[(.) TokenType.Type];
				case .Struct:       typeI = tokenTypeIds[(.) TokenType.Struct];
				case .Interface:    typeI = tokenTypeIds[(.) TokenType.Interface];
				case .GenericParam: typeI = tokenTypeIds[(.) TokenType.TypeParameter];
				case .Literal:
					if (GetToken!().Contains('"')) typeI = tokenTypeIds[(.) TokenType.String];
					else {
						bool hasDigit = false;

						for (let char in GetToken!()) {
							if (char.IsDigit) {
								hasDigit = true;
								break;
							}
						}

						typeI = hasDigit ? tokenTypeIds[(.) TokenType.Number] : -1;
					}
				case (.) 159:       typeI = tokenTypeIds[(.) TokenType.Macro];
				default:            typeI = -1;
				}

				if (typeI != -1) {
					if (buffer.Length > 1) buffer.Append(',');
					(line - lastTokenLine).ToString(buffer);
					buffer.Append(',');
					(start - lastTokenStart).ToString(buffer);
					buffer.Append(',');
					(end - start).ToString(buffer);
					buffer.Append(',');
					typeI.ToString(buffer);
					buffer.Append(",0");

					lastTokenLine = line;
					lastTokenStart = start;
				}
			}

			bool preprocessorDirective = false;

			for (let char in data) {
				if (column == 0 && char.mChar == '#') preprocessorDirective = true;
				else if (preprocessorDirective && char.mChar == '\n') preprocessorDirective = false;

				SourceElementType type = (.) char.mDisplayTypeId;
				if (preprocessorDirective) type = (.) 159;

				if (lastType != type) {
					AddToken(lastType, line, lastTokenEnd, column - (lastChar == '\r' ? 1 : 0));

					lastType = type;
					lastTokenEnd = column;
				}

				if (char.mChar == '\n') {
					AddToken(lastType, line, lastTokenEnd, column - (lastChar == '\r' ? 1 : 0));

					line++;
					column = 0;
					lastTokenEnd = 0;
					lastTokenStart = 0;
				}
				else column++;

				lastChar = char.mChar;
			}

			buffer.Append(']');
		}

		private Result<Json, Error> OnChangeConfiguration(Json args) {
			StringView configuration = args["configuration"].AsString;

			if (app.mConfigName != configuration) {
				bool hasConfig = false;

				for (let config in app.mWorkspace.mConfigs.Keys) {
					if (config == configuration) {
						hasConfig = true;
						break;
					}
				}

				if (hasConfig) {
					app.mConfigName.Set(configuration);
					app.mWorkspace.FixOptions();
					app.SaveWorkspaceUserDataCustom();
		
					app.compiler.[Friend]HandleOptions(null, 0);
					ParseAll();
		
					for (let document in documents) document.MarkCharDataDirty();
		
					Send("workspace/semanticTokens/refresh", .Null(), true);
				}
			}

			Json json = .Object();
			json["configuration"] = .String(app.mConfigName);

			return json;
		}

		private Result<Json, Error> OnWorkspaceSettings() {
			Json json = .Object();


			
			return json;
		}

		private Result<Json, Error> OnShutdown() {
			Log.Info("Shutting down");

			app.Stop();
			app.Shutdown();

			Stop();

			return Json.Null();
		}

		protected override void OnMessage(Json json) {
			StringView method = json["method"].AsString;
			if (method.IsEmpty) return;

			Log.Debug("Received: {}", method);

			Json args = json["params"];

			switch (method) {
			case "initialize":                        HandleRequest(json, OnInitialize(args));
			case "initialized":                       OnInitialized();
			case "shutdown":                          HandleRequest(json, OnShutdown());

			case "textDocument/didOpen":              OnDidOpen(args);
			case "textDocument/didChange":            OnDidChange(args);
			case "textDocument/didClose":             OnDidClose(args);

			case "textDocument/foldingRange":         HandleRequest(json, OnFoldingRange(args));
			case "textDocument/completion":           HandleRequest(json, OnCompletion(args));
			case "completionItem/resolve":            HandleRequest(json, OnCompletionResolve(args));
			case "textDocument/documentSymbol":       HandleRequest(json, OnDocumentSymbol(args));
			case "textDocument/signatureHelp":        HandleRequest(json, OnSignatureHelp(args));
			case "textDocument/hover":                HandleRequest(json, OnHover(args));
			case "textDocument/definition":           HandleRequest(json, OnDefinition(args));
			case "textDocument/references":           HandleRequest(json, OnReferences(args));
			case "textDocument/rename":               HandleRequest(json, OnRename(args));
			case "textDocument/prepareRename":        HandleRequest(json, OnPrepareRename(args));
			case "textDocument/semanticTokens/full":  HandleRequest(json, OnSemanticTokensFull(args));

			case "workspace/symbol":                  HandleRequest(json, OnWorkspaceSymbol(args));

			case "beef/changeConfiguration":          HandleRequest(json, OnChangeConfiguration(args));
			case "beef/workspaceSettings":            HandleRequest(json, OnWorkspaceSettings());
			}
		}

		private void HandleRequest(Json json, Result<Json, Error> result) {
			Json response = .Object();

			response["jsonrpc"] = .String("2.0");
			response["id"] = json["id"];

			switch (result) {
			case .Ok(let val):
				response["result"] = result;
			case .Err(let err):
				response["error"] = err.GetJson();
				delete err;
			}

			Send(response);
			response.Dispose();
		}

		private int requestId = 0;

		private void Send(StringView method, Json json, bool request = false) {
			Json notification = .Object();

			notification["jsonrpc"] = .String("2.0");
			notification["method"] = .String(method);
			notification["params"] = json;

			if (request) notification["id"] = .Number(requestId++);

			Send(notification);
			notification.Dispose();
		}
	}
}
