import asyncio
import json
import websockets
from concurrent.futures import ThreadPoolExecutor

CONNECTED = set()

async def handle(ws, path=None):
    print("Client connected:", ws.remote_address)
    CONNECTED.add(ws)
    try:
        async for message in ws:
            try:
                data = json.loads(message)
            except Exception:
                print("Received non-json:", message)
                continue

            if data.get("type") == "coords":
                print("\n===> New coords received:")
                print(f" board_id={data.get('board_id')} defect_id={data.get('defect_id')}")
                print(" coords:", data.get("x"), data.get("y"))
                print("\nPress 'q' then Enter to send PROCESS to client (or 's' to skip).")

                loop = asyncio.get_event_loop()
                with ThreadPoolExecutor(1) as ex:
                    inp = await loop.run_in_executor(ex, input, "> ")

                if inp.strip().lower() == 'q':
                    reply = {"type": "process", "defect_id": data.get("defect_id")}
                    await ws.send(json.dumps(reply))
                    print("Sent PROCESS to client for defect_id:", data.get("defect_id"))
                else:
                    print("Skipped PROCESS for this defect.")

            elif data.get("type") == "result":
                print("\n<=== AI result received from client:")
                print(json.dumps(data, indent=2, ensure_ascii=False))

            else:
                print("Unknown message type:", data.get("type"))
    except websockets.exceptions.ConnectionClosed:
        print("Client disconnected")
    finally:
        CONNECTED.discard(ws)

async def main():
    server = await websockets.serve(handle, "0.0.0.0", 8765)
    print("WebSocket server listening on ws://0.0.0.0:8765")
    await server.wait_closed()

if __name__ == "__main__":
    try:
        asyncio.run(main())
    except KeyboardInterrupt:
        print("Server stopped")