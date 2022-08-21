using System;

namespace BeefLsp {
	abstract class LspServer {
		private IConnection connection ~ delete _;

		private int contentsSize = 0;

		public void StartStdio() {
			Log.Info("Starting server on stdio");

			connection = new StdioConnection(this);
			Start();
		}

		public void StartTcp(int port) {
			Log.SetupStdio();
			Log.Info("Starting server on port {}", port);

			connection = new TcpConnection(this, port);
			Start();
		}

		public void Stop() {
			connection.Stop();
		}

		protected abstract void OnMessage(Json json);

		public void Send(Json json) {
			String jsonStr = new .();
			defer delete jsonStr; // For some reason using ScopedAlloc! here was causing memory leaks
			JsonWriter.Write(json, jsonStr);

			String header = scope $"Content-Length: {jsonStr.Length}\r\n\r\n";

			int size = jsonStr.Length + header.Length;
			uint8* data = new:ScopedAlloc! .[size]*;

			Internal.MemCpy(data, header.Ptr, header.Length);
			Internal.MemCpy(&data[header.Length], jsonStr.Ptr, jsonStr.Length);

			connection.Send(data, size).IgnoreError();
		}

		private void Start() {
			// Connect
			Log.Info("Connecting to a client");

			if (connection.Start() == .Err) {
				Log.Error("Failed to start connection with the client");
				return;
			}

			Log.Info("Connected");

			// Run
			Run();
		}

		private void Run() {
			while (connection.IsOpen) {
				if (connection.WaitForData() case .Ok(let buffer)) {
					ProcessBuffer(buffer);
					connection.ReleaseBuffer();
				}
			}
		}

		private void ProcessBuffer(RecvBuffer buffer) {
			if (!connection.IsOpen) return;

			if (contentsSize == 0) {
				// Parse header      TODO: needs better detection
				if (buffer.HasEnough(50)) {
					StringView header = .((char8*) buffer.buffer, 50);
					int i = header.IndexOf("\r\n\r\n");

					if (i == -1) {
						Log.Error("Failed to find \r\n\r\n ending sequence in header, something went wrong. Closing connection");
						Stop();
						return;
					}

					header = header[...(i - 1)];

					for (let field in header.Split("\r\n")) {
						if (field.StartsWith("Content-Length: ")) {
							contentsSize = int.Parse(field[16...]);
							break;
						}
					}

					buffer.Skip(i + 4);
					header = .((char8*) buffer.buffer, 50);

					ProcessBuffer(buffer);
				}
			}
			else {
				// Parse contents
				if (buffer.HasEnough(contentsSize)) {
					StringView msg = .((char8*) buffer.buffer, contentsSize);

					Json json = JsonParser.ParseString(msg);
					OnMessage(json);
					json.Dispose();

					buffer.Skip(contentsSize);
					contentsSize = 0;
					
					ProcessBuffer(buffer);
				}
			}
		}
	}
}