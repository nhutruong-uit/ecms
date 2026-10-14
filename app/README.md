# app/

Ứng dụng web Streamlit của ECMS. Chạy: `streamlit run app/main.py` (xem `docs/SETUP.md`).

```
app/
├── main.py            # điểm vào: chưa đăng nhập → trang Đăng nhập; đã đăng nhập → menu theo vai trò
├── core/
│   ├── config.py      # đọc .env
│   ├── db.py          # pyodbc: query / scalar / call_proc; đặt SESSION_CONTEXT (app_user, ma_cn) cho mỗi kết nối
│   ├── auth.py        # sp_DangNhap, phiên trong st.session_state, require_role()
│   ├── menu.py        # cây menu 2 cấp: nhóm → chức năng, vai trò được thấy
│   └── ui.py          # bảng chọn dòng, lỗi cạnh ô nhập (FieldErrors), thông báo, định dạng tiền
├── pages/             # mỗi chức năng một file
│   ├── dang_nhap.py, trang_chu.py
│   ├── danh_muc_*.py      T19 · Như
│   ├── he_thong_*.py      T19 · Như
│   ├── dao_tao_*.py       T20 · Trâm
│   ├── hoc_vien_*.py      T21 · Dương
│   ├── hoc_tap_*.py       T22 · Phú
│   ├── tai_chinh_*.py     T23 · Giang
│   └── bao_cao_*.py       T24 · Giang
└── reports/           # sinh PDF / Excel (reportlab, openpyxl)
```

## Nguyên tắc

- Kết nối bằng login ít quyền **`ecms_app`** (role `r_App`): chỉ `SELECT` view / hàm trả về bảng và `EXECUTE` procedure – mọi bảng bị `DENY`.
  Trang **không** viết `INSERT/UPDATE/DELETE` trực tiếp; đọc qua `vw_*`, ghi qua `sp_*`.
- Lỗi nghiệp vụ do procedure `THROW 500xx` với thông báo tiếng Việt; `ui.run()` hiển thị nguyên văn.
- Mỗi trang gọi `auth.require_role(...)` ở dòng đầu (chặn cả khi gõ thẳng URL).
- Thêm chức năng: tạo `pages/<nhom>_<ten>.py` và thêm một dòng vào `core/menu.py` (trang chưa có file sẽ tự ẩn).
- `ui.options()` cache danh sách chọn 60 giây cho mọi phiên – chỉ dùng cho danh mục, không dùng cho view lọc theo chi nhánh.
