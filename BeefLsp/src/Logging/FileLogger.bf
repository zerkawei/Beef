namespace BeefLsp;

using System;
using System.IO;

class FileLogger : ILogger {
	private FileStream fs ~ delete _;
	private StreamWriter writer ~ delete _;

	public this() {
		fs = new .();
		fs.Create(scope $"beeflsp_{DateTime.Now.ToString(.. scope .())..Replace('/', '-')..Replace(':', '-')}.log", .Write, .Read);
		
		writer = new StreamWriter(fs, .ASCII, 4096, true);
	}

	public void Log(Message message) {
		writer.WriteLine(message.text);
	}
}