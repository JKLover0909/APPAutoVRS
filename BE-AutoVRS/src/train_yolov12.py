import os
import json
import argparse
from datetime import datetime
from ultralytics import YOLO
from glob import glob
import re

def evaluate_on_known_defect_images(model_path, image_dir, confidence_threshold=0.05):
    """
    Đánh giá mô hình trên tập ảnh chỉ chứa lỗi khuyết mạch (không có annotation).
    """
    model = YOLO(model_path)
    missing_detection_count = 0
    correct_detection_count = 0
    total_images = 0

    image_paths = glob(os.path.join(image_dir, "*.jpg")) + glob(os.path.join(image_dir, "*.png")) + glob(os.path.join(image_dir, "*.bmp"))

    for image_path in image_paths:
        try:
            results = model.predict(image_path, conf=0.01, verbose=False)[0]  # lấy tất cả dự đoán
            preds = results.obb
            confidences = preds.conf.tolist() if preds else []

            found_tp = any(conf > confidence_threshold for conf in confidences)

            if found_tp:
                correct_detection_count += 1
            else:
                missing_detection_count += 1

            total_images += 1
        except Exception as e:
            print(f"⚠️ Lỗi xử lý ảnh {image_path}: {e}")

    if total_images == 0:
        return {
            "known_defect_eval": {
                "total_images": 0,
                "correct_detections": 0,
                "missing_detections": 0,
                "tp_rate": None,
                "fn_rate": None
            }
        }

    return {
        "known_defect_eval": {
            "total_images": total_images,
            "correct_detections": correct_detection_count,
            "missing_detections": missing_detection_count,
            "tp_rate": round(correct_detection_count / total_images, 3),
            "fn_rate": round(missing_detection_count / total_images, 3)
        }
    }


def evaluate_on_other_defect_images(model_path, image_dir, confidence_threshold=0.5):
    """
    Đánh giá mô hình khi đưa vào ảnh của các loại lỗi khác (không phải khuyết mạch).
    """
    model = YOLO(model_path)
    false_positive_count = 0
    true_negative_count = 0
    total_images = 0

    image_paths = glob(os.path.join(image_dir, "*.jpg")) + glob(os.path.join(image_dir, "*.png")) + glob(os.path.join(image_dir, "*.bmp"))

    for image_path in image_paths:
        try:
            results = model.predict(image_path, conf=0.01, verbose=False)[0]  # lấy tất cả dự đoán
            preds = results.obb
            # predicted_classes = preds.cls.tolist() if preds else []
            confidences = preds.conf.tolist() if preds else []

            found_fp = any(conf > confidence_threshold for conf in confidences)

            if found_fp:
                false_positive_count += 1
            else:
                true_negative_count += 1

            total_images += 1
        except Exception as e:
            print(f"⚠️ Lỗi xử lý ảnh {image_path}: {e}")

    if total_images == 0:
        return {
            "other_defect_eval": {
                "total_images": 0,
                "false_positives": 0,
                "true_negatives": 0,
                "fp_rate": None,
                "tn_rate": None
            }
        }

    return {
        "other_defect_eval": {
            "total_images": total_images,
            "false_positives": false_positive_count,
            "true_negatives": true_negative_count,
            "fp_rate": round(false_positive_count / total_images, 3),
            "tn_rate": round(true_negative_count / total_images, 3)
        }
    }



