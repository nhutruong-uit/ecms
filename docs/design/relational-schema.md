# Lược đồ quan hệ ECMS (T06)

Quy ước: <u>gạch chân</u> = khoá chính, *in nghiêng* = khoá ngoại, `[suy diễn]` = thuộc tính suy diễn được lưu/tính.

## 1. Lược đồ

| # | Lược đồ quan hệ |
|:-:|---|
| 1 | CHINHANH (<u>MaCN</u>, TenCN, DiaChi, SoDienThoai, NgayThanhLap, *MaNVQuanLy*) |
| 2 | NHANVIEN (<u>MaNV</u>, HoNV, TenNV, NgaySinh, GioiTinh, SoDienThoai, Email, ChucVu, LuongCoBan, NgayVaoLam, *MaCN*, *MaNVQuanLy*, TrangThai) |
| 3 | GIAOVIEN (<u>*MaGV*</u>, LoaiGV, QuocTich, TrinhDo, DonGiaBuoi) |
| 4 | CHUNGCHI_GV (<u>*MaGV*, TenChungChi</u>, Diem, NgayCap, NoiCap) |
| 5 | PHONGHOC (<u>*MaCN*, MaPhong</u>, SucChua, LoaiPhong) |
| 6 | CAHOC (<u>MaCa</u>, TenCa, GioBatDau, GioKetThuc) |
| 7 | CHUONGTRINH (<u>MaCT</u>, TenCT, DoiTuong, MoTa) |
| 8 | KHOAHOC (<u>MaKH</u>, TenKH, *MaCT*, CapDo, DiemDauVaoTu, DiemDauVaoDen, MucTieuDauRa, SoBuoi, HocPhi, *MaKHTienQuyet*) |
| 9 | LOPHOC (<u>MaLop</u>, TenLop, *MaKH*, *MaCN*, *MaGV*, NgayKhaiGiang, NgayKetThuc, SiSoToiDa, SiSoHienTai `[suy diễn]`, TrangThai) |
| 10 | LICHHOC (<u>*MaLop*, Thu, *MaCa*</u>, *MaCN*, *MaPhong*) – FK (MaLop, MaCN) → LOPHOC; (MaCN, MaPhong) → PHONGHOC |
| 11 | BUOIHOC (<u>*MaLop*, STT</u>, NgayHoc, *MaCa*, MaPhong, NoiDung, TrangThai) |
| 12 | HOCVIEN (<u>MaHV</u>, HoHV, TenHV, NgaySinh, GioiTinh, SoDienThoai, Email, SoNha, PhuongXa, QuanHuyen, TinhTP, HoTenPhuHuynh, NgayTao, *MaCN*, TrangThai) |
| 13 | KIEMTRA_DAUVAO (<u>MaKT</u>, *MaHV*, NgayKT, DiemTong `[suy diễn từ XML]`, KetQuaChiTiet (XML), *MaKHDeXuat*, *MaNVCham*) |
| 14 | DANGKY (<u>MaDK</u>, *MaHV*, *MaLop*, NgayDK, HocPhi, GiamGia, ThanhTien `[suy diễn]`, HanDongHP `[suy diễn]`, TrangThaiHP `[suy diễn]`, DiemGK, DiemCK, DiemTB `[suy diễn]`, KetQua `[suy diễn]`, TrangThai) – khoá dự tuyển (MaHV, MaLop) |
| 15 | DIEMDANH (<u>*MaDK*, *MaLop*, *STT*</u>, TrangThai, GhiChu) – FK (MaDK, MaLop) → DANGKY; (MaLop, STT) → BUOIHOC |
| 16 | PHIEUTHU (<u>MaPT</u>, SoPhieu `[suy diễn]`, *MaHV*, *MaNV*, NgayThu, HinhThuc, TongTien `[suy diễn]`, GhiChu) |
| 17 | CT_PHIEUTHU (<u>*MaPT*, *MaDK*</u>, SoTien) |
| 18 | TAIKHOAN (<u>TenDangNhap</u>, MatKhauHash, Salt, VaiTro, *MaNV*, *MaHV*, TrangThai, SoLanSai, LanDangNhapCuoi, NgayTao) |
| 19 | NHATKY (<u>MaNK</u>, TenBang, ThaoTac, KhoaChinh, DuLieuCu, DuLieuMoi, NguoiThucHien, NguoiDungUD, ThoiGian) |
| 20 | NGAYLE (<u>Ngay</u>, TenNgayLe) – phụ trợ |
| 21 | CANHBAO_CHUYENCAN (<u>MaCB</u>, *MaDK*, NgayCanhBao, SoBuoiDaHoc, SoBuoiVang, TyLeVang, MucDo, DaXuLy) – phụ trợ |
| 22 | BANGLUONG (<u>Thang, *MaGV*</u>, SoBuoiDay, DonGiaBuoi, LuongCoBan, TongLuong `[suy diễn]`, NgayTinh) – phụ trợ |

## 2. Phụ thuộc hàm và dạng chuẩn

Ký hiệu: K = khoá chính; "K → *" nghĩa là khoá xác định mọi thuộc tính còn lại.

