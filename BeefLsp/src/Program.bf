using System;

using BeefLsp;

namespace BeefLsp {
	class Program {
		public static void Main(String[] args) {
			for (let arg in args) {
				if (arg == "--logDebug") {
					Log.LogDebug = true;
				}

				if (arg == "-h" || arg == "--help") {
					Console.WriteLine("""
						Language server for the Beef programming language. By default stdio is used to community with the client.
						
						 --help, -h     Prints this text.
						 --logFile      Uses a beeflsp_.log file for logging.
						 --logDebug     Logs debug info.
						 --port=<port>  Uses a TCP connection with the specified port.
						""");

					return;
				}
			}

			scope BeefLspServer().Start(args);
		}
	}
}