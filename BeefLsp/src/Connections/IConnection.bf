using System;

namespace BeefLsp {
	interface IConnection {
		bool IsOpen { get; };

		Result<void> Start();
		void Stop();

		Result<RecvBuffer> WaitForData();
		void ReleaseBuffer();

		Result<void> Send(void* data, int size);
	}
}