# Defect Types Reference - BE-AutoVRS

## 📋 Danh Sách 11 Loại Lỗi PCB

| ID | Class Name | Tiếng Việt | English | Always NG | Needs SAM |
|----|------------|------------|---------|-----------|-----------|
| 0 | BamDinhKhongTot | Bám dính không tốt | Poor adhesion | ✅ | ❌ |
| 1 | DiVat | Dị vật | Foreign object | ❌ | ❌ |
| 2 | DiVatDuongMach | Dị vật đường mạch | Foreign object on trace | ✅ | ❌ |
| 3 | KhuyetMach | Khuyết mạch | Open circuit | ❌ | ✅ |
| 4 | NganMach | Ngắn mạch | Short circuit | ✅ | ❌ |
| 5 | ThieuDong | Thiếu đồng | Missing copper | ❌ | ✅ |
| 6 | ThieuDongDuongMach | Thiếu đồng đường mạch | Missing copper on trace | ❌ | ❌ |
| 7 | ThuaDong | Thừa đồng | Excess copper | ❌ | ✅ |
| 8 | ThuaDongDuongMach | Thừa đồng đường mạch | Excess copper on trace | ❌ | ❌ |
| 9 | VetLom | Vết lõm | Dent | ✅ | ❌ |
| 10 | Xuoc | Xước | Scratch | ✅ | ❌ |

---

## 🔍 Chi Tiết Từng Loại Lỗi

### 1️⃣ BamDinhKhongTot (Poor Adhesion)
**Mô tả**: Lớp đồng bám dính không tốt lên lớp cơ sở PCB

**Phán định**:
- ✅ **Always NG** - Luôn lỗi không phụ thuộc vào kích thước
- Không cần SAM segmentation

**Lý do**: Ảnh hưởng nghiêm trọng đến độ bền cơ học và dẫn điện

---

### 2️⃣ DiVat (Foreign Object)
**Mô tả**: Dị vật trên bề mặt PCB (bụi, rác, tạp chất)

**Phán định**:
- ❌ Không phải always NG
- Cần kiểm tra sau khi làm sạch

**Tiêu chuẩn**:
```
IF defect_length < 1.3mm:
    → OK (requires_recheck: true)
ELSE:
    → NG
```

**Lưu ý**: Cần xác nhận lại sau khi làm sạch bề mặt

---

### 3️⃣ DiVatDuongMach (Foreign Object on Trace)
**Mô tả**: Dị vật nằm trên đường mạch dẫn điện

**Phán định**:
- ✅ **Always NG** - Vị trí quan trọng
- Không cần SAM

**Lý do**: Có thể gây ngắn mạch hoặc gián đoạn dòng điện

---

### 4️⃣ KhuyetMach (Open Circuit)
**Mô tả**: Đứt gãy hoặc thiếu hụt trên đường mạch

**Phán định**:
- ❌ Không always NG
- ✅ **Cần SAM** để đo trace width

**Tiêu chuẩn**:
```
1. Segment TRACE bằng SAM
2. Đo trace_width tại vị trí defect
3. IF defect_width <= 1/3 * trace_width:
      → OK (khuyết nhỏ, không ảnh hưởng)
   ELSE:
      → NG (khuyết quá lớn)
```

**Công thức**:
```
defect_width_ratio = defect_width / trace_width
IF defect_width_ratio <= 0.33:
    → OK
ELSE:
    → NG
```

---

### 5️⃣ NganMach (Short Circuit)
**Mô tả**: Hai đường mạch bị chập (short) với nhau

**Phán định**:
- ✅ **Always NG** - Lỗi nghiêm trọng
- Không cần SAM

**Lý do**: Gây chập mạch, hỏng mạch điện tử

---

### 6️⃣ ThieuDong (Missing Copper)
**Mô tả**: Thiếu đồng trên bề mặt PCB

**Phán định**:
- ❌ Không always NG
- ✅ **Cần SAM** để đo copper width

**Tiêu chuẩn**:
```
1. IF defect_length > 1.3mm:
      → NG (quá dài)
   
2. ELSE:
      a. Segment COPPER area bằng SAM
      b. Đo copper_width
      c. IF defect_length < 1/3 * copper_width:
            → OK (thiếu nhỏ)
         ELSE:
            → NG (thiếu đáng kể)
```

**Công thức**:
```
IF defect_length > 1.3mm:
    → NG
ELSE IF defect_length < copper_width / 3:
    → OK
ELSE:
    → NG
```

---

### 7️⃣ ThieuDongDuongMach (Missing Copper on Trace)
**Mô tả**: Thiếu đồng trên đường mạch dẫn điện

**Phán định**:
- ❌ Không always NG
- ❌ Không cần SAM (dùng OBB size)

**Tiêu chuẩn**:
```
IF defect_length < 1.3mm:
    → OK (thiếu nhỏ)
ELSE:
    → NG (ảnh hưởng dẫn điện)
```

---

### 8️⃣ ThuaDong (Excess Copper)
**Mô tả**: Thừa đồng trên bề mặt PCB

**Phán định**:
- ❌ Không always NG
- ✅ **Cần SAM** nếu < 1.3mm

**Tiêu chuẩn**:
```
IF defect_length > 1.3mm:
    → NG (quá dài)
ELSE:
    → OK (thừa nhỏ, chấp nhận được)
```

---