def evaluate_and_save_metrics(model_path, data_yaml, output_dir, prefix="", other_defect_image_dir=None, known_defect_dir=None):
    try:
        model = YOLO(model_path)
        splits = ["train", "val", "test"]
        split_metrics = {}

        def to_float(val):
            return float(val) if hasattr(val, '__float__') else float(val[0])

        for split in splits:
            try:
                results = model.val(data=data_yaml, split=split)
                split_metrics[split] = {
                    "precision": round(to_float(results.box.p), 3),
                    "recall": round(to_float(results.box.r), 3),
                    "mAP50": round(to_float(results.box.map50), 3),
                    "mAP50-95": round(to_float(results.box.map), 3)
                }
            except Exception as e:
                print(f"⚠️ Error evaluating split '{split}': {e}")
                split_metrics[split] = {
                    "precision": None,
                    "recall": None,
                    "mAP50": None,
                    "mAP50-95": None
                }

        average_metrics = {}
        keys = ["precision", "recall", "mAP50", "mAP50-95"]
        for key in keys:
            values = [split_metrics[split][key] for split in split_metrics if split_metrics[split][key] is not None]
            if values:
                average_metrics[key] = round(sum(values) / len(values), 3)
            else:
                average_metrics[key] = None

        final_metrics = {
            "model_path": model_path,
            "datetime": datetime.now().isoformat(),
            "train": split_metrics.get("train", {}),
            "val": split_metrics.get("val", {}),
            "test": split_metrics.get("test", {}),
            "average": average_metrics
        }

        # Đánh giá ảnh lỗi khác (nếu có cung cấp)
        if other_defect_image_dir and os.path.exists(other_defect_image_dir):
            print(f"\n🔍 Đánh giá trên ảnh các lỗi khác trong: {other_defect_image_dir}")
            other_defect_results = evaluate_on_other_defect_images(model_path, other_defect_image_dir)
            final_metrics.update(other_defect_results)

        if known_defect_dir and os.path.exists(known_defect_dir):
            print(f"✅ Đánh giá ảnh bo vàng : {known_defect_dir}")
            known_defect_results = evaluate_on_known_defect_images(model_path, known_defect_dir)
            final_metrics.update(known_defect_results)

        os.makedirs(output_dir, exist_ok=True)
        output_path = os.path.join(output_dir, f"{prefix}_metrics.json")
        with open(output_path, "w") as f:
            json.dump(final_metrics, f, indent=4)

        print(f"✅ Saved metrics to {output_path}")

    except Exception as e:
        print(f"❌ Error evaluating {model_path}: {e}")






def safe_filename(name):
    # Loại bỏ ký tự không hợp lệ cho Windows file/folder
    return re.sub(r'[<>:"/\\|?*]', '_', name)

def train_yolov12(task, data_yaml, model_output_dir, model_name="yolov12n.pt", epochs=500, imgsz=640, batch = 32, workers=4):
    if not os.path.exists(data_yaml):
        print(f"Không tìm thấy data.yaml tại: {data_yaml}")
        return

    dataset_name = os.path.basename(os.path.dirname(data_yaml))
    dataset_name = safe_filename(dataset_name)  # Sửa ở đây

    print(f"\nTraining model from scratch: {dataset_name}")
    try:
        model = YOLO(model_name)
    except Exception as e:
        print(f"❌ Không thể load model {model_name}: {e}")
        return

    model.train(
        data=data_yaml,
        task=task,
        epochs=epochs,
        imgsz=imgsz,
        batch=batch,
        workers=workers,
        device="cuda",
        project=model_output_dir,
        name=dataset_name,
        save_period=0,
        exist_ok=True,
        verbose=True,
        
        # # Augment tuned for small defects
        mosaic=1.0,
        mixup=0.0,
        degrees=0.0,
        translate=0.1,
        scale=0.3,
        hsv_h=0.015, hsv_s=0.7, hsv_v=0.4,

        # (Optional) freeze backbone if needed
        # freeze=10,
    )
    # weights_dir = os.path.join(model_output_dir, dataset_name, "weights")
    # for name in ["best.pt", "last.pt"]:
    #     model_path = os.path.join(weights_dir, name)
    #     if os.path.exists(model_path):
    #         evaluate_and_save_metrics(
    #             model_path=model_path,
    #             data_yaml=data_yaml,
    #             output_dir=weights_dir,
    #             prefix=name.replace(".pt", ""),
    #             other_defect_image_dir=args.other_defect_image_dir,
    #             known_defect_dir=args.known_defect_dir
    #         )


