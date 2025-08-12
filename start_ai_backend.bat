@echo off
echo 🔧 Setup AutoVRS AI Detection Backend
echo.

REM Kiểm tra file best.onnx
if exist "best.onnx" (
    echo ✅ File best.onnx tìm thấy
    copy "best.onnx" "BE-AutoVRS\best.onnx"
    echo ✅ Đã copy best.onnx vào BE-AutoVRS
) else (
    echo ❌ Không tìm thấy file best.onnx
    echo 📁 Vui lòng đặt file best.onnx trong thư mục gốc APPAutoVRS
)

echo.
echo 📦 Cài đặt Python dependencies...
cd BE-AutoVRS
pip install -r requirements_ai.txt

echo.
echo 🚀 Chạy AI Detection API...
python run_ai_api.py

pause
