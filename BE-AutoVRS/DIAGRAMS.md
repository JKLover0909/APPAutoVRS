# BE-AutoVRS System Diagrams

## 1. Overall System Architecture

```mermaid
graph TB
    subgraph Flutter["Flutter App (Frontend)"]
        UI[UI Components]
        DB[(SQLite DB)]
    end
    
    subgraph Backend["BE-AutoVRS Backend"]
        AI[AI Detection API<br/>Port 8082]
        PLC[PLC Gateway API<br/>Port 8083]
        CAM[Camera Stream<br/>Port 8999 WS]
        COORD[WS Coordinator<br/>Port 8081]
    end
    
    subgraph Hardware["Hardware"]
        OMRON[Omron PLC<br/>FinsNet]
        SICK[SICK IC4 Camera]
    end
    
    subgraph Models["AI Models"]
        MULTI[MultiClass ONNX<br/>1 model, 11 classes]
        SINGLE[SingleClass ONNX<br/>11 models]
        SAM2[SAM2 Model<br/>Segmentation]
    end
    
    UI -->|REST API| AI
    UI -->|REST API| PLC
    UI -->|WebSocket| CAM
    UI -->|WebSocket| COORD
    
    AI --> MULTI
    AI --> SINGLE
    AI --> SAM2
    
    PLC --> OMRON
    PLC --> SICK
    PLC -->|POST| AI
    
    CAM --> SICK
    
    style Flutter fill:#e1f5ff
    style Backend fill:#fff3e0
    style Hardware fill:#f3e5f5
    style Models fill:#e8f5e9
```

## 2. AI Detection Pipeline Flow

```mermaid
flowchart TD
    START([Input Image BGR]) --> PREP[Preprocess<br/>Resize & Normalize]
    PREP --> MULTI{MultiClass<br/>Detection}
    
    MULTI -->|Has detections| RESULT[Detection Results]
    MULTI -->|No detections| ENSEMBLE[SingleClass<br/>Ensemble]
    
    ENSEMBLE --> PARALLEL[Run 11 Models<br/>in Parallel]
    PARALLEL --> NMS[Apply NMS]
    NMS --> RESULT
    
    RESULT --> CHECK{Need SAM?}
    CHECK -->|Yes<br/>KhuyetMach,ThuaDong,ThieuDong| SAM[SAM Segmentation]
    CHECK -->|No| VERDICT
    
    SAM --> MEASURE[Measure<br/>Trace Width]
    MEASURE --> VERDICT[Verdict Engine]
    
    VERDICT --> RULES{Apply Rules}
    
    RULES --> RULE1{Always NG?}
    RULE1 -->|Yes| NG[NG]
    RULE1 -->|No| RULE2
    
    RULE2{Count >= 3?}
    RULE2 -->|Yes| NG
    RULE2 -->|No| RULE3
    
    RULE3{Size/Ratio<br/>Check}
    RULE3 -->|Pass| OK[OK]
    RULE3 -->|Fail| NG
    
    OK --> OUTPUT([Output:<br/>InspectionResult])
    NG --> OUTPUT
    
    style START fill:#4caf50,color:#fff
    style OUTPUT fill:#2196f3,color:#fff
    style OK fill:#8bc34a
    style NG fill:#f44336,color:#fff
    style SAM fill:#ff9800
```

## 3. PLC Gateway Workflow

```mermaid
sequenceDiagram
    participant F as Flutter App
    participant G as PLC Gateway
    participant P as Omron PLC
    participant C as SICK Camera
    participant A as AI API
    
    F->>G: POST /api/inspect-defect<br/>{x, y, board_id}
    
    G->>P: Connect FinsNet<br/>192.168.3.1:9600
    activate P
    
    G->>P: Write X → D2810
    G->>P: Write Y → D2910
    G->>P: Trigger → D3000 = 1
    G->>P: Trigger → D3000 = 0
    
    Note over G,P: Wait 2s for<br/>PLC movement
    
    deactivate P
    
    G->>C: snap_single()
    activate C
    C-->>G: Image frame (BGR)
    deactivate C
    
    G->>A: POST /api/ai-detection<br/>{image_base64}
    activate A
    A-->>G: Detection results
    deactivate A
    
    G-->>F: Response with<br/>detections + verdict
```

