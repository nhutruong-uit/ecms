#!/usr/bin/env python3
"""Sinh dữ liệu cho slide báo cáo tiến độ (docs/tien-do/).

    python scripts/build_tien_do.py

- Đọc database/01_schema.sql → 22 bảng, cột, khoá chính, khoá ngoại (kiểm tra khớp số liệu báo cáo).
- Đọc database/*.sql → tên 40 procedure, 17 function, 14 trigger, 27 view, 3 cursor, đối chiếu với ý nghĩa khai báo trong DOI_TUONG.
- Đọc report/02-to-chuc-thong-tin.md → phụ thuộc hàm và khoá dự tuyển của từng quan hệ (Bảng 2.11).
- Đọc report/01-tong-quan.md → nhóm người dùng, 22 yêu cầu chức năng, 8 phi chức năng, 7 báo cáo (Bảng 1.5 – 1.8).
- Đọc docs/data/tasks.json + `gh issue list` + `git log` → tiến độ kế hoạch so với thực tế.
- Chép ảnh từ report/images vào docs/tien-do/img, vì GitHub Pages chỉ phục vụ thư mục docs/.

Ghi ra docs/tien-do/data/tien-do.js (window.TIEN_DO = …) thay vì .json để mở được cả từ ổ đĩa, không cần máy chủ.
Không có `gh` thì giữ nguyên phần tiến độ của lần sinh trước.
"""
from __future__ import annotations

import json
import re
import shutil
import subprocess
import sys
from datetime import date, datetime, timedelta, timezone
from pathlib import Path

ROOT = Path(__file__).resolve().parent.parent
OUT = ROOT / "docs" / "tien-do"
VN = timezone(timedelta(hours=7))

# Ý nghĩa, nhóm, dạng chuẩn (báo cáo Bảng 2.11), số dòng dữ liệu mẫu (Bảng 2.25)
META = {
    "CHINHANH": ("Chi nhánh trung tâm", "danhmuc", "BCNF", 3),
    "PHONGHOC": ("Phòng học, thực thể yếu theo chi nhánh", "danhmuc", "BCNF", 12),
    "CAHOC": ("Ca học trong ngày", "danhmuc", "BCNF", 6),
    "NGAYLE": ("Ngày lễ, bảng phụ trợ khi sinh buổi học", "danhmuc", "BCNF", 30),
    "NHANVIEN": ("Nhân viên: quản lý, giáo vụ, kế toán, giáo viên", "nhansu", "BCNF", 20),
    "GIAOVIEN": ("Giáo viên, chuyên biệt hoá của NHANVIEN", "nhansu", "BCNF", 10),
    "CHUNGCHI_GV": ("Chứng chỉ giáo viên, thuộc tính đa trị", "nhansu", "BCNF", 15),
    "BANGLUONG": ("Bảng lương theo tháng, là chứng từ", "nhansu", "2NF", 0),
    "CHUONGTRINH": ("Chương trình: IELTS, TOEIC, Giao tiếp, Thiếu nhi", "daotao", "BCNF", 4),
    "KHOAHOC": ("Khoá học, có khoá tiên quyết (đệ quy)", "daotao", "BCNF", 12),
    "LOPHOC": ("Lớp học: một lần mở của khoá học", "daotao", "BCNF", 25),
    "LICHHOC": ("Lịch cố định, liên kết ba ngôi lớp – phòng – ca", "daotao", "1NF", 50),
    "BUOIHOC": ("Buổi học cụ thể, thực thể yếu theo lớp", "daotao", "BCNF", 598),
    "HOCVIEN": ("Hồ sơ học viên", "hocvien", "BCNF", 349),
    "KIEMTRA_DAUVAO": ("Kiểm tra đầu vào, chi tiết lưu dạng XML", "hocvien", "2NF", 357),
    "DANGKY": ("Ghi danh: liên kết N – M học viên và lớp", "hocvien", "2NF", 539),
    "DIEMDANH": ("Điểm danh từng buổi", "hocvien", "1NF", 10063),
    "CANHBAO_CHUYENCAN": ("Cảnh báo chuyên cần, ảnh chụp tại ngày cảnh báo", "hocvien", "2NF", 0),
    "PHIEUTHU": ("Phiếu thu học phí (master)", "taichinh", "BCNF", 501),
    "CT_PHIEUTHU": ("Chi tiết phiếu thu (detail)", "taichinh", "BCNF", 508),
    "TAIKHOAN": ("Tài khoản đăng nhập ứng dụng", "hethong", "BCNF", 80),
    "NHATKY": ("Nhật ký kiểm toán, chỉ được thêm", "hethong", "BCNF", 0),
}

