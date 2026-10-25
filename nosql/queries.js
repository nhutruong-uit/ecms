// Truy vấn MongoDB tương ứng các câu SQL (T27).   docker exec -i ecms-mongo mongosh ecms < nosql/queries.js
// Mục 7 sửa dữ liệu demo – chạy lại nosql/migrate.py để nạp lại từ SQL Server.
// Mỗi mục ghi kèm câu SQL tương đương trên CSDL quan hệ.
const ketQua = (ten, c) => { print(`\n=== ${ten}`); c.forEach(d => printjson(d)); };

// 1. SQL: SELECT … FROM HOCVIEN h JOIN DANGKY d … JOIN LOPHOC l … WHERE h.MaHV = 'HV0019'
//    Mongo: một document chứa sẵn đăng ký, điểm, điểm danh (nhúng) → không cần JOIN
ketQua("1. Hồ sơ học viên HV0019", db.hoc_vien.find({ _id: "HV0019" },
  { ho_ten: 1, sdt: 1, "dang_ky.lop": 1, "dang_ky.diem.tb": 1, "dang_ky.ket_qua": 1, "dang_ky.hoc_phi.trang_thai": 1 }));

// 2. SQL: SELECT l.MaCN, MONTH(p.NgayThu), SUM(c.SoTien) FROM CT_PHIEUTHU c JOIN PHIEUTHU p … JOIN DANGKY d … JOIN LOPHOC l …
//    Doanh thu tính theo chi nhánh CỦA LỚP (như vw_DoanhThuThang), không theo chi nhánh người lập phiếu
ketQua("2. Doanh thu chi nhánh lớp × tháng 2026", db.phieu_thu.aggregate([
  { $match: { ngay_thu: { $gte: ISODate("2026-01-01"), $lt: ISODate("2027-01-01") } } },
  { $unwind: "$chi_tiet" },
  { $group: { _id: { cn: "$chi_tiet.chi_nhanh", thang: { $month: "$ngay_thu" } }, tong: { $sum: "$chi_tiet.so_tien" },
              so_phieu: { $addToSet: "$_id" } } },
  { $project: { tong: 1, so_phieu: { $size: "$so_phieu" } } },
  { $sort: { "_id.cn": 1, "_id.thang": 1 } }, { $limit: 6 }]));

// 3. SQL: … WHERE KetQuaChiTiet.exist('/KetQua/KyNang[@Ten="Speaking" and @Diem < 3]') = 1   (XQuery trên cột XML)
//    Mongo: kết quả kiểm tra là document lồng – lọc thẳng theo đường dẫn trường
ketQua("3. Số bài kiểm tra Speaking < 3", db.hoc_vien.aggregate([
  { $unwind: "$kiem_tra" }, { $match: { "kiem_tra.ky_nang.speaking.diem": { $lt: 3 } } }, { $count: "so_bai" }]));

// 4. SQL: SELECT TOP 10 MaDK, SUM(CASE WHEN TrangThai = N'Vắng' …) / COUNT(*) … GROUP BY … ORDER BY … DESC
ketQua("4. Top 5 tỷ lệ vắng", db.hoc_vien.aggregate([
  { $unwind: "$dang_ky" }, { $match: { "dang_ky.trang_thai": "Đang học", "dang_ky.diem_danh.0": { $exists: true } } },
  { $project: { ho_ten: 1, lop: "$dang_ky.lop", ty_le_vang: { $divide: [
      { $size: { $filter: { input: "$dang_ky.diem_danh", cond: { $eq: ["$$this.trang_thai", "Vắng"] } } } },
      { $size: "$dang_ky.diem_danh" }] } } },
  { $sort: { ty_le_vang: -1 } }, { $limit: 5 }]));

// 5. SQL: WITH c AS (… UNION ALL … JOIN c ON k.MaKH = c.MaKHTienQuyet) – CTE đệ quy
//    Mongo: $graphLookup duyệt đồ thị tiên quyết
ketQua("5. Lộ trình tiên quyết IE65", db.khoa_hoc.aggregate([
  { $match: { _id: "IE65" } },
  { $graphLookup: { from: "khoa_hoc", startWith: "$tien_quyet", connectFromField: "tien_quyet", connectToField: "_id",
                    as: "can_hoc_truoc", depthField: "buoc" } },
  { $project: { ten: 1, "can_hoc_truoc._id": 1, "can_hoc_truoc.buoc": 1 } }]));

// 6. SQL: SELECT … FROM LOPHOC l JOIN KHOAHOC k ON k.MaKH = l.MaKH WHERE … AND SiSoHienTai < SiSoToiDa
ketQua("6. Lớp đang mở còn chỗ", db.lop_hoc.aggregate([
  { $match: { trang_thai: { $in: ["Sắp mở", "Đang học"] }, $expr: { $lt: ["$si_so.hien_tai", "$si_so.toi_da"] } } },
  { $lookup: { from: "khoa_hoc", localField: "khoa_hoc", foreignField: "_id", as: "kh" } }, { $unwind: "$kh" },
  { $project: { khoa: "$kh.ten", con_cho: { $subtract: ["$si_so.toi_da", "$si_so.hien_tai"] }, lich: 1 } }]));

// 7. Cập nhật điểm danh một buổi – mảng lồng 2 cấp dùng arrayFilters
//    SQL: UPDATE DIEMDANH SET TrangThai = N'Có phép' WHERE MaDK = @dk AND STT = 1   (đúng MỘT đăng ký, MỘT buổi)
//    arrayFilters phải lọc đúng mã đăng ký ("d.ma_dk": dk) – lọc { $exists: true } sẽ sửa buổi 1 của MỌI đăng ký
const dk = db.hoc_vien.findOne({ _id: "HV0019" }).dang_ky.find(d => d.diem_danh.length > 0).ma_dk;
const r7 = db.hoc_vien.updateOne({ _id: "HV0019" }, { $set: { "dang_ky.$[d].diem_danh.$[b].trang_thai": "Có phép" } },
  { arrayFilters: [{ "d.ma_dk": dk }, { "b.buoi": 1 }] });
print(`\n=== 7. Đã cập nhật điểm danh buổi 1 của đăng ký ${dk} (${r7.modifiedCount} document)`);
