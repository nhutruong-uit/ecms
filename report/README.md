# report/

Mỗi chương một file Markdown, viết song song với task. Cuối dự án (T29) ghép thành báo cáo Word / PDF theo mẫu báo cáo thực hành của nhóm (`template/mau-bao-cao-uit.docx`, tách từ Lab 04):

```bash
pip install -r scripts/requirements-docs.txt
python scripts/build_report.py --pdf     # → BaoCao_IE103_Nhom1.docx/.pdf và HuongDanSuDung_ECMS.docx/.pdf
```

Mở file `.docx` bằng Word, chọn **Yes** khi được hỏi cập nhật trường để hiện Mục lục và Danh mục hình ảnh (có số trang).
Nguồn hướng dẫn sử dụng: [`docs/user-guide/huong-dan-su-dung.md`](../docs/user-guide/huong-dan-su-dung.md).

| File | Nội dung | Người viết |
|---|---|---|
| `01-tong-quan.md` | 1.1 Giới thiệu bài toán · 1.2 Khảo sát nghiệp vụ · 1.3 Yêu cầu · 1.4 Quy trình QLTT & DIKW · 1.5 Công cụ QLTT thực tế | Như (T02) |
| `02-to-chuc-thong-tin.md` | 2.1–2.2 ERD & từ điển dữ liệu · 2.3 Class Diagram · 2.4 Mô hình quan hệ & chuẩn hoá · 2.5 RBTV · 2.6 So sánh mô hình phẳng – quan hệ – XML · 2.7 Cài đặt · 2.8 Dữ liệu mẫu | Trâm (T04–T07), Dương (T08) |
| `03-xu-ly-thong-tin.md` | 3.1 Truy vấn SQL & XML · 3.2 An ninh dữ liệu (xác thực, phân quyền, view, backup/restore, import/export) · 3.3 Lập trình CSDL (procedure, function, trigger, cursor) | Dương (T09, T10, T18), Như (T15), Giang (T16, T17), Phú (T11–T14) |
| `04-trinh-bay-thong-tin.md` | 4.1 Menu · 4.2 Form · 4.3 Report & dashboard | Giang (T28), ảnh từ T19–T24 |
| `05-csdl-tien-tien.md` | 5.1 Hướng đối tượng · 5.2 Phân tán · 5.3 NoSQL · 5.4 So sánh, đánh giá | Trâm (T25), Phú (T26), Dương (T27) |
| `06-ket-luan.md` | Kết quả, hạn chế, hướng phát triển, bảng phân công & đóng góp | Như (T29) |

Ảnh minh hoạ để trong `report/images/<chương>/`.
