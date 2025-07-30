"""
Test script để kiểm tra defect detection service
"""
import cv2
import numpy as np
import sys
import os

# Add src to path
sys.path.append(os.path.join(os.path.dirname(__file__), 'src'))

from services.defect_detection_service import DefectDetectionService

def test_defect_detection():
    """Test defect detection với ảnh mẫu"""
    try:
        # Load model
        model_path = "src/models/yolov8n.onnx"
        if not os.path.exists(model_path):
            print(f"❌ Model not found at {model_path}")
            return False
        
        detector = DefectDetectionService(model_path)
        print("✅ DefectDetectionService initialized successfully")
        
        # Tạo ảnh test đơn giản
        test_image = np.random.randint(0, 255, (640, 640, 3), dtype=np.uint8)
        
        # Test detection
        annotated_frame, detections = detector.detect_defects_from_frame(test_image)
        
        print(f"✅ Detection completed")
        print(f"   - Input shape: {test_image.shape}")
        print(f"   - Output shape: {annotated_frame.shape}")
        print(f"   - Detections found: {len(detections)}")
        
        # Save result
        cv2.imwrite("detection_test_result.jpg", annotated_frame)
        print("✅ Test result saved as detection_test_result.jpg")
        
        return True
        
    except Exception as e:
        print(f"❌ Error in defect detection: {e}")
        return False

if __name__ == "__main__":
    print("🔍 Testing Defect Detection Service...")
    success = test_defect_detection()
    if success:
        print("✅ All tests passed!")
    else:
        print("❌ Tests failed!")
