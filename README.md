# ECMS – Hệ thống Quản lý Trung tâm Tiếng Anh

[![CI](https://github.com/nhutruong-uit/ecms/actions/workflows/ci.yml/badge.svg?branch=main)](https://github.com/nhutruong-uit/ecms/actions/workflows/ci.yml)

Đồ án môn **IE103 – Quản lý thông tin** · Trường Đại học Công nghệ Thông tin – ĐHQG TP.HCM · **Nhóm 1**

- 📋 **Kế hoạch & phân công chi tiết:** https://nhutruong-uit.github.io/ecms/
- 🗂️ **Bảng công việc (GitHub Project):** https://github.com/users/nhutruong-uit/projects/1
- 🐞 **Danh sách task:** [Issues](https://github.com/nhutruong-uit/ecms/issues)

## Thành viên

| STT | Họ và tên | MSSV | Vai trò |
|:---:|---|:---:|---|
| 1 | Đỗ Phạm Minh Trâm | 25540042 | Thiết kế CSDL: ERD, Class Diagram, mô hình quan hệ, DDL · Phân hệ Đào tạo · CSDL hướng đối tượng |
| 2 | Trương Quang Như | 25540022 | **Nhóm trưởng**: khảo sát & yêu cầu, môi trường, xác thực – phân quyền · Đăng nhập, menu, danh mục · Tổng hợp báo cáo |
| 3 | Nguyễn Việt Phú | 25540025 | Lập trình CSDL: procedure, function, trigger, cursor · Phân hệ Học tập · CSDL phân tán |
| 4 | Đỗ Bình Dương | 25540008 | Truy vấn & dữ liệu: dữ liệu mẫu, SQL, XML/XPath/XQuery, import/export · Phân hệ Học viên · NoSQL |
| 5 | Nguyễn Bảo Giang | 25540009 | Trình bày thông tin: view, backup/restore · Thu học phí · Báo cáo & dashboard · Chương 4 |

## Bài toán

Một chuỗi trung tâm tiếng Anh có nhiều chi nhánh, mở các chương trình IELTS, TOEIC, Giao tiếp, Thiếu nhi. Hệ thống quản lý:

- **Danh mục:** chi nhánh, phòng học, ca học, nhân viên, giáo viên và chứng chỉ của giáo viên
- **Đào tạo:** chương trình, khoá học (có khoá tiên quyết), lớp học, lịch học, buổi học
- **Học viên:** hồ sơ, kiểm tra đầu vào (kết quả lưu dạng XML), ghi danh vào lớp
- **Học tập:** điểm danh, điểm giữa kỳ / cuối kỳ, cảnh báo chuyên cần
- **Tài chính:** phiếu thu học phí (master–detail), công nợ
- **Báo cáo:** doanh thu, sĩ số, bảng điểm, dashboard
- **Hệ thống:** tài khoản, phân quyền theo vai trò, nhật ký kiểm toán

## Phạm vi theo đề cương

| Chương | Nội dung trong đồ án |
|---|---|
| 1. Tổng quan | Khảo sát nghiệp vụ, quy trình quản lý thông tin, DIKW, so sánh công cụ thực tế |
| 2. Tổ chức thông tin | ERD, Class Diagram, mô hình quan hệ (3NF), RBTV, so sánh mô hình phẳng – quan hệ – XML, script DDL |
| 3. Xử lý thông tin | ≥ 25 truy vấn SQL, XPath/XQuery; xác thực, phân quyền, view, mã hoá (TLS, TDE), che dữ liệu, kiểm toán (trigger, SQL Server Audit, ledger), backup/restore, import/export; procedure, function, trigger, cursor |
| 4. Trình bày thông tin | Ứng dụng web Streamlit: menu theo vai trò, form CRUD và master–detail, báo cáo PDF/Excel/Word, dashboard |
| 5. Mô hình CSDL tiên tiến | Mô hình hướng đối tượng (OID, 3 chiến lược ánh xạ kế thừa); CSDL phân tán theo chi nhánh (phân mảnh, nửa kết, 2PC, sự cố trạm); chuyển sang MongoDB và so sánh đọc / ghi |

## Công nghệ

- **CSDL:** Microsoft SQL Server 2022 / 2025 (Windows: SSMS · macOS / Linux: Docker, SQL Server 2025)
- **Ứng dụng web:** Python 3.11+, Streamlit, pyodbc (ODBC Driver 18), pandas, Plotly
- **Báo cáo:** reportlab (PDF), openpyxl (Excel), python-docx (Word)
- **Kiểm thử:** script T-SQL (`database/tests/`), pytest + Streamlit AppTest (`tests/`), Playwright chụp ảnh màn hình (`scripts/chup_anh.py`)
- **NoSQL (Chương 5):** MongoDB
- **Thiết kế:** draw.io, Graphviz, Mermaid

## Cấu trúc thư mục

```
ecms/
├── app/          # Ứng dụng web Streamlit
├── database/     # Script SQL, đánh số theo thứ tự chạy (xem database/README.md)
├── data/         # CSV / XML mẫu cho import
├── nosql/        # Demo MongoDB
├── docs/         # GitHub Pages + docs/design (ERD, Class Diagram, ...)
├── report/       # Báo cáo theo chương
├── slides/       # Slide thuyết trình
└── scripts/      # Công cụ: commit-as.sh, sync_issues.py, sync_project.py, ...
```

## Sản phẩm nộp (v1.0.0)

Bản phát hành: [**v1.0.0**](https://github.com/nhutruong-uit/ecms/releases/tag/v1.0.0) – đính kèm báo cáo, hướng dẫn sử dụng (Word + PDF) và slide; mã nguồn đúng với nhánh `main` tại tag `v1.0.0`.

| Tài liệu | File | Nguồn |
|---|---|---|
| Báo cáo đồ án | [`report/BaoCao_IE103_Nhom1.docx`](report/BaoCao_IE103_Nhom1.docx) · [`.pdf`](report/BaoCao_IE103_Nhom1.pdf) | `report/01-…07-*.md` |
| Hướng dẫn sử dụng | [`report/HuongDanSuDung_ECMS.docx`](report/HuongDanSuDung_ECMS.docx) · [`.pdf`](report/HuongDanSuDung_ECMS.pdf) | [`docs/user-guide/huong-dan-su-dung.md`](docs/user-guide/huong-dan-su-dung.md) |
| Slide thuyết trình | [`slides/ECMS_Nhom1.pptx`](slides/ECMS_Nhom1.pptx) | `scripts/build_slides.py` |

Dựng lại từ nguồn:

```bash
pip install -r scripts/requirements-docs.txt
python scripts/chup_anh.py           # chụp lại ảnh màn hình (cần CSDL vừa dựng và ứng dụng đang chạy, xem đầu file)
python scripts/build_report.py       # → report/*.docx
scripts/export_pdf.sh                # macOS + Word: cập nhật mục lục, số trang, xuất PDF  (Windows: .\scripts\export_pdf.ps1)
python scripts/build_slides.py
```

## Cài đặt & chạy

Hướng dẫn chi tiết: [docs/SETUP.md](docs/SETUP.md). Tóm tắt trên macOS:

```bash
cp .env.example .env
docker compose up -d --wait          # SQL Server 2025, chờ "healthy" (đã đổi xong collation)
database/run_all.sh                  # dựng CSDL ECMS (01 → 09)
pip install -r requirements.txt
streamlit run app/main.py            # http://localhost:8501
pytest tests/ -q                     # 125 ca kiểm thử ứng dụng
```

Windows (SQL Server + SSMS): `.\database\run_all.ps1` rồi làm như trên từ bước `pip install`; xem [docs/SETUP.md](docs/SETUP.md).

## Làm việc nhóm

Xem [CONTRIBUTING.md](CONTRIBUTING.md): quy trình nhánh, commit, pull request, Definition of Done và cách commit đúng tên người phụ trách.