| Quan hệ | Phụ thuộc hàm (ngoài K → *) | Khoá dự tuyển | Dạng chuẩn |
|---|---|---|---|
| CHINHANH | TenCN → MaCN; MaNVQuanLy → MaCN | MaCN, TenCN, MaNVQuanLy | BCNF |
| NHANVIEN | SoDienThoai → MaNV; Email → MaNV | MaNV, SoDienThoai, Email | BCNF |
| GIAOVIEN | – | MaGV | BCNF |
| CHUNGCHI_GV | (MaGV, TenChungChi) → Diem, NgayCap, NoiCap | (MaGV, TenChungChi) | BCNF |
| PHONGHOC | (MaCN, MaPhong) → SucChua, LoaiPhong | (MaCN, MaPhong) | BCNF |
| CAHOC | TenCa → MaCa | MaCa, TenCa | BCNF |
| CHUONGTRINH | TenCT → MaCT | MaCT, TenCT | BCNF |
| KHOAHOC | TenKH → MaKH; (MaCT, CapDo) → MaKH | MaKH, TenKH, (MaCT, CapDo) | BCNF |
| LOPHOC | MaLop → MaKH, MaCN, MaGV…; *SiSoHienTai* = COUNT(DANGKY) – lưu cố ý | MaLop | 3NF/BCNF (\*) |
| LICHHOC | MaLop → MaCN (vì MaLop là một phần khoá → **vi phạm 2NF?** xem ghi chú) | (MaLop, Thu, MaCa) | 3NF (\*\*) |
| BUOIHOC | (MaLop, NgayHoc, MaCa) → STT | (MaLop, STT), (MaLop, NgayHoc, MaCa) | BCNF |
| HOCVIEN | – (PhuongXa, QuanHuyen không xác định nhau vì trùng tên phường giữa các quận) | MaHV | BCNF |
| KIEMTRA_DAUVAO | KetQuaChiTiet → DiemTong (suy diễn) | MaKT | 3NF (\*) |
| DANGKY | (MaHV, MaLop) → MaDK; HocPhi, GiamGia → ThanhTien; DiemGK, DiemCK → DiemTB → KetQua | MaDK, (MaHV, MaLop) | 3NF (\*) |
| DIEMDANH | MaDK → MaLop (MaLop là thuộc tính khoá) | (MaDK, MaLop, STT) | 3NF (MaDK không phải siêu khoá nên chưa BCNF; giữ MaLop để có FK (MaLop, STT) → BUOIHOC, bảo đảm học viên chỉ được điểm danh ở buổi của lớp mình) |
| PHIEUTHU | MaPT → SoPhieu; TongTien = Σ CT_PHIEUTHU.SoTien | MaPT, SoPhieu | BCNF (\*) |
| CT_PHIEUTHU | (MaPT, MaDK) → SoTien | khoá chính | BCNF |
| TAIKHOAN | MaNV → TenDangNhap; MaHV → TenDangNhap | TenDangNhap, MaNV, MaHV | BCNF |
| NHATKY | – | MaNK | BCNF |

**(\*) Thuộc tính suy diễn cố ý lưu (phi chuẩn hoá có kiểm soát)**

| Thuộc tính | Lý do lưu | Cách duy trì nhất quán |
|---|---|---|
| DANGKY.ThanhTien, DiemTB, HanDongHP; PHIEUTHU.SoPhieu; BANGLUONG.TongLuong | Truy vấn, lọc, sắp xếp, đánh chỉ mục thường xuyên | **Computed column PERSISTED** – SQL Server tự tính lại, không thể sai lệch. Phụ thuộc bắc cầu này không gây dị thường cập nhật |
| HOCVIEN.Tuoi, HoTen | Hiển thị | Computed column không lưu (Tuổi phụ thuộc ngày hiện tại nên không thể PERSISTED) |
| LOPHOC.SiSoHienTai | Kiểm tra "lớp còn chỗ" ở mỗi lần ghi danh, hiển thị danh sách lớp | Trigger `trg_DangKy_SiSo` trên DANGKY (T13) |
| PHIEUTHU.TongTien, DANGKY.TrangThaiHP | Báo cáo doanh thu, công nợ | Trigger `trg_CTPhieuThu_TongTien` (T13) |
| DANGKY.KetQua | Lọc học viên đạt để cấp chứng nhận | Trigger tính từ DiemTB và tỷ lệ chuyên cần (T13) |
| DANGKY.HocPhi | Giữ đúng học phí tại thời điểm ghi danh dù KHOAHOC.HocPhi thay đổi sau này | Không phải phụ thuộc hàm MaLop → HocPhi vì giá trị là *lịch sử* |
| KIEMTRA_DAUVAO.DiemTong | Lọc / sắp xếp mà không phải phân tích XML | Tính khi ghi nhận kết quả (procedure T21) |

**(\*\*) LICHHOC.MaCN:** MaCN phụ thuộc vào MaLop (một phần khoá) nên về hình thức LICHHOC chỉ đạt 1NF đối với MaCN. Nhóm **cố ý giữ** MaCN để dùng khoá ngoại phức hợp (MaCN, MaPhong) → PHONGHOC và (MaLop, MaCN) → LOPHOC. Hai khoá ngoại này *bắt buộc* phòng học phải thuộc đúng chi nhánh của lớp – một RBTV liên quan hệ được kiểm tra bằng khai báo thay vì trigger. MaCN không thể lệch vì FK (MaLop, MaCN) chỉ chấp nhận đúng cặp đang có trong LOPHOC. Phương án chuẩn hoá đầy đủ (bỏ MaCN, kiểm tra bằng trigger) được so sánh trong báo cáo mục 2.5.
