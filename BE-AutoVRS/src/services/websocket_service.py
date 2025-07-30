"""
WebSocket Service for AutoVRS
Handles real-time communication with Flutter frontend
"""

import asyncio
import json
import time
from typing import Dict, Set, Any, Optional
from fastapi import WebSocket, WebSocketDisconnect
from loguru import logger
from .camera_service import camera_service


class WebSocketManager:
    """Manages WebSocket connections and broadcasting"""
    
    def __init__(self):
        self.active_connections: Set[WebSocket] = set()
        self.is_streaming = False
        self.stream_task = None
        
    async def connect(self, websocket: WebSocket, client_id: str):
        """Accept new WebSocket connection"""
        await websocket.accept()
        self.active_connections.add(websocket)
        logger.info(f"Client {client_id} connected. Total connections: {len(self.active_connections)}")
        
        # Send welcome message
        await self.send_personal_message({
            "type": "connection",
            "status": "connected",
            "client_id": client_id,
            "server_time": time.time(),
            "camera_status": "initializing"
        }, websocket)
        
        # Auto-start streaming for any connection
        if not self.is_streaming:
            await self.start_streaming()
            logger.info("Auto-started streaming for new connection")
    
    def disconnect(self, websocket: WebSocket, client_id: str):
        """Remove WebSocket connection"""
        self.active_connections.discard(websocket)
        logger.info(f"Client {client_id} disconnected. Total connections: {len(self.active_connections)}")
        
        # Stop streaming if no connections left
        if len(self.active_connections) == 0:
            asyncio.create_task(self.stop_streaming())
    
    async def send_personal_message(self, message: Dict[str, Any], websocket: WebSocket):
        """Send message to specific client"""
        try:
            await websocket.send_text(json.dumps(message))
        except Exception as e:
            logger.error(f"Error sending personal message: {e}")
    
    async def broadcast(self, message: Dict[str, Any]):
        """Broadcast message to all connected clients"""
        if not self.active_connections:
            return
        
        message_text = json.dumps(message)
        disconnected = set()
        
        for websocket in self.active_connections.copy():
            try:
                await websocket.send_text(message_text)
            except Exception as e:
                logger.error(f"Error broadcasting to client: {e}")
                disconnected.add(websocket)
        
        # Remove disconnected clients
        for websocket in disconnected:
            self.active_connections.discard(websocket)
    
    async def start_streaming(self):
        """Start streaming camera frames"""
        if self.is_streaming:
            return
        
        self.is_streaming = True
        self.stream_task = asyncio.create_task(self._stream_loop())
        logger.info("WebSocket streaming started")
    
    async def stop_streaming(self):
        """Stop streaming camera frames"""
        if not self.is_streaming:
            return
        
        self.is_streaming = False
        if self.stream_task:
            self.stream_task.cancel()
            try:
                await self.stream_task
            except asyncio.CancelledError:
                pass
        
        logger.info("WebSocket streaming stopped")
    
    async def _stream_loop(self):
        """Main streaming loop"""
        try:
            camera_wait_count = 0
            while self.is_streaming and self.active_connections:
                # Get current frame from camera
                frame = camera_service.get_current_frame()
                
                if frame is not None:
                    camera_wait_count = 0  # Reset wait counter
                    # Convert to square format
                    square_frame = camera_service.resize_to_square(frame, 640)
                    
                    # Convert to base64
                    frame_base64 = camera_service.frame_to_base64(square_frame, quality=75)
                    
                    if frame_base64:
                        # Prepare message
                        message = {
                            "type": "video_frame",
                            "data": frame_base64,
                            "timestamp": time.time(),
                            "frame_info": camera_service.get_frame_info()
                        }
                        
                        # Broadcast to all clients
                        await self.broadcast(message)
                else:
                    # Camera not ready, send waiting message
                    camera_wait_count += 1
                    if camera_wait_count % 10 == 1:  # Send message every 1 second
                        waiting_message = {
                            "type": "camera_status",
                            "status": "waiting",
                            "message": "Đang khởi tạo camera...",
                            "timestamp": time.time()
                        }
                        await self.broadcast(waiting_message)
                
                # Control streaming rate (10 FPS for WebSocket)
                await asyncio.sleep(0.1)
                
        except asyncio.CancelledError:
            logger.info("Streaming loop cancelled")
        except Exception as e:
            logger.error(f"Error in streaming loop: {e}")
    
    async def handle_message(self, websocket: WebSocket, client_id: str, message: str):
        """Handle incoming WebSocket messages"""
        try:
            data = json.loads(message)
            message_type = data.get("type")
            
            if message_type == "capture_image":
                await self._handle_capture_request(websocket, client_id, data)
            elif message_type == "get_status":
                await self._handle_status_request(websocket, client_id)
            elif message_type == "ping":
                await self._handle_ping(websocket, client_id, data)
            elif message_type == "set_detection":
                await self._handle_detection_setting(websocket, client_id, data)
            else:
                logger.warning(f"Unknown message type: {message_type}")
                
        except json.JSONDecodeError:
            logger.error(f"Invalid JSON from client {client_id}: {message}")
        except Exception as e:
            logger.error(f"Error handling message from {client_id}: {e}")
    
    async def _handle_capture_request(self, websocket: WebSocket, client_id: str, data: Dict[str, Any]):
        """Handle image capture request with defect detection"""
        try:
            filename = data.get("filename")
            enable_detection = data.get("enable_detection", True)  # Default to True
            
            # Use new capture method that returns dictionary
            if enable_detection and camera_service.is_detection_available():
                capture_result = camera_service.capture_with_detection_analysis(filename)
            else:
                capture_result = camera_service.capture_image(filename, apply_detection=False)
            
            response = {
                "type": "capture_response",
                "request_id": data.get("request_id"),
                "success": capture_result["success"],
                "message": capture_result["message"],
                "filepath": capture_result["filepath"],
                "image_data": capture_result["base64_image"],
                "detection_results": capture_result.get("detection_results"),
                "analysis": capture_result.get("analysis"),
                "timestamp": time.time()
            }
            
            await self.send_personal_message(response, websocket)
            
            # Log with detection info
            if capture_result.get("detection_results"):
                num_defects = len(capture_result["detection_results"].get("detections", []))
                logger.info(f"Capture request from {client_id}: {capture_result['message']} - {num_defects} defects detected")
            else:
                logger.info(f"Capture request from {client_id}: {capture_result['message']}")
            
        except Exception as e:
            error_response = {
                "type": "capture_response",
                "request_id": data.get("request_id"),
                "success": False,
                "message": f"Capture error: {str(e)}",
                "timestamp": time.time()
            }
            await self.send_personal_message(error_response, websocket)
    
    async def _handle_status_request(self, websocket: WebSocket, client_id: str):
        """Handle status request"""
        try:
            status = {
                "type": "status_response",
                "camera_info": camera_service.get_frame_info(),
                "detection_status": camera_service.get_detection_status(),
                "connections": len(self.active_connections),
                "streaming": self.is_streaming,
                "server_time": time.time()
            }
            
            await self.send_personal_message(status, websocket)
            
        except Exception as e:
            logger.error(f"Error handling status request: {e}")
    
    async def _handle_ping(self, websocket: WebSocket, client_id: str, data: Dict[str, Any]):
        """Handle ping message"""
        try:
            pong = {
                "type": "pong",
                "timestamp": time.time(),
                "client_timestamp": data.get("timestamp"),
                "client_id": client_id
            }
            
            await self.send_personal_message(pong, websocket)
            
        except Exception as e:
            logger.error(f"Error handling ping: {e}")
    
    async def _handle_detection_setting(self, websocket: WebSocket, client_id: str, data: Dict[str, Any]):
        """Handle defect detection enable/disable setting"""
        try:
            enabled = data.get("enabled", True)
            camera_service.set_detection_enabled(enabled)
            
            response = {
                "type": "detection_setting_response",
                "request_id": data.get("request_id"),
                "success": True,
                "enabled": enabled,
                "detection_status": camera_service.get_detection_status(),
                "message": f"Defect detection {'enabled' if enabled else 'disabled'}",
                "timestamp": time.time()
            }
            
            await self.send_personal_message(response, websocket)
            logger.info(f"Detection setting changed by {client_id}: {'enabled' if enabled else 'disabled'}")
            
        except Exception as e:
            error_response = {
                "type": "detection_setting_response",
                "request_id": data.get("request_id"),
                "success": False,
                "message": f"Error changing detection setting: {str(e)}",
                "timestamp": time.time()
            }
            await self.send_personal_message(error_response, websocket)
            logger.error(f"Error handling detection setting: {e}")


# Global WebSocket manager instance
websocket_manager = WebSocketManager()
