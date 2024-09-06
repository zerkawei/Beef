using System;

namespace BeefLsp {
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