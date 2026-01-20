"""
Verdict Engine - Logic phán định OK/NG cho PCB defects

Implements factory quality standards for automated defect classification.
"""

import numpy as np
from typing import List, Optional, Tuple
from dataclasses import dataclass, field

from src.standards import QualityStandards, DefectCriteria
from utils.detection import Detection, SegmentationResult


@dataclass
class VerdictReason:
    """Detailed reasoning for verdict decision."""
    verdict: str  # "OK" or "NG"
    reason_code: str
    reason_text: str
    measurements: dict = field(default_factory=dict)
    
    def __repr__(self):
        return f"{self.verdict}: {self.reason_text}"


@dataclass
class DefectVerdict:
    """Complete verdict for a single defect."""
    detection: Detection
    segmentation: Optional[SegmentationResult]
    verdict: str  # "OK" or "NG"
    reason: VerdictReason
    requires_recheck: bool = False  # For DiVat - needs cleaning check
    
    def to_dict(self) -> dict:
        """Export to dict."""
        return {
            "detection": self.detection.to_dict(),
            "segmentation": self.segmentation.to_dict() if self.segmentation else None,
            "verdict": self.verdict,
            "reason": {
                "code": self.reason.reason_code,
                "text": self.reason.reason_text,
                "measurements": self.reason.measurements
            },
            "requires_recheck": self.requires_recheck
        }


