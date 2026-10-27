# report/

Mỗi chương một file Markdown, viết song song với task. Cuối dự án (T29) ghép thành báo cáo Word / PDF theo mẫu báo cáo thực hành của nhóm (`template/mau-bao-cao-uit.docx`, tách từ Lab 04):

```bash
pip install -r scripts/requirements-docs.txt
python scripts/build_report.py           # → BaoCao_IE103_Nhom1.docx và HuongDanSuDung_ECMS.docx
scripts/export_pdf.sh                    # macOS + Word: cập nhật Mục lục, số trang và xuất PDF giống hệt bản Word
```

PDF nộp bài luôn xuất **bằng Microsoft Word** (`scripts/export_pdf.sh`): khổ A4, Times New Roman 13, mục lục và danh mục hình có
số trang; file `.docx` cũng được thay bằng bản Word đã cập nhật nên mở ra không bị hỏi cập nhật trường. Lần đầu Word có thể
xin quyền truy cập file: bấm **Select…** và chọn file trong `report/.build/` (không xoá thư mục này).
Windows có Word: `.\scripts\export_pdf.ps1` (Word qua COM, không cần thao tác tay). Không có Word: `python scripts/build_report.py --pdf`
in PDF bằng Chrome/Edge (mục lục không có số trang).

Cỡ chữ 13 pt cho thân bài, bảng và chú thích hình / bảng (chú thích in nghiêng); bảng nhiều chữ tự giảm 12 → 11 → 10,5 pt
cho tới khi mỗi hàng trung bình không quá 2,2 / 2,8 dòng chữ (bảng thoáng giữ 13 pt khi không quá 1,8 dòng). Mọi đoạn văn thụt đầu dòng 0,5 cm; riêng khối mã dùng Consolas 10,5 pt
(mỗi dòng mã ≤ 76 ký tự để không bị Word tự xuống dòng). Chú thích hình / bảng nên ngắn để Danh mục hình ảnh, Danh mục
bảng không xuống dòng (khoảng 60 ký tự sau "Hình x.y."). Bảng thấp hơn nửa trang được giữ trọn một trang, bảng cao hơn
được ngắt giữa hai dòng (lặp dòng tiêu đề); hình trên trang dọc cao tối đa 17,5 cm để không đẩy trang trống.
Nguồn hướng dẫn sử dụng: [`docs/user-guide/huong-dan-su-dung.md`](../docs/user-guide/huong-dan-su-dung.md).

| File | Nội dung | Người viết |
|---|---|---|
| `01-tong-quan.md` | Lời mở đầu · 1.1 Giới thiệu bài toán · 1.2 Khảo sát nghiệp vụ · 1.3 Hiện trạng · 1.4 Mục tiêu, phạm vi · 1.5 Đặc tả yêu cầu · 1.6 Quy trình QLTT & DIKW · 1.7 Công cụ QLTT thực tế · 1.8 Công cụ, phương pháp | Như (T02) |
| `02-to-chuc-thong-tin.md` | 2.1–2.2 ERD & từ điển dữ liệu · 2.3 Class Diagram · 2.4 Mô hình quan hệ & chuẩn hoá · 2.5 RBTV · 2.6 So sánh mô hình phẳng – quan hệ – XML · 2.7 Cài đặt · 2.8 Dữ liệu mẫu | Trâm (T04–T07), Dương (T08) |
| `03-xu-ly-thong-tin.md` | 3.1 Truy vấn SQL & XML · 3.2 An ninh dữ liệu (xác thực, phân quyền, view, backup/restore, import/export) · 3.3 Lập trình CSDL (procedure, function, trigger, cursor) | Dương (T09, T10, T18), Như (T15), Giang (T16, T17), Phú (T11–T14) |
| `04-trinh-bay-thong-tin.md` | 4.1 Menu · 4.2 Form · 4.3 Report & dashboard · 4.4 Đánh giá | Giang (T28), ảnh từ T19–T24 |
| `05-csdl-tien-tien.md` | 5.1 Hướng đối tượng · 5.2 Phân tán · 5.3 NoSQL · 5.4 So sánh, đánh giá | Trâm (T25), Phú (T26), Dương (T27) |
| `06-ket-luan.md` | Kết quả, kiểm thử tích hợp, khó khăn, hạn chế, hướng phát triển, bài học, phân công & đóng góp · Tài liệu tham khảo · Phụ lục A, B | Như (T29) |
| `07-phu-luc.md` | Phụ lục C – Từ điển dữ liệu (chuyển từ mục 2.2) | Trâm (T05), Như (T30) |

## Quy ước viết

Theo mẫu báo cáo thực hành Lab 04 của nhóm:

- Mỗi chương mở đầu bằng một đoạn giới thiệu và kết thúc bằng mục **Tiểu kết chương**.
- Mỗi đối tượng kỹ thuật đi theo trình tự **Phân tích → Mã lệnh → Kiểm thử → Kết quả → Nhận xét**; bảng và khối mã luôn có một câu dẫn phía trước.
- Khối mã có dòng tiêu đề: viết ` ```sql title="Mã lệnh – sp_DangKyHoc" ` (hoặc `Kiểm thử – …`, `Kết quả – …`).
- Chú thích hình ngắn gọn, dạng `*Hình x.y – Tên hình*` ngay dưới ảnh; phần giải thích đặt trong đoạn văn trước hình.
- Mọi bảng có chú thích `*Bảng x.y – Tên bảng*` ngay trên bảng (phụ lục: `*Bảng C.1 – …*`), đánh số liên tục trong chương;
  `build_report.py` in cảnh báo khi thiếu chú thích hoặc số nhảy cóc, và sinh Danh mục bảng, Danh mục từ viết tắt.
- Chỉ số dưới / trên viết `<sub>…</sub>`, `<sup>…</sup>`.
- Viết văn xuôi tiếng Việt đầy đủ: không dùng mã task (T11…), không dẫn đường dẫn tệp trong thân bài (gom ở Phụ lục A), số viết theo kiểu Việt Nam (`1.234.000`, `4,22`).

Ảnh minh hoạ để trong `report/images/<chương>/`.
