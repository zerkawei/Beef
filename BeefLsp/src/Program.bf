using System;

using BeefLsp;

namespace BeefLsp {
	class Program {
		public static void Main(String[] args) {
			//Test(args);
			//return;

			scope Lsp().Start();
		}

		private static void Test(String[] args) {
			String commandLine = scope String();
			commandLine.Join(" ", params args);

			LspApp app = scope .();
			app.ParseCommandLine(commandLine);

			if (app.mFailed) {
				Console.Error.WriteLine("  Run with \"-help\" for a list of command-line arguments");
			}
			else {
				app.Init();
				app.Run();
			}

			app.Shutdown();
		}
	}
}