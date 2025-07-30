"""
Configuration settings for AutoVRS Backend
"""
from pydantic_settings import BaseSettings
from pydantic import ConfigDict, Field
from typing import List
import os


class Settings(BaseSettings):
    """Application settings loaded from environment variables"""
    
    # Security
    secret_key: str = "your-secret-key-change-in-production"
    access_token_expire_minutes: int = 30
    
    class Config:
        env_file = ".env"
        case_sensitive = False
        protected_namespaces = ('settings_',)
    debug: bool = True
    host: str = "0.0.0.0"
    port: int = 8000
    websocket_port: int = 8001
    log_level: str = "INFO"
    
    # Camera Configuration
    camera_index: int = 0
    camera_width: int = 640
    camera_height: int = 480
    camera_fps: int = 30
    
    # AI Model Configuration
    vrs_model_path: str = "../best.onnx"  # Changed from model_path to avoid conflict
    confidence_threshold: float = 0.5
    iou_threshold: float = 0.4
    
    # Database Configuration
    database_url: str = "sqlite:///./autovrs.db"
    
    # File Storage
    captures_dir: str = "./captures"
    max_capture_size_mb: int = 10
    supported_image_formats: List[str] = Field(default=["jpg", "jpeg", "png", "bmp"])
    
    # WebSocket Configuration
    ws_heartbeat_interval: int = 30
    ws_max_connections: int = 10
    
    # Security
    secret_key: str = "your-secret-key-change-in-production"
    access_token_expire_minutes: int = 30

    def get_full_model_path(self) -> str:
        """Get full path to the AI model"""
        if os.path.isabs(self.vrs_model_path):
            return self.vrs_model_path
        return os.path.join(os.path.dirname(__file__), "..", self.vrs_model_path)
    
    def get_full_captures_dir(self) -> str:
        """Get full path to captures directory"""
        if os.path.isabs(self.captures_dir):
            return self.captures_dir
        return os.path.join(os.path.dirname(__file__), "..", self.captures_dir)


# Global settings instance
settings = Settings()
