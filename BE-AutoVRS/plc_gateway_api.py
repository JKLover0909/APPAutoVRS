"""
PLC Gateway API - REST API for AutoVRS + PLC + Camera + AI Integration

Workflow:
1. Flutter gửi defect coordinates
2. Gửi tọa độ đến PLC Omron (X, Y, Trigger)
3. Đợi PLC di chuyển camera (timeout cố định)
4. Capture ảnh từ SICK camera (snap_single)
5. Gửi ảnh đến AI Detection API
6. Trả kết quả về Flutter

Port: 8083
"""

from fastapi import FastAPI, HTTPException
from fastapi.middleware.cors import CORSMiddleware
from pydantic import BaseModel
from typing import Optional, Dict, Any
import cv2
import numpy as np
import base64
import time
import asyncio
import logging
import traceback
import requests
import os
import sys

# PLC Communication
PLC_AVAILABLE = False
OmronConnection = None

try:
    import clr
    
    # Build full path to ClassLibrary.dll
    BASE_DIR = os.path.dirname(os.path.abspath(__file__))
    DLL_PATH = os.path.join(BASE_DIR, "ClassLibrary.dll")
    
    if not os.path.isfile(DLL_PATH):
        print(f"⚠️  WARNING: ClassLibrary.dll not found at: {DLL_PATH}")
        print("   Build the project and copy the DLL to BE-AutoVRS folder.")
    else:
        # Load DLL with full path
        clr.AddReference(DLL_PATH)
        from ClassLibrary.PLC.Omron import OmronConnection
        PLC_AVAILABLE = True
        print(f"✅ PLC DLL loaded successfully from: {DLL_PATH}")
        
except ImportError:
    print("⚠️  WARNING: pythonnet not installed. Install with: pip install pythonnet")
except Exception as e:
    print(f"⚠️  WARNING: PLC DLL not available: {e}")

# SICK Camera
try:
    import imagingcontrol4 as ic4
    IC4_AVAILABLE = True
except ImportError:
    print("⚠️  WARNING: imagingcontrol4 not installed. Camera capture disabled.")
    IC4_AVAILABLE = False

# ===============================
# Logging
# ===============================
logging.basicConfig(level=logging.INFO, format="%(asctime)s [%(levelname)s] %(message)s")
logger = logging.getLogger("PLCGateway")

# ===============================
# FastAPI app
# ===============================
app = FastAPI(title="PLC Gateway API", version="1.0.0")
app.add_middleware(
    CORSMiddleware,
    allow_origins=["*"],
    allow_credentials=True,
    allow_methods=["*"],
    allow_headers=["*"],
)

# ===============================
# Request/Response Models
# ===============================
class InspectDefectRequest(BaseModel):
    """Request to inspect a defect"""
    defect_x: float          # X coordinate (pixel)
    defect_y: float          # Y coordinate (pixel)
    board_id: Optional[str] = None
    defect_id: Optional[int] = None
    
    # PLC Configuration
    plc_pc_ip: str = "192.168.3.101"
    plc_ip: str = "192.168.3.1"
    plc_port: int = 9600
    plc_mem_area: str = "D"
    plc_x_addr: int = 2810
    plc_y_addr: int = 2910
    plc_trigger_addr: int = 3000
    
    # Wait time (milliseconds)
    plc_move_timeout_ms: int = 2000  # Đợi PLC di chuyển 2 giây
    
    # AI Configuration
    ai_confidence_threshold: float = 0.25
    ai_api_url: str = "http://localhost:8082/api/ai-detection"


class MoveRequest(BaseModel):
    """Simple request to move camera to coordinates (WebSocket coordinator use)"""
    x: float  # X coordinate (mm from Gerber)
    y: float  # Y coordinate (mm from Gerber)
    board_id: Optional[int] = None
    defect_id: Optional[int] = None


class MoveResponse(BaseModel):
    """Response after moving camera"""
    success: bool
    message: str
    plc_x: Optional[float] = None  # PLC coordinate (x10)
    plc_y: Optional[float] = None  # PLC coordinate (x10)
    elapsed_seconds: Optional[float] = None


