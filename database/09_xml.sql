/* =====================================================================
   ECMS – 09_xml.sql : dữ liệu XML – XML Schema, XPath/XQuery, FOR XML, OPENXML   (T10)
   Phần 1–2 (schema, đối tượng cho ứng dụng) là bắt buộc; phần 3–5 là truy vấn minh hoạ.
   Cấu trúc kết quả kiểm tra đầu vào:
     <KetQua HinhThuc="Online|Tại trung tâm" DeThi="ECMS-PT-01">
       <KyNang Ten="Listening" Diem="6.5"><NhanXet>…</NhanXet></KyNang>   × 4 kỹ năng
       <NhanXetChung>…</NhanXetChung>
       <DeXuat MaKH="IE55"/>
     </KetQua>
   Chạy lại được: bỏ ràng buộc schema khỏi cột, tạo lại XML SCHEMA COLLECTION rồi gắn lại.
   ===================================================================== */
USE ECMS;
GO
SET ANSI_NULLS ON;
SET QUOTED_IDENTIFIER ON;
SET NOCOUNT ON;
GO

/* =====================================================================
   1. XML SCHEMA COLLECTION và typed XML
   ===================================================================== */
-- Gỡ các đối tượng phụ thuộc schema (khi chạy lại)
DROP VIEW IF EXISTS dbo.vw_KiemTraChiTiet;
IF EXISTS (SELECT 1 FROM sys.columns c JOIN sys.tables t ON t.object_id = c.object_id
           WHERE t.name = 'KIEMTRA_DAUVAO' AND c.name = 'KetQuaChiTiet' AND c.xml_collection_id <> 0)
    ALTER TABLE dbo.KIEMTRA_DAUVAO ALTER COLUMN KetQuaChiTiet XML NOT NULL;
IF EXISTS (SELECT 1 FROM sys.xml_schema_collections WHERE name = 'XSC_KetQuaKiemTra')
    DROP XML SCHEMA COLLECTION dbo.XSC_KetQuaKiemTra;
GO

CREATE XML SCHEMA COLLECTION dbo.XSC_KetQuaKiemTra AS N'
<xs:schema xmlns:xs="http://www.w3.org/2001/XMLSchema">
  <xs:simpleType name="Diem">                      <!-- điểm 0 – 10, tối đa 1 chữ số thập phân -->
    <xs:restriction base="xs:decimal">
      <xs:minInclusive value="0"/><xs:maxInclusive value="10"/><xs:fractionDigits value="1"/>
    </xs:restriction>
  </xs:simpleType>
  <xs:simpleType name="TenKyNang">
    <xs:restriction base="xs:string">
      <xs:enumeration value="Listening"/><xs:enumeration value="Reading"/>
      <xs:enumeration value="Writing"/><xs:enumeration value="Speaking"/>
    </xs:restriction>
  </xs:simpleType>
  <xs:element name="KetQua">
    <xs:complexType>
      <xs:sequence>
        <xs:element name="KyNang" minOccurs="4" maxOccurs="4">
          <xs:complexType>
            <xs:sequence><xs:element name="NhanXet" type="xs:string" minOccurs="0"/></xs:sequence>
            <xs:attribute name="Ten" type="TenKyNang" use="required"/>
            <xs:attribute name="Diem" type="Diem" use="required"/>
          </xs:complexType>
        </xs:element>
        <xs:element name="NhanXetChung" type="xs:string" minOccurs="0"/>
        <xs:element name="DeXuat" minOccurs="0">
          <xs:complexType><xs:attribute name="MaKH" type="xs:string" use="required"/></xs:complexType>
        </xs:element>
      </xs:sequence>
      <xs:attribute name="HinhThuc" use="required">
        <xs:simpleType><xs:restriction base="xs:string">
          <xs:enumeration value="Online"/><xs:enumeration value="Tại trung tâm"/>
        </xs:restriction></xs:simpleType>
      </xs:attribute>
      <xs:attribute name="DeThi" type="xs:string" use="optional"/>
    </xs:complexType>
  </xs:element>