# Cột suy diễn do trigger hoặc procedure duy trì (cột tính toán thì đọc được từ DDL)
DUY_TRI = {
    ("LOPHOC", "SiSoHienTai"): "trg_DangKy_SiSo",
    ("PHIEUTHU", "TongTien"): "trg_CTPhieuThu_TongTien",
    ("DANGKY", "TrangThaiHP"): "trg_CTPhieuThu_TongTien",
    ("DANGKY", "KetQua"): "trg_DangKy_KetQua",
    ("KIEMTRA_DAUVAO", "DiemTong"): "sp_GhiKetQuaKiemTra",
}

# Việc của Sprint 4 nhóm báo cáo là còn làm, dù issue trên GitHub đã đóng
CON_LAI = {"T29", "T30"}

ANH = [
    "ch3/lop-bao-ve.png", "ch3/xac-thuc-phien.png", "ch3/giao-dich-thu-hoc-phi.png", "ch3/sao-luu-phuc-hoi.png",
    "ch4/07_xep_lich.jpg", "ch4/10_ghi_danh.jpg", "ch4/11_diem_danh.jpg", "ch4/14_phieu_thu.jpg",
    "ch4/16_dashboard.jpg", "ch4/18_nhat_ky.jpg", "ch4/19_pdf_phieu_thu.jpg",
    "ch5/phan-manh.png", "ch5/hai-pha.png",
]


