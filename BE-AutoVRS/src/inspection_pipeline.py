"""
AOI Inspection Pipeline

Unified pipeline for PCB defect inspection:

Pipeline Flow:
1. Input Image → MultiClass YOLO OBB Detector
2. If no detection → Fallback to SingleClass YOLO OBB Ensemble
3. Get defect OBB (position, size, class)
4. For defects requiring trace measurement (KhuyetMach, ThuaDong, ThieuDong):
   → Run SAM2 to segment PCB TRACE (not defect)
   → Measure trace width perpendicular to defect
5. Apply quality standards → Verdict Engine
6. Output: OK/NG with reasoning

Key Logic:
- SAM segments the TRACE/COPPER LINE, not the defect itself
- Defect size comes from YOLO OBB
- Trace width comes from SAM segmentation
- Standards compare defect size vs trace width
"""

import numpy as np
from typing import List, Optional, Set, Dict
from dataclasses import dataclass

from src.onnx_multiclass_detector import ONNXMultiClassDetector
from src.onnx_singleclass_detector import ONNXSingleClassEnsemble
from src.segment_trace import SAMTraceSegmenter
from src.standards import QualityStandards
from src.verdict_engine import VerdictEngine
from utils.detection import Detection, InspectionResult, SegmentationResult


@dataclass
class PipelineConfig:
    """Configuration for inspection pipeline."""
    # Detection
    multiclass_model_path: str
    single_engine_paths: List[str]
    single_engine_names: List[str]
    multiclass_class_map: Optional[Dict[int, str]] = None  # class_id -> class_name mapping
    
    # Inference parameters
    device: int = 0  # Legacy - kept for compatibility
    imgsz: int = 640
    conf_multiclass: float = 0.1
    conf_single: float = 0.1
    iou_nms_single: float = 0.4
    single_threads: int = 4
    
    # ONNX Runtime providers
    onnx_providers: Optional[List[str]] = None
    
    # SAM (for trace segmentation and width measurement)
    sam_model_path: Optional[str] = None
    sam_enabled_classes: Set[str] = None  # Classes that require trace measurement
    
    # Quality Standards
    pixel_size_um: float = 10.0  # Pixel size (µm/pixel) for mm conversion
    
    def __post_init__(self):
        if self.sam_enabled_classes is None:
            # Classes that require SAM trace measurement per quality standards
            # KhuyetMach: needs trace width to compare defect width
            # ThuaDongDuongMach: needs line width between traces
            # ThieuDong: needs copper width
            self.sam_enabled_classes = {
                "KhuyetMach", "ThuaDongDuongMach", "ThieuDong"
            }