</xs:schema>';
GO
-- Gắn schema vào cột (typed XML, DOCUMENT = phải có đúng 1 phần tử gốc). Dữ liệu cũ được kiểm tra lại toàn bộ.
ALTER TABLE dbo.KIEMTRA_DAUVAO ALTER COLUMN KetQuaChiTiet XML(DOCUMENT dbo.XSC_KetQuaKiemTra) NOT NULL;
GO

/* =====================================================================
   2. ĐỐI TƯỢNG CHO ỨNG DỤNG WEB (T21)
   ===================================================================== */

-- Tách XML thành cột quan hệ để hiển thị / lọc: .value() trên typed XML
CREATE OR ALTER VIEW dbo.vw_KiemTraChiTiet
AS
SELECT t.MaKT, t.MaHV, h.HoTen, h.MaCN, t.NgayKT, t.DiemTong,
       t.KetQuaChiTiet.value('(/KetQua/@HinhThuc)[1]', 'NVARCHAR(20)') AS HinhThuc,
       t.KetQuaChiTiet.value('(/KetQua/KyNang[@Ten="Listening"]/@Diem)[1]', 'DECIMAL(3,1)') AS Listening,
       t.KetQuaChiTiet.value('(/KetQua/KyNang[@Ten="Reading"]/@Diem)[1]',   'DECIMAL(3,1)') AS Reading,
       t.KetQuaChiTiet.value('(/KetQua/KyNang[@Ten="Writing"]/@Diem)[1]',   'DECIMAL(3,1)') AS Writing,
       t.KetQuaChiTiet.value('(/KetQua/KyNang[@Ten="Speaking"]/@Diem)[1]',  'DECIMAL(3,1)') AS Speaking,
       t.KetQuaChiTiet.value('(/KetQua/NhanXetChung)[1]', 'NVARCHAR(500)') AS NhanXetChung,
       t.MaKHDeXuat, k.TenKH AS KhoaDeXuat, nv.HoTen AS NguoiCham,
       CAST(t.KetQuaChiTiet AS NVARCHAR(MAX)) AS XmlGoc
FROM dbo.KIEMTRA_DAUVAO t
JOIN dbo.HOCVIEN h ON h.MaHV = t.MaHV
LEFT JOIN dbo.KHOAHOC k ON k.MaKH = t.MaKHDeXuat
LEFT JOIN dbo.NHANVIEN nv ON nv.MaNV = t.MaNVCham;
GO

-- Ghi nhận kết quả kiểm tra đầu vào: dựng XML bằng FOR XML PATH, tính điểm tổng, gợi ý khoá học
CREATE OR ALTER PROCEDURE dbo.sp_GhiKetQuaKiemTra
    @MaHV         CHAR(6),
    @Listening    DECIMAL(3,1),
    @Reading      DECIMAL(3,1),
    @Writing      DECIMAL(3,1),
    @Speaking     DECIMAL(3,1),
    @MaCT         VARCHAR(5) = NULL,            -- chương trình học viên quan tâm (để gợi ý đúng khoá)
    @HinhThuc     NVARCHAR(20) = N'Tại trung tâm',
    @NhanXetL     NVARCHAR(200) = NULL,
    @NhanXetR     NVARCHAR(200) = NULL,
    @NhanXetW     NVARCHAR(200) = NULL,
    @NhanXetS     NVARCHAR(200) = NULL,
    @NhanXetChung NVARCHAR(500) = NULL,
    @MaNVCham     CHAR(6) = NULL,
    @MaKT         INT OUTPUT,
    @MaKHDeXuat   VARCHAR(6) = NULL OUTPUT
