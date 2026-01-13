"""
SICK Camera WebSocket Stream Server
Streams frames from SICK camera via IC4 to Flutter app on port 8999
Protocol: Binary JPEG frames (no base64, no JSON wrapper)
"""

import asyncio
import websockets
import cv2
import logging
from typing import Set
from datetime import datetime

try:
    import imagingcontrol4 as ic4
    IC4_AVAILABLE = True
except ImportError:
    IC4_AVAILABLE = False
    print("⚠️  WARNING: imagingcontrol4 not installed. Will use mock camera.")

# ===============================
# Logging
# ===============================
logging.basicConfig(
    level=logging.INFO,
    format="%(asctime)s [%(levelname)s] %(message)s"
)
logger = logging.getLogger("SICKCameraStream")


class SICKCameraStreamServer:
    """WebSocket server streaming SICK camera frames"""
    
    def __init__(self, use_mock=False):
        self.clients: Set[websockets.WebSocketServerProtocol] = set()
        self.current_frame_jpeg = None
        self.running = False
        self.use_mock = use_mock or not IC4_AVAILABLE
        self.grabber = None
        self.frame_count = 0
        
        # Configuration
        self.width = 640
        self.height = 480
        self.jpeg_quality = 70
        self.target_fps = 20
        self.frame_interval = 1.0 / self.target_fps  # 0.05 seconds
        
    def start_camera_stream(self):
        """Initialize and start camera stream"""
        if self.use_mock:
            logger.info("🎥 Starting MOCK camera (IC4 not available)")
            self.running = True
            return
        
        try:
            # Initialize IC4 library
            ic4.Library.init()
            logger.info("✅ IC4 Library initialized")
            
            # Get available devices
            devices = ic4.DeviceEnum.devices()
            if not devices:
                raise Exception("No SICK camera devices found")
            
            logger.info(f"📷 Found {len(devices)} camera(s)")
            device_info = devices[0]
            logger.info(f"📷 Using camera: {device_info.model_name}")
            
            # Setup grabber
            self.grabber = ic4.Grabber()
            self.grabber.device_open(device_info)
            
            # Configure camera properties
            prop_map = self.grabber.device_property_map
            
            # Set resolution
            if prop_map.find(ic4.PropId.WIDTH):
                prop_map.set_value(ic4.PropId.WIDTH, self.width)
            if prop_map.find(ic4.PropId.HEIGHT):
                prop_map.set_value(ic4.PropId.HEIGHT, self.height)
            
            logger.info(f"📐 Camera configured: {self.width}x{self.height}")
            
            # Setup frame listener
            class FrameListener(ic4.QueueSinkListener):
                def __init__(self, server):
                    super().__init__()
                    self.server = server
                
                def sink_connected(self, sink, image_type, min_buffers_required):
                    return True
                
                def frames_queued(self, sink):
                    try:
                        buffer = sink.pop_output_buffer()
                        frame = buffer.numpy_wrap()
                        
                        # Encode to JPEG
                        encode_params = [cv2.IMWRITE_JPEG_QUALITY, self.server.jpeg_quality]
                        success, jpeg = cv2.imencode('.jpg', frame, encode_params)
                        
                        if success:
                            self.server.current_frame_jpeg = jpeg.tobytes()
                            self.server.frame_count += 1
                    except Exception as e:
                        logger.error(f"❌ Frame processing error: {e}")
            
            listener = FrameListener(self)
            sink = ic4.QueueSink(listener, max_output_buffers=1)
            self.grabber.stream_setup(sink)
            
            self.running = True
            logger.info("✅ SICK camera stream started")
            
        except Exception as e:
            logger.error(f"❌ Camera initialization failed: {e}")
            logger.info("🔄 Falling back to MOCK camera")
            self.use_mock = True
            self.running = True
    
    def generate_mock_frame(self):
        """Generate mock frame for testing without real camera"""
        # Create test pattern
        frame = cv2.imread('test_pattern.jpg') if False else None
        
        if frame is None:
            # Generate simple test pattern
            import numpy as np
            frame = np.zeros((self.height, self.width, 3), dtype=np.uint8)
            
            # Add timestamp text
            timestamp = datetime.now().strftime("%H:%M:%S.%f")[:-3]
            cv2.putText(
                frame, 
                f"MOCK CAMERA", 
                (50, 200), 
                cv2.FONT_HERSHEY_SIMPLEX, 
                1.5, 
                (255, 255, 255), 
                2
            )
            cv2.putText(
                frame, 
                f"Frame: {self.frame_count}", 
                (50, 280), 
                cv2.FONT_HERSHEY_SIMPLEX, 
                1, 
                (0, 255, 0), 
                2
            )
            cv2.putText(
                frame, 
                timestamp, 
                (50, 340), 
                cv2.FONT_HERSHEY_SIMPLEX, 
                0.8, 
                (0, 255, 255), 
                2
            )
        
        # Encode to JPEG
        encode_params = [cv2.IMWRITE_JPEG_QUALITY, self.jpeg_quality]
        success, jpeg = cv2.imencode('.jpg', frame, encode_params)
        
        if success:
            self.current_frame_jpeg = jpeg.tobytes()
            self.frame_count += 1
    
    async def send_frames(self):
        """Continuously send frames to all connected clients"""
        logger.info("🎬 Frame sender started")
        
        while self.running:
            try:
                # Generate mock frame if needed
                if self.use_mock:
                    self.generate_mock_frame()
                
                # Send frame to all clients
                if self.current_frame_jpeg and self.clients:
                    # Send binary JPEG to all clients
                    disconnected = set()
                    for client in self.clients:
                        try:
                            await client.send(self.current_frame_jpeg)
                        except websockets.exceptions.ConnectionClosed:
                            disconnected.add(client)
                        except Exception as e:
                            logger.warning(f"⚠️  Send error: {e}")
                            disconnected.add(client)
                    
                    # Remove disconnected clients
                    self.clients -= disconnected
                
                # Control frame rate
                await asyncio.sleep(self.frame_interval)
                
            except Exception as e:
                logger.error(f"❌ Frame sender error: {e}")
                await asyncio.sleep(0.1)
    
    async def handle_client(self, websocket, path):
        """Handle WebSocket client connection"""
        client_addr = websocket.remote_address
        logger.info(f"✅ Client connected: {client_addr}")
        self.clients.add(websocket)
        
        try:
            # Send initial status message (optional)
            status = {
                "type": "connection",
                "status": "connected",
                "camera": "MOCK" if self.use_mock else "SICK",
                "resolution": f"{self.width}x{self.height}",
                "fps": self.target_fps
            }
            # Note: We send JSON only for initial handshake
            # After that, only binary frames
            import json
            await websocket.send(json.dumps(status))
            
            # Keep connection alive and listen for commands
            async for message in websocket:
                try:
                    # Handle text commands (optional)
                    if isinstance(message, str):
                        import json
                        data = json.loads(message)
                        command = data.get("command")
                        
                        if command == "stop":
                            logger.info("🛑 Stop command received")
                            self.running = False
                        elif command == "ping":
                            await websocket.send(json.dumps({"type": "pong"}))
                        
                except Exception as e:
                    logger.warning(f"⚠️  Message handling error: {e}")
                    
        except websockets.exceptions.ConnectionClosed:
            logger.info(f"🔌 Client disconnected: {client_addr}")
        except Exception as e:
            logger.error(f"❌ Client error: {e}")
        finally:
            self.clients.discard(websocket)
            logger.info(f"👋 Client removed: {client_addr} (Total: {len(self.clients)})")
    
    async def start_server(self, host="0.0.0.0", port=8999):
        """Start WebSocket server"""
        logger.info("=" * 60)
        logger.info("🚀 SICK Camera WebSocket Server")
        logger.info("=" * 60)
        logger.info(f"📡 Server: ws://{host}:{port}")
        logger.info(f"📷 Camera: {'MOCK' if self.use_mock else 'SICK IC4'}")
        logger.info(f"📐 Resolution: {self.width}x{self.height}")
        logger.info(f"🎥 Target FPS: {self.target_fps}")
        logger.info(f"📦 JPEG Quality: {self.jpeg_quality}")
        logger.info("=" * 60)
        
        # Start frame sender task
        frame_task = asyncio.create_task(self.send_frames())
        
        # Start WebSocket server
        async with websockets.serve(self.handle_client, host, port):
            logger.info("✅ Server ready, waiting for clients...")
            await asyncio.Future()  # Run forever
    
    def stop(self):
        """Stop camera and server"""
        logger.info("🛑 Stopping server...")
        self.running = False
        
        if self.grabber:
            try:
                self.grabber.stream_stop()
                logger.info("📷 Camera stream stopped")
            except Exception as e:
                logger.warning(f"⚠️  Camera stop error: {e}")
        
        if IC4_AVAILABLE:
            try:
                ic4.Library.exit()
                logger.info("✅ IC4 Library closed")
            except:
                pass


async def main():
    """Main entry point"""
    # Create server instance
    server = SICKCameraStreamServer(use_mock=not IC4_AVAILABLE)
    
    try:
        # Start camera
        server.start_camera_stream()
        
        # Start server
        await server.start_server(host="0.0.0.0", port=8999)
        
    except KeyboardInterrupt:
        logger.info("\n⚠️  Keyboard interrupt received")
    except Exception as e:
        logger.error(f"❌ Server error: {e}")
    finally:
        server.stop()
        logger.info("👋 Server shutdown complete")


if __name__ == "__main__":
    asyncio.run(main())
