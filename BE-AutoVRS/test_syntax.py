
import sys
import os

try:
    print("Checking imports for ai_detection_api...")
    import ai_detection_api
    print("Successfully imported ai_detection_api")
    
    # Check if classes exist
    print(f"Service Class: {ai_detection_api.AdvancedAIService}")
    print("Syntax check passed.")
    
except ImportError as e:
    print(f"Import Error: {e}")
    sys.exit(1)
except Exception as e:
    print(f"General Error: {e}")
    sys.exit(1)