def finetune_model(task, model_path, data_yaml, model_output_dir, epochs=500, imgsz=640, batch =64):
    best_model_path = os.path.join(model_path, "weights", "best.pt")
    model_name = os.path.basename(model_path)

    if not os.path.exists(best_model_path):
        print(f"Bỏ qua {model_name} vì không có best.pt")
        return

    if not os.path.exists(data_yaml):
        print(f"Bỏ qua {model_name} vì không có dataset: {data_yaml}")
        return

    print(f"\n🚀 Fine-tuning model: {model_name}")
    try:
        model = YOLO(best_model_path)
    except Exception as e:
        print(f"❌ Không thể load model {best_model_path}: {e}")
        return

    model.train(
        data=data_yaml,
        task=task,
        epochs=epochs,
        imgsz=imgsz,
        workers=4,
        batch=batch,
        project=model_output_dir,
        name=model_name,
        exist_ok=True,
        verbose=True
    )


if __name__ == "__main__":
    parser = argparse.ArgumentParser()
    parser.add_argument("--data_dir", type=str, help="Thư mục chứa các dataset con")
    parser.add_argument("--model_name", type=str, default="yolov12n.pt", help="Tên model YOLOv12 gốc")
    parser.add_argument("--model_input_dir", type=str, help="Thư mục chứa mô hình đã train (best.pt)")
    parser.add_argument("--model_output_dir", type=str, default="runs/train", help="Nơi lưu model output")
    parser.add_argument("--task", type=str, default="detect", choices=["detect", "obb"], help="Loại bài toán: detect hoặc obb")
    parser.add_argument("--epochs", type=int, default=500, help="Số epochs để train hoặc fine-tune")
    parser.add_argument("--workers", type=int, default=4, help="Số workers cho DataLoader")
    parser.add_argument("--batch", type=int, default=16, help="Kích thước batch")
    parser.add_argument("--imgsz", type=int, default=640)
    parser.add_argument("--mode", choices=["train", "finetune"], required=True, help="train hoặc finetune")
    parser.add_argument("--other_defect_image_dir", type=str, help="Thư mục chứa ảnh lỗi khác để đánh giá FP")
    parser.add_argument("--known_defect_dir", type=str, help="Thư mục chứa ảnh lỗi khuyết mạch để đánh giá TP")

    args = parser.parse_args()
    # conda activate D:\aoi_inspection\.conda
    # python D:\aoi_inspection\src\train_yolov12.py --mode train --task obb --data_dir "E:\data\OBBDatasetTrain_Fitbox\singleclass_datasets" --model_output_dir "E:\models\FitOBB\MultiClassModelOBB_fitobb_Ver3\singleclass_model" --epochs 120 --workers 4 --batch 32 --model_name "C:\Users\WIN\Downloads\yolo11s-obb.pt" --other_defect_image_dir "D:\aoi_inspection\data\Other_Defect_Eval_2" --known_defect_dir "D:\aoi_inspection\data\Test Khyết Mạch\Bo Vàng"
    if args.mode == "train":
        for subdir in os.listdir(args.data_dir)[10:]:
            print(f"Processing subdir: {subdir}")
            dataset_dir = os.path.join(args.data_dir, subdir)
            data_yaml = os.path.join(dataset_dir, "data.yaml")
            if os.path.isdir(dataset_dir):
                train_yolov12(
                    data_yaml=data_yaml,
                    task=args.task,
                    model_output_dir=args.model_output_dir,
                    model_name=args.model_name,
                    epochs=args.epochs,
                    imgsz=args.imgsz,
                    batch=args.batch,
                    workers=args.workers
                )
    elif args.mode == "finetune":
        for model_subdir in os.listdir(args.model_input_dir):
            model_path = os.path.join(args.model_input_dir, model_subdir)
            if not os.path.isdir(model_path):
                continue

            data_yaml = os.path.join(args.data_dir, model_subdir, "data.yaml")

            finetune_model(
                model_path=model_path,
                data_yaml=data_yaml,
                task=args.task,
                model_output_dir=args.model_output_dir,
                epochs=args.epochs,
                imgsz=args.imgsz,
                batch=args.batch
            )
    else:
        print(f"Không hỗ trợ chế độ '{args.mode}'. Vui lòng chọn 'train' hoặc 'finetune'.")
        exit(1)
