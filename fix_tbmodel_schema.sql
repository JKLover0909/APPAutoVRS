-- ============================================================
-- FIX tbModel TABLE SCHEMA
-- Đổi tên cột thành id_model và thêm cột name
-- ============================================================

-- Bước 1: Đổi tên cột PRIMARY KEY thành id_model
-- Lưu ý: Thay 'id' bằng tên cột cũ nếu khác
ALTER TABLE tbModel RENAME COLUMN id TO id_model;

-- Hoặc nếu cột cũ không có tên cụ thể, sử dụng cách khác:
-- ALTER TABLE tbModel RENAME TO tbModel_old;
-- CREATE TABLE tbModel (
--   id_model INTEGER PRIMARY KEY AUTOINCREMENT,
--   name TEXT,
--   line_size REAL,
--   space_size REAL,
--   url_gerber TEXT
-- );
-- INSERT INTO tbModel (id_model, line_size, space_size, url_gerber) 
-- SELECT rowid, line_size, space_size, url_gerber FROM tbModel_old;
-- DROP TABLE tbModel_old;

-- Bước 2: Thêm cột name nếu chưa tồn tại
ALTER TABLE tbModel ADD COLUMN name VARCHAR(255) DEFAULT 'Unknown';

-- ============================================================
-- Kiểm tra kết quả
-- ============================================================
PRAGMA table_info(tbModel);