# Ý nghĩa từng đối tượng lập trình của CSDL ECMS: (nhóm, tên, ý nghĩa). Khi sinh, tên phải khớp đúng với database/*.sql.
DOI_TUONG = {
    "procedure": [
        ("Nghiệp vụ chính", "sp_DangKyHoc", "Ghi danh học viên vào lớp: kiểm tra chỗ trống, trùng lặp, khoá tiên quyết"),
        ("Nghiệp vụ chính", "sp_ThuHocPhi", "Lập phiếu thu kèm nhiều dòng chi tiết (master – detail)"),
        ("Nghiệp vụ chính", "sp_XepLichLop", "Thêm buổi cố định trong tuần cho lớp, báo trùng phòng và trùng giáo viên"),
        ("Nghiệp vụ chính", "sp_XoaLichLop", "Bỏ một buổi khỏi lịch cố định của lớp"),
        ("Nghiệp vụ chính", "sp_DiemDanhBuoi", "Điểm danh cả lớp cho một buổi trong một lần lưu"),
        ("Nghiệp vụ chính", "sp_NhapDiem", "Nhập điểm giữa kỳ, cuối kỳ cho nhiều học viên"),
        ("Nghiệp vụ chính", "sp_ChuyenLop", "Chuyển học viên sang lớp khác cùng khoá học"),
        ("Nghiệp vụ chính", "sp_ThongKeDoanhThu", "Doanh thu theo chi nhánh và tháng trong một khoảng ngày"),
        ("Nghiệp vụ chính", "sp_TimKiemHocVien", "Tìm học viên theo nhiều tiêu chí, có phân trang"),
        ("Nghiệp vụ chính", "sp_HuyDangKy", "Huỷ đăng ký chưa đóng tiền"),
        ("Nghiệp vụ chính", "sp_XuLyCanhBao", "Đánh dấu đã xử lý một cảnh báo chuyên cần"),
        ("Nghiệp vụ chính", "sp_CapNhatTrangThaiLop", "Lớp Sắp mở tới ngày khai giảng và có học viên thì chuyển sang Đang học"),
        ("Thêm, sửa, xoá cho form web", "sp_LuuChiNhanh", "Thêm hoặc sửa chi nhánh"),
        ("Thêm, sửa, xoá cho form web", "sp_XoaChiNhanh", "Xoá chi nhánh"),
        ("Thêm, sửa, xoá cho form web", "sp_LuuPhongHoc", "Thêm hoặc sửa phòng học"),
        ("Thêm, sửa, xoá cho form web", "sp_XoaPhongHoc", "Xoá phòng học"),
        ("Thêm, sửa, xoá cho form web", "sp_LuuCaHoc", "Thêm hoặc sửa ca học"),
        ("Thêm, sửa, xoá cho form web", "sp_XoaCaHoc", "Xoá ca học"),
        ("Thêm, sửa, xoá cho form web", "sp_LuuNhanVien", "Thêm hoặc sửa nhân viên, kèm phần giáo viên, trong một giao dịch"),
        ("Thêm, sửa, xoá cho form web", "sp_XoaNhanVien", "Xoá nhân viên; đã có dữ liệu phát sinh thì chỉ cho nghỉ việc"),
        ("Thêm, sửa, xoá cho form web", "sp_LuuChungChi", "Thêm hoặc sửa chứng chỉ của giáo viên"),
        ("Thêm, sửa, xoá cho form web", "sp_XoaChungChi", "Xoá chứng chỉ của giáo viên"),
        ("Thêm, sửa, xoá cho form web", "sp_LuuChuongTrinh", "Thêm hoặc sửa chương trình"),
        ("Thêm, sửa, xoá cho form web", "sp_XoaChuongTrinh", "Xoá chương trình"),
        ("Thêm, sửa, xoá cho form web", "sp_LuuKhoaHoc", "Thêm hoặc sửa khoá học, chặn vòng lặp khoá tiên quyết"),
        ("Thêm, sửa, xoá cho form web", "sp_XoaKhoaHoc", "Xoá khoá học"),
        ("Thêm, sửa, xoá cho form web", "sp_LuuLopHoc", "Mở lớp hoặc sửa lớp, tự sinh mã lớp"),
        ("Thêm, sửa, xoá cho form web", "sp_XoaLopHoc", "Xoá lớp chưa có học viên; đã có học viên thì chuyển sang Huỷ"),
        ("Thêm, sửa, xoá cho form web", "sp_LuuHocVien", "Thêm hoặc sửa hồ sơ học viên"),
        ("Cursor và bản đối chứng", "sp_SinhBuoiHoc", "Sinh các buổi học từ lịch cố định, bỏ ngày lễ, bằng cursor"),
        ("Cursor và bản đối chứng", "sp_SinhBuoiHoc_SetBased", "Cùng việc, xử lý theo tập hợp để so sánh"),
        ("Cursor và bản đối chứng", "sp_TinhLuongGiaoVien", "Tính bảng lương tháng của từng giáo viên, bằng cursor"),
        ("Cursor và bản đối chứng", "sp_TinhLuongGiaoVien_SetBased", "Cùng việc, một câu MERGE để so sánh"),
        ("Cursor và bản đối chứng", "sp_CanhBaoChuyenCan", "Ghi cảnh báo cho đăng ký vắng quá ngưỡng, bằng cursor"),
        ("Cursor và bản đối chứng", "sp_CanhBaoChuyenCan_SetBased", "Cùng việc, một câu INSERT … SELECT để so sánh"),
        ("Tài khoản", "sp_DangNhap", "Kiểm tra đăng nhập; sai 5 lần thì tạm khoá 15 phút"),
        ("Tài khoản", "sp_DoiMatKhau", "Đổi mật khẩu của chính mình"),
        ("Tài khoản", "sp_TaoTaiKhoan", "Tạo tài khoản, vai trò khớp với chức vụ nhân viên"),
        ("Tài khoản", "sp_CapNhatTaiKhoan", "Khoá, mở khoá, đổi vai trò hoặc đặt lại mật khẩu"),
        ("Kiểm tra đầu vào", "sp_GhiKetQuaKiemTra", "Ghi kết quả kiểm tra: dựng XML, tính điểm tổng, gợi ý khoá học"),
    ],
    "function": [
        ("Nghiệp vụ", "fn_TinhTuoi", "Tuổi tròn tại một ngày"),
        ("Nghiệp vụ", "fn_TyLeChuyenCan", "Tỷ lệ chuyên cần (%) của một đăng ký"),
        ("Nghiệp vụ", "fn_XepLoai", "Xếp loại theo điểm trung bình"),
        ("Nghiệp vụ", "fn_SoTienDaDong", "Số tiền đã đóng cho một đăng ký"),
        ("Nghiệp vụ", "fn_SoTienConNo", "Tổng số tiền học viên còn nợ"),
        ("Nghiệp vụ", "fn_SoChoConLai", "Số chỗ còn trống của lớp"),
        ("Nghiệp vụ", "fn_LichHocHocVien", "Lịch học của học viên trong một tuần"),
        ("Nghiệp vụ", "fn_LopCuaGiaoVien", "Các lớp của một giáo viên"),
        ("Nghiệp vụ", "fn_GoiYKhoaHoc", "Gợi ý khoá học theo điểm kiểm tra đầu vào"),
        ("Nghiệp vụ", "fn_BangDiemLop", "Bảng điểm của lớp: điểm, chuyên cần, xếp loại, thứ hạng"),
        ("An ninh", "fn_NguoiDungHienTai", "Danh tính người đang gọi, nguồn cho mọi kiểm tra quyền theo dòng"),
        ("An ninh", "fn_TrongPhamVi", "Chi nhánh có thuộc phạm vi của người đang gọi không"),
        ("An ninh", "fn_DuocThaoTacLop", "Người đang gọi có được ghi dữ liệu học tập của lớp không"),
        ("An ninh", "fn_VaiTroTheoChucVu", "Vai trò tài khoản theo chức vụ"),
        ("Mật khẩu và XML", "fn_BamMatKhau", "Băm mật khẩu có salt, lặp 10.000 vòng SHA2_256"),
        ("Mật khẩu và XML", "fn_MatKhauHopLe", "Kiểm tra độ mạnh của mật khẩu"),
        ("Mật khẩu và XML", "fn_KyNangKiemTra", "Tách các kỹ năng của bài kiểm tra từ XML"),
    ],
    "trigger": [
        ("Đăng ký và sĩ số", "trg_DangKy_KiemTraSiSo", "Chặn ghi danh làm lớp vượt sĩ số tối đa"),
        ("Đăng ký và sĩ số", "trg_DangKy_SiSo", "Cập nhật sĩ số hiện tại của lớp"),
        ("Đăng ký và sĩ số", "trg_DangKy_KetQua", "Tính kết quả Đạt hoặc Không đạt khi có điểm cuối kỳ"),
        ("Phiếu thu và lịch học", "trg_CTPhieuThu_TongTien", "Kiểm tra chi tiết phiếu thu, cập nhật tổng tiền và trạng thái học phí"),
        ("Phiếu thu và lịch học", "trg_LichHoc_KiemTraTrung", "Chặn trùng phòng, trùng giáo viên khi xếp lịch"),
        ("Nhật ký kiểm toán", "trg_NhatKy_DangKy", "Ghi nhật ký thay đổi trên đăng ký"),
        ("Nhật ký kiểm toán", "trg_NhatKy_PhieuThu", "Ghi nhật ký thay đổi trên phiếu thu"),
        ("Nhật ký kiểm toán", "trg_NhatKy_Luong", "Ghi nhật ký khi lương cơ bản của nhân viên thay đổi"),
        ("Nhật ký kiểm toán", "trg_NhatKy_CTPhieuThu", "Ghi nhật ký tiền đã thu của từng đăng ký"),
        ("Nhật ký kiểm toán", "trg_NhatKy_TaiKhoan", "Ghi nhật ký tài khoản, không ghi hash và salt"),
        ("Nhật ký kiểm toán", "trg_NhatKy_HocVien", "Ghi nhật ký thay đổi hồ sơ học viên"),
        ("Nhật ký kiểm toán", "trg_NhatKy_ChiDoc", "Không cho sửa hoặc xoá nhật ký"),
        ("INSTEAD OF trên view", "trg_vwDangKyChiTiet_Insert", "Cho phép ghi danh qua view đăng ký chi tiết"),
        ("INSTEAD OF trên view", "trg_vwDangKyChiTiet_Delete", "Cho phép huỷ đăng ký qua view; đã có phiếu thu thì chặn"),
    ],
    "view": [
        ("Bảo mật", "vw_NhanVien_CongKhai", "Thông tin nhân viên công khai, ẩn lương và ngày sinh"),
        ("Bảo mật", "vw_HocVien_ChiNhanh", "Học viên của chi nhánh người dùng đang đăng nhập"),
        ("Bảo mật", "vw_LichDayGiaoVien", "Lịch dạy của giáo viên, không có học viên, học phí, lương"),
        ("Nghiệp vụ", "vw_DangKyChiTiet", "Đăng ký chi tiết, nguồn cho form ghi danh"),
        ("Nghiệp vụ", "vw_CongNoHocVien", "Công nợ theo từng đăng ký chưa đóng đủ"),
        ("Nghiệp vụ", "vw_BangDiem", "Bảng điểm, xếp loại, chuyên cần của mọi đăng ký"),
        ("Nghiệp vụ", "vw_DoanhThuThang", "Doanh thu theo chi nhánh và tháng, lưu sẵn kết quả (indexed view)"),
        ("Nghiệp vụ", "vw_SiSoLop", "Sĩ số và tỷ lệ lấp đầy từng lớp"),
        ("Nghiệp vụ", "vw_LopHoc_DangMo", "Lớp đang mở tuyển hoặc đang học, sửa được qua view"),
        ("Danh mục", "vw_DM_ChiNhanh", "Danh mục chi nhánh cho form"),
        ("Danh mục", "vw_DM_PhongHoc", "Danh mục phòng học cho form"),
        ("Danh mục", "vw_DM_CaHoc", "Danh mục ca học cho form"),
        ("Danh mục", "vw_NhanVien", "Thông tin nhân viên đầy đủ, có lương"),
        ("Danh mục", "vw_ChungChiGV", "Chứng chỉ của giáo viên"),
        ("Đào tạo", "vw_DM_ChuongTrinh", "Danh mục chương trình cho form"),
        ("Đào tạo", "vw_DM_KhoaHoc", "Danh mục khoá học cho form"),
        ("Đào tạo", "vw_LichHoc", "Lịch cố định của lớp: thứ, ca, phòng"),
        ("Đào tạo", "vw_BuoiHoc", "Buổi học cụ thể kèm số học viên đã điểm danh"),
        ("Học tập", "vw_DiemDanh", "Điểm danh của học viên theo từng buổi"),
        ("Học tập", "vw_CanhBao", "Cảnh báo chuyên cần kèm thông tin liên hệ"),
        ("Tài chính", "vw_PhieuThu", "Phiếu thu kèm thông tin học viên, chi nhánh, người lập"),
        ("Tài chính", "vw_CTPhieuThu", "Chi tiết phiếu thu, số dư tính tại thời điểm lập phiếu"),
        ("Báo cáo", "vw_BaoCaoDoanhThu", "Dữ liệu doanh thu cho báo cáo và dashboard"),
        ("Báo cáo", "vw_BangLuong", "Bảng lương giáo viên theo tháng"),
        ("Quản trị", "vw_TaiKhoan", "Danh sách tài khoản, không có hash và salt"),
        ("Quản trị", "vw_NhatKy", "Nhật ký cho trang quản trị"),
        ("XML", "vw_KiemTraChiTiet", "Tách XML kết quả kiểm tra thành cột quan hệ"),
    ],
}
CURSOR = ("sp_SinhBuoiHoc", "sp_TinhLuongGiaoVien", "sp_CanhBaoChuyenCan")
# Tệp tính vào từng loại đối tượng của CSDL ECMS (sao lưu ở master, 13_distributed ở các CSDL trạm nên không tính)
NGUON_DOI_TUONG = {
    "procedure": ("05_procedures.sql", "07_cursors.sql", "08_security.sql", "09_xml.sql"),
    "function": ("01_schema.sql", "03_functions.sql", "08_security.sql", "09_xml.sql"),
    "trigger": ("06_triggers.sql",),
    "view": ("04_views.sql", "08_security.sql", "09_xml.sql"),
}


