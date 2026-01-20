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
        self.sink = None
        self.frame_count = 0
        self.listener = None
        
        # Configuration
        self.width = 1920  # Camera capture resolution
        self.height = 1080
        self.target_width = 1920  # Output stream resolution
        self.target_height = 1080
        self.jpeg_quality = 60  # Lowered from 70 for better FPS at high resolutions
        self.target_fps = 30  # Increased from 20 to 30 FPS
        self.frame_interval = 1.0 / self.target_fps  # ~0.033 seconds
        
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
            
            # Set pixel format to color (BGR8)
            try:
                prop_map.set_value(ic4.PropId.PIXEL_FORMAT, ic4.PixelFormat.BGR8)
                logger.info("🎨 Pixel format: BGR8 (Color)")
            except Exception as e:
                logger.warning(f"⚠️  Could not set BGR8, using default: {e}")
            
            # Set resolution
            if prop_map.find(ic4.PropId.WIDTH):
                prop_map.set_value(ic4.PropId.WIDTH, self.width)
            if prop_map.find(ic4.PropId.HEIGHT):
                prop_map.set_value(ic4.PropId.HEIGHT, self.height)
            
            # Set ROI origin to top-left corner
            try:
                prop_map.set_value(ic4.PropId.OFFSET_AUTO_CENTER, "Off")
                prop_map.set_value(ic4.PropId.OFFSET_X, 0)
                prop_map.set_value(ic4.PropId.OFFSET_Y, 0)
                logger.info("📍 ROI offset: (0, 0)")
            except Exception as e:
                logger.warning(f"⚠️  Could not set ROI offset: {e}")
            
            # Configure exposure (5ms = 5000µs)
            try:
                prop_map.set_value(ic4.PropId.EXPOSURE_AUTO, "Off")
                prop_map.set_value(ic4.PropId.EXPOSURE_TIME, 5000.0)
                logger.info("⏱️  Exposure: 5ms (manual)")
            except Exception as e:
                logger.warning(f"⚠️  Could not set exposure: {e}")
            
            # Enable auto gain
            try:
                prop_map.set_value(ic4.PropId.GAIN_AUTO, "Continuous")
                logger.info("📈 Gain: Auto (Continuous)")
            except Exception as e:
                logger.warning(f"⚠️  Could not set auto gain: {e}")
            
            logger.info(f"📐 Camera configured: {self.width}x{self.height}")
            
            # Setup QueueSink with listener for continuous streaming
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
                        
                        # Rotate frame 180 degrees
                        frame = cv2.rotate(frame, cv2.ROTATE_90_CLOCKWISE)
                        
                        # Camera now captures at target resolution, no resize needed
                        # (unless target was changed during runtime)
                        if (frame.shape[1] != self.server.target_width or 
                            frame.shape[0] != self.server.target_height):
                            frame = cv2.resize(
                                frame, 
                                (self.server.target_width, self.server.target_height),
                                interpolation=cv2.INTER_AREA  # Better quality for downscaling
                            )
                        
                        # Encode to JPEG with adaptive quality based on resolution
                        # Lower quality for high-res to maintain FPS
                        pixels = frame.shape[0] * frame.shape[1]
                        if pixels > 8_000_000:  # > 4K
                            quality = 50  # 20MP needs aggressive compression
                        elif pixels > 3_000_000:  # > Full HD
                            quality = 55  # 2K, 4K
                        else:
                            quality = self.server.jpeg_quality  # VGA, HD, Full HD
                        
                        encode_params = [cv2.IMWRITE_JPEG_QUALITY, quality]
                        success, jpeg = cv2.imencode('.jpg', frame, encode_params)
                        
                        if success:
                            self.server.current_frame_jpeg = jpeg.tobytes()
                            self.server.frame_count += 1
                    except Exception as e:
                        logger.error(f"❌ Frame processing error: {e}")
            
            self.listener = FrameListener(self)
            self.sink = ic4.QueueSink(self.listener, max_output_buffers=1)
            self.grabber.stream_setup(self.sink, setup_option=ic4.StreamSetupOption.ACQUISITION_START)
            
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
            # Generate simple test pattern at target resolution
            import numpy as np
            frame = np.zeros((self.target_height, self.target_width, 3), dtype=np.uint8)
            
            # NOTE: Text overlays removed - display will show clean frame only
        else:
            # Resize loaded image to target resolution
            frame = cv2.resize(
                frame, 
                (self.target_width, self.target_height),
                interpolation=cv2.INTER_LINEAR
            )
        
        # Rotate frame 180 degrees
        frame = cv2.rotate(frame, cv2.ROTATE_180)
        
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
                # Generate mock frame if needed (QueueSink listener handles real camera)
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
    
    async def handle_client(self, websocket):
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
                        msg_type = data.get("type")
                        command = data.get("command")
                        
                        if msg_type == "change_resolution":
                            # Change camera capture resolution (restart stream)
                            new_width = data.get("width", 1920)
                            new_height = data.get("height", 1080)
                            
                            logger.info(f"📐 Changing camera resolution to {new_width}x{new_height}...")
                            
                            try:
                                # Stop current stream
                                if self.grabber and not self.use_mock:
                                    try:
                                        self.grabber.stream_stop()
                                        logger.info("⏸️  Stream stopped")
                                    except Exception as e:
                                        logger.warning(f"⚠️  Stream stop warning: {e}")
                                    
                                    # Update camera resolution
                                    self.width = new_width
                                    self.height = new_height
                                    self.target_width = new_width
                                    self.target_height = new_height
                                    
                                    # Reconfigure camera
                                    prop_map = self.grabber.device_property_map
                                    
                                    if prop_map.find(ic4.PropId.WIDTH):
                                        prop_map.set_value(ic4.PropId.WIDTH, self.width)
                                    if prop_map.find(ic4.PropId.HEIGHT):
                                        prop_map.set_value(ic4.PropId.HEIGHT, self.height)
                                    
                                    logger.info(f"📐 Camera reconfigured: {self.width}x{self.height}")
                                    
                                    # Restart stream
                                    self.grabber.stream_setup(
                                        self.sink, 
                                        setup_option=ic4.StreamSetupOption.ACQUISITION_START
                                    )
                                    logger.info("▶️  Stream restarted")
                                else:
                                    # Mock camera - just update resolution
                                    self.width = new_width
                                    self.height = new_height
                                    self.target_width = new_width
                                    self.target_height = new_height
                                    logger.info(f"📐 Mock camera resolution updated: {new_width}x{new_height}")
                                
                                await websocket.send(json.dumps({
                                    "type": "resolution_changed",
                                    "width": new_width,
                                    "height": new_height,
                                    "success": True
                                }))
                            except Exception as e:
                                logger.error(f"❌ Failed to change resolution: {e}")
                                await websocket.send(json.dumps({
                                    "type": "resolution_changed",
                                    "width": self.width,
                                    "height": self.height,
                                    "success": False,
                                    "error": str(e)
                                }))
                        elif command == "stop":
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