class InspectDefectResponse(BaseModel):
    """Response after inspection"""
    success: bool
    message: str
    step: str  # "plc_sent", "camera_captured", "ai_detected", "completed", "error"
    
    # Coordinates sent to PLC
    plc_coords: Optional[Dict[str, float]] = None
    
    # Captured image info
    image_captured: bool = False
    image_base64: Optional[str] = None  # For debugging
    
    # AI Detection results
    ai_detections: Optional[list] = None
    ai_verdict: Optional[str] = None
    ai_statistics: Optional[Dict[str, Any]] = None
    
    # Timing
    timing: Optional[Dict[str, float]] = None
    error_details: Optional[str] = None


# ===============================
# PLC Service
# ===============================
class PLCService:
    """Service for PLC communication"""
    
    def __init__(self):
        self.connection = None
    
    def connect(self, pc_ip: str, plc_ip: str, port: int) -> bool:
        """Connect to PLC"""
        if not PLC_AVAILABLE:
            logger.warning("⚠️  PLC DLL not available, using mock mode")
            return True  # Mock success
        
        try:
            self.connection = OmronConnection(pc_ip, plc_ip, port)
            logger.info(f"✅ Connected to PLC: {plc_ip}:{port}")
            return True
        except Exception as e:
            logger.error(f"❌ PLC connection failed: {e}")
            return False
    
    def send_coordinates(
        self,
        mem_area: str,
        x_addr: int,
        y_addr: int,
        trigger_addr: int,
        x_val: float,
        y_val: float
    ) -> bool:
        """Send coordinates to PLC"""
        if not PLC_AVAILABLE or self.connection is None:
            logger.info(f"🔧 [MOCK] Would send: X={x_val}, Y={y_val}")
            return True
        
        try:
            # Write X coordinate
            ok_x = self.connection.WriteFloat(mem_area, x_addr, str(x_val))
            
            # Write Y coordinate
            ok_y = self.connection.WriteFloat(mem_area, y_addr, str(y_val))
            
            # Write trigger = 1
            ok_trigger = self.connection.WriteInt(mem_area, trigger_addr, "1")
            
            # Small delay
            time.sleep(0.05)
            
            # Reset trigger = 0
            self.connection.WriteInt(mem_area, trigger_addr, "0")
            
            logger.info(f"✅ PLC write OK: X={ok_x}, Y={ok_y}, Trigger={ok_trigger}")
            return ok_x and ok_y and ok_trigger
        
        except Exception as e:
            logger.error(f"❌ PLC write failed: {e}")
            return False
    
    def close(self):
        """Close PLC connection"""
        if self.connection:
            try:
                self.connection.Close()
                logger.info("🔌 PLC connection closed")
            except:
                pass