def tach_ds(s: str) -> list[str]:
    return [x.strip() for x in s.split(",")]


def doc_schema() -> dict:
    sql = (ROOT / "database" / "01_schema.sql").read_text(encoding="utf-8")
    tables, fks = {}, []

    def them_fk(bang: str, ten: str, cot: str, dich: str, cot_dich: str, xoa: str | None) -> None:
        fks.append({"ten": ten, "tu": bang, "cot": tach_ds(cot), "den": dich, "cotDen": tach_ds(cot_dich),
                    "xoa": "CASCADE" if xoa else "NO ACTION"})

    for m in re.finditer(r"^CREATE TABLE (\w+) \(\n(.*?)^\);", sql, re.S | re.M):
        ten, than = m.group(1), m.group(2)
        cols, pk = [], []
        for dong in than.splitlines():
            dong = dong.split("--")[0].rstrip()
            d = re.match(r"^    (\w+)\s+(.*)$", dong)          # dòng lùi sâu hơn là phần tiếp của dòng trước
            if not d:
                continue
            tu, con = d.groups()
            if tu == "CONSTRAINT":
                c = re.match(r"(\w+)\s+(.*)$", con)
                k, dn = c.groups()
                if dn.startswith("PRIMARY KEY"):
                    pk = tach_ds(re.search(r"\((.*?)\)", dn).group(1))
                f = re.match(r"FOREIGN KEY \((.*?)\) REFERENCES (\w+) \((.*?)\)( ON DELETE CASCADE)?", dn)
                if f:
                    them_fk(ten, k, f.group(1), f.group(2), f.group(3), f.group(4))
            elif con.startswith("AS "):
                cols.append({"ten": tu, "kieu": "tính toán", "tinh": "PERSISTED" if "PERSISTED" in con else "ảo"})
            else:
                k = re.match(r"([A-Z0-9]+(?:\([^)]*\))?)", con).group(1)
                c = {"ten": tu, "kieu": k, "null": "NOT NULL" not in con}
                if (ten, tu) in DUY_TRI:
                    c["duyTri"] = DUY_TRI[(ten, tu)]
                cols.append(c)
        tables[ten] = {"cot": cols, "pk": pk}

    for m in re.finditer(r"ALTER TABLE (\w+) ADD CONSTRAINT (\w+)\s+FOREIGN KEY \((.*?)\) REFERENCES (\w+) \((.*?)\)", sql):
        them_fk(m.group(1), m.group(2), m.group(3), m.group(4), m.group(5), None)

    so_check = len(re.findall(r"\bCHECK \(", sql))
    # CK_NHANVIEN_TuoiLaoDong gọi fn_TinhTuoi nên phải thêm sau khi có hàm, ở 03_functions.sql
    so_check += len(re.findall(r"WITH CHECK ADD CONSTRAINT CK_", (ROOT / "database" / "03_functions.sql").read_text(encoding="utf-8")))
    so_tinh = sum(1 for t in tables.values() for c in t["cot"] if "tinh" in c)
    # Số liệu đã ghi trong báo cáo (Bảng 6.1); lệch thì phải sửa báo cáo hoặc slide, không để im
    kiem = {"bảng": (len(tables), 22), "khoá ngoại": (len(fks), 33), "CHECK": (so_check, 53), "cột tính toán": (so_tinh, 8)}
    for ten, (co, can) in kiem.items():
        if co != can:
            sys.exit(f"Lệch số liệu {ten}: đọc được {co}, báo cáo ghi {can}")
    if set(tables) != set(META):
        sys.exit(f"Lệch danh sách bảng: {set(tables) ^ set(META)}")

    for ten, t in tables.items():
        y, nhom, nf, dong = META[ten]
        t.update(y=y, nhom=nhom, nf=nf, dong=dong)
    return {"bang": tables, "fk": fks}


