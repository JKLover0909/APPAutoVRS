# config_ai.py
import os

# ====== SETUP PATHS (Đường dẫn tương đối) ======
# Lấy thư mục hiện tại của script
BASE_DIR = os.path.dirname(os.path.abspath(__file__))
MODELS_DIR = os.path.join(BASE_DIR, 'models')

# ====== MULTICLASS (ONNX) ======
MULTICLASS_MODEL = os.path.join(MODELS_DIR, 'multiclass_model', 'weights', 'best.onnx')

# ====== SINGLE-CLASS (ONNX - LOAD TỪ DANH SÁCH CỐ ĐỊNH) ======
# Lưu ý: Các đường dẫn này trỏ đến thư mục local, cần đảm bảo file tồn tại
SINGLE_ENGINE_PATHS = [
    os.path.join(MODELS_DIR, 'singleclass_model', 'BamDinhKhongTot', 'weights', 'best.onnx'),
    os.path.join(MODELS_DIR, 'singleclass_model', 'ThieuDongDuongMach', 'weights', 'best.onnx'),
    os.path.join(MODELS_DIR, 'singleclass_model', 'DiVat', 'weights', 'best.onnx'),
    os.path.join(MODELS_DIR, 'singleclass_model', 'DiVatDuongMach', 'weights', 'best.onnx'),
    os.path.join(MODELS_DIR, 'singleclass_model', 'KhuyetMach', 'weights', 'best.onnx'),
    os.path.join(MODELS_DIR, 'singleclass_model', 'NganMach', 'weights', 'best.onnx'),
    os.path.join(MODELS_DIR, 'singleclass_model', 'ThieuDong', 'weights', 'best.onnx'),
    os.path.join(MODELS_DIR, 'singleclass_model', 'ThuaDong', 'weights', 'best.onnx'),
    os.path.join(MODELS_DIR, 'singleclass_model', 'ThuaDongDuongMach', 'weights', 'best.onnx'),
    os.path.join(MODELS_DIR, 'singleclass_model', 'VetLom', 'weights', 'best.onnx'),
    os.path.join(MODELS_DIR, 'singleclass_model', 'Xuoc', 'weights', 'best.onnx'),
]

# Class names for both multiclass and single-class models (must match data.yaml order)
SINGLE_ENGINE_NAMES = [
    "BamDinhKhongTot",      # 0
    "DiVat",                # 1
    "DiVatDuongMach",       # 2
    "KhuyetMach",           # 3
    "NganMach",             # 4
    "ThieuDong",            # 5
    "ThieuDongDuongMach",   # 6
    "ThuaDong",             # 7
    "ThuaDongDuongMach",    # 8
    "VetLom",               # 9
    "Xuoc",                 # 10
]

# NOTE: MULTICLASS_CLASS_MAP not needed - model uses sequential 0-10 IDs

# ====== INFERENCE PARAMS (ONNX Runtime) ======
# ONNX Runtime providers: CPUExecutionProvider (CPU) or CUDAExecutionProvider (GPU)
try:
    import onnxruntime as ort
    available_providers = ort.get_available_providers()
    
    if 'CUDAExecutionProvider' in available_providers:
        ONNX_PROVIDERS = ['CUDAExecutionProvider', 'CPUExecutionProvider']
        DEVICE = 'cuda'  # For compatibility with old code
        print(f"✅ ONNX Runtime: Using GPU (CUDA)")
        print(f"   Available providers: {available_providers}")
    else:
        ONNX_PROVIDERS = ['CPUExecutionProvider']
        DEVICE = 'cpu'
        print("⚠️  ONNX Runtime: Using CPU")
        print("   This may be slower. Install onnxruntime-gpu for GPU acceleration.")
        print(f"   Available providers: {available_providers}")
except ImportError:
    print("❌ ERROR: onnxruntime not installed!")
    print("   Install with: pip install onnxruntime  (CPU)")
    print("             or: pip install onnxruntime-gpu  (GPU)")
    ONNX_PROVIDERS = ['CPUExecutionProvider']
    DEVICE = 'cpu'

IMGSZ             = 640
CONF_MULTICLASS   = 0.10
CONF_SINGLE       = 0.10
IOU_NMS_SINGLE    = 0.4
SINGLE_THREADS    = 4      # số luồng ThreadPoolExecutor cho single models

# ====== SAM (tuỳ chọn) ======
# Set to None để disable SAM, hoặc cập nhật đường dẫn nếu có file SAM
SAM_MODEL_PATH = None  # os.path.join(MODELS_DIR, 'sam2_s.pt')

# ====== QUALITY STANDARDS ======
PIXEL_SIZE_UM = 10.0  # Pixel size in micrometers (µm/pixel)

# ====== DRAWING ======
TEXT_SCALE = 0.6
TEXT_THICK = 2
POLY_THICK = 2
