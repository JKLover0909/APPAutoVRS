#!/usr/bin/env python3
"""
Test script to verify OpenCV and NumPy compatibility
"""

try:
    import numpy as np
    print(f"✓ NumPy {np.__version__} imported successfully")
    
    import cv2
    print(f"✓ OpenCV {cv2.__version__} imported successfully")
    
    # Test camera access
    cap = cv2.VideoCapture(0)
    if cap.isOpened():
        print("✓ Camera access successful")
        cap.release()
    else:
        print("⚠ Camera not available (this is OK for testing)")
    
    print("\n🎉 All dependencies are working correctly!")
    
except ImportError as e:
    print(f"❌ Import error: {e}")
except Exception as e:
    print(f"❌ Error: {e}")