def chay(*lenh: str) -> str:
    return subprocess.run(lenh, cwd=ROOT, capture_output=True, text=True, encoding="utf-8", check=True).stdout


def doc_tien_do() -> dict:
    plan = json.loads((ROOT / "docs" / "data" / "tasks.json").read_text(encoding="utf-8"))
    issues = json.loads(chay("gh", "issue", "list", "--state", "all", "--limit", "200", "--json", "number,closedAt,state"))
    dong = {i["number"]: i for i in issues}
    viec = []
    for t in plan["tasks"]:
        i = dong[t["issue"]]
        xong = None
        if i["state"] == "CLOSED" and t["id"] not in CON_LAI:
            xong = datetime.fromisoformat(i["closedAt"].replace("Z", "+00:00")).astimezone(VN).date().isoformat()
        viec.append({"id": t["id"], "ten": t["title"], "ai": t["owner"], "sprint": t["sprint"], "han": t["due"],
                     "issue": t["issue"], "xong": xong})
    run = json.loads(chay("gh", "run", "list", "--branch", "main", "--workflow", "ci.yml", "--limit", "1", "--json", "conclusion,createdAt"))
    rel = json.loads(chay("gh", "release", "view", "--json", "tagName,publishedAt"))
    return {
        "viec": viec,
        "sprint": plan["sprints"],
        "batDau": plan["project"]["start"],
        "han": plan["project"]["deadline"],
        "commit": int(chay("git", "rev-list", "--count", "origin/main", "--no-merges").strip()),
        "pr": len(json.loads(chay("gh", "pr", "list", "--state", "merged", "--limit", "500", "--json", "number"))),
        "ci": run[0]["conclusion"] if run else None,
        "phatHanh": {"tag": rel["tagName"], "ngay": rel["publishedAt"][:10]},
    }


