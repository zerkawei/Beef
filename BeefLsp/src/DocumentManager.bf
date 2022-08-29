using System;
using System.IO;
using System.Collections;

using IDE;
using IDE.Compiler;

namespace BeefLsp {
	enum CompilerDataType {
		Completions,
		Navigation,
		Hover,
		GoToDefinition,
		SymbolInfo
	}

	class Document {
		public String path ~ delete _;
		public int version;
		public String contents ~ delete _;

		private ProjectSource source;
		private BfParser parser;

		[AllowAppend]
		public this(StringView path, int version, String contents, ProjectSource source) {
			this.path = new .(path);
			this.version = version;
			this.contents = contents;
			this.source = source;
		}

		public void SetContents(int version, StringView contents) {
			this.version = version;
			this.contents.Set(contents);
		}

		public (int, int) GetLine(int position) {
			return parser.GetLineCharAtIdx(position);
		}

		public int GetPosition(Json json) {
			return parser.GetIndexAtLine((.) json["position"]["line"].AsNumber) + (.) json["position"]["character"].AsNumber + 1;
		}

		public void Parse(delegate void(BfPassInstance pass) callback) {
			LspApp.APP.LockSystem!();

			parser = LspApp.APP.mBfBuildSystem.CreateParser(source);

			BfPassInstance pass = LspApp.APP.mBfBuildSystem.CreatePassInstance("Parse");
			defer delete pass;

			parser.SetSource(contents, path, -1);
			parser.Parse(pass, false);
			parser.Reduce(pass);
			parser.BuildDefs(pass, null, false);

			// Classify
			BfResolvePassData passData = .Create(.None);
			defer delete passData;

			LspApp.APP.compiler.ClassifySource(pass, passData);

			// Publish diagnostics
			callback(pass);
		}

		public void GetCompilerData(CompilerDataType type, int character, String buffer, StringView entryName = "") {
			LspApp.APP.LockSystem!();

			BfParser parser = LspApp.APP.mBfBuildSystem.CreateParser(source, false);

			String name;
			switch (type) {
			case .Completions:    name = "GetCompilerData - Completions";
			case .Navigation:     name = "GetCompilerData - Navigation";
			case .Hover:          name = "GetCompilerData - Hover";
			case .GoToDefinition: name = "GetCompilerData - GoToDefinition";
			case .SymbolInfo:     name = "GetCompilerData - SymbolInfo";
			}

			let pass = LspApp.APP.mBfBuildSystem.CreatePassInstance(name);
			defer delete pass;

			ResolveType resolveType;
			switch (type) {
			case .Completions:    resolveType = .Autocomplete;
			case .Navigation:     resolveType = .GetNavigationData;
			case .Hover:          resolveType = .GetResultString;
			case .GoToDefinition: resolveType = .GoToDefinition;
			case .SymbolInfo:     resolveType = .GetSymbolInfo;
			}
			
			parser.SetIsClassifying();
			parser.SetSource(contents, path, -1);
			parser.SetAutocomplete(type == .Navigation ? -1 : character);

			let passData = parser.CreateResolvePassData(resolveType);
			defer delete passData;

			if (!entryName.IsEmpty) passData.SetDocumentationRequest(scope .(entryName));

			parser.Parse(pass, false);
			parser.Reduce(pass);
			parser.BuildDefs(pass, passData, false);

			BfParser.[Friend]BfParser_CreateClassifier(parser.mNativeBfParser, pass.mNativeBfPassInstance, passData.mNativeResolvePassData, null);
			LspApp.APP.compiler.ClassifySource(pass, passData);
			parser.FinishClassifier(passData);

			LspApp.APP.compiler.GetAutocompleteInfo(buffer);

			delete parser;
			LspApp.APP.mBfBuildSystem.RemoveOldData();
		}

		public void GetFoldingData(String buffer) {
			LspApp.APP.LockSystem!();

			var resolvePassData = parser.CreateResolvePassData(.None);
			defer delete resolvePassData;

			LspApp.APP.compiler.GetCollapseRegions(parser, resolvePassData, "", buffer);
		}
	}

	class DocumentManager {
		private Dictionary<String, Document> documents = new .() ~ DeleteDictionaryAndValues!(_);

		public Document Add(StringView path, int version, String contents, ProjectSource source) {
			Document document = new .(path, version, contents, source);
			documents[document.path] = document;

			return document;
		}

		public void Remove(StringView path) {
			if (documents.GetAndRemoveAlt(path) case .Ok(let val)) {
				delete val.value;
			}
		}

		public Document Get(StringView path) {
			String key;
			Document document;

			if (!documents.TryGetAlt(path, out key, out document)) return null;
			return document;
		}
	}
}