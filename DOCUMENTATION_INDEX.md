# 📚 AutoVRS Documentation Index

## 📖 Documentation Files

### 1. **README_ANALYSIS.md** ⭐ START HERE
Your entry point to all documentation.
- Overview of the entire system
- What each document covers
- Quick navigation guide
- Learning paths for different roles
- Integration points

**Read this first for**: Complete understanding

---

### 2. **QUICK_REFERENCE.md** ⭐ USE DAILY
Quick lookup guide for fast reference.
- Key ports and services (table format)
- Service communication matrix
- Provider methods & properties
- Database table schemas
- Screen navigation routes
- Typical workflow steps
- Common issues & solutions
- Performance tips

**Use this for**: 
- Quick lookups
- Port numbers
- API endpoints
- Database queries
- Troubleshooting

**Location**: `c:\Users\sonng\Code\APPAutoVRS\QUICK_REFERENCE.md`

---

### 3. **ARCHITECTURE_ANALYSIS.md** ⭐ FOR DEEP UNDERSTANDING
Comprehensive architecture breakdown.
- Technology stack details
- Folder structure with annotations
- App entry point & lifecycle
- Backend services explanation
- API communication flows
- Data models & database relationships
- Key services & providers documentation
- Manual VRS screen workflow
- All dependencies listed

**Read this for**:
- Understanding system design
- How components interact
- Service responsibilities
- Database relationships
- Authentication flow

**Location**: `c:\Users\sonng\Code\APPAutoVRS\ARCHITECTURE_ANALYSIS.md`

---

### 4. **API_FLOW_DETAILED.md** ⭐ FOR INTEGRATION
Technical deep-dive into API communication.
- QCamber REST API flow (PCB capture)
- AutoVRS WebSocket flow (video streaming)
- AI Detection flow (defect detection)
- Manual VRS screen integration
- Database integration
- Complete workflows with ASCII diagrams
- Step-by-step process descriptions

**Read this for**:
- Understanding API interactions
- Debugging communication issues
- Implementing new features
- Testing integration points

**Location**: `c:\Users\sonng\Code\APPAutoVRS\API_FLOW_DETAILED.md`

---

## 🎯 How to Use This Documentation

### 👨‍💻 Frontend Developer (Flutter/Dart)
1. **Start**: README_ANALYSIS.md → "Learning Paths" section
2. **Read**: ARCHITECTURE_ANALYSIS.md → "Kiến Trúc Flutter App"
3. **Reference**: QUICK_REFERENCE.md → Keep handy
4. **Deep-dive**: ARCHITECTURE_ANALYSIS.md → "Key Services & Providers"
5. **Code**: Study `App/lib/screens/vrs/manual_vrs_screen.dart`

---

### 🔧 Backend Developer (Python/AI)
1. **Start**: QUICK_REFERENCE.md → "Key Ports"
2. **Study**: API_FLOW_DETAILED.md → All flows
3. **Reference**: QUICK_REFERENCE.md → "Service Communication Matrix"
4. **Code**: Study `BE-AutoVRS/TestRestAPI.ipynb`
5. **Debug**: Use QUICK_REFERENCE.md → "Common Issues & Solutions"

---

### 🔗 Integration Developer
1. **Start**: ARCHITECTURE_ANALYSIS.md → "API Communication Flow"
2. **Deep-dive**: API_FLOW_DETAILED.md → All detailed flows
3. **Reference**: QUICK_REFERENCE.md → Communication matrix
4. **Test**: Use TestRestAPI.ipynb as reference
5. **Debug**: Cross-reference all three docs

---

### 🚀 New Team Member
1. **First**: README_ANALYSIS.md (10 minutes)
2. **Overview**: ARCHITECTURE_ANALYSIS.md → "Tổng Quan" section
3. **Key Info**: QUICK_REFERENCE.md → Tables & matrices
4. **Details**: Choose one documentation based on your role
5. **Code**: Study the corresponding source files

---

## 📋 Quick Navigation

### 🔌 Ports & Services
**File**: QUICK_REFERENCE.md → "Key Ports"
- QCamber API: Port 8686
- AutoVRS WebSocket: Port 12345
- AI Detection: Port 8082
- Video Stream: Port 8081

### 📱 UI Screens
**File**: QUICK_REFERENCE.md → "Screen Navigation"
- `/` → Home
- `/manual-vrs` → Main inspection screen
- `/statistics` → Statistics
- `/board-align/:step` → Alignment

### 💾 Database
**File**: QUICK_REFERENCE.md → "Database Tables"
- tbModel → AI Models
- tbLot → Batches
- tbBoard → PCB Boards
- tbDefect → Detected Defects
- tbConfig → Configuration