class InspectionPipeline:
    """
    Main AOI inspection pipeline.
    
    Workflow:
    1. Try MultiClass detection
    2. If no results, fallback to SingleClass ensemble
    3. Optionally run SAM segmentation on specific classes
    4. Return unified InspectionResult objects
    """
    
    def __init__(self, config: PipelineConfig):
        self.config = config
        
        # Load ONNX detectors
        print("Loading ONNX inspection pipeline...")
        
        # Determine ONNX providers from config
        providers = ['CPUExecutionProvider']
        if hasattr(config, 'onnx_providers'):
            providers = config.onnx_providers
        
        self.multiclass_detector = ONNXMultiClassDetector(
            model_path=config.multiclass_model_path,
            conf_threshold=config.conf_multiclass,
            providers=providers,
            imgsz=config.imgsz,
            class_names=config.single_engine_names  # Sequential 0-10 class names from data.yaml
        )
        
        self.single_ensemble = ONNXSingleClassEnsemble(
            model_paths=config.single_engine_paths,
            class_names=config.single_engine_names,
            conf_threshold=config.conf_single,
            iou_threshold=config.iou_nms_single,
            providers=providers,
            num_threads=config.single_threads,
            imgsz=config.imgsz
        )
        
        # Load SAM if provided
        self.sam_segmenter = None
        if config.sam_model_path:
            self.sam_segmenter = SAMTraceSegmenter(
                weights=config.sam_model_path,
                pixel_size_um=config.pixel_size_um,
                use_prior=True
            )
        
        # Initialize quality standards and verdict engine
        self.standards = QualityStandards(pixel_size_um=config.pixel_size_um)
        self.verdict_engine = VerdictEngine(self.standards)
        
        print("✓ ONNX Pipeline ready")

    def inspect(
        self, 
        image_bgr: np.ndarray, 
        use_sam: bool = True
    ) -> List[InspectionResult]:
        """
        Run complete inspection pipeline on image.
        
        Args:
            image_bgr: Input image in BGR format
            use_sam: Whether to run SAM segmentation
            
        Returns:
            List of InspectionResult objects with verdicts
        """
        # Step 1: Try multiclass detection
        detections = self.multiclass_detector.predict(image_bgr)
        detection_source = "MultiClass"
        
        # Step 2: Fallback to single-class ensemble if needed
        if not detections:
            detections = self.single_ensemble.predict(image_bgr)
            detection_source = "SingleClass"
        
        if not detections:
            print("✓ No defects detected (OK)")
            return []
        
        # Step 3: Run SAM to segment TRACE for required defect classes
        detection_segmentation_pairs = []
        for det in detections:
            segmentation = None
            
            # Check if this defect needs SAM trace measurement per quality standards
            criteria = self.standards.get_criteria(det.class_name)
            needs_sam = criteria and criteria.requires_sam
            
            if (use_sam and 
                self.sam_segmenter and 
                needs_sam and
                det.class_name in self.config.sam_enabled_classes):
                # SAM segments the PCB TRACE (not the defect)
                # Returns trace width measurement
                segmentation = self._run_sam(image_bgr, det)
            
            detection_segmentation_pairs.append((det, segmentation))
        
        # Step 4: Apply verdict engine to get OK/NG decisions
        defect_verdicts, overall_verdict = self.verdict_engine.evaluate_multiple_defects(
            detection_segmentation_pairs
        )
        
        # Step 5: Convert to InspectionResult format
        results = []
        for verdict_obj in defect_verdicts:
            result = InspectionResult(
                detection=verdict_obj.detection,
                segmentation=verdict_obj.segmentation,
                verdict=verdict_obj.verdict,
                reason_code=verdict_obj.reason.reason_code,
                reason_text=verdict_obj.reason.reason_text,
                measurements=verdict_obj.reason.measurements,
                requires_recheck=verdict_obj.requires_recheck
            )
            results.append(result)
        
        # Summary
        ng_count = sum(1 for r in results if r.verdict == "NG")
        ok_count = len(results) - ng_count
        print(f"✓ Found {len(results)} defects via {detection_source}: {ng_count} NG, {ok_count} OK")
        print(f"  Overall verdict: {overall_verdict}")
        
        return results

    def _run_sam(
        self, 
        image_bgr: np.ndarray, 
        detection: Detection
    ) -> Optional[SegmentationResult]:
        """
        Run SAM segmentation to measure TRACE width (not defect).
        
        For defects like KhuyetMach, ThuaDong, ThieuDong:
        - SAM segments the PCB trace/copper line
        - Measures trace width perpendicular to defect
        """
        try:
            # Use SAMTraceSegmenter to segment trace and measure width
            result = self.sam_segmenter.segment_and_measure_from_obb(
                image_bgr=image_bgr,
                obb_poly_xy=detection.poly,
                frac_v=1.0,
                frac_uv=1.0,
                margin_px=2,
                step=0.5,
                max_len=512,
                selection_radius=10,
            )
            
            if result is None or result.mask is None or result.mask.sum() == 0:
                print(f"⚠️ SAM returned empty mask for {detection.class_name}")
                return None
            
            return result
            
        except Exception as e:
            print(f"⚠️ SAM failed for {detection.class_name}: {e}")
            return None

    def batch_inspect(
        self, 
        images: List[np.ndarray], 
        use_sam: bool = True
    ) -> List[List[InspectionResult]]:
        """Run inspection on multiple images."""
        return [self.inspect(img, use_sam=use_sam) for img in images]
