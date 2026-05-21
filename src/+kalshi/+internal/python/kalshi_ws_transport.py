"""Python WebSocket transport used by the MATLAB Kalshi client."""

import asyncio
import json
import queue
import threading


class KalshiWebSocketTransport:
    """Small threaded wrapper around the Python websockets package."""

    def __init__(self, url, headers_json="[]", timeout=30):
        self.url = url
        self.headers = {
            item["name"]: item["value"] for item in json.loads(headers_json or "[]")
        }
        self.timeout = float(timeout)
        self.loop = None
        self.websocket = None
        self.thread = None
        self.inbox = queue.Queue()
        self.errors = queue.Queue()
        self.connected = threading.Event()
        self.closed = threading.Event()

    def connect(self):
        self.thread = threading.Thread(target=self._thread_main, daemon=True)
        self.thread.start()
        if not self.connected.wait(self.timeout):
            self._raise_pending_error()
            raise TimeoutError("Timed out connecting to Kalshi WebSocket")
        self._raise_pending_error()

    def send_json(self, payload_json):
        self._require_connection()
        future = asyncio.run_coroutine_threadsafe(
            self.websocket.send(payload_json), self.loop
        )
        return future.result(timeout=self.timeout)

    def receive(self, timeout=0):
        try:
            return self.inbox.get(timeout=float(timeout))
        except queue.Empty:
            return None

    def close(self):
        self.closed.set()
        if self.websocket is not None and self.loop is not None:
            try:
                future = asyncio.run_coroutine_threadsafe(
                    self.websocket.close(), self.loop
                )
                future.result(timeout=min(self.timeout, 5.0))
            except Exception:
                pass

    def _thread_main(self):
        self.loop = asyncio.new_event_loop()
        asyncio.set_event_loop(self.loop)
        try:
            self.loop.run_until_complete(self._run())
        except Exception as exc:  # pragma: no cover - surfaced to MATLAB
            self.errors.put(exc)
            self.connected.set()
        finally:
            self.loop.close()

    async def _run(self):
        import websockets

        try:
            self.websocket = await websockets.connect(
                self.url, additional_headers=self.headers
            )
        except TypeError:
            self.websocket = await websockets.connect(
                self.url, extra_headers=self.headers
            )

        self.connected.set()
        async for message in self.websocket:
            self.inbox.put(message)
            if self.closed.is_set():
                break

    def _raise_pending_error(self):
        try:
            error = self.errors.get_nowait()
        except queue.Empty:
            return
        raise error

    def _require_connection(self):
        if self.websocket is None or self.loop is None:
            raise RuntimeError("WebSocket is not connected")