## 4. AI Model Architecture

```mermaid
graph LR
    subgraph Input
        IMG[Input Image<br/>640x640x3]
    end
    
    subgraph MultiClass["MultiClass Model (ONNX)"]
        MC1[YOLOv11 OBB<br/>Backbone]
        MC2[Detection Head]
        MC3[11 Classes Output]
    end
    
    subgraph SingleClass["SingleClass Ensemble (ONNX)"]
        SC1[Model 1: BamDinhKhongTot]
        SC2[Model 2: DiVat]
        SC3[Model 3: DiVatDuongMach]
        SC4[Model 4: KhuyetMach]
        SC5[Model 5: NganMach]
        SC6[Model 6: ThieuDong]
        SC7[Model 7: ThieuDongDuongMach]
        SC8[Model 8: ThuaDong]
        SC9[Model 9: ThuaDongDuongMach]
        SC10[Model 10: VetLom]
        SC11[Model 11: Xuoc]
        NMS[NMS Merge]
    end
    
    subgraph Segmentation
        SAM[SAM2 Model]
        SEG[Trace Segmentation]
        MEASURE[Width Measurement]
    end
    
    IMG --> MC1
    MC1 --> MC2
    MC2 --> MC3
    MC3 --> OUT1[Detections]
    
    IMG --> SC1 & SC2 & SC3 & SC4 & SC5 & SC6 & SC7 & SC8 & SC9 & SC10 & SC11
    SC1 & SC2 & SC3 & SC4 & SC5 & SC6 & SC7 & SC8 & SC9 & SC10 & SC11 --> NMS
    NMS --> OUT2[Detections]
    
    OUT1 & OUT2 --> CHECK{Need SAM?}
    CHECK -->|Yes| SAM
    SAM --> SEG
    SEG --> MEASURE
    MEASURE --> FINAL[Final Results]
    CHECK -->|No| FINAL
    
    style IMG fill:#4caf50,color:#fff
    style FINAL fill:#2196f3,color:#fff
```

## 5. Data Flow Architecture

```mermaid
graph TD
    subgraph Sources["Data Sources"]
        CAM_SRC[SICK Camera<br/>1920x1080 @ 30fps]
        FILE_SRC[File Upload<br/>Base64 Image]
        PLC_SRC[PLC Trigger<br/>Coordinates]
    end
    
    subgraph Processing["Processing Layer"]
        PREP[Image Preprocessing]
        DETECT[ONNX Detection]
        SEG[SAM Segmentation]
        VERDICT[Verdict Engine]
    end
    
    subgraph Storage["Storage"]
        INPUT[Image_input/]
        OUTPUT[Image_output/]
        VIDEO[recorded_videos/]
        RUNS[runs/]
    end
    
    subgraph Output["Output Channels"]
        API_OUT[REST API Response]
        WS_OUT[WebSocket Stream]
        VIS[Visualization]
    end
    
    CAM_SRC --> PREP
    FILE_SRC --> PREP
    PLC_SRC --> CAM_SRC
    
    PREP --> DETECT
    DETECT --> SEG
    SEG --> VERDICT
    
    PREP -.->|Save| INPUT
    VERDICT -.->|Save| OUTPUT
    CAM_SRC -.->|Record| VIDEO
    DETECT -.->|Runs| RUNS
    
    VERDICT --> API_OUT
    VERDICT --> VIS
    CAM_SRC --> WS_OUT
    VIS --> OUTPUT
    
    style CAM_SRC fill:#4caf50
    style FILE_SRC fill:#8bc34a
    style PLC_SRC fill:#cddc39
    style VERDICT fill:#ff9800
    style API_OUT fill:#2196f3,color:#fff
```

## 6. Verdict Engine Decision Tree

