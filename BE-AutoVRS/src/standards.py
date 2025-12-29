"""
Quality Standards and Criteria for PCB Defect Inspection

Based on factory specifications (Kho lỗi phán định TM.xlsx)
"""

from dataclasses import dataclass
from typing import Optional, Dict, Set
from enum import Enum


class DefectClass(Enum):
    """Defect classification types."""
    BAM_DINH_KHONG_TOT = "BamDinhKhongTot"      # Adhesion defect
    THIEUDONGDUONGMACH = "ThieuDongDuongMach"    # Pin mark
    DI_VAT = "DiVat"                             # Foreign object
    DI_VAT_DUONG_MACH = "DiVatDuongMach"        # Foreign object on trace
    KHUYET_MACH = "KhuyetMach"                   # Open circuit
    NGAN_MACH = "NganMach"                       # Short circuit
    THIEU_DONG = "ThieuDong"                     # Missing copper
    THUA_DONG = "ThuaDong"                       # Excess copper
    THUA_DONG_DUONG_MACH = "ThuaDongDuongMach"  # Excess copper on trace
    VET_LOM = "VetLom"                           # Dent
    XUOC = "Xuoc"                                # Scratch


@dataclass
class DefectCriteria:
    """Criteria for a specific defect type."""
    defect_class: DefectClass
    is_always_ng: bool = False                   # Always NG regardless of size
    max_defects_allowed: int = 2                 # Max number before auto NG
    requires_sam: bool = False                   # Needs SAM segmentation
    max_length_mm: Optional[float] = None        # Max allowed length (mm)
    width_ratio_threshold: Optional[float] = None  # For trace width comparison
    length_ratio_threshold: Optional[float] = None # For length comparison
    
    # For special cases
    requires_cleaning_check: bool = False        # DiVat - needs re-check after cleaning
    
    def __repr__(self):
        return f"DefectCriteria({self.defect_class.value})"