def doc_bang_md(md: str, nhan: str) -> list[list[str]]:
    """Các dòng dữ liệu của bảng Markdown nằm ngay sau dòng chú thích `*Bảng …*`."""
    dong = md.splitlines()
    i = next(k for k, d in enumerate(dong) if d.startswith(f"*{nhan} "))
    hang: list[list[str]] = []
    for d in dong[i + 1:]:
        if not d.startswith("|"):
            if hang:
                break
            continue
        hang.append([c.strip().replace("`", "") for c in d.strip().strip("|").split("|")])
    return hang[2:]  # bỏ dòng tiêu đề và dòng ngăn cách


def doc_yeu_cau() -> dict:
    """Nhóm người dùng, yêu cầu chức năng, phi chức năng, báo cáo: mục 1.5 của báo cáo (Bảng 1.5 – 1.8)."""
    md = (ROOT / "report" / "01-tong-quan.md").read_text(encoding="utf-8")
    nhom = doc_bang_md(md, "Bảng 1.5")
    chuc_nang = doc_bang_md(md, "Bảng 1.6")
    phi = doc_bang_md(md, "Bảng 1.7")
    bao_cao = doc_bang_md(md, "Bảng 1.8")
    assert (len(nhom), len(chuc_nang), len(phi), len(bao_cao)) == (6, 22, 8, 7), "Số dòng ở Bảng 1.5 – 1.8 lệch với báo cáo"
    return {
        "nhomNguoiDung": [{"ten": r[0], "moTa": r[1], "role": r[2]} for r in nhom],
        "chucNang": [{"ma": r[0], "yeuCau": r[1], "nguoiDung": r[2]} for r in chuc_nang],
        "phiChucNang": [{"ma": r[0], "nhom": r[1], "yeuCau": r[2]} for r in phi],
        "baoCao": [{"ten": r[0], "loai": r[1], "nguoiDung": r[2]} for r in bao_cao],
    }


