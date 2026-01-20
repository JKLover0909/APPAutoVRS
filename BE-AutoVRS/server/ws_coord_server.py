import asyncio
import json
import websockets # type: ignore
import httpx  # For calling PLC Gateway API

CONNECTED = set()
PLC_GATEWAY_URL = "http://localhost:8083/api/plc/move"

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
                print(f" coords: X={data.get('x')}mm, Y={data.get('y')}mm")
                
                # Call PLC Gateway API to move camera
                try:
                    async with httpx.AsyncClient(timeout=15.0) as client:
                        print(f"\n📡 Calling PLC Gateway API: {PLC_GATEWAY_URL}")
                        response = await client.post(
                            PLC_GATEWAY_URL,
                            json={
                                "x": data.get("x"),
                                "y": data.get("y"),
                                "board_id": data.get("board_id"),
                                "defect_id": data.get("defect_id")
                            }
                        )
                        
                        if response.status_code == 200:
                            result = response.json()
                            print(f"✅ PLC movement successful:")
                            print(f"   {result.get('message')}")
                            print(f"   Elapsed: {result.get('elapsed_seconds', 0):.1f}s")
                            
                            # Send PROCESS signal to Flutter client
                            reply = {"type": "process", "defect_id": data.get("defect_id")}
                            await ws.send(json.dumps(reply))
                            print(f"✅ Sent PROCESS signal to Flutter client for defect_id={data.get('defect_id')}")
                        else:
                            error_detail = response.json().get("detail", "Unknown error")
                            print(f"❌ PLC Gateway API error: {response.status_code} - {error_detail}")
                            
                except httpx.TimeoutException:
                    print(f"❌ PLC Gateway API timeout (>15s)")
                except httpx.ConnectError:
                    print(f"❌ Cannot connect to PLC Gateway at {PLC_GATEWAY_URL}")
                    print("   Make sure run_plc_gateway.py is running")
                except Exception as e:
                    print(f"❌ Error calling PLC Gateway: {e}")

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