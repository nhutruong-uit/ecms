# docs/design/

Sơ đồ và tài liệu thiết kế (file nguồn + ảnh `.png` chèn vào báo cáo).

ERD (Hình 2.1) và sơ đồ lớp (Hình 2.3) vẽ bằng toạ độ đặt tay: `python3 docs/design/erd.py`, `python3 docs/design/class-diagram.py` sinh `.svg` và `.png` (thư viện chung `scripts/so_do.py`, cần `rsvg-convert`); script in ra các lỗi bố cục nếu nhãn chồng nhau hay đường cắt qua hình. Các sơ đồ CSDL và Hình 2.4 trong `report/images/ch2/` dựng cùng cách. File `.drawio` là bản vẽ ban đầu, không còn dùng trong báo cáo.

| File | Task |
|---|---|
| `quy-trinh-nghiep-vu.drawio` | T02 |
| `erd.py` (`erd.drawio` bản đầu) | T04 |
| `class-diagram.py` (`class-diagram.drawio` bản đầu) | T05 |
| `relational-schema.md`, `flat-example.xlsx` | T06 |
| `db-diagram.png` | T07 |
| `odl-schema.md` | T25 |
| `menu-tree.png` | T28 |
