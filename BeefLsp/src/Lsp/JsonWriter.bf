using System;

namespace BeefLsp {
	static class JsonWriter {
		public static void Write(Json json, String buffer) {
			switch (json.type) {
			case .String: buffer.AppendF("\"{}\"", json.AsString);
			case .Object: WriteObject(json, buffer);
			case .Array:  WriteObject(json, buffer);
			default:      json.ToString(buffer);
			}
		}

		private static void WriteObject(Json json, String buffer) {
			buffer.Append('{');

			int i = 0;
			for (let field in json.AsObject) {
				if (i > 0) buffer.Append(',');

				buffer.Append('"');
				buffer.Append(field.key);
				buffer.Append("\":");
				Write(field.value, buffer);

				i++;
			}

			buffer.Append('}');
		}

		private static void WriteArray(Json json, String buffer) {
			buffer.Append('[');

			int i = 0;
			for (let item in json.AsArray) {
				if (i > 0) buffer.Append(',');

				Write(item, buffer);

				i++;
			}

			buffer.Append(']');
		}
	}
}