### 9️⃣ ThuaDongDuongMach (Excess Copper on Trace)
**Mô tả**: Thừa đồng trên đường mạch

**Phán định**:
- ❌ Không always NG
- ❌ Cần SAM chỉ khi < 1.3mm

**Tiêu chuẩn**:
```
1. IF defect_length > 1.3mm:
      → NG (quá dài)

2. ELSE:
      a. Segment LINE width bằng SAM
      b. IF defect_width > 30% * line_width:
            → NG (thừa quá nhiều)
         ELSE:
            → OK (thừa nhỏ)
```

**Công thức**:
```
IF defect_length > 1.3mm:
    → NG
ELSE IF defect_width > 0.3 * line_width:
    → NG
ELSE:
    → OK
```

---

### 🔟 VetLom (Dent)
**Mô tả**: Vết lõm trên bề mặt PCB

**Phán định**:
- ✅ **Always NG** - Ảnh hưởng độ phẳng
- Không cần SAM

**Lý do**: Ảnh hưởng đến chất lượng bề mặt và linh kiện

---

### 1️⃣1️⃣ Xuoc (Scratch)
**Mô tả**: Vết xước trên bề mặt PCB

**Phán định**:
- ✅ **Always NG** - Làm hỏng lớp bảo vệ
- Không cần SAM

**Lý do**: Phá hủy lớp solder mask hoặc đồng

---

## 📊 Tóm Tắt Phán Định

### Always NG (5 loại - Luôn lỗi)
1. **BamDinhKhongTot** - Bám dính kém
2. **DiVatDuongMach** - Dị vật trên mạch
3. **NganMach** - Ngắn mạch
4. **VetLom** - Vết lõm
5. **Xuoc** - Xước

### Needs SAM (3 loại - Cần đo)
1. **KhuyetMach** - Đo trace width
2. **ThieuDong** - Đo copper width
3. **ThuaDong** - Đo copper width (nếu < 1.3mm)

### Length-Based (3 loại - Dựa vào chiều dài)
1. **DiVat** - < 1.3mm → OK
2. **ThieuDongDuongMach** - < 1.3mm → OK
3. **ThuaDongDuongMach** - < 1.3mm → Kiểm tra thêm

---

## 🎯 Quick Decision Matrix

| Defect Type | Length Check | Width Check | SAM Required | Final Decision |
|-------------|--------------|-------------|--------------|----------------|
| BamDinhKhongTot | - | - | ❌ | Always NG |
| DiVat | < 1.3mm | - | ❌ | OK if small |
| DiVatDuongMach | - | - | ❌ | Always NG |
| KhuyetMach | - | ≤ 1/3 trace | ✅ | OK if narrow |
| NganMach | - | - | ❌ | Always NG |
| ThieuDong | < 1.3mm | < 1/3 copper | ✅ | OK if small |
| ThieuDongDuongMach | < 1.3mm | - | ❌ | OK if short |
| ThuaDong | < 1.3mm | - | ✅ | OK if short |
| ThuaDongDuongMach | < 1.3mm | ≤ 30% line | ✅ | OK if small |
| VetLom | - | - | ❌ | Always NG |
| Xuoc | - | - | ❌ | Always NG |

---

## 🔧 Implementation Notes

### SAM Segmentation
```python
# Các defect cần SAM segmentation
SAM_ENABLED_CLASSES = {
    "KhuyetMach",           # Segment TRACE
    "ThuaDong",             # Segment COPPER
    "ThieuDong",            # Segment COPPER
    "ThuaDongDuongMach"     # Segment LINE (optional)
}
```

### Thresholds
```python
# Ngưỡng chiều dài
MAX_LENGTH_MM = 1.3  # 1.3mm

# Ngưỡng tỷ lệ
TRACE_WIDTH_RATIO = 1/3      # 33.3%
LINE_WIDTH_RATIO = 0.3       # 30%
COPPER_WIDTH_RATIO = 1/3     # 33.3%
```

### Multi-Defect Rule
```python
# Quy tắc số lượng lỗi
MAX_TOTAL_DEFECTS = 2
# Nếu total_defects >= 3 → NG
```

---

## 📖 References

- **Standards**: `src/standards.py`
- **Verdict Engine**: `src/verdict_engine.py`
- **Quality Specs**: Based on "Kho lỗi phán định TM.xlsx"

---

## 🎓 Training Data

### Model Paths
```
models/singleclass_model/
├── BamDinhKhongTot/weights/best.onnx
├── DiVat/weights/best.onnx
├── DiVatDuongMach/weights/best.onnx
├── KhuyetMach/weights/best.onnx
├── NganMach/weights/best.onnx
├── ThieuDong/weights/best.onnx
├── ThieuDongDuongMach/weights/best.onnx
├── ThuaDong/weights/best.onnx
├── ThuaDongDuongMach/weights/best.onnx
├── VetLom/weights/best.onnx
└── Xuoc/weights/best.onnx
```

### Class ID Mapping
```python
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
```

---

## ✅ Validation Checklist

Khi thêm defect mới hoặc modify standards:

- [ ] Add defect class to `DefectClass` enum
- [ ] Define `DefectCriteria` in `standards.py`
- [ ] Update verdict logic in `verdict_engine.py`
- [ ] Train ONNX model và đặt vào `models/`
- [ ] Update `SINGLE_ENGINE_NAMES` trong `config_ai.py`
- [ ] Test với sample images
- [ ] Update documentation (file này)
