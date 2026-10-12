# ECMS – Hệ thống Quản lý Trung tâm Tiếng Anh

Đồ án môn **IE103 – Quản lý thông tin** · Trường Đại học Công nghệ Thông tin – ĐHQG TP.HCM · **Nhóm 1**

- 📋 **Kế hoạch & phân công chi tiết:** https://nhutruong-uit.github.io/ecms/
- 🗂️ **Bảng công việc:** tab [Projects](https://github.com/nhutruong-uit/ecms/projects) của repo
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
| 3. Xử lý thông tin | ≥ 25 truy vấn SQL, XPath/XQuery; xác thực, phân quyền, view, backup/restore, import/export; procedure, function, trigger, cursor |
| 4. Trình bày thông tin | Ứng dụng web Streamlit: menu theo vai trò, form CRUD và master–detail, báo cáo PDF/Excel, dashboard |
| 5. Mô hình CSDL tiên tiến | Chuyển sang mô hình hướng đối tượng, thiết kế CSDL phân tán theo chi nhánh, chuyển sang MongoDB |

## Công nghệ

- **CSDL:** Microsoft SQL Server 2022 (Windows: SSMS · macOS: Docker)
- **Ứng dụng web:** Python 3.11+, Streamlit, pyodbc (ODBC Driver 18), pandas, Plotly
- **Báo cáo:** reportlab (PDF), openpyxl (Excel)
- **NoSQL (Chương 5):** MongoDB
- **Thiết kế:** draw.io, Mermaid

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

## Cài đặt & chạy

Hướng dẫn chi tiết sẽ có ở `docs/SETUP.md` (task T03).

## Làm việc nhóm

Xem [CONTRIBUTING.md](CONTRIBUTING.md): quy trình nhánh, commit, pull request, Definition of Done và cách commit đúng tên người phụ trách.
