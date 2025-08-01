"""
AutoVRS Backend Runner
Simple script to start the AutoVRS backend server
"""

import os
import sys
import subprocess

def main():
    """Run the AutoVRS backend server"""
    print("🚀 Starting AutoVRS Backend Server...")
    print("=" * 50)
    
    # Check if virtual environment exists
    venv_path = "venv_new"
    if not os.path.exists(venv_path):
        print("📦 Virtual environment not found. Creating...")
        subprocess.run([sys.executable, "-m", "venv_new", venv_path])
        print("✅ Virtual environment created")
    
    # Determine activation script
    if sys.platform == "win32":
        activate_script = os.path.join(venv_path, "Scripts", "activate.bat")
        python_executable = os.path.join(venv_path, "Scripts", "python.exe")
        pip_executable = os.path.join(venv_path, "Scripts", "pip.exe")
    else:
        activate_script = os.path.join(venv_path, "bin", "activate")
        python_executable = os.path.join(venv_path, "bin", "python")
        pip_executable = os.path.join(venv_path, "bin", "pip")
    
    # Install requirements if needed
    requirements_file = "requirements.txt"
    if os.path.exists(requirements_file):
        print("📚 Installing requirements...")
        subprocess.run([pip_executable, "install", "-r", requirements_file])
        print("✅ Requirements installed")
    
    # Start the server
    print("🎯 Starting FastAPI server...")
    print("📡 WebSocket endpoint: ws://localhost:8000/ws/{client_id}")
    print("🌐 API documentation: http://localhost:8000/docs")
    print("❤️ Health check: http://localhost:8000/health")
    print("=" * 50)
    
    try:
        subprocess.run([python_executable, "main.py"])
    except KeyboardInterrupt:
        print("\n👋 Server stopped by user")
    except Exception as e:
        print(f"❌ Error starting server: {e}")

if __name__ == "__main__":
    main()
