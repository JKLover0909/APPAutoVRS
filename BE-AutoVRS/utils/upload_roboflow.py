import os

from PIL import Image
from roboflow import Roboflow


def upload_images_to_roboflow(image_folder, api_key, workspace, project_name):
    rf = Roboflow(api_key=api_key)
    project = rf.workspace(workspace).project(project_name)

    for filename in os.listdir(image_folder):
        if not filename.lower().endswith(('.jpg', '.jpeg', '.png', '.bmp')):
            continue

        image_path = os.path.join(image_folder, filename)
        print(f"Uploading {filename}...")

        try:
            project.upload(image_path)
        except Exception as e:
            error_msg = str(e)
            print(f"Upload failed: {error_msg}")
            print(f"Attempting to convert and re-upload: {filename}")

            try:
                with Image.open(image_path) as img:
                    rgb_img = img.convert("RGB")
                    rgb_img.save(image_path, "JPEG")

                print(f"Re-uploading converted {filename}...")
                project.upload(image_path)
            except Exception as convert_err:
                print(f"Failed to convert and upload {filename}: {convert_err}")

    print("✅ Upload hoàn tất.")
