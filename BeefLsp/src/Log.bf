using System;
using System.IO;

namespace BeefLsp {
	static class Log {
		private static StreamWriter writer = null;
		private static bool ownsWriter = false;
		private static bool isStdio = false;

		public static bool LogDebug =
#if DEBUG
			true;
#else
			false;
#endif

		static ~this() {
			if (ownsWriter) {
				writer.Flush();
				delete writer;
			}
		}

		public static void SetupStdio() {
			if (writer != null) return;

			writer = Console.Out;
			isStdio = true;
		}

		public static void SetupFile() {
			if (writer != null) return;

			FileStream fs = new .();
			fs.Create(scope $"beeflsp_{DateTime.Now.ToString(.. scope .())..Replace('/', '-')..Replace(':', '-')}.log", .Write, .Read);
			
			writer = new StreamWriter(fs, .ASCII, 4096, true);
			ownsWriter = true;
		}

		public static void Debug(StringView fmt, params Object[] args) {
			if (writer == null || !LogDebug) return;

			if (isStdio) Console.ForegroundColor = .DarkGray;

			String str = AppendHeader(.. scope .(), "DEBUG");
			str.AppendF(fmt, params args);
			writer.WriteLine(str);

			writer.Flush();
		}

		public static void Info(StringView fmt, params Object[] args) {
			if (writer == null) return;

			if (isStdio) Console.ForegroundColor = .White;

			String str = AppendHeader(.. scope .(), "INFO");
			str.AppendF(fmt, params args);
			writer.WriteLine(str);

			writer.Flush();
		}

		public static void Warning(StringView fmt, params Object[] args) {
			if (writer == null) return;

			if (isStdio) Console.ForegroundColor = .Yellow;

			String str = AppendHeader(.. scope .(), "WARNING");
			str.AppendF(fmt, params args);
			Console.WriteLine(str);

			writer.Flush();
		}

		public static void Error(StringView fmt, params Object[] args) {
			if (writer == null) return;

			if (isStdio) Console.ForegroundColor = .Red;

			String str = AppendHeader(.. scope .(), "ERROR");
			str.AppendF(fmt, params args);
			writer.WriteLine(str);

			writer.Flush();
		}

		private static void AppendHeader(String str, StringView name) {
#if BF_PLATFORM_WINDOWS
			DateTime time = .Now;
			str.AppendF("[{:D2}:{:D2}:{:D2}] {}: ", time.Hour, time.Minute, time.Second, name);
#else
			str.AppendF("{}: ", name);
#endif
		}
	}
}