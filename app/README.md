# app/

Ứng dụng web Streamlit (khung tạo ở task T03).

```
app/
├── main.py            # điểm vào: đăng nhập + st.navigation (menu theo vai trò)
├── core/              # db.py (pyodbc), auth.py, config.py
├── pages/             # mỗi phân hệ một nhóm trang
│   ├── danh_muc_*.py      T19 · Như
│   ├── he_thong_*.py      T19 · Như
│   ├── dao_tao_*.py       T20 · Trâm
│   ├── hoc_vien_*.py      T21 · Dương
│   ├── hoc_tap_*.py       T22 · Phú
│   ├── tai_chinh_*.py     T23 · Giang
│   └── bao_cao_*.py       T24 · Giang
└── reports/           # sinh PDF / Excel (reportlab, openpyxl)
```

Nguyên tắc: trang chỉ gọi **stored procedure / view / function**, không viết SQL thao tác trực tiếp lên bảng, và kết nối bằng tài khoản ít quyền `r_App` (T15).