# ===============================
# Camera Service
# ===============================
class CameraService:
    """Service for SICK camera capture"""
    
    def __init__(self):
        self.grabber = None
        self.sink = None
        self.initialized = False
    
    def initialize(self) -> bool:
        """Initialize camera"""
        if not IC4_AVAILABLE:
            logger.warning("⚠️  IC4 not available, using mock camera")
            self.initialized = True
            return True
        
        try:
            # Initialize IC4
            ic4.Library.init()
            
            # Get devices
            devices = ic4.DeviceEnum.devices()
            if not devices:
                raise Exception("No camera found")
            
            device = devices[0]
            logger.info(f"📷 Using camera: {device.model_name}")
            
            # Setup grabber
            self.grabber = ic4.Grabber()
            self.grabber.device_open(device)
            
            # Setup sink for snap_single
            self.sink = ic4.SnapSink()
            self.grabber.stream_setup(self.sink)
            
            self.initialized = True
            logger.info("✅ Camera initialized")
            return True
            
        except Exception as e:
            logger.error(f"❌ Camera initialization failed: {e}")
            logger.info("🔄 Using mock camera")
            self.initialized = True
            return True
    
    def capture_frame(self, timeout_ms: int = 1000) -> Optional[np.ndarray]:
        """Capture single frame"""
        if not IC4_AVAILABLE or self.grabber is None:
            # Mock frame
            logger.info("🔧 [MOCK] Generating test frame")
            frame = np.zeros((480, 640, 3), dtype=np.uint8)
            cv2.putText(frame, "MOCK CAMERA", (200, 240), 
                       cv2.FONT_HERSHEY_SIMPLEX, 1, (0, 255, 0), 2)
            return frame
        
        try:
            # Capture using snap_single
            image = self.sink.snap_single(timeout_ms)
            
            logger.info(f"📸 Captured image: {image.image_type}")
            
            # Convert to numpy array (OpenCV BGR format)
            frame = image.numpy_wrap()
            
            # Optional: save for debugging
            # image.save_as_bmp("last_capture.bmp")
            
            return frame
            
        except Exception as e:
            logger.error(f"❌ Camera capture failed: {e}")
            return None
    
    def cleanup(self):
        """Cleanup camera resources"""
        if self.grabber:
            try:
                self.grabber.stream_stop()
            except:
                pass
        
        if IC4_AVAILABLE:
            try:
                ic4.Library.exit()
            except:
                pass


# ===============================
# AI Service Client
# ===============================
class AIServiceClient:
    """Client for AI Detection API"""
    
    @staticmethod
    def detect(image_bgr: np.ndarray, confidence_threshold: float, api_url: str) -> Optional[Dict]:
        """Send image to AI API and get detections"""
        try:
            # Encode image to base64
            success, jpeg = cv2.imencode('.jpg', image_bgr)
            if not success:
                raise Exception("Failed to encode image")
            
            image_base64 = base64.b64encode(jpeg.tobytes()).decode('utf-8')
            
            # Send request
            logger.info(f"🤖 Sending to AI API: {api_url}")
            response = requests.post(
                api_url,
                json={
                    "image_base64": image_base64,
                    "confidence_threshold": confidence_threshold
                },
                timeout=30
            )
            
            if response.status_code != 200:
                raise Exception(f"AI API error: {response.status_code}")
            
            result = response.json()
            logger.info(f"✅ AI detected {len(result.get('detections', []))} defects")
            
            return result
            
        except Exception as e:
            logger.error(f"❌ AI detection failed: {e}")
            return None


# ===============================
# Global Services
# ===============================
plc_service = PLCService()
# camera_service = CameraService()  # Disabled: Camera handled by run_sick_camera.py (port 8999)


# ===============================
# API Endpoints
# ===============================
@app.on_event("startup")
async def startup_event():
    """Initialize services on startup"""
    logger.info("=" * 60)
    logger.info("🚀 PLC Gateway API Starting...")
    logger.info("=" * 60)
    
    # Initialize camera - DISABLED to avoid conflict with run_sick_camera.py
    # camera_service.initialize()
    logger.info("⚠️  Camera service disabled (run_sick_camera.py handles camera)")
    
    logger.info("✅ Services ready")


@app.on_event("shutdown")
async def shutdown_event():
    """Cleanup on shutdown"""
    logger.info("🛑 Shutting down...")
    plc_service.close()
    # camera_service.cleanup()  # Disabled


@app.get("/")
async def root():
    """Health check"""
    return {
        "service": "PLC Gateway API",
        "status": "running",
        "plc_available": PLC_AVAILABLE,
        "camera_available": IC4_AVAILABLE
    }


