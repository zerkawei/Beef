using System;
using System.Threading;

namespace BeefLsp {
	class StdioConnection : IConnection {
		private LspServer server;

		private Thread thread ~ delete _;
		private bool open;

		private WaitEvent waitEvent ~ delete _;
		private Monitor bufferMonitor ~ delete _;
		private RecvBuffer buffer ~ delete _;

		public this(LspServer server) {
			this.server = server;

			this.waitEvent = new .();
			this.bufferMonitor = new .();
			this.buffer = new .();
		}

		public bool IsOpen => open;

		public Result<void> Start() {
			thread = new .(new => Run);

			open = true;
			thread.Start(false);

			return .Ok;
		}

		public void Stop() {
			open = false;

			thread.Join();

			waitEvent.Set(true);
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
			if (Console.Out.Write(Span<uint8>((.) data, size)) == .Err) return .Err;
			return .Ok;
		}

		private void Run() {
			uint8* data = new:ScopedAlloc! .[4096]*;

			while (open) {
				switch (Console.In.BaseStream.TryRead(.(data, 4096))) {
				case .Ok(let received):
					bufferMonitor.Enter();
					buffer.Add(data, received);
					bufferMonitor.Exit();

					waitEvent.Set();

				case .Err:
					open = false;
				}
			}
		}
	}
}