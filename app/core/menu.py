"""Cây menu theo vai trò (T19). Nguyên tắc Chương 4: rộng và nông – tối đa 2 cấp (nhóm → chức năng),
nhóm theo nghiệp vụ, ẩn mục người dùng không có quyền.

Thêm chức năng mới: tạo file trong app/pages/ và thêm một dòng vào MENU. Trang chưa có file sẽ tự ẩn.
"""
from pathlib import Path

PAGES_DIR = Path(__file__).resolve().parent.parent / "pages"

QL, GVU, KT, GV, HV = "QuanLy", "GiaoVu", "KeToan", "GiaoVien", "HocVien"
ALL = (QL, GVU, KT, GV, HV)

# (nhóm, file, tiêu đề, icon, vai trò được thấy)
MENU = [
    ("", "trang_chu.py", "Trang chủ", ":material/home:", ALL),

    ("Danh mục", "danh_muc_chi_nhanh.py", "Chi nhánh, phòng, ca học", ":material/apartment:", (QL,)),
    ("Danh mục", "danh_muc_nhan_vien.py", "Nhân viên & giáo viên", ":material/badge:", (QL, KT)),

    ("Đào tạo", "dao_tao_khoa_hoc.py", "Chương trình & khoá học", ":material/menu_book:", (QL, GVU)),
    ("Đào tạo", "dao_tao_lop_hoc.py", "Lớp học", ":material/groups:", (QL, GVU)),
    ("Đào tạo", "dao_tao_lich_hoc.py", "Xếp lịch & buổi học", ":material/calendar_month:", (QL, GVU)),

    ("Học viên", "hoc_vien_ho_so.py", "Hồ sơ học viên", ":material/person_search:", (QL, GVU)),
    ("Học viên", "hoc_vien_kiem_tra.py", "Kiểm tra đầu vào", ":material/quiz:", (QL, GVU)),
    ("Học viên", "hoc_vien_ghi_danh.py", "Ghi danh", ":material/how_to_reg:", (QL, GVU)),
    ("Học viên", "hoc_vien_cua_toi.py", "Lịch học & kết quả của tôi", ":material/school:", (HV,)),

    ("Học tập", "hoc_tap_diem_danh.py", "Điểm danh", ":material/fact_check:", (GV, QL)),
    ("Học tập", "hoc_tap_nhap_diem.py", "Nhập điểm", ":material/grading:", (GV, QL)),
    ("Học tập", "hoc_tap_canh_bao.py", "Cảnh báo chuyên cần", ":material/warning:", (GV, GVU, QL)),

    ("Tài chính", "tai_chinh_phieu_thu.py", "Lập phiếu thu", ":material/receipt_long:", (KT, QL)),
    ("Tài chính", "tai_chinh_cong_no.py", "Công nợ", ":material/account_balance_wallet:", (KT, QL, GVU)),

    ("Báo cáo", "bao_cao_dashboard.py", "Dashboard", ":material/dashboard:", (QL, KT)),
    ("Báo cáo", "bao_cao_danh_sach.py", "Báo cáo & xuất file", ":material/summarize:", (QL, KT, GVU, GV)),

    ("Hệ thống", "he_thong_tai_khoan.py", "Tài khoản", ":material/manage_accounts:", (QL,)),
    ("Hệ thống", "he_thong_nhat_ky.py", "Nhật ký hệ thống", ":material/history:", (QL,)),
    ("Hệ thống", "he_thong_doi_mat_khau.py", "Đổi mật khẩu", ":material/key:", ALL),
    ("Hệ thống", "he_thong_ket_noi.py", "Kiểm tra kết nối", ":material/lan:", (QL,)),
]


def menu_for(role: str) -> dict[str, list[tuple[str, str, str]]]:
    """{nhóm: [(file, tiêu đề, icon)]} cho vai trò, chỉ gồm trang đã có file."""
    out: dict[str, list[tuple[str, str, str]]] = {}
    for group, file, title, icon, roles in MENU:
        if role in roles and (PAGES_DIR / file).exists():
            out.setdefault(group, []).append((file, title, icon))
    return out