class VerdictEngine:
    """
    Engine for determining OK/NG verdict based on quality standards.
    
    Implements the complete decision tree:
    1. Check if defect class is always NG
    2. Check total defect count (>= 3 → NG)
    3. Apply size/measurement-based criteria
    4. For SAM-required defects, evaluate width/length ratios
    """
    
    def __init__(self, standards: Optional[QualityStandards] = None):
        """
        Initialize verdict engine.
        
        Args:
            standards: Quality standards to use (defaults to DEFAULT_STANDARDS)
        """
        from src.standards import DEFAULT_STANDARDS
        self.standards = standards or DEFAULT_STANDARDS
    
    def evaluate_single_defect(
        self,
        detection: Detection,
        segmentation: Optional[SegmentationResult] = None
    ) -> DefectVerdict:
        """
        Evaluate verdict for a single defect.
        
        Args:
            detection: Defect detection result
            segmentation: Optional SAM segmentation result
            
        Returns:
            DefectVerdict with decision and reasoning
        """
        defect_class = detection.class_name
        criteria = self.standards.get_criteria(defect_class)
        
        if criteria is None:
            # Unknown defect type → conservative NG
            reason = VerdictReason(
                verdict="NG",
                reason_code="UNKNOWN_DEFECT",
                reason_text=f"Loại lỗi không xác định: {defect_class}"
            )
            return DefectVerdict(detection, segmentation, "NG", reason)
        
        # Check if always NG
        if criteria.is_always_ng:
            reason = VerdictReason(
                verdict="NG",
                reason_code="ALWAYS_NG",
                reason_text=f"{defect_class} luôn là NG theo tiêu chuẩn"
            )
            return DefectVerdict(detection, segmentation, "NG", reason)
        
        # Evaluate based on defect type
        if defect_class == "KhuyetMach":
            return self._evaluate_khuyet_mach(detection, segmentation, criteria)
        elif defect_class == "ThuaDong":
            return self._evaluate_thua_dong(detection, segmentation, criteria)
        elif defect_class == "ThuaDongDuongMach":
            return self._evaluate_thua_dong_duong_mach(detection, segmentation, criteria)
        elif defect_class == "ThieuDong":
            return self._evaluate_thieu_dong(detection, segmentation, criteria)
        elif defect_class == "DiVat":
            return self._evaluate_di_vat(detection, segmentation, criteria)
        else:
            # Default: check size only
            return self._evaluate_by_size(detection, segmentation, criteria)
    
    def evaluate_multiple_defects(
        self,
        defects: List[Tuple[Detection, Optional[SegmentationResult]]]
    ) -> Tuple[List[DefectVerdict], str]:
        """
        Evaluate multiple defects and determine overall verdict.
        
        Args:
            defects: List of (detection, segmentation) tuples
            
        Returns:
            (list of DefectVerdicts, overall_verdict)
        """
        if not defects:
            return [], "OK"
        
        # Evaluate each defect
        verdicts = []
        for detection, segmentation in defects:
            verdict = self.evaluate_single_defect(detection, segmentation)
            verdicts.append(verdict)
        
        # Check total defect count rule
        if len(defects) >= 3:
            # Mark all as NG due to count
            for v in verdicts:
                if v.verdict == "OK":
                    v.verdict = "NG"
                    v.reason = VerdictReason(
                        verdict="NG",
                        reason_code="DEFECT_COUNT",
                        reason_text=f"Tổng số lỗi ({len(defects)}) >= 3"
                    )
        
        # Overall verdict: NG if any defect is NG
        overall = "NG" if any(v.verdict == "NG" for v in verdicts) else "OK"
        
        return verdicts, overall
    
    def _evaluate_khuyet_mach(
        self,
        detection: Detection,
        segmentation: Optional[SegmentationResult],
        criteria: DefectCriteria
    ) -> DefectVerdict:
        """
        Evaluate KhuyetMach (Open circuit).
        
        Logic:
        - Use SAM to measure trace width at defect
        - If defect_width <= 1/3 trace_width → OK
        - Else → NG
        """
        if segmentation is None or segmentation.width_px == 0:
            reason = VerdictReason(
                verdict="NG",
                reason_code="NO_MEASUREMENT",
                reason_text="Khuyết mạch cần đo SAM nhưng không có kết quả"
            )
            return DefectVerdict(detection, segmentation, "NG", reason)
        
        # Get defect width from detection OBB
        defect_width_px = detection.width
        
        # Get trace width from SAM measurement
        trace_width_px = segmentation.width_px
        
        # Calculate ratio
        width_ratio = defect_width_px / (trace_width_px + 1e-6)
        
        # Convert numpy types to Python native types
        measurements = {
            "defect_width_px": float(defect_width_px),
            "trace_width_px": float(trace_width_px),
            "width_ratio": float(width_ratio),
            "threshold": float(criteria.width_ratio_threshold)
        }
        
        if width_ratio <= criteria.width_ratio_threshold:
            reason = VerdictReason(
                verdict="OK",
                reason_code="KHUYET_MACH_OK",
                reason_text=f"Bề rộng lỗi ({width_ratio:.2%}) <= 1/3 bề rộng mạch",
                measurements=measurements
            )
            return DefectVerdict(detection, segmentation, "OK", reason)
        else:
            reason = VerdictReason(
                verdict="NG",
                reason_code="KHUYET_MACH_NG",
                reason_text=f"Bề rộng lỗi ({width_ratio:.2%}) > 1/3 bề rộng mạch",
                measurements=measurements
            )
            return DefectVerdict(detection, segmentation, "NG", reason)
    
    def _evaluate_thua_dong(
        self,
        detection: Detection,
        segmentation: Optional[SegmentationResult],
        criteria: DefectCriteria
    ) -> DefectVerdict:
        """
        Evaluate ThuaDong (Excess copper).
        
        Logic:
        - If defect_length > 1.3mm → NG
        - Else → OK
        """
        # Convert length to mm
        defect_length_mm = self.standards.px_to_mm(detection.length)
        
        measurements = {
            "defect_length_px": float(detection.length),
            "defect_length_mm": float(defect_length_mm),
            "threshold_mm": float(criteria.max_length_mm)
        }
        
        if defect_length_mm > criteria.max_length_mm:
            reason = VerdictReason(
                verdict="NG",
                reason_code="THUA_DONG_NG",
                reason_text=f"Chiều dài lỗi ({defect_length_mm:.2f}mm) > 1.3mm",
                measurements=measurements
            )
            return DefectVerdict(detection, segmentation, "NG", reason)
        else:
            reason = VerdictReason(
                verdict="OK",
                reason_code="THUA_DONG_OK",
                reason_text=f"Chiều dài lỗi ({defect_length_mm:.2f}mm) < 1.3mm",
                measurements=measurements
            )
            return DefectVerdict(detection, segmentation, "OK", reason)
    
    def _evaluate_thua_dong_duong_mach(
        self,
        detection: Detection,
        segmentation: Optional[SegmentationResult],
        criteria: DefectCriteria
    ) -> DefectVerdict:
        """
        Evaluate ThuaDongDuongMach (Excess copper on trace).
        
        Logic:
        - If defect_length > 1.3mm → NG
        - Else: Use SAM to measure Line width
        - If defect_width > 30% Line_width → NG
        - Else → OK
        """
        # Convert length to mm
        defect_length_mm = self.standards.px_to_mm(detection.length)
        
        # First check: length > 1.3mm
        if defect_length_mm > criteria.max_length_mm:
            reason = VerdictReason(
                verdict="NG",
                reason_code="THUA_DONG_DUONG_MACH_LENGTH",
                reason_text=f"Chiều dài lỗi ({defect_length_mm:.2f}mm) > 1.3mm",
                measurements={"defect_length_mm": float(defect_length_mm)}
            )
            return DefectVerdict(detection, segmentation, "NG", reason)
        
        # Second check: requires SAM measurement of Line width
        if segmentation is None or segmentation.width_px == 0:
            reason = VerdictReason(
                verdict="NG",
                reason_code="NO_MEASUREMENT",
                reason_text="Thừa đồng đường mạch cần đo khoảng cách Line bằng SAM nhưng không có kết quả"
            )
            return DefectVerdict(detection, segmentation, "NG", reason)
        
        # Get Line width from SAM
        line_width_px = segmentation.width_px
        defect_width_px = detection.width
        
        width_ratio = defect_width_px / (line_width_px + 1e-6)
        
        measurements = {
            "defect_width_px": float(defect_width_px),
            "defect_length_mm": float(defect_length_mm),
            "line_width_px": float(line_width_px),
            "width_ratio": float(width_ratio),
            "threshold": float(criteria.width_ratio_threshold)
        }
        
        if width_ratio > criteria.width_ratio_threshold:
            reason = VerdictReason(
                verdict="NG",
                reason_code="THUA_DONG_DUONG_MACH_NG",
                reason_text=f"Bề rộng lỗi ({width_ratio:.2%}) > 30% bề rộng Line",
                measurements=measurements
            )
            return DefectVerdict(detection, segmentation, "NG", reason)
        else:
            reason = VerdictReason(
                verdict="OK",
                reason_code="THUA_DONG_DUONG_MACH_OK",
                reason_text=f"Bề rộng lỗi ({width_ratio:.2%}) <= 30% bề rộng Line",
                measurements=measurements
            )
            return DefectVerdict(detection, segmentation, "OK", reason)
    
    def _evaluate_thieu_dong(
        self,
        detection: Detection,
        segmentation: Optional[SegmentationResult],
        criteria: DefectCriteria
    ) -> DefectVerdict:
        """
        Evaluate ThieuDong (Missing copper).
        
        Logic:
        - If defect_length > 1.3mm → NG
        - Else: Use SAM to measure copper width
        - If defect_length < 1/3 copper_width → OK
        - Else → NG
        """
        # Convert length to mm
        defect_length_mm = self.standards.px_to_mm(detection.length)
        
        # First check: length > 1.3mm
        if defect_length_mm > criteria.max_length_mm:
            reason = VerdictReason(
                verdict="NG",
                reason_code="THIEU_DONG_LENGTH",
                reason_text=f"Chiều dài lỗi ({defect_length_mm:.2f}mm) > 1.3mm",
                measurements={"defect_length_mm": float(defect_length_mm)}
            )
            return DefectVerdict(detection, segmentation, "NG", reason)
        
        # Second check: requires SAM measurement
        if segmentation is None or segmentation.width_px == 0:
            reason = VerdictReason(
                verdict="NG",
                reason_code="NO_MEASUREMENT",
                reason_text="Thiếu đồng cần đo SAM nhưng không có kết quả"
            )
            return DefectVerdict(detection, segmentation, "NG", reason)
        
        # Get copper width from SAM
        copper_width_px = segmentation.width_px
        defect_length_px = detection.length
        
        length_ratio = defect_length_px / (copper_width_px + 1e-6)
        
        measurements = {
            "defect_length_px": float(defect_length_px),
            "defect_length_mm": float(defect_length_mm),
            "copper_width_px": float(copper_width_px),
            "length_ratio": float(length_ratio),
            "threshold": float(criteria.length_ratio_threshold)
        }
        
        if length_ratio < criteria.length_ratio_threshold:
            reason = VerdictReason(
                verdict="OK",
                reason_code="THIEU_DONG_OK",
                reason_text=f"Chiều dài lỗi ({length_ratio:.2%}) < 1/3 bề rộng đồng",
                measurements=measurements
            )
            return DefectVerdict(detection, segmentation, "OK", reason)
        else:
            reason = VerdictReason(
                verdict="NG",
                reason_code="THIEU_DONG_NG",
                reason_text=f"Chiều dài lỗi ({length_ratio:.2%}) >= 1/3 bề rộng đồng",
                measurements=measurements
            )
            return DefectVerdict(detection, segmentation, "NG", reason)
    
    def _evaluate_di_vat(
        self,
        detection: Detection,
        segmentation: Optional[SegmentationResult],
        criteria: DefectCriteria
    ) -> DefectVerdict:
        """
        Evaluate DiVat (Foreign object).
        
        Logic:
        - Requires cleaning and re-check
        - If defect_length < 1.3mm → OK
        - Else → NG
        """
        defect_length_mm = self.standards.px_to_mm(detection.length)
        
        measurements = {
            "defect_length_px": float(detection.length),
            "defect_length_mm": float(defect_length_mm),
            "threshold_mm": float(criteria.max_length_mm)
        }
        
        if defect_length_mm < criteria.max_length_mm:
            reason = VerdictReason(
                verdict="OK",
                reason_code="DI_VAT_OK",
                reason_text=f"Chiều dài dị vật ({defect_length_mm:.2f}mm) < 1.3mm (sau khi làm sạch)",
                measurements=measurements
            )
            return DefectVerdict(detection, segmentation, "OK", reason, requires_recheck=True)
        else:
            reason = VerdictReason(
                verdict="NG",
                reason_code="DI_VAT_NG",
                reason_text=f"Chiều dài dị vật ({defect_length_mm:.2f}mm) >= 1.3mm",
                measurements=measurements
            )
            return DefectVerdict(detection, segmentation, "NG", reason, requires_recheck=True)
    
    def _evaluate_by_size(
        self,
        detection: Detection,
        segmentation: Optional[SegmentationResult],
        criteria: DefectCriteria
    ) -> DefectVerdict:
        """
        Default evaluation based on size only.
        Used for defects without specific criteria.
        """
        # Conservative: small defects OK, large defects NG
        defect_length_mm = self.standards.px_to_mm(detection.length)
        
        measurements = {
            "defect_length_px": float(detection.length),
            "defect_length_mm": float(defect_length_mm)
        }
        
        # Simple heuristic: > 1mm → NG
        if defect_length_mm > 1.0:
            reason = VerdictReason(
                verdict="NG",
                reason_code="SIZE_NG",
                reason_text=f"Kích thước lỗi ({defect_length_mm:.2f}mm) > 1.0mm",
                measurements=measurements
            )
            return DefectVerdict(detection, segmentation, "NG", reason)
        else:
            reason = VerdictReason(
                verdict="OK",
                reason_code="SIZE_OK",
                reason_text=f"Kích thước lỗi ({defect_length_mm:.2f}mm) <= 1.0mm",
                measurements=measurements
            )
            return DefectVerdict(detection, segmentation, "OK", reason)