### 🔄 Workflows
**File**: API_FLOW_DETAILED.md → Workflow sections
- Live Inspection
- PCB Capture
- AI Detection
- Database Integration

### 🐛 Troubleshooting
**File**: QUICK_REFERENCE.md → "Common Issues & Solutions"
- No video → WebSocket issue
- AI fails → Port 8082 issue
- Database locked → Connection issue
- Capture timeout → QCamber busy

---

## 🎓 Topic Index

### Architecture & Design
- **ARCHITECTURE_ANALYSIS.md**: Complete system design
- **API_FLOW_DETAILED.md**: Component interactions
- **QUICK_REFERENCE.md**: High-level overview

### Frontend (Flutter)
- **ARCHITECTURE_ANALYSIS.md**: "Kiến Trúc Flutter App" section
- **QUICK_REFERENCE.md**: "Providers" section
- Source: `App/lib/screens/vrs/manual_vrs_screen.dart`

### Backend (Python)
- **ARCHITECTURE_ANALYSIS.md**: "Backend Services" section
- **API_FLOW_DETAILED.md**: "API Flows" sections
- Source: `BE-AutoVRS/TestRestAPI.ipynb`

### APIs & Communication
- **QUICK_REFERENCE.md**: "Service Communication Matrix"
- **API_FLOW_DETAILED.md**: All flows with diagrams
- **ARCHITECTURE_ANALYSIS.md**: "API Communication Flow"

### Database
- **QUICK_REFERENCE.md**: "Database Tables"
- **ARCHITECTURE_ANALYSIS.md**: "Data Models & Database"
- **API_FLOW_DETAILED.md**: "Database Integration"

### Authentication & Security
- **QUICK_REFERENCE.md**: "Authentication" section
- **ARCHITECTURE_ANALYSIS.md**: Search for "AuthProvider"

### Testing
- **API_FLOW_DETAILED.md**: "Testing" sections
- **QUICK_REFERENCE.md**: "Testing & Notebooks"
- Source: `BE-AutoVRS/TestRestAPI.ipynb`

### Troubleshooting
- **QUICK_REFERENCE.md**: "Common Issues & Solutions"
- **QUICK_REFERENCE.md**: "Debugging"
- **API_FLOW_DETAILED.md**: Each flow has error handling

### Performance
- **QUICK_REFERENCE.md**: "Performance Tips"
- **ARCHITECTURE_ANALYSIS.md**: Memory optimization notes
- **API_FLOW_DETAILED.md**: WebSocket optimization

---

## 📊 Document Comparison Matrix

| Topic | README | QUICK REF | ARCHITECTURE | API FLOW |
|-------|--------|-----------|--------------|----------|
| System Overview | ✅✅ | ✅ | ✅✅✅ | ✅ |
| Ports & Services | ✅ | ✅✅✅ | ✅ | ✅✅ |
| Frontend Code | ✅ | ✅ | ✅✅✅ | ✅ |
| Backend Code | ✅ | ✅ | ✅✅ | ✅✅✅ |
| Database | ✅ | ✅✅ | ✅✅ | ✅ |
| API Details | ✅ | ✅ | ✅ | ✅✅✅ |
| Workflows | ✅ | ✅ | ✅ | ✅✅✅ |
| Troubleshooting | ✅ | ✅✅✅ | ✅ | ✅ |
| Quick Reference | ✅ | ✅✅✅ | ✗ | ✗ |
| Learning Paths | ✅✅ | ✗ | ✗ | ✗ |

---

## 🔗 File Cross-References

### When reading README_ANALYSIS.md
- For details → See ARCHITECTURE_ANALYSIS.md
- For quick info → See QUICK_REFERENCE.md
- For workflows → See API_FLOW_DETAILED.md

### When reading QUICK_REFERENCE.md
- For more details → See ARCHITECTURE_ANALYSIS.md
- For workflows → See API_FLOW_DETAILED.md
- For overview → See README_ANALYSIS.md

### When reading ARCHITECTURE_ANALYSIS.md
- For quick lookup → See QUICK_REFERENCE.md
- For workflows → See API_FLOW_DETAILED.md
- For introduction → See README_ANALYSIS.md

### When reading API_FLOW_DETAILED.md
- For overview → See README_ANALYSIS.md
- For details → See ARCHITECTURE_ANALYSIS.md
- For quick lookup → See QUICK_REFERENCE.md

---

## 📝 Key Concepts Defined