AS
BEGIN
    SET NOCOUNT ON;
    IF NOT EXISTS (SELECT 1 FROM dbo.HOCVIEN WHERE MaHV = @MaHV) THROW 50100, N'Học viên không tồn tại.', 1;
    DECLARE @Tong DECIMAL(3,1) = ROUND((@Listening + @Reading + @Writing + @Speaking) / 4, 1);
    SELECT TOP 1 @MaKHDeXuat = MaKH FROM dbo.fn_GoiYKhoaHoc(@Tong, @MaCT) ORDER BY SoLopConCho DESC, CapDo;

    DECLARE @x XML(DOCUMENT dbo.XSC_KetQuaKiemTra);     -- sai cấu trúc / điểm ngoài 0–10 sẽ bị XML Schema từ chối
    SET @x = (
        SELECT @HinhThuc AS '@HinhThuc', CONCAT('ECMS-PT-', FORMAT(GETDATE(), 'MM')) AS '@DeThi',
               (SELECT k.Ten AS '@Ten', k.Diem AS '@Diem', k.NhanXet AS 'NhanXet'
                FROM (VALUES (1, 'Listening', @Listening, @NhanXetL), (2, 'Reading', @Reading, @NhanXetR),
                             (3, 'Writing', @Writing, @NhanXetW), (4, 'Speaking', @Speaking, @NhanXetS)) k (STT, Ten, Diem, NhanXet)
                ORDER BY k.STT FOR XML PATH('KyNang'), TYPE),
               @NhanXetChung AS 'NhanXetChung',
               @MaKHDeXuat AS 'DeXuat/@MaKH'
        FOR XML PATH('KetQua'), TYPE);

    INSERT dbo.KIEMTRA_DAUVAO (MaHV, DiemTong, KetQuaChiTiet, MaKHDeXuat, MaNVCham)
    VALUES (@MaHV, @Tong, @x, @MaKHDeXuat, @MaNVCham);
    SET @MaKT = SCOPE_IDENTITY();
END
GO

-- Các kỹ năng của một bài kiểm tra, tách bằng .nodes() (trang Kiểm tra đầu vào – T21)
CREATE OR ALTER FUNCTION dbo.fn_KyNangKiemTra (@MaKT INT)
RETURNS TABLE
AS
RETURN
    SELECT kn.n.value('@Ten', 'VARCHAR(10)') AS KyNang,
           kn.n.value('@Diem', 'DECIMAL(3,1)') AS Diem,
           kn.n.value('(NhanXet)[1]', 'NVARCHAR(200)') AS NhanXet
    FROM dbo.KIEMTRA_DAUVAO t CROSS APPLY t.KetQuaChiTiet.nodes('/KetQua/KyNang') AS kn(n)
    WHERE t.MaKT = @MaKT;
GO

-- 08_security.sql chạy trước file này nên cấp quyền cho ứng dụng tại đây
GRANT SELECT ON dbo.vw_KiemTraChiTiet TO r_App;
GRANT EXECUTE ON dbo.sp_GhiKetQuaKiemTra TO r_App;
GRANT SELECT ON dbo.fn_KyNangKiemTra TO r_App;
GRANT SELECT ON dbo.vw_KiemTraChiTiet TO r_GiaoVu;
GRANT EXECUTE ON dbo.sp_GhiKetQuaKiemTra TO r_GiaoVu;
GO

/* =====================================================================
   3. TRUY VẤN XPath / XQuery trên cột XML (X01 – X12)
   ===================================================================== */
PRINT N'--- X01. .value(): điểm từng kỹ năng của 5 lần kiểm tra gần nhất';
SELECT TOP 5 MaKT, MaHV, NgayKT,
       KetQuaChiTiet.value('(/KetQua/KyNang[@Ten="Listening"]/@Diem)[1]', 'DECIMAL(3,1)') AS L,
       KetQuaChiTiet.value('(/KetQua/KyNang[@Ten="Reading"]/@Diem)[1]',   'DECIMAL(3,1)') AS R,
       KetQuaChiTiet.value('(/KetQua/KyNang[@Ten="Writing"]/@Diem)[1]',   'DECIMAL(3,1)') AS W,
       KetQuaChiTiet.value('(/KetQua/KyNang[@Ten="Speaking"]/@Diem)[1]',  'DECIMAL(3,1)') AS S,
       DiemTong