```mermaid
graph TD
    START([Defect Detected]) --> CLASS{Get Defect<br/>Class}
    
    CLASS --> CHECK1{Is Always NG?<br/>BamDinhKhongTot<br/>NganMach<br/>VetLom<br/>Xuoc<br/>DiVatDuongMach}
    CHECK1 -->|Yes| NG1[NG: Always Fail]
    
    CHECK1 -->|No| CHECK2{Total Defects<br/>>= 3?}
    CHECK2 -->|Yes| NG2[NG: Too Many Defects]
    
    CHECK2 -->|No| TYPE{Defect Type?}
    
    TYPE -->|KhuyetMach| SAM1[SAM: Measure<br/>Trace Width]
    SAM1 --> RULE1{defect_width ≤<br/>1/3 * trace_width?}
    RULE1 -->|Yes| OK1[OK]
    RULE1 -->|No| NG3[NG: Too Wide]
    
    TYPE -->|ThuaDong| LEN1{length > 1.3mm?}
    LEN1 -->|Yes| NG4[NG: Too Long]
    LEN1 -->|No| OK2[OK]
    
    TYPE -->|ThuaDongDuongMach| LEN2{length > 1.3mm?}
    LEN2 -->|Yes| NG5[NG: Too Long]
    LEN2 -->|No| SAM2[SAM: Measure<br/>Line Width]
    SAM2 --> RULE2{width > 30%<br/>* line_width?}
    RULE2 -->|Yes| NG6[NG: Too Wide]
    RULE2 -->|No| OK3[OK]
    
    TYPE -->|ThieuDong| LEN3{length > 1.3mm?}
    LEN3 -->|Yes| NG7[NG: Too Long]
    LEN3 -->|No| SAM3[SAM: Measure<br/>Copper Width]
    SAM3 --> RULE3{length < 1/3<br/>* copper_width?}
    RULE3 -->|Yes| OK4[OK]
    RULE3 -->|No| NG8[NG: Too Long]
    
    TYPE -->|DiVat| LEN4{length < 1.3mm?}
    LEN4 -->|Yes| OK5[OK<br/>Requires Recheck]
    LEN4 -->|No| NG9[NG: Too Big]
    
    TYPE -->|Others| OK6[OK]
    
    style START fill:#4caf50,color:#fff
    style NG1 fill:#f44336,color:#fff
    style NG2 fill:#f44336,color:#fff
    style NG3 fill:#f44336,color:#fff
    style NG4 fill:#f44336,color:#fff
    style NG5 fill:#f44336,color:#fff
    style NG6 fill:#f44336,color:#fff
    style NG7 fill:#f44336,color:#fff
    style NG8 fill:#f44336,color:#fff
    style NG9 fill:#f44336,color:#fff
    style OK1 fill:#8bc34a
    style OK2 fill:#8bc34a
    style OK3 fill:#8bc34a
    style OK4 fill:#8bc34a
    style OK5 fill:#cddc39
    style OK6 fill:#8bc34a
    style SAM1 fill:#ff9800
    style SAM2 fill:#ff9800
    style SAM3 fill:#ff9800
```

## 7. SICK Camera Stream Architecture

```mermaid
sequenceDiagram
    participant F as Flutter App
    participant WS as WebSocket Server<br/>(Port 8999)
    participant IC4 as IC4 FrameListener
    participant CAM as SICK Camera
    
    F->>WS: Connect WebSocket
    activate WS
    Note over WS: Add client to set
    
    WS->>IC4: Start capture thread
    activate IC4
    
    loop Every ~33ms (30 FPS)
        CAM->>IC4: Frame ready callback
        IC4->>IC4: Get frame from queue
        IC4->>IC4: cv2.imencode(JPEG)
        
        IC4->>WS: Update current_frame_jpeg
        
        WS->>F: Send binary JPEG
        Note over F: Image.memory(bytes)
    end
    
    F->>WS: Disconnect
    Note over WS: Remove client from set
    
    deactivate IC4
    deactivate WS
```

## 8. Class Diagram - Core Components

