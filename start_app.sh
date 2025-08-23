# Backend
Start-Process powershell -ArgumentList '-NoExit', '-Command', `
"conda activate autovrs; cd C:\Users\sonng\Code\APPAutoVRS\BE-AutoVRS; python ai_detection_api.py"

# Đợi backend khởi động 5 giây
Start-Sleep -Seconds 5

# Camera
Start-Process powershell -ArgumentList '-NoExit', '-Command', `
"cd C:\Users\sonng\Code\APPAutoVRS\CameraApp; C:\Users\sonng\Code\APPAutoVRS\CameraApp\SimpleCameraViewer.exe"

# Flutter
Start-Process powershell -ArgumentList '-NoExit', '-Command', `
"cd C:\Users\sonng\Code\APPAutoVRS\app; flutter run -d windows"