FROM KIEMTRA_DAUVAO ORDER BY NgayKT DESC, MaKT DESC;

PRINT N'--- X02. .exist() + sql:column(): Speaking thấp hơn điểm tổng từ 0.7 trở lên (cần lớp phản xạ)';
SELECT t.MaKT, h.HoTen, t.DiemTong,
       t.KetQuaChiTiet.value('(/KetQua/KyNang[@Ten="Speaking"]/@Diem)[1]', 'DECIMAL(3,1)') AS Speaking
FROM KIEMTRA_DAUVAO t JOIN HOCVIEN h ON h.MaHV = t.MaHV
WHERE t.KetQuaChiTiet.exist('/KetQua/KyNang[@Ten="Speaking" and @Diem <= sql:column("t.DiemTong") - 0.7]') = 1
ORDER BY t.DiemTong DESC;

PRINT N'--- X03. .nodes() + CROSS APPLY: tách 4 kỹ năng thành 4 dòng (quan hệ hoá)';
SELECT TOP 8 t.MaKT, kn.n.value('@Ten', 'VARCHAR(10)') AS KyNang, kn.n.value('@Diem', 'DECIMAL(3,1)') AS Diem,
       kn.n.value('(NhanXet)[1]', 'NVARCHAR(200)') AS NhanXet
FROM KIEMTRA_DAUVAO t CROSS APPLY t.KetQuaChiTiet.nodes('/KetQua/KyNang') AS kn(n)
ORDER BY t.MaKT;

PRINT N'--- X04. .nodes() + GROUP BY: điểm trung bình từng kỹ năng theo hình thức thi';
SELECT HinhThuc, KyNang, CAST(AVG(Diem) AS DECIMAL(4,2)) AS DiemTB, COUNT(*) AS SoBai
FROM (SELECT t.KetQuaChiTiet.value('(/KetQua/@HinhThuc)[1]', 'NVARCHAR(20)') AS HinhThuc,   -- phương thức XML không
             kn.n.value('@Ten', 'VARCHAR(10)') AS KyNang,                                    -- dùng được trong GROUP BY
             kn.n.value('@Diem', 'DECIMAL(3,1)') AS Diem                                     -- → tách trong bảng dẫn xuất
      FROM KIEMTRA_DAUVAO t CROSS APPLY t.KetQuaChiTiet.nodes('/KetQua/KyNang') AS kn(n)) x
GROUP BY HinhThuc, KyNang
ORDER BY HinhThuc, KyNang;

PRINT N'--- X05. .query(): lấy riêng mảnh XML các kỹ năng >= 7 điểm';
SELECT TOP 5 MaKT, KetQuaChiTiet.query('/KetQua/KyNang[@Diem >= 7]') AS KyNangManh
FROM KIEMTRA_DAUVAO WHERE KetQuaChiTiet.exist('/KetQua/KyNang[@Diem >= 7]') = 1;