@app.post("/api/inspect-defect", response_model=InspectDefectResponse)
async def inspect_defect(request: InspectDefectRequest):
    """
    Main endpoint: Send coordinates to PLC, capture image, run AI detection
    """
    timing = {}
    start_time = time.time()
    
    try:
        logger.info("=" * 60)
        logger.info(f"🔍 Inspecting defect at ({request.defect_x}, {request.defect_y})")
        
        # Step 1: Connect to PLC
        logger.info("📡 Step 1: Connecting to PLC...")
        step1_start = time.time()
        
        if not plc_service.connect(request.plc_pc_ip, request.plc_ip, request.plc_port):
            raise Exception("Failed to connect to PLC")
        
        timing["plc_connect"] = time.time() - step1_start
        
        # Step 2: Send coordinates to PLC
        logger.info("📤 Step 2: Sending coordinates to PLC...")
        step2_start = time.time()
        
        if not plc_service.send_coordinates(
            request.plc_mem_area,
            request.plc_x_addr,
            request.plc_y_addr,
            request.plc_trigger_addr,
            request.defect_x,
            request.defect_y
        ):
            raise Exception("Failed to send coordinates to PLC")
        
        timing["plc_send"] = time.time() - step2_start
        
        # Step 3: Wait for PLC to move camera
        logger.info(f"⏳ Step 3: Waiting {request.plc_move_timeout_ms}ms for PLC movement...")
        await asyncio.sleep(request.plc_move_timeout_ms / 1000.0)
        timing["plc_wait"] = request.plc_move_timeout_ms / 1000.0
        
        # Step 4: Capture image
        logger.info("📸 Step 4: Capturing image from camera...")
        step4_start = time.time()
        
        frame = camera_service.capture_frame(timeout_ms=1000)
        if frame is None:
            raise Exception("Failed to capture image")
        
        timing["camera_capture"] = time.time() - step4_start
        
        # Step 5: Send to AI API
        logger.info("🤖 Step 5: Sending to AI Detection API...")
        step5_start = time.time()
        
        ai_result = AIServiceClient.detect(
            frame,
            request.ai_confidence_threshold,
            request.ai_api_url
        )
        
        if ai_result is None:
            raise Exception("AI detection failed")
        
        timing["ai_detection"] = time.time() - step5_start
        timing["total"] = time.time() - start_time
        
        # Step 6: Return results
        logger.info("✅ Inspection completed successfully!")
        logger.info(f"⏱️  Total time: {timing['total']:.2f}s")
        
        # Optional: encode image for response (debugging)
        success, jpeg = cv2.imencode('.jpg', frame)
        image_base64 = base64.b64encode(jpeg.tobytes()).decode('utf-8') if success else None
        
        return InspectDefectResponse(
            success=True,
            message="Inspection completed successfully",
            step="completed",
            plc_coords={"x": request.defect_x, "y": request.defect_y},
            image_captured=True,
            image_base64=image_base64,  # Include for debugging (can be large)
            ai_detections=ai_result.get("detections", []),
            ai_verdict=ai_result.get("statistics", {}).get("system_verdict", "UNKNOWN"),
            ai_statistics=ai_result.get("statistics", {}),
            timing=timing
        )
        
    except Exception as e:
        logger.error(f"❌ Inspection failed: {e}")
        logger.error(traceback.format_exc())
        
        return InspectDefectResponse(
            success=False,
            message=f"Inspection failed: {str(e)}",
            step="error",
            error_details=traceback.format_exc(),
            timing=timing
        )
    
    finally:
        # Cleanup PLC connection
        plc_service.close()


@app.get("/api/test-plc")
async def test_plc():
    """Test PLC connection only"""
    try:
        if plc_service.connect("192.168.3.101", "192.168.3.1", 9600):
            plc_service.close()
            return {"success": True, "message": "PLC connection OK"}
        else:
            return {"success": False, "message": "PLC connection failed"}
    except Exception as e:
        return {"success": False, "message": str(e)}


# @app.get("/api/test-camera")  # Disabled: Camera handled by run_sick_camera.py
# async def test_camera():
#     """Test camera capture only"""
#     try:
#         frame = camera_service.capture_frame()
#         if frame is not None:
#             return {
#                 "success": True,
#                 "message": "Camera capture OK",
#                 "shape": frame.shape
#             }
#         else:
#             return {"success": False, "message": "Camera capture failed"}
#     except Exception as e:
#         return {"success": False, "message": str(e)}


