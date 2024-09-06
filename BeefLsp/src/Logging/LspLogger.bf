namespace BeefLsp;

using System;

class LspLogger : ILogger {
	private LspServer lsp;

	public this(LspServer lsp) {
		this.lsp = lsp;
	}

	public void Log(Message message) {
		if (!lsp.IsOpen) return;

		Json json = .Object();

		json["type"] = .Number(4);
		json["message"] = .String(message.text);

		lsp.Send("window/logMessage", json);
	}
}