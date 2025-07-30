"""
Main FastAPI application for AutoVRS Backend
"""

import asyncio
from contextlib import asynccontextmanager
from fastapi import FastAPI, WebSocket, WebSocketDisconnect, HTTPException
from fastapi.middleware.cors import CORSMiddleware
from fastapi.responses import JSONResponse
from typing import Optional
import uvicorn
from loguru import logger
import sys
import os

# Add src to path
sys.path.append(os.path.join(os.path.dirname(__file__), 'src'))

from config.settings import settings
from src.services import camera_service, websocket_manager


@asynccontextmanager
async def lifespan(app: FastAPI):
    """Application lifespan events"""
    # Startup
    logger.info("Starting AutoVRS Backend...")
    
    # Initialize camera
    camera_initialized = await camera_service.initialize()
    if not camera_initialized:
        logger.error("Failed to initialize camera")
        raise RuntimeError("Camera initialization failed")
    
    # Start camera capture
    camera_service.start_capture()
    logger.info("AutoVRS Backend started successfully")
    
    yield
    
    # Shutdown
    logger.info("Shutting down AutoVRS Backend...")
    await camera_service.cleanup()
    await websocket_manager.stop_streaming()
    logger.info("AutoVRS Backend shutdown complete")


# Create FastAPI app
app = FastAPI(
    title="AutoVRS Backend",
    description="Backend service for Automatic Visual Reference System",
    version="1.0.0",
    lifespan=lifespan
)

# Add CORS middleware
app.add_middleware(
    CORSMiddleware,
    allow_origins=["*"],  # In production, specify exact origins
    allow_credentials=True,
    allow_methods=["*"],
    allow_headers=["*"],
)


# Health check endpoint
@app.get("/")
async def root():
    """Root endpoint for health check"""
    return {
        "message": "AutoVRS Backend API",
        "version": "1.0.0",
        "status": "running",
        "camera_status": "active" if camera_service.is_running else "inactive"
    }


@app.get("/health")
async def health_check():
    """Detailed health check"""
    try:
        camera_info = camera_service.get_frame_info()
        return {
            "status": "healthy",
            "timestamp": camera_info.get("last_update", 0),
            "camera": camera_info,
            "websocket_connections": len(websocket_manager.active_connections),
            "settings": {
                "camera_resolution": f"{settings.camera_width}x{settings.camera_height}",
                "camera_fps": settings.camera_fps,
                "model_path": settings.model_path
            }
        }
    except Exception as e:
        logger.error(f"Health check failed: {e}")
        raise HTTPException(status_code=500, detail=str(e))


@app.get("/camera/info")
async def get_camera_info():
    """Get camera information"""
    try:
        return camera_service.get_frame_info()
    except Exception as e:
        logger.error(f"Failed to get camera info: {e}")
        raise HTTPException(status_code=500, detail=str(e))


@app.post("/camera/capture")
async def capture_image(filename: Optional[str] = None):
    """Capture an image from camera with defect detection"""
    try:
        result = camera_service.capture_with_detection_analysis(filename)
        
        if result["success"]:
            return {
                "success": True,
                "message": result["message"],
                "filepath": result["filepath"],
                "detection_results": result.get("detection_results"),
                "analysis": result.get("analysis")
            }
        else:
            raise HTTPException(status_code=500, detail=result["message"])
            
    except Exception as e:
        logger.error(f"Capture failed: {e}")
        raise HTTPException(status_code=500, detail=str(e))


@app.websocket("/ws/{client_id}")
async def websocket_endpoint(websocket: WebSocket, client_id: str):
    """WebSocket endpoint for real-time communication"""
    await websocket_manager.connect(websocket, client_id)
    
    try:
        while True:
            # Receive messages from client
            message = await websocket.receive_text()
            await websocket_manager.handle_message(websocket, client_id, message)
            
    except WebSocketDisconnect:
        websocket_manager.disconnect(websocket, client_id)
    except Exception as e:
        logger.error(f"WebSocket error for client {client_id}: {e}")
        websocket_manager.disconnect(websocket, client_id)


@app.get("/ws/status")
async def websocket_status():
    """Get WebSocket connection status"""
    return {
        "active_connections": len(websocket_manager.active_connections),
        "streaming": websocket_manager.is_streaming
    }


if __name__ == "__main__":
    # Configure logging
    logger.remove()
    logger.add(
        sys.stderr,
        level=settings.log_level,
        format="<green>{time:YYYY-MM-DD HH:mm:ss}</green> | <level>{level}</level> | <cyan>{name}</cyan>:<cyan>{function}</cyan>:<cyan>{line}</cyan> - <level>{message}</level>"
    )
    
    logger.info(f"Starting server on {settings.host}:{settings.port}")
    
    # Run the server
    uvicorn.run(
        "main:app",
        host=settings.host,
        port=settings.port,
        reload=settings.debug,
        log_level=settings.log_level.lower()
    )