def doc_chuan_hoa(bang: dict) -> dict:
    """Phụ thuộc hàm và khoá dự tuyển của 22 quan hệ: Bảng 2.11 (16 quan hệ) + 6 quan hệ hiển nhiên đạt BCNF."""
    md = (ROOT / "report" / "02-to-chuc-thong-tin.md").read_text(encoding="utf-8")
    hang = doc_bang_md(md, "Bảng 2.11")
    assert len(hang) == 16, "Bảng 2.11 phải có 16 quan hệ"
    kq = {r[0]: {"phuThuoc": r[1], "khoa": r[2]} for r in hang}
    sai = set(kq) - set(bang)
    assert not sai, f"Bảng 2.11 có quan hệ không có trong schema: {sai}"
    for ten in bang:
        if ten not in kq:  # sáu quan hệ không có phụ thuộc hàm nào khác ngoài khoá chính
            pk = bang[ten]["pk"]
            kq[ten] = {"phuThuoc": "Không có phụ thuộc hàm nào khác", "khoa": pk[0] if len(pk) == 1 else f"({', '.join(pk)})"}
    assert len(kq) == 22
    return kq


def doc_lap_trinh() -> dict:
    """Danh sách procedure, function, trigger, view, cursor kèm ý nghĩa; tên đối chiếu với database/*.sql."""
    mau = re.compile(r"^\s*CREATE\s+(?:OR\s+ALTER\s+)?(PROCEDURE|PROC|FUNCTION|TRIGGER|VIEW)\s+(?:\[?dbo\]?\.)?\[?(\w+)\]?", re.I | re.M)
    for loai, tep in NGUON_DOI_TUONG.items():
        thuc = set()
        for t in tep:
            for m in mau.finditer((ROOT / "database" / t).read_text(encoding="utf-8")):
                if {"PROC": "procedure"}.get(m.group(1).upper(), m.group(1).lower()) == loai:
                    thuc.add(m.group(2))
        khai_bao = {ten for _, ten, _ in DOI_TUONG[loai]}
        assert thuc == khai_bao, f"{loai}: thiếu ý nghĩa cho {sorted(thuc - khai_bao)}, thừa {sorted(khai_bao - thuc)}"
    so_cursor = len(re.findall(r"DECLARE\s+\w+\s+CURSOR", (ROOT / "database" / "07_cursors.sql").read_text(encoding="utf-8"), re.I))
    assert so_cursor == len(CURSOR), "Số cursor trong 07_cursors.sql lệch với CURSOR"
    kq = {loai: [{"nhom": n, "ten": t, "yNghia": y} for n, t, y in ds] for loai, ds in DOI_TUONG.items()}
    y_nghia = {t: y for _, t, y in DOI_TUONG["procedure"]}
    kq["cursor"] = [{"ten": t, "yNghia": y_nghia[t]} for t in CURSOR]
    return kq


