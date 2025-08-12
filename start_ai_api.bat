@echo off
echo 🤖 Starting AutoVRS AI Detection API...
echo.

REM Check if Python is installed
python --version >nul 2>&1
if errorlevel 1 (
    echo ❌ Python is not installed or not in PATH
    echo Please install Python 3.8+ and try again
    pause
    exit /b 1
)

REM Check if virtual environment exists
if not exist "venv" (
    echo 📦 Creating virtual environment...
    python -m venv venv
)

REM Activate virtual environment
echo 🔧 Activating virtual environment...
call venv\Scripts\activate.bat

REM Install requirements
echo 📥 Installing requirements...
pip install -r requirements.txt

REM Check if best.onnx exists
if exist "best.onnx" (
    echo ✅ Model file 'best.onnx' found
) else (
    echo ⚠️ Model file 'best.onnx' not found - running in demo mode
    echo You can copy best.onnx to this directory for actual AI detection
)

echo.
echo 🚀 Starting API server...
echo 📡 API will be available at: http://localhost:8082
echo 📋 API Documentation: http://localhost:8082/docs
echo 🛑 Press Ctrl+C to stop
echo.

python ai_detection_api.py

pause
