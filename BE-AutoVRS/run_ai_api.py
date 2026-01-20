
import uvicorn
import os
import sys

# Import config để kiểm tra models
sys.path.insert(0, os.path.dirname(os.path.abspath(__file__)))
try:
    import config_ai
except ImportError:
    pass

if __name__ == "__main__":
    # Kiểm tra model files
    print("🔍 Kiểm tra models...")
    
    if os.path.exists(config_ai.MULTICLASS_MODEL):
        print(f"✅ Multiclass model: {config_ai.MULTICLASS_MODEL}")
    else:
        print(f"⚠️ Multiclass model không tồn tại: {config_ai.MULTICLASS_MODEL}")
    
    print(f"✅ Đã load {len(config_ai.SINGLE_ENGINE_PATHS)} single-class models")
    
    print("\n🤖 Starting AutoVRS AI Detection API...")
    print("📋 API Documentation: http://localhost:8082/docs")
    print("🔧 Health Check: http://localhost:8082/health")
    print("🛑 Press Ctrl+C to stop\n")
    
    # Dùng reload=False để tránh khởi tạo FastAPI 2 lần
    # Chỉ dùng reload=True khi develop (cần tự restart manual)
    uvicorn.run(
        "ai_detection_api:app",
        host="0.0.0.0",
        port=8082,
        reload=False,  # ✅ Tắt reload để log không bị duplicate
        log_level="info"
    )
