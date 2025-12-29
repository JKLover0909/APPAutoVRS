import os
import subprocess

def export_pt_to_engine(pt_path):
    try:
        print(f"🚀 Exporting: {pt_path}")
        cmd = [
            "yolo", "export",
            f"model={pt_path}",
            f"format=engine",
        ]
        result = subprocess.run(cmd, capture_output=True, text=True)

        if result.returncode == 0:
            print(f"✅ Done: {pt_path} → .engine")
        else:
            print(f"❌ Failed: {pt_path}\n{result.stderr}")
    except Exception as e:
        print(f"⚠️ Error with {pt_path}: {e}")

def batch_convert_pt_to_engine(root_dir):
    found = False
    for subdir, _, files in os.walk(root_dir):
        for file in files:
            if file == "best.pt":
                found = True
                pt_path = os.path.join(subdir, file)
                export_pt_to_engine(pt_path)
    
    if not found:
        print("❗ No best.pt files found.")

if __name__ == "__main__":
    import argparse

    parser = argparse.ArgumentParser(description="Batch convert YOLOv8 .pt to .engine using Ultralytics CLI")
    parser.add_argument("--models_dir", type=str, required=True, help="Directory containing .pt models")
    args = parser.parse_args()

    batch_convert_pt_to_engine(args.models_dir)
