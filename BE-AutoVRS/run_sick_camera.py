"""
Entry point for SICK Camera WebSocket Server
Run this to start streaming frames to Flutter app
"""

import asyncio
import sys
from sick_camera_stream import main

if __name__ == "__main__":
    print("🚀 Starting SICK Camera Stream Server...")
    print("📋 Port: 8999")
    print("🔧 Press Ctrl+C to stop")
    print()
    
    try:
        asyncio.run(main())
    except KeyboardInterrupt:
        print("\n👋 Server stopped by user")
        sys.exit(0)
    except Exception as e:
        print(f"\n❌ Fatal error: {e}")
        sys.exit(1)
