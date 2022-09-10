namespace BeefLsp;

using System;
using System.Collections;

class Documentation {
	public String long ~ delete _;
	public StringView brief;

	public Dictionary<StringView, StringView> parameters ~ delete _;
	public StringView returns;

	public this() {
		long = new .();
		parameters = new .();
	}

	public void Parse(StringView docs) {
		for (let line in Utils.Lines(docs)) {
			if (line.StartsWith("@brief")) {
				int spaceI = line.IndexOf(' ');
				brief = line.Substring(spaceI + 1);
			}
			else if (line.StartsWith("@param")) {
				StringView param = line[6...]..TrimStart();

				int spaceI = param.IndexOf(' ');
				StringView name = param[0...spaceI - 1];
				StringView desc = param.Substring(spaceI + 1);

				parameters[name] = desc;
			}
			else if (line.StartsWith("@return")) {
				int spaceI = line.IndexOf(' ');
				returns = line.Substring(spaceI + 1);
			}
			else {
				if (!long.IsEmpty) long.Append('\n');
				long.Append(line);
			}
		}
	}

	public void ToString(StringView header, bool markdown, String buffer) {
		mixin NewLine() {
			if (markdown) buffer.Append("  \n");
			else buffer.Append('\n');
		}

		// Header
		if (!header.IsEmpty) {
			buffer.Append(header);

			if (!brief.IsEmpty || !long.IsEmpty || !returns.IsEmpty) {
				NewLine!();
				NewLine!();
			}
		}
		
		// Brief description
		if (!brief.IsEmpty) {
			buffer.Append(markdown ? "**Brief:** " : "Brief: ");
			buffer.Append(brief);
			if (!long.IsEmpty || !returns.IsEmpty) NewLine!();
		}

		// Long description
		if (!long.IsEmpty) {
			if (markdown) {
				for (let line in Utils.Lines(long)) {
					buffer.Append(line);
					if (@line.HasMore) NewLine!();
				}
			}
			else buffer.Append(long);

			if (!returns.IsEmpty) NewLine!();
		}

		// Returns
		if (!returns.IsEmpty) {
			if (!buffer.IsEmpty) NewLine!();
			buffer.Append(markdown ? "**Returns:** " : "Returns: ");
			buffer.Append(returns);
		}
	}

	public void ToStringParameter(StringView name, bool markdown, String buffer) {
		StringView _name, doc;

		if (parameters.TryGetAlt(name, out _name, out doc)) {
			buffer.Append(markdown ? "**Parameter:** " : "Parameter: ");
			buffer.Append(doc);
		}
	}
}