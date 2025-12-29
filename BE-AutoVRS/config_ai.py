# config_ai.py
import os

# ====== MULTICLASS (nếu dùng) ======
MULTICLASS_MODEL = r"models\multiclass_model\weights\best.pt"

# ====== SINGLE-CLASS (LOAD TỪ DANH SÁCH CỐ ĐỊNH) ======
# Lưu ý: Các đường dẫn này trỏ đến thư mục local, cần đảm bảo file tồn tại
SINGLE_ENGINE_PATHS = [
    r"models\singleclass_model\BamDinhKhongTot\weights\best.pt",
    r"models\singleclass_model\ThieuDongDuongMach\weights\best.pt",
    r"models\singleclass_model\DiVat\weights\best.pt",
    r"models\singleclass_model\DiVatDuongMach\weights\best.pt",
    r"models\singleclass_model\KhuyetMach\weights\best.pt",
    r"models\singleclass_model\NganMach\weights\best.pt",
    r"models\singleclass_model\ThieuDong\weights\best.pt",
    r"models\singleclass_model\ThuaDong\weights\best.pt",
    r"models\singleclass_model\ThuaDongDuongMach\weights\best.pt",
    r"models\singleclass_model\VetLom\weights\best.pt",
    r"models\singleclass_model\Xuoc\weights\best.pt",
]

SINGLE_ENGINE_NAMES = [
    "BamDinhKhongTot",
    "ThieuDongDuongMach",
    "DiVat",
    "DiVatDuongMach",
    "KhuyetMach",
    "NganMach",
    "ThieuDong",
    "ThuaDong",
    "ThuaDongDuongMach",
    "VetLom",
    "Xuoc",
]

# ====== INFERENCE PARAMS ======
DEVICE            = 0      # 0 / 1 / "cuda:0" / "cpu"
IMGSZ             = 640
CONF_MULTICLASS   = 0.10
CONF_SINGLE       = 0.10
IOU_NMS_SINGLE    = 0.4
SINGLE_THREADS    = 4      # số luồng ThreadPoolExecutor cho single models

# ====== SAM (tuỳ chọn) ======
# Cập nhật đường dẫn nếu có file SAM
SAM_MODEL_PATH    = None # r"C:\Users\sonng\Code\APPAutoVRS\BE-AutoVRS\models\sam2_s.pt"

# ====== QUALITY STANDARDS ======
PIXEL_SIZE_UM = 10.0  # Pixel size in micrometers (µm/pixel)

# ====== DRAWING ======
TEXT_SCALE = 0.6
TEXT_THICK = 2
POLY_THICK = 2
