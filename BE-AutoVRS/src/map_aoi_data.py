import os
import re
import shutil
from glob import glob

class AOIMapper:
    def __init__(self, from_path, to_path, min_filename_length=10):
        self.from_path = from_path      # Path to DataAOI (chứa Folder PCI)
        self.to_path = to_path          # Path to VRS
        self.min_filename_length = min_filename_length
        self.pattern = re.compile(r'([Ll]\d+)__([\d\-]+)_([\d]+)_([\d]+)_(.+)')

    def copy_aoi_images(self):
        copied = 0
        missing = 0

        for ma_hang in os.listdir(self.to_path):
            ma_hang_path = os.path.join(self.to_path, ma_hang)
            if not os.path.isdir(ma_hang_path):
                continue

            for ten_loi in os.listdir(ma_hang_path):
                loi_folder = os.path.join(ma_hang_path, ten_loi)
                if not os.path.isdir(loi_folder):
                    continue

                for filename in os.listdir(loi_folder):
                    file_path = os.path.join(loi_folder, filename)
                    name_only, ext = os.path.splitext(filename)

                    if not os.path.isfile(file_path) or len(name_only) < self.min_filename_length:
                        continue

                    match = self.pattern.match(name_only)
                    if not match:
                        print(f'Không khớp regex: {filename}')
                        continue

                    layer = match.group(1).upper()
                    lot = match.group(2)
                    bo_order = match.group(3)
                    aoi_order = match.group(4)

                    # Truy cập từ: DataAOI/Folder_PCI/Mã hàng/Lot/Layer/Thứ tự bo
                    search_folder = os.path.join(self.from_path, ma_hang, lot, layer, bo_order)
                    if not os.path.isdir(search_folder):
                        print(f'Không tìm thấy thư mục: {search_folder}')
                        missing += 1
                        continue

                    pattern_path = os.path.join(search_folder, f"{aoi_order}.*")
                    matched_files = glob(pattern_path)

                    if not matched_files:
                        print(f'Không tìm thấy ảnh AOI: {pattern_path}')
                        missing += 1
                        continue

                    source_img_path = matched_files[0]
                    ext = os.path.splitext(source_img_path)[1]
                    new_name = f"{ma_hang}_{lot}_{layer}_{bo_order}_{aoi_order}_AOIDATA{ext}"
                    dest_path = os.path.join(loi_folder, new_name)

                    shutil.copy2(source_img_path, dest_path)
                    print(f'✅ Copied: {new_name}')
                    copied += 1

        print(f'\nTổng ảnh AOI đã copy: {copied}')
        print(f'Tổng ảnh bị thiếu: {missing}')

    def create_training_data(self, target_root='Data_Training', keyword='AOIDATA'):
        if os.path.exists(target_root):
            shutil.rmtree(target_root)
        os.makedirs(target_root)

        copied_training = 0
        for ma_hang in os.listdir(self.to_path):
            ma_hang_path = os.path.join(self.to_path, ma_hang)
            if not os.path.isdir(ma_hang_path):
                continue

            for ten_loi in os.listdir(ma_hang_path):
                loi_folder = os.path.join(ma_hang_path, ten_loi)
                if not os.path.isdir(loi_folder):
                    continue

                for file in os.listdir(loi_folder):
                    if keyword in file:
                        src_file = os.path.join(loi_folder, file)
                        dest_folder = os.path.join(target_root, ten_loi)
                        os.makedirs(dest_folder, exist_ok=True)
                        shutil.copy2(src_file, os.path.join(dest_folder, file))
                        copied_training += 1

        print(f'\nTổng ảnh có AOIDATA đã sao chép sang {target_root}: {copied_training}')
