
import uvicorn
import os

if __name__ == "__main__":
    # Kiểm tra model file
    model_path = "best.onnx"
    if not os.path.exists(model_path):
        print(f"❌ Model file không tồn tại: {model_path}")
        print("📁 Vui lòng copy file best.onnx vào thư mục BE-AutoVRS")
        print("🔄 Tiếp tục chạy API mà không có model...")
    
    print("🤖 Starting AutoVRS AI Detection API...")
    print("📋 API Documentation: http://localhost:8082/docs")
    print("🔧 Health Check: http://localhost:8082/health")
    print("🛑 Press Ctrl+C to stop")
    
    uvicorn.run(
        "ai_detection_api:app",
        host="0.0.0.0",
        port=8082,
        reload=True,
        log_level="info"
    )