@app.post("/api/plc/move", response_model=MoveResponse)
async def move_camera_simple(request: MoveRequest):
    """
    Simple endpoint to move camera to coordinates (for WebSocket coordinator)
    
    Workflow:
    1. Receive Gerber coordinates (mm)
    2. Multiply by 10 for PLC coordinate system
    3. Write to PLC registers
    4. Wait 10 seconds
    5. Return success
    
    Request:
        {
            "x": 150.5,
            "y": 250.3,
            "board_id": 1003,
            "defect_id": 5
        }
    
    Response:
        {
            "success": true,
            "message": "Camera moved to position (1505.0, 2503.0)",
            "plc_x": 1505.0,
            "plc_y": 2503.0,
            "elapsed_seconds": 10.2
        }
    """
    logger.info(f"\n{'='*60}")
    logger.info(f"📥 Move request received:")
    if request.board_id:
        logger.info(f"   Board ID: {request.board_id}")
    if request.defect_id:
        logger.info(f"   Defect ID: {request.defect_id}")
    logger.info(f"   Gerber coords: X={request.x:.3f}mm, Y={request.y:.3f}mm")
    
    # PLC Configuration (default)
    PLC_CONFIG = {
        "pc_ip": "192.168.3.101",
        "plc_ip": "192.168.3.1",
        "port": 9600,
        "mem_area": "D",
        "x_addr": 2810,
        "y_addr": 2910,
        "trigger_addr": 3000,
        "coord_multiplier": 10.0,
        "wait_seconds": 10.0,
    }
    
    plc = PLCService()
    
    try:
        # Step 1: Connect to PLC
        logger.info("🔌 Connecting to PLC...")
        if not plc.connect(PLC_CONFIG["pc_ip"], PLC_CONFIG["plc_ip"], PLC_CONFIG["port"]):
            raise HTTPException(status_code=500, detail="Failed to connect to PLC")
        
        # Step 2: Use PLC coordinates directly (already scaled in plc_coor column)
        plc_x = request.x
        plc_y = request.y
        
        logger.info(f"📍 PLC coords: X={plc_x:.1f}, Y={plc_y:.1f} (from plc_coor column)")
        
        # Step 3: Write to PLC
        logger.info("✍️  Writing coordinates to PLC...")
        success = plc.send_coordinates(
            mem_area=PLC_CONFIG["mem_area"],
            x_addr=PLC_CONFIG["x_addr"],
            y_addr=PLC_CONFIG["y_addr"],
            trigger_addr=PLC_CONFIG["trigger_addr"],
            x_val=plc_x,
            y_val=plc_y
        )
        
        if not success:
            raise HTTPException(status_code=500, detail="Failed to write coordinates to PLC")
        
        # Step 4: Wait for PLC to complete movement
        logger.info(f"⏳ Waiting {PLC_CONFIG['wait_seconds']}s for PLC movement...")
        start_time = time.time()
        time.sleep(PLC_CONFIG["wait_seconds"])
        elapsed = time.time() - start_time
        
        logger.info(f"✅ PLC movement completed in {elapsed:.1f}s")
        logger.info(f"{'='*60}\n")
        
        return MoveResponse(
            success=True,
            message=f"Camera moved to position ({plc_x:.1f}, {plc_y:.1f})",
            plc_x=plc_x,
            plc_y=plc_y,
            elapsed_seconds=elapsed
        )
        
    except HTTPException:
        raise
    except Exception as e:
        logger.error(f"❌ Move camera failed: {e}")
        logger.error(traceback.format_exc())
        raise HTTPException(status_code=500, detail=str(e))
    
    finally:
        plc.close()


# ===============================
# Main
# ===============================
if __name__ == "__main__":
    import uvicorn
    
    print("=" * 60)
    print("🚀 Starting PLC Gateway API")
    print("=" * 60)
    print("📡 URL: http://localhost:8083")
    print("📚 Docs: http://localhost:8083/docs")
    print("=" * 60)
    
    uvicorn.run(app, host="0.0.0.0", port=8083, log_level="info")
