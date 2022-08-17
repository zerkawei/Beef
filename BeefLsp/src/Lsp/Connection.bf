using System;
using System.Net;

namespace BeefLsp {
	interface ILspHandler {
		void OnMessage(Json json);
	}

	class Connection {
		private ILspHandler handler;

		private Socket listener ~ delete _;
		private Socket client ~ delete _;

		private RecvBuffer buffer = new .() ~ delete _;
		private bool open = true;
		private int contentsSize = 0;

		public this(ILspHandler handler) {
			this.handler = handler;

			Socket.Init();

			listener = new .();
			listener.Blocking = true;

			client = new .();
			client.Blocking = true;
		}

		public void Start() {
			// Connect
			Console.WriteLine("Connecting");

			if (listener.Listen(5556) == .Err) {
				Console.WriteLine("Failed to listen on port 5556");
				return;
			}

			if (client.AcceptFrom(listener) == .Err) {
				Console.WriteLine("Failed to connect to the client");
				return;
			}

			Console.WriteLine("Connected");

			// Loop
			uint8* data = new:ScopedAlloc! .[4096]*;

			while (open) {
				switch (client.Recv(data, 4096)) {
				case .Ok(let received):
					buffer.Add(data, received);
					OnData();

				case .Err:
					Console.WriteLine("Connection closed");
					open = false;
				}
			}
		}

		public void Send(Json json) {
			String jsonStr = new:ScopedAlloc! .();
			JsonWriter.Write(json, jsonStr);

			String header = scope $"Content-Length: {jsonStr.Length}\r\n\r\n";

			int size = jsonStr.Length + header.Length;
			uint8* data = new:ScopedAlloc! .[size]*;

			Internal.MemCpy(data, header.Ptr, header.Length);
			Internal.MemCpy(&data[header.Length], jsonStr.Ptr, jsonStr.Length);

			int sent = client.Send(data, size);
			if (sent != size) Console.WriteLine("Failed to send message");
		}

		private void OnData() {
			if (contentsSize == 0) {
				// Parse header      TODO: needs better detection
				if (buffer.HasEnough(50)) {
					StringView header = .((char8*) buffer.buffer, 50);
					int i = header.IndexOf("\r\n\r\n");

					if (i == -1) {
						Console.WriteLine("Failed to find \r\n\r\n ending sequence in header, something went wrong. Closing connection");
						open = false;
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

					OnData();
				}
			}
			else {
				// Parse contents
				if (buffer.HasEnough(contentsSize)) {
					StringView msg = .((char8*) buffer.buffer, contentsSize);

					Json json = JsonParser.ParseString(msg);
					handler.OnMessage(json);
					json.Dispose();

					buffer.Skip(contentsSize);
					contentsSize = 0;
					
					OnData();
				}
			}
		}

		class RecvBuffer {
			public uint8* buffer ~ delete _;
			private int size, capacity;

			public this() {
				capacity = 8192;
				buffer = new .[capacity]*;
			}

			private void EnsureCapacity(int additionalSize) {
				if (size + additionalSize > capacity) {
					capacity = Math.Max((int) (capacity * 1.5), size + additionalSize);

					uint8* newBuffer = new .[capacity]*;
					Internal.MemCpy(newBuffer, buffer, size);

					delete buffer;
					buffer = newBuffer;
				}
			}

			public void Add(void* data, int size) {
				EnsureCapacity(size);

				Internal.MemCpy(&buffer[this.size], data, size);
				this.size += size;
			}

			public bool HasEnough(int size) {
				return this.size >= size;
			}

			public void Skip(int size) {
				this.size -= size;
				Internal.MemCpy(buffer, &buffer[size], this.size);
			}
		}
	}
}