PRINT N'--- X06. FLWOR: kỹ năng yếu nhất của mỗi bài (for / let / order by / return)';
SELECT TOP 8 MaKT,
       KetQuaChiTiet.query('
         let $min := min(/KetQua/KyNang/@Diem)
         for $k in /KetQua/KyNang
         where $k/@Diem = $min
         order by $k/@Ten
         return <YeuNhat KyNang="{data($k/@Ten)}" Diem="{data($k/@Diem)}"/>') AS KyNangYeu
FROM KIEMTRA_DAUVAO ORDER BY MaKT;

PRINT N'--- X07. FLWOR + hàm tổng hợp: chênh lệch giữa kỹ năng mạnh nhất và yếu nhất';
SELECT TOP 5 MaKT, DiemTong,
       KetQuaChiTiet.value('max(/KetQua/KyNang/@Diem) - min(/KetQua/KyNang/@Diem)', 'DECIMAL(3,1)') AS ChenhLech
FROM KIEMTRA_DAUVAO
ORDER BY ChenhLech DESC;

PRINT N'--- X08. sql:column(), sql:variable(): so khoá đề xuất trong XML với cột quan hệ';
DECLARE @Nguong DECIMAL(3,1) = 8;
SELECT COUNT(*) AS SoBaiKhop,
       SUM(CASE WHEN KetQuaChiTiet.exist('/KetQua/KyNang[@Diem >= sql:variable("@Nguong")]') = 1 THEN 1 ELSE 0 END) AS CoKyNangTu8
FROM KIEMTRA_DAUVAO
WHERE KetQuaChiTiet.exist('/KetQua/DeXuat[@MaKH = sql:column("MaKHDeXuat")]') = 1;

/* .modify() – XML DML, chạy trong transaction rồi rollback để không đổi dữ liệu mẫu */
BEGIN TRANSACTION;
DECLARE @kt INT = (SELECT MIN(MaKT) FROM KIEMTRA_DAUVAO);
PRINT N'--- X09. .modify(replace value of): chấm phúc khảo – sửa điểm Writing';
UPDATE KIEMTRA_DAUVAO SET KetQuaChiTiet.modify('replace value of (/KetQua/KyNang[@Ten="Writing"]/@Diem)[1] with ("5.5" cast as Diem?)')   -- typed XML: giá trị mới phải đúng kiểu Diem
WHERE MaKT = @kt;
PRINT N'--- X10. .modify(insert): thêm nhận xét chung khi chưa có';
UPDATE KIEMTRA_DAUVAO SET KetQuaChiTiet.modify('insert <NhanXetChung>Đã phúc khảo phần Writing</NhanXetChung> after (/KetQua/KyNang)[4]')
WHERE MaKT = @kt AND KetQuaChiTiet.exist('/KetQua/NhanXetChung') = 0;
UPDATE KIEMTRA_DAUVAO SET KetQuaChiTiet.modify('replace value of (/KetQua/NhanXetChung)[1] with "Đã phúc khảo phần Writing"')   -- phần tử kiểu đơn: không dùng text()
WHERE MaKT = @kt;
PRINT N'--- X11. .modify(delete): bỏ nhận xét chi tiết của kỹ năng Listening';
UPDATE KIEMTRA_DAUVAO SET KetQuaChiTiet.modify('delete /KetQua/KyNang[@Ten="Listening"]/NhanXet')
WHERE MaKT = @kt;
SELECT MaKT, KetQuaChiTiet FROM KIEMTRA_DAUVAO WHERE MaKT = @kt;
ROLLBACK TRANSACTION;

PRINT N'--- X12. XML Schema từ chối dữ liệu sai cấu trúc';
DECLARE @Loi TABLE (TruongHop NVARCHAR(100), ThongBao NVARCHAR(500));
DECLARE @mau TABLE (TruongHop NVARCHAR(100), XmlText NVARCHAR(MAX));
INSERT @mau VALUES
 (N'Điểm 11 (ngoài 0–10)', N'<KetQua HinhThuc="Online"><KyNang Ten="Listening" Diem="11"/><KyNang Ten="Reading" Diem="5"/><KyNang Ten="Writing" Diem="5"/><KyNang Ten="Speaking" Diem="5"/></KetQua>'),
 (N'Thiếu kỹ năng (3/4)',   N'<KetQua HinhThuc="Online"><KyNang Ten="Listening" Diem="5"/><KyNang Ten="Reading" Diem="5"/><KyNang Ten="Writing" Diem="5"/></KetQua>'),
 (N'Tên kỹ năng lạ',        N'<KetQua HinhThuc="Online"><KyNang Ten="Grammar" Diem="5"/><KyNang Ten="Reading" Diem="5"/><KyNang Ten="Writing" Diem="5"/><KyNang Ten="Speaking" Diem="5"/></KetQua>'),
 (N'Thiếu thuộc tính HinhThuc', N'<KetQua><KyNang Ten="Listening" Diem="5"/><KyNang Ten="Reading" Diem="5"/><KyNang Ten="Writing" Diem="5"/><KyNang Ten="Speaking" Diem="5"/></KetQua>'),
 (N'Hợp lệ',                N'<KetQua HinhThuc="Online"><KyNang Ten="Listening" Diem="5"/><KyNang Ten="Reading" Diem="5.5"/><KyNang Ten="Writing" Diem="5"/><KyNang Ten="Speaking" Diem="6"/></KetQua>');
DECLARE @th NVARCHAR(100), @xt NVARCHAR(MAX), @typed XML(DOCUMENT dbo.XSC_KetQuaKiemTra);
DECLARE c CURSOR LOCAL FAST_FORWARD FOR SELECT TruongHop, XmlText FROM @mau;
OPEN c; FETCH NEXT FROM c INTO @th, @xt;
WHILE @@FETCH_STATUS = 0
BEGIN
    BEGIN TRY SET @typed = @xt; INSERT @Loi VALUES (@th, N'✓ Hợp lệ theo XSC_KetQuaKiemTra'); END TRY
    BEGIN CATCH INSERT @Loi VALUES (@th, CONCAT(N'✗ ', ERROR_NUMBER(), N': ', ERROR_MESSAGE())); END CATCH
    FETCH NEXT FROM c INTO @th, @xt;
END
CLOSE c; DEALLOCATE c;
SELECT * FROM @Loi;
GO

/* =====================================================================
   4. FOR XML – xuất dữ liệu quan hệ ra XML
   ===================================================================== */
PRINT N'--- X13. FOR XML RAW: danh mục khoá học, mỗi dòng một phần tử <KhoaHoc>';
SELECT MaKH, TenKH, MaCT, SoBuoi, HocPhi FROM KHOAHOC ORDER BY MaCT, CapDo
FOR XML RAW('KhoaHoc'), ROOT('DanhMucKhoaHoc');

PRINT N'--- X14. FOR XML AUTO: lồng tự động theo thứ tự bảng trong FROM (chương trình → khoá học)';
SELECT ChuongTrinh.MaCT, ChuongTrinh.TenCT, KhoaHoc.MaKH, KhoaHoc.TenKH, KhoaHoc.CapDo
FROM CHUONGTRINH AS ChuongTrinh JOIN KHOAHOC AS KhoaHoc ON KhoaHoc.MaCT = ChuongTrinh.MaCT
ORDER BY ChuongTrinh.MaCT, KhoaHoc.CapDo
FOR XML AUTO, ROOT('ChuongTrinhDaoTao');

PRINT N'--- X15. FOR XML PATH lồng nhiều cấp: Chi nhánh → Lớp đang học → Học viên (gửi đối tác / Sở GD)';
SELECT cn.MaCN AS '@Ma', cn.TenCN AS '@Ten',
       (SELECT l.MaLop AS '@Ma', k.TenKH AS 'KhoaHoc', l.NgayKhaiGiang AS 'KhaiGiang', nv.HoTen AS 'GiaoVien',
               (SELECT h.MaHV AS '@Ma', h.HoTen AS 'HoTen', h.NgaySinh AS 'NgaySinh', d.TrangThaiHP AS 'HocPhi'
                FROM DANGKY d JOIN HOCVIEN h ON h.MaHV = d.MaHV
                WHERE d.MaLop = l.MaLop AND d.TrangThai = N'Đang học' ORDER BY h.TenHV
                FOR XML PATH('HocVien'), TYPE) AS 'DanhSach'
        FROM LOPHOC l JOIN KHOAHOC k ON k.MaKH = l.MaKH JOIN NHANVIEN nv ON nv.MaNV = l.MaGV
        WHERE l.MaCN = cn.MaCN AND l.TrangThai = N'Đang học'
        ORDER BY l.MaLop
        FOR XML PATH('Lop'), TYPE)
FROM CHINHANH cn
ORDER BY cn.MaCN
FOR XML PATH('ChiNhanh'), ROOT('ECMS');
GO

/* =====================================================================
   5. NHẬP XML từ hệ thống khác: OPENXML và .nodes()
   Đối tác thi thử gửi kết quả theo cấu trúc riêng → chuyển sang cấu trúc ECMS.
   (Đọc từ file data/xml/ketqua_doitac.xml bằng OPENROWSET – xem 12_import_export.sql)
   ===================================================================== */
DECLARE @doc NVARCHAR(MAX) = N'
<DanhSachThi DonVi="TrungTamKhaoThi" Ngay="2026-10-10">
  <ThiSinh SDT="0901234999" HoTen="Nguyễn Văn Khách"><Diem KyNang="L">6.0</Diem><Diem KyNang="R">6.5</Diem><Diem KyNang="W">5.5</Diem><Diem KyNang="S">6.0</Diem></ThiSinh>
  <ThiSinh SDT="0901234888" HoTen="Trần Thị Mới"><Diem KyNang="L">4.0</Diem><Diem KyNang="R">4.5</Diem><Diem KyNang="W">3.5</Diem><Diem KyNang="S">4.0</Diem></ThiSinh>
</DanhSachThi>';

PRINT N'--- X16. OPENXML: sp_xml_preparedocument → đọc như bảng → sp_xml_removedocument';
DECLARE @h INT;
EXEC sp_xml_preparedocument @h OUTPUT, @doc;
SELECT *
FROM OPENXML(@h, '/DanhSachThi/ThiSinh', 1)            -- 1 = ánh xạ theo thuộc tính
WITH (SDT VARCHAR(15) '@SDT', HoTen NVARCHAR(70) '@HoTen',
      L DECIMAL(3,1) 'Diem[@KyNang="L"]', R DECIMAL(3,1) 'Diem[@KyNang="R"]',
      W DECIMAL(3,1) 'Diem[@KyNang="W"]', S DECIMAL(3,1) 'Diem[@KyNang="S"]');
EXEC sp_xml_removedocument @h;                          -- giải phóng bộ nhớ của tài liệu đã phân tích

PRINT N'--- X17. .nodes(): cùng việc trên, chuyển sang XML chuẩn ECMS và kiểm tra bằng XML Schema';
DECLARE @x XML = @doc;
SELECT ts.n.value('@SDT', 'VARCHAR(15)') AS SDT, ts.n.value('@HoTen', 'NVARCHAR(70)') AS HoTen,
       CAST((SELECT 'Online' AS '@HinhThuc', 'DOITAC' AS '@DeThi',
                    (SELECT CASE d.n.value('@KyNang', 'CHAR(1)') WHEN 'L' THEN 'Listening' WHEN 'R' THEN 'Reading'
                                 WHEN 'W' THEN 'Writing' ELSE 'Speaking' END AS '@Ten',
                            d.n.value('.', 'DECIMAL(3,1)') AS '@Diem'
                     FROM ts.n.nodes('Diem') d(n) FOR XML PATH('KyNang'), TYPE)
             FOR XML PATH('KetQua'), TYPE) AS XML(DOCUMENT dbo.XSC_KetQuaKiemTra)) AS KetQuaChuanECMS
FROM @x.nodes('/DanhSachThi/ThiSinh') ts(n);
GO

PRINT N'✓ 09_xml.sql: XML Schema đã gắn vào KIEMTRA_DAUVAO.KetQuaChiTiet; 17 truy vấn XML.';
GO