### Defect Detection
**See**: API_FLOW_DETAILED.md → "AI Detection Flow"
Process of using YOLOv11 to identify PCB defects

### Manual VRS Screen
**See**: ARCHITECTURE_ANALYSIS.md → "Manual VRS Screen Flow"
Main UI screen for manual PCB inspection

### State Management (Provider)
**See**: QUICK_REFERENCE.md → "Providers"
Flutter state management using Provider package

### WebSocket Stream
**See**: API_FLOW_DETAILED.md → "Continuous Video Frame Streaming"
Real-time video streaming from AutoVRS server

### QCamberAPI
**See**: API_FLOW_DETAILED.md → "QCamber API Flow"
Python helper class for REST API interactions

---

## 🎯 Common Tasks & Where to Find Info

### "I need to understand the entire system"
1. Read: README_ANALYSIS.md (30 min)
2. Skim: ARCHITECTURE_ANALYSIS.md (20 min)
3. Bookmark: QUICK_REFERENCE.md (reference)

### "I need to debug a WebSocket connection issue"
1. Check: QUICK_REFERENCE.md → "Common Issues & Solutions"
2. Study: API_FLOW_DETAILED.md → "AutoVRS WebSocket Flow"
3. Reference: QUICK_REFERENCE.md → "Debugging"

### "I need to add a new feature to manual inspection"
1. Study: ARCHITECTURE_ANALYSIS.md → "Manual VRS Screen Flow"
2. Reference: Source code → `manual_vrs_screen.dart`
3. Check: QUICK_REFERENCE.md → "Screen Navigation"

### "I need to integrate a new AI model"
1. Study: API_FLOW_DETAILED.md → "AI Detection Flow"
2. Reference: `lib/services/ai_detection_service.dart`
3. Check: QUICK_REFERENCE.md → Port 8082

### "I need to modify the database schema"
1. Study: ARCHITECTURE_ANALYSIS.md → "Data Models & Database"
2. Reference: `lib/services/local_database_service.dart`
3. Check: QUICK_REFERENCE.md → "Database Tables"

---

## 📞 Support & References

### For Port Information
→ QUICK_REFERENCE.md → "Key Ports"

### For API Endpoints
→ QUICK_REFERENCE.md → "Service Communication Matrix"
→ API_FLOW_DETAILED.md → Specific flow section

### For Database Queries
→ QUICK_REFERENCE.md → "Database Tables"
→ ARCHITECTURE_ANALYSIS.md → "Data Models & Database"

### For Troubleshooting
→ QUICK_REFERENCE.md → "Common Issues & Solutions"
→ QUICK_REFERENCE.md → "Debugging"

### For Code References
→ ARCHITECTURE_ANALYSIS.md → "File Structure"
→ README_ANALYSIS.md → "Learning Paths"

---

## ✨ Pro Tips

1. **Bookmark QUICK_REFERENCE.md** - You'll use it daily
2. **Keep README_ANALYSIS.md open** when onboarding new team members
3. **Use API_FLOW_DETAILED.md** when debugging communication issues
4. **Reference ARCHITECTURE_ANALYSIS.md** for design discussions
5. **Cross-reference documents** for comprehensive understanding

---

## 📋 File Metadata

```
README_ANALYSIS.md
├─ Size: Overview & Navigation
├─ Read Time: 10-15 minutes
├─ Audience: Everyone
└─ Purpose: Entry point & guide

QUICK_REFERENCE.md
├─ Size: Reference tables & lists
├─ Read Time: Browse as needed
├─ Audience: Developers (daily use)
└─ Purpose: Quick lookups

ARCHITECTURE_ANALYSIS.md
├─ Size: Comprehensive documentation
├─ Read Time: 30-45 minutes
├─ Audience: Developers & architects
└─ Purpose: System understanding

API_FLOW_DETAILED.md
├─ Size: Technical deep-dive
├─ Read Time: 20-30 minutes
├─ Audience: Integration developers
└─ Purpose: API interactions
```

---

## 🎓 Learning Recommendations

### Week 1: Foundation
- Day 1: Read README_ANALYSIS.md + QUICK_REFERENCE.md
- Day 2-3: Read ARCHITECTURE_ANALYSIS.md
- Day 4-5: Read API_FLOW_DETAILED.md

### Week 2: Hands-On
- Deep-dive into your specific domain (frontend/backend)
- Study relevant source code files
- Run TestRestAPI.ipynb for testing

### Week 3: Integration
- Work on your first feature/fix
- Use documentation as reference
- Understand workflows end-to-end

---

**Last Updated**: October 20, 2025  
**Generated by**: GitHub Copilot  
**Version**: 1.0