```mermaid
classDiagram
    class InspectionPipeline {
        +config: PipelineConfig
        +multiclass_detector: ONNXMultiClassDetector
        +single_ensemble: ONNXSingleClassEnsemble
        +sam_segmenter: SAMTraceSegmenter
        +verdict_engine: VerdictEngine
        +inspect(image_bgr) List~InspectionResult~
    }
    
    class ONNXMultiClassDetector {
        +model_path: str
        +conf_threshold: float
        +session: InferenceSession
        +predict(image_bgr) List~Detection~
        -preprocess(image) ndarray
        -postprocess(outputs) List~Detection~
    }
    
    class ONNXSingleClassEnsemble {
        +model_paths: List~str~
        +class_names: List~str~
        +sessions: List~InferenceSession~
        +predict(image_bgr) List~Detection~
        -predict_single(image, session) List~Detection~
        -nms_merge(all_detections) List~Detection~
    }
    
    class SAMTraceSegmenter {
        +model: SAM
        +pixel_size_um: float
        +segment(image, detection) SegmentationResult
        -predict_mask(image, points) ndarray
    }
    
    class VerdictEngine {
        +standards: QualityStandards
        +evaluate_single_defect(detection, segmentation) DefectVerdict
        -check_always_ng(class_name) bool
        -check_size_criteria(detection) VerdictReason
    }
    
    class Detection {
        +class_name: str
        +conf: float
        +poly: ndarray
        +bbox: List~float~
        +width: float
        +length: float
    }
    
    class SegmentationResult {
        +mask: ndarray
        +width_px: float
        +width_mm: float
        +p_left: ndarray
        +p_right: ndarray
    }
    
    class InspectionResult {
        +detection: Detection
        +segmentation: SegmentationResult
        +verdict: str
        +reason: VerdictReason
    }
    
    InspectionPipeline --> ONNXMultiClassDetector
    InspectionPipeline --> ONNXSingleClassEnsemble
    InspectionPipeline --> SAMTraceSegmenter
    InspectionPipeline --> VerdictEngine
    
    ONNXMultiClassDetector ..> Detection
    ONNXSingleClassEnsemble ..> Detection
    SAMTraceSegmenter ..> SegmentationResult
    VerdictEngine ..> InspectionResult
    
    InspectionResult --> Detection
    InspectionResult --> SegmentationResult
```

## 9. Deployment Architecture

```mermaid
graph TB
    subgraph Server["Production Server"]
        subgraph Docker["Docker Containers (Optional)"]
            AI_CONT[AI API Container<br/>:8082]
            PLC_CONT[PLC Gateway Container<br/>:8083]
            CAM_CONT[Camera Stream Container<br/>:8999]
        end
        
        subgraph Python["Python Processes"]
            AI_PROC[uvicorn ai_api:app<br/>--port 8082]
            PLC_PROC[uvicorn plc_gateway:app<br/>--port 8083]
            CAM_PROC[python run_sick_camera.py<br/>--port 8999]
        end
    end
    
    subgraph Network["Network"]
        LAN[LAN: 192.168.3.x]
        PLC_NET[PLC: 192.168.3.1]
        CAM_NET[Camera: 192.168.3.x]
    end
    
    subgraph Client["Client Devices"]
        FLUTTER[Flutter App<br/>Windows/Android]
    end
    
    FLUTTER -->|HTTP REST| AI_CONT
    FLUTTER -->|HTTP REST| PLC_CONT
    FLUTTER -->|WebSocket| CAM_CONT
    
    AI_CONT --> AI_PROC
    PLC_CONT --> PLC_PROC
    CAM_CONT --> CAM_PROC
    
    PLC_PROC --> LAN
    LAN --> PLC_NET
    CAM_PROC --> LAN
    LAN --> CAM_NET
    
    style Server fill:#e1f5ff
    style Docker fill:#fff3e0
    style Python fill:#f3e5f5
    style Network fill:#e8f5e9
    style Client fill:#fce4ec
```

---

## Legend

- 🟢 **Green**: Input/Start points
- 🔵 **Blue**: Output/End points
- 🟠 **Orange**: Processing/Critical steps
- 🔴 **Red**: Failure/NG states
- 🟡 **Yellow**: Warning/Special cases