def main() -> None:
    (OUT / "img").mkdir(parents=True, exist_ok=True)
    (OUT / "data").mkdir(exist_ok=True)
    for a in ANH:
        shutil.copyfile(ROOT / "report" / "images" / a, OUT / "img" / Path(a).name)

    dich = OUT / "data" / "tien-do.js"
    cu = {}
    if dich.exists():
        cu = json.loads(dich.read_text(encoding="utf-8").split("=", 1)[1].rstrip().rstrip(";"))
    try:
        tien_do = doc_tien_do()
        ngay = date.today().isoformat()
    except (OSError, subprocess.CalledProcessError, KeyError) as e:
        if "tienDo" not in cu:
            raise
        print(f"Không đọc được GitHub ({e}); giữ phần tiến độ của lần trước.")
        tien_do, ngay = cu["tienDo"], cu["capNhat"]

    schema = doc_schema()
    du_lieu = {"capNhat": ngay, "schema": schema, "chuanHoa": doc_chuan_hoa(schema["bang"]), "yeuCau": doc_yeu_cau(),
               "lapTrinh": doc_lap_trinh(), "tienDo": tien_do}
    dich.write_text("window.TIEN_DO = " + json.dumps(du_lieu, ensure_ascii=False, separators=(",", ":")) + ";\n", encoding="utf-8")
    print(f"✓ {dich.relative_to(ROOT)}: {len(du_lieu['schema']['bang'])} bảng, {len(du_lieu['schema']['fk'])} khoá ngoại, "
          f"{sum(1 for v in tien_do['viec'] if v['xong'])}/{len(tien_do['viec'])} việc xong")


if __name__ == "__main__":
    main()
