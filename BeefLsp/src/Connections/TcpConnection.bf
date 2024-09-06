using System;
using System.Net;
using System.Threading;

namespace BeefLsp {
	class TcpConnection : IConnection {
		private LspServer server;
		private int port;

		private Thread thread ~ delete _;
		private bool open;

		private Socket listener ~ delete _;
		private Socket client ~ delete _;

		private WaitEvent waitEvent ~ delete _;
		private Monitor bufferMonitor ~ delete _;
		private RecvBuffer buffer ~ delete _;

		public this(LspServer server, int port) {
			this.server = server;
			this.port = port;

			this.waitEvent = new .();
			this.bufferMonitor = new .();
			this.buffer = new .();
		}

		public bool IsOpen => open;

		public Result<void> Start() {
			// Create sockets
			Socket.Init();

			listener = new .();
			listener.Blocking = true;

			client = new .();
			client.Blocking = false;

			// Connect
			if (listener.Listen(5556) == .Err) return .Err;
			if (client.AcceptFrom(listener) == .Err) return .Err;

			// Start thread
			thread = new .(new => Run);

			open = true;
			thread.Start(false);

			return .Ok;
		}

		public void Stop() {
			open = false;
			waitEvent.Set(true);
			
			thread.Join();

			listener.Close();
			client.Close();
		}

		public Result<RecvBuffer> WaitForData() {
			waitEvent.WaitFor();
			if (!open) return .Err;

			bufferMonitor.Enter();
			return buffer;
		}

		public void ReleaseBuffer() {
			bufferMonitor.Exit();
		}

		public Result<void> Send(void* data, int size) {
			if (client.Send(data, size) == .Err) return .Err;
			return .Ok;
		}

		private void Run() {
			uint8* data = new:ScopedAlloc! .[4096]*;

			while (open) {
				Socket.FDSet readSet = .();
				readSet.Add(client.NativeSocket);

				int32 count = Socket.Select(&readSet, null, null, 1000);
				if (count <= 0) continue;

				switch (client.Recv(data, 4096)) {
				case .Ok(let received):
					if (received <= 0) continue;

					bufferMonitor.Enter();
					buffer.Add(data, received);
					bufferMonitor.Exit();

					waitEvent.Set();

				case .Err:
					open = false;
					waitEvent.Set(true);
				}
			}
		}
	}
}