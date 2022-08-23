using System;
using System.IO;
using System.Collections;

namespace BeefLsp {
	struct LineInfo : this(int line, int start) {}

	class Document {
		public String path ~ delete _;
		public int version;
		public String contents ~ delete _;

		[AllowAppend]
		public this(StringView path, int version, String contents) {
			this.path = new .(path);
			this.version = version;
			this.contents = contents;
		}

		public void SetContents(int version, StringView contents) {
			this.version = version;
			this.contents.Set(contents);
		}

		public LineInfo GetLineInfo(int character) {
			int currentCharacter = 0;
			int line = 0;
			int lineStart = 0;

			for (let char in contents.RawChars) {
				if (char == '\n') {
					line++;
					lineStart = currentCharacter + 1;
				}

				currentCharacter++;
				if (currentCharacter >= character) break;
			}

			return .(line, lineStart);
		}

		public int GetPosition(int line, int lineCharacter) {
			int currentLine = 0;

			for (let char in contents.RawChars) {
				if (char == '\n') {
					currentLine++;

					if (currentLine == line) {
						return @char.Index + lineCharacter + 1;
					}
				}
			}

			return -1;
		}

		public int GetPosition(Json json) {
			return GetPosition((.) json["position"]["line"].AsNumber, (.) json["position"]["character"].AsNumber);
		}
	}

	class DocumentManager {
		private Dictionary<String, Document> documents = new .() ~ DeleteDictionaryAndValues!(_);

		public Document Add(StringView path, int version, String contents) {
			Document document = new .(path, version, contents);
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