class QualityStandards:
    """
    Factory quality standards for PCB defect inspection.
    
    Standards based on "Kho lỗi phán định TM.xlsx":
    
    1. Always NG defects (regardless of size):
       - BamDinhKhongTot (Adhesion defect)
       - NganMach (Short circuit)
       - VetLom (Dent)
       - Xuoc (Scratch)
       - DiVatDuongMach (Foreign object on trace)
    
    2. Multi-defect rule:
       - If total defects >= 3 → NG
    
    3. KhuyetMach (Open circuit):
       - Use SAM to measure trace width at defect
       - If defect_width <= 1/3 trace_width → OK
       - Else → NG
    
    4. ThuaDong (Excess copper):
       - If defect_length > 1.3mm → NG
       - If defect_length < 1.3mm → OK
    
    5. ThuaDongDuongMach (Excess copper on trace):
       - If defect_length > 1.3mm → NG
       - Else: Use SAM to measure Line width
       - If defect_width > 30% Line_width → NG
       - Else → OK
    
    6. ThieuDong (Missing copper):
       - If defect_length > 1.3mm → NG
       - Else: Use SAM to measure copper width
       - If defect_length < 1/3 copper_width → OK
       - Else → NG
    
    7. DiVat (Foreign object):
       - Requires cleaning and re-check
       - If defect_length < 1.3mm → OK
       - Else → NG
    
    8. DiVatDuongMach (Foreign object on trace):
       - Always NG
    """
    
    # Pixel size for conversion (µm/pixel) - to be set from config
    PIXEL_SIZE_UM = 10.0  # Default: 10µm/pixel
    
    # Global thresholds
    MAX_TOTAL_DEFECTS = 2  # If defects >= 3 → NG
    
    # Length thresholds (mm)
    MAX_LENGTH_MM = 1.3
    
    # Ratio thresholds
    KHUYET_MACH_WIDTH_RATIO = 1/3      # defect_width <= 1/3 trace_width
    THUA_DONG_DUONG_MACH_WIDTH_RATIO = 0.30  # defect_width > 30% Line_width → NG
    THIEU_DONG_LENGTH_RATIO = 1/3      # defect_length < 1/3 copper_width
    
    def __init__(self, pixel_size_um: float = 10.0):
        """
        Initialize quality standards.
        
        Args:
            pixel_size_um: Pixel size in micrometers per pixel
        """
        self.PIXEL_SIZE_UM = pixel_size_um
        self._criteria = self._initialize_criteria()
    
    def _initialize_criteria(self) -> Dict[str, DefectCriteria]:
        """Initialize criteria for all defect types."""
        return {
            # Always NG defects
            DefectClass.BAM_DINH_KHONG_TOT.value: DefectCriteria(
                defect_class=DefectClass.BAM_DINH_KHONG_TOT,
                is_always_ng=True
            ),
            DefectClass.NGAN_MACH.value: DefectCriteria(
                defect_class=DefectClass.NGAN_MACH,
                is_always_ng=True
            ),
            DefectClass.VET_LOM.value: DefectCriteria(
                defect_class=DefectClass.VET_LOM,
                is_always_ng=True
            ),
            DefectClass.XUOC.value: DefectCriteria(
                defect_class=DefectClass.XUOC,
                is_always_ng=True
            ),
            DefectClass.DI_VAT_DUONG_MACH.value: DefectCriteria(
                defect_class=DefectClass.DI_VAT_DUONG_MACH,
                is_always_ng=True
            ),
            
            # Conditional NG - requires SAM measurement
            DefectClass.KHUYET_MACH.value: DefectCriteria(
                defect_class=DefectClass.KHUYET_MACH,
                requires_sam=True,
                width_ratio_threshold=self.KHUYET_MACH_WIDTH_RATIO
            ),
            DefectClass.THUA_DONG.value: DefectCriteria(
                defect_class=DefectClass.THUA_DONG,
                requires_sam=False,
                max_length_mm=self.MAX_LENGTH_MM
            ),
            DefectClass.THUA_DONG_DUONG_MACH.value: DefectCriteria(
                defect_class=DefectClass.THUA_DONG_DUONG_MACH,
                requires_sam=True,
                max_length_mm=self.MAX_LENGTH_MM,
                width_ratio_threshold=self.THUA_DONG_DUONG_MACH_WIDTH_RATIO
            ),
            DefectClass.THIEU_DONG.value: DefectCriteria(
                defect_class=DefectClass.THIEU_DONG,
                requires_sam=True,
                max_length_mm=self.MAX_LENGTH_MM,
                length_ratio_threshold=self.THIEU_DONG_LENGTH_RATIO
            ),
            
            # Special cases
            DefectClass.DI_VAT.value: DefectCriteria(
                defect_class=DefectClass.DI_VAT,
                requires_cleaning_check=True,
                max_length_mm=self.MAX_LENGTH_MM
            ),
            DefectClass.THIEUDONGDUONGMACH.value: DefectCriteria(
                defect_class=DefectClass.THIEUDONGDUONGMACH,
                is_always_ng=True
            ),
        }
    
    def get_criteria(self, defect_class_name: str) -> Optional[DefectCriteria]:
        """Get criteria for a specific defect type."""
        return self._criteria.get(defect_class_name)
    
    def get_always_ng_classes(self) -> Set[str]:
        """Get set of defect classes that are always NG."""
        return {
            name for name, criteria in self._criteria.items()
            if criteria.is_always_ng
        }
    
    def get_sam_required_classes(self) -> Set[str]:
        """Get set of defect classes that require SAM measurement."""
        return {
            name for name, criteria in self._criteria.items()
            if criteria.requires_sam
        }
    
    def px_to_mm(self, pixels: float) -> float:
        """Convert pixels to millimeters."""
        return (pixels * self.PIXEL_SIZE_UM) / 1000.0
    
    def mm_to_px(self, mm: float) -> float:
        """Convert millimeters to pixels."""
        return (mm * 1000.0) / self.PIXEL_SIZE_UM
    
    def __repr__(self):
        return f"QualityStandards(pixel_size={self.PIXEL_SIZE_UM}µm/px)"


# Global instance (can be reconfigured)
DEFAULT_STANDARDS = QualityStandards()
