"""Dựng slide thuyết trình đồ án (T29) → slides/ECMS_Nhom1.pptx.

    pip install -r scripts/requirements-docs.txt
    python scripts/build_slides.py

Bảng màu và logo lấy theo mẫu báo cáo (report/template/mau-bao-cao-uit.docx). Mỗi phần ghi người trình bày trong
chân slide và ghi chú (speaker notes) – tổng thời lượng dự kiến ≈ 18 phút + demo.
"""
from io import BytesIO
from pathlib import Path

from docx import Document
from PIL import Image
from pptx import Presentation
from pptx.dml.color import RGBColor
from pptx.enum.shapes import MSO_SHAPE
from pptx.enum.text import MSO_ANCHOR, PP_ALIGN
from pptx.util import Cm, Pt

ROOT = Path(__file__).resolve().parent.parent
OUT = ROOT / "slides" / "ECMS_Nhom1.pptx"
IMG = ROOT / "report" / "images" / "ch4"
DES = ROOT / "docs" / "design"
NAVY, BLUE, GREY, LIGHT, WHITE = (RGBColor(0x1F, 0x38, 0x64), RGBColor(0x2E, 0x75, 0xB6), RGBColor(0x59, 0x59, 0x59),
                                  RGBColor(0xE7, 0xEC, 0xF5), RGBColor(0xFF, 0xFF, 0xFF))
FONT = "Times New Roman"
W, H = Cm(33.867), Cm(19.05)       # 16:9

prs = Presentation()
prs.slide_width, prs.slide_height = W, H
BLANK = prs.slide_layouts[6]


def logo() -> BytesIO:
    tpl = Document(ROOT / "report" / "template" / "mau-bao-cao-uit.docx")
    blob = next(r.target_part.blob for r in tpl.part.rels.values() if r.reltype.endswith("/image"))
    return BytesIO(blob)


def text(slide, x, y, w, h, content, size=20, bold=False, color=None, align=PP_ALIGN.LEFT, anchor=MSO_ANCHOR.TOP):
    tb = slide.shapes.add_textbox(x, y, w, h)
    tf = tb.text_frame
    tf.word_wrap = True
    tf.vertical_anchor = anchor
    tf.margin_left = tf.margin_right = Cm(0.2)
    lines = content if isinstance(content, list) else [content]
    for i, ln in enumerate(lines):
        p = tf.paragraphs[0] if i == 0 else tf.add_paragraph()
        p.alignment = align
        r = p.add_run()
        r.text = ln
        r.font.name, r.font.size, r.font.bold = FONT, Pt(size), bold
        r.font.color.rgb = color or RGBColor(0, 0, 0)
    return tb


def bullets(slide, x, y, w, h, items, size=20):
    """items: chuỗi hoặc (chuỗi, cấp). Chuỗi dạng 'Đậm: thường' → phần trước dấu ':' in đậm."""
    tb = slide.shapes.add_textbox(x, y, w, h)
    tf = tb.text_frame
    tf.word_wrap = True
    for i, it in enumerate(items):
        s, lvl = (it, 0) if isinstance(it, str) else it
        p = tf.paragraphs[0] if i == 0 else tf.add_paragraph()
        p.space_after = Pt(6)
        mark = p.add_run()
        mark.text = ("■  " if lvl == 0 else "      –  ")
        mark.font.name, mark.font.size = FONT, Pt(size - 6 if lvl == 0 else size - 2)
        mark.font.color.rgb = BLUE
        head, sep, rest = s.partition(": ")
        if sep and len(head) <= 40:
            r = p.add_run()
            r.text = head + ": "
            r.font.name, r.font.size, r.font.bold = FONT, Pt(size - 2 * lvl), True
            r.font.color.rgb = NAVY
            s = rest
        r = p.add_run()
        r.text = s
        r.font.name, r.font.size = FONT, Pt(size - 2 * lvl)
    return tb


def picture(slide, path, x, y, max_w, max_h):
    with Image.open(path) as im:
        iw, ih = im.size
    scale = min(max_w / iw, max_h / ih)
    w, h = int(iw * scale), int(ih * scale)
    pic = slide.shapes.add_picture(str(path), x + (max_w - w) // 2, y + (max_h - h) // 2, w, h)
    pic.line.color.rgb = RGBColor(0xBF, 0xBF, 0xBF)
    return pic


def table(slide, x, y, w, rows, col_w=None, size=14, row_h=Cm(0.9)):
    shape = slide.shapes.add_table(len(rows), len(rows[0]), x, y, w, row_h * len(rows))
    t = shape.table
    if col_w:
        for i, cw in enumerate(col_w):
            t.columns[i].width = int(w * cw / sum(col_w))
    for r, row in enumerate(rows):
        for c, v in enumerate(row):
            cell = t.cell(r, c)
            cell.text = str(v)
            cell.margin_left = cell.margin_right = Cm(0.15)
            cell.fill.solid()
            cell.fill.fore_color.rgb = NAVY if r == 0 else (LIGHT if r % 2 == 0 else WHITE)
            for p in cell.text_frame.paragraphs:
                p.alignment = PP_ALIGN.CENTER if r == 0 or c > 0 and len(str(v)) < 12 else PP_ALIGN.LEFT
                for run in p.runs:
                    run.font.name, run.font.size, run.font.bold = FONT, Pt(size), r == 0
                    run.font.color.rgb = WHITE if r == 0 else RGBColor(0, 0, 0)
    return t


STT = {"n": 0}


def slide(title, nguoi, notes=""):
    s = prs.slides.add_slide(BLANK)
    STT["n"] += 1
    bar = s.shapes.add_shape(MSO_SHAPE.RECTANGLE, 0, 0, W, Cm(2.3))
    bar.fill.solid()
    bar.fill.fore_color.rgb = NAVY
    bar.line.fill.background()
    text(s, Cm(1), Cm(0.25), W - Cm(5), Cm(1.8), title, 28, True, WHITE, anchor=MSO_ANCHOR.MIDDLE)
    s.shapes.add_picture(logo(), W - Cm(3.1), Cm(0.2), height=Cm(1.9))
    line = s.shapes.add_shape(MSO_SHAPE.RECTANGLE, Cm(1), H - Cm(1.15), W - Cm(2), Cm(0.04))
    line.fill.solid()
    line.fill.fore_color.rgb = BLUE
    line.line.fill.background()
    text(s, Cm(1), H - Cm(1.05), Cm(22), Cm(0.8), f"IE103 – Nhóm 1 · ECMS · Trình bày: {nguoi}", 12, color=GREY)
    text(s, W - Cm(4), H - Cm(1.05), Cm(3), Cm(0.8), str(STT["n"]), 12, color=GREY, align=PP_ALIGN.RIGHT)
    s.notes_slide.notes_text_frame.text = f"Người trình bày: {nguoi}. {notes}".strip()
    return s


L, T, CW, CH = Cm(1.2), Cm(2.9), W - Cm(2.4), H - Cm(4.4)      # vùng nội dung

# ----------------------------------------------------------------------------- 1. bìa
s = prs.slides.add_slide(BLANK)
STT["n"] += 1
bg = s.shapes.add_shape(MSO_SHAPE.RECTANGLE, 0, 0, W, H)
bg.fill.solid()
bg.fill.fore_color.rgb = NAVY
bg.line.fill.background()
panel = s.shapes.add_shape(MSO_SHAPE.RECTANGLE, Cm(1.5), Cm(1.2), W - Cm(3), H - Cm(2.4))
panel.fill.solid()
panel.fill.fore_color.rgb = WHITE
panel.line.fill.background()
s.shapes.add_picture(logo(), Cm(2.5), Cm(1.8), height=Cm(2.6))
text(s, Cm(6.2), Cm(1.9), Cm(24), Cm(2.6), ["ĐẠI HỌC QUỐC GIA TP. HỒ CHÍ MINH", "TRƯỜNG ĐẠI HỌC CÔNG NGHỆ THÔNG TIN",
                                              "KHOA KHOA HỌC VÀ KỸ THUẬT THÔNG TIN"], 15, True, NAVY)
text(s, Cm(2.5), Cm(5.4), W - Cm(5), Cm(1.2), "ĐỒ ÁN MÔN HỌC IE103 – QUẢN LÝ THÔNG TIN · LỚP IE103.Q21.VB2", 18, True, BLUE,
     PP_ALIGN.CENTER)
text(s, Cm(2.5), Cm(6.7), W - Cm(5), Cm(3.9), ["HỆ THỐNG QUẢN LÝ", "TRUNG TÂM TIẾNG ANH (ECMS)"], 36, True, NAVY, PP_ALIGN.CENTER)
text(s, Cm(2.5), Cm(10.8), W - Cm(5), Cm(1), "Giảng viên hướng dẫn: TS. Võ Phương Bình", 18, align=PP_ALIGN.CENTER)
table(s, Cm(7.5), Cm(12.1), Cm(19), [["STT", "Họ và tên", "MSSV"], ["1", "Đỗ Phạm Minh Trâm", "25540042"],
                                     ["2", "Trương Quang Như (nhóm trưởng)", "25540022"], ["3", "Nguyễn Việt Phú", "25540025"],
                                     ["4", "Đỗ Bình Dương", "25540008"], ["5", "Nguyễn Bảo Giang", "25540009"]],
      [1, 6, 2.5], 14, Cm(0.72))
s.notes_slide.notes_text_frame.text = "Người trình bày: Như – giới thiệu nhóm, đề tài (30 giây)."

# ----------------------------------------------------------------------------- 2. nội dung
s = slide("Nội dung trình bày", "Như", "Giới thiệu bố cục 6 phần và người phụ trách từng phần.")
table(s, L + Cm(2), T + Cm(0.5), CW - Cm(4), [
    ["Phần", "Nội dung", "Trình bày", "Thời lượng"],
    ["1", "Tổng quan – bài toán, khảo sát, yêu cầu", "Như", "2 phút"],
    ["2", "Tổ chức thông tin – ERD, Class Diagram, lược đồ quan hệ, cài đặt", "Trâm", "3 phút"],
    ["3", "Xử lý thông tin – truy vấn, XML, an ninh, lập trình CSDL", "Dương · Như · Giang · Phú", "5 phút"],
    ["4", "Trình bày thông tin – menu, form, báo cáo, dashboard", "Giang", "3 phút"],
    ["5", "Mô hình CSDL tiên tiến – hướng đối tượng, phân tán, NoSQL", "Trâm · Phú · Dương", "3 phút"],
    ["6", "Kiểm thử, demo, kết luận", "Như", "2 phút + demo"]], [1, 9, 4, 2.4], 17, Cm(1.25))

# ----------------------------------------------------------------------------- 3. bài toán
s = slide("1. Bài toán và hiện trạng", "Như", "Nhấn mạnh 3 chi nhánh dùng Excel rời rạc → mục tiêu tập trung hoá dữ liệu.")
bullets(s, L, T, Cm(15.5), CH, [
    "Đối tượng: chuỗi 3 chi nhánh trung tâm tiếng Anh tại TP.HCM, 4 chương trình (IELTS, TOEIC, Giao tiếp, Thiếu nhi)",
    "Nghiệp vụ: tư vấn → kiểm tra đầu vào → ghi danh → thu học phí → học & điểm danh → thi → báo cáo",
    "Hiện trạng: mỗi chi nhánh một file Excel",
    ("Trùng lặp, sai lệch thông tin học viên", 1), ("Không kiểm soát sĩ số, trùng phòng, khoá tiên quyết", 1),
    ("Báo cáo doanh thu tổng hợp thủ công 1–2 ngày", 1), ("Không phân quyền, không sao lưu", 1),
    "Mục tiêu: CSDL tập trung + ứng dụng web theo vai trò, ràng buộc nghiệp vụ đặt tại CSDL"], 19)
picture(s, DES / "quy-trinh-nghiep-vu.png", Cm(17.5), T, Cm(15.2), CH)

# ----------------------------------------------------------------------------- 4. yêu cầu
s = slide("1. Đặc tả yêu cầu", "Như", "22 yêu cầu chức năng, 8 phi chức năng; 5 tác nhân.")
table(s, L, T + Cm(0.2), Cm(15), [["Vai trò", "Chức năng chính"], ["Quản lý", "Danh mục, tài khoản, nhật ký, dashboard"],
                                  ["Giáo vụ", "Khoá học, mở lớp, xếp lịch, ghi danh"], ["Kế toán", "Phiếu thu, công nợ, lương"],
                                  ["Giáo viên", "Điểm danh, nhập điểm, cảnh báo"], ["Học viên", "Lịch học, điểm, học phí"]],
      [1.3, 3.4], 16, Cm(1.3))
bullets(s, Cm(17.2), T, Cm(15.5), CH, [
    "22 yêu cầu chức năng (FR01–FR22): từ đăng nhập, danh mục đến sao lưu và nhập / xuất",
    "8 yêu cầu phi chức năng:",
    ("Toàn vẹn – giao dịch, ràng buộc tại CSDL", 1), ("Bảo mật – quyền tối thiểu, ẩn lương", 1),
    ("Truy vết – nhật ký thay đổi", 1), ("Sẵn sàng – RPO 15 phút", 1), ("Tiếng Việt, dễ dùng, tái lập bằng 1 lệnh", 1),
    "Ánh xạ DIKW: điểm danh → chuyên cần → cảnh báo bỏ học"], 18)

# ----------------------------------------------------------------------------- 5. ERD
s = slide("2. Tổ chức thông tin – ERD và Class Diagram", "Trâm",
          "Giải thích thực thể yếu (PHONGHOC, BUOIHOC), chuyên biệt hoá NHANVIEN–GIAOVIEN, liên kết 3 ngôi LICHHOC.")
picture(s, DES / "erd.png", L, T, Cm(19.5), CH)
bullets(s, Cm(21.2), T, Cm(11.6), CH, [
    "17 tập thực thể: 2 thực thể yếu, 1 chuyên biệt hoá, 1 liên kết 3 ngôi",
    "Đủ loại thuộc tính: khoá, phức hợp, đa trị, suy diễn",
    "Class Diagram UML: kế thừa, kết hợp, thành phần, phụ thuộc",
    "So sánh ERD ↔ Class Diagram trên cùng bài toán"], 18)

# ----------------------------------------------------------------------------- 6. lược đồ
s = slide("2. Lược đồ quan hệ và cài đặt", "Trâm", "Sơ đồ sinh từ metadata sau khi chạy 01_schema.sql.")
picture(s, DES / "db-diagram.png", L, T, Cm(19.5), CH)
bullets(s, Cm(21.2), T, Cm(11.6), CH, [
    "22 bảng, 32 khoá ngoại, 22 chỉ mục",
    "Chuẩn hoá: 17/22 quan hệ đạt BCNF, phần còn lại có lý do giữ",
    "RBTV: CHECK, UNIQUE, FK, computed column PERSISTED, trigger",
    "So sánh mô hình phẳng – quan hệ – XML",
    "Dữ liệu mẫu ~350 học viên, 25 lớp, ~500 phiếu thu"], 18)

# ----------------------------------------------------------------------------- 7. truy vấn
s = slide("3. Xử lý thông tin – Truy vấn SQL và XML", "Dương", "Chọn 1–2 truy vấn tiêu biểu để chạy trực tiếp (Q18, Q24).")
table(s, L, T + Cm(0.2), Cm(16), [["Nhóm", "Kỹ thuật", "Số câu"], ["Cơ bản", "LIKE, BETWEEN, TOP … WITH TIES", "5"],
                                  ["Kết nối", "INNER/LEFT/RIGHT/FULL JOIN, self-join", "5"],
                                  ["Gom nhóm", "GROUP BY, HAVING, ROLLUP", "5"], ["Lồng", "IN, NOT EXISTS, tương quan, ALL", "5"],
                                  ["Tập hợp", "UNION, INTERSECT, EXCEPT, phép chia", "5"], ["Nâng cao", "CTE đệ quy, hàm cửa sổ, PIVOT", "6"]],
      [2.2, 5, 1], 15, Cm(1.15))
bullets(s, Cm(18), T, Cm(14.8), CH, [
    "31 truy vấn trả lời câu hỏi quản lý thực tế",
    "XML: kết quả kiểm tra đầu vào lưu cột XML có XML Schema",
    ("query(), value(), exist(), nodes(), modify()", 1), ("FOR XML / OPENXML, điểm ngoài 0–10 bị từ chối", 1),
    "Đo hiệu năng trước / sau khi thêm chỉ mục"], 18)

# ----------------------------------------------------------------------------- 8. an ninh
s = slide("3. An ninh dữ liệu", "Như · Giang", "Như: xác thực, phân quyền. Giang: view, sao lưu – phục hồi. Dương: nhập / xuất.")
bullets(s, L, T, Cm(16), CH, [
    "Xác thực: login SQL theo vai trò; tài khoản ứng dụng băm SHA2_256 + salt, khoá sau 5 lần sai",
    "Phân quyền: 5 role, ứng dụng dùng login ecms_app bị DENY trên mọi bảng – chỉ EXECUTE procedure, SELECT view",
    "Row-level: SESSION_CONTEXT lọc dữ liệu theo chi nhánh; ẩn lương với vai trò không liên quan",
    "36 ca kiểm thử phân quyền đều PASS"], 18)
bullets(s, Cm(17.8), T, Cm(15), CH, [
    "View: 27 view – bảo mật, báo cáo, indexed view doanh thu, WITH CHECK OPTION",
    "Sao lưu: FULL tuần, DIFF ngày, LOG 15 phút → RPO 15 phút",
    "Phục hồi theo thời điểm (STOPAT) ra CSDL song song để đối chiếu",
    "Nhập / xuất: BULK INSERT, bcp, FOR JSON / XML, pandas – kiểm tra và báo dòng lỗi"], 18)

# ----------------------------------------------------------------------------- 9. lập trình
s = slide("3. Lập trình CSDL", "Phú", "Demo sp_DangKyHoc báo lỗi 'Lớp đã đủ sĩ số' và trigger cập nhật sĩ số.")
table(s, L, T + Cm(0.2), CW, [["Đối tượng", "Số lượng", "Ví dụ tiêu biểu", "Kiểm thử"],
                              ["Stored procedure", "38", "sp_DangKyHoc, sp_ThuHocPhi (JSON master–detail, SAVE TRANSACTION)", "25 ca PASS"],
                              ["Function", "13", "fn_GoiYKhoaHoc, fn_BangDiemLop (inline / multi-statement TVF)", "–"],
                              ["Trigger", "11", "sĩ số, tổng tiền phiếu thu, chặn trùng phòng, nhật ký JSON, INSTEAD OF", "17 ca PASS"],
                              ["Cursor", "3", "sinh buổi học bỏ qua ngày lễ, tính lương, cảnh báo chuyên cần", "so sánh set-based"]],
      [2.4, 1.2, 8, 2], 16, Cm(1.5))
text(s, L, T + Cm(8.4), CW, Cm(3), ["Lỗi nghiệp vụ trả về bằng THROW 500xx với thông báo tiếng Việt → giao diện hiển thị nguyên văn.",
                                    "Mọi nghiệp vụ nhiều bước chạy trong transaction lồng được; trigger viết set-based."], 18, color=GREY)

# ----------------------------------------------------------------------------- 10. menu
s = slide("4. Trình bày thông tin – Menu và Form", "Giang", "Đăng nhập 2 vai trò khác nhau để thấy menu thay đổi.")
picture(s, DES / "menu-tree.png", L, T, Cm(8), CH)
picture(s, IMG / "02_trang_chu.jpg", Cm(9.8), T, Cm(11.4), Cm(7.1))
picture(s, IMG / "04_kiem_tra_nhap_lieu.jpg", Cm(21.6), T, Cm(11.2), Cm(7.1))
bullets(s, Cm(9.8), T + Cm(7.6), Cm(23), Cm(6.5), [
    "Menu rộng & nông: 2 cấp, 8 nhóm theo nghiệp vụ, ẩn theo vai trò, chặn cả truy cập bằng URL",
    "Form: control theo kiểu dữ liệu, giá trị mặc định, lỗi hiện ngay dưới ô nhập + kiểm tra lần 2 tại CSDL",
    "Ánh xạ mỗi form ↔ view / procedure / trigger – giao diện không truy cập bảng gốc"], 18)

# ----------------------------------------------------------------------------- 11. master-detail
s = slide("4. Form master–detail và nhập liệu hàng loạt", "Giang", "Demo lập phiếu thu 2 khoản, in PDF.")
picture(s, IMG / "14_phieu_thu.jpg", L, T, Cm(15.6), Cm(9.8))
picture(s, IMG / "11_diem_danh.jpg", Cm(17.2), T, Cm(15.6), Cm(9.8))
text(s, L, T + Cm(10.1), Cm(15.6), Cm(2.5), "Phiếu thu: 1 phiếu – nhiều đăng ký, thu một phần, lưu 1 giao dịch (sp_ThuHocPhi)", 16,
     align=PP_ALIGN.CENTER)
text(s, Cm(17.2), T + Cm(10.1), Cm(15.6), Cm(2.5), "Điểm danh / nhập điểm: lưới sửa trực tiếp, lưu cả lớp một lần", 16,
     align=PP_ALIGN.CENTER)

# ----------------------------------------------------------------------------- 12. báo cáo
s = slide("4. Báo cáo và Dashboard", "Giang", "Mở PDF doanh thu: Report/Page/Group header-footer, Trang X / Y.")
picture(s, IMG / "16_dashboard.jpg", L, T, Cm(17), Cm(10.6))
picture(s, IMG / "20_pdf_doanh_thu.jpg", Cm(18.6), T, Cm(7), CH)
bullets(s, Cm(25.9), T, Cm(7), CH, ["9 báo cáo: định kỳ, theo yêu cầu, tổng hợp, biểu mẫu", "PDF + Excel",
                                    "Dashboard 6 KPI so kỳ trước, đọc từ indexed view"], 16)
text(s, L, T + Cm(10.9), Cm(17), Cm(2.5), "Dashboard – tầng Knowledge trong DIKW", 16, align=PP_ALIGN.CENTER, color=GREY)

# ----------------------------------------------------------------------------- 13. CSDL tiên tiến
s = slide("5. Mô hình CSDL tiên tiến", "Trâm · Phú · Dương", "Trâm: hướng đối tượng · Phú: phân tán · Dương: NoSQL.")
table(s, L, T + Cm(0.2), CW, [
    ["Tiêu chí", "Quan hệ", "Hướng đối tượng", "Phân tán (theo chi nhánh)", "NoSQL (MongoDB)"],
    ["Mô hình hoá ECMS", "Tốt, tách bảng", "Tự nhiên nhất", "Như quan hệ + phân mảnh", "Tự nhiên cho hồ sơ"],
    ["Toàn vẹn & giao dịch", "Mạnh nhất (ACID)", "Trong phương thức", "ACID cục bộ, 2PC", "Yếu, không FK"],
    ["Báo cáo thống kê", "Mạnh nhất", "Yếu (N+1)", "Tốt nếu cục bộ", "Khá (aggregation)"],
    ["Đọc 1 hồ sơ trọn vẹn", "Nhiều JOIN", "Duyệt đối tượng", "Như quan hệ", "Nhanh nhất – 1 document"],
    ["Mở rộng", "Dọc", "Dọc", "Ngang theo chi nhánh", "Ngang (sharding)"],
    ["Demo", "–", "ODL + mapper Python", "3 trạm + partitioned view", "4 collection, 6 cặp truy vấn"]],
      [2.6, 2.3, 2.3, 3, 3], 15, Cm(1.25))
text(s, L, T + Cm(9.6), CW, Cm(2), "Kết luận: quan hệ tập trung là lựa chọn chính; phân tán khi mở rộng nhiều tỉnh; NoSQL làm kho phụ "
     "(polyglot persistence).", 17, True, NAVY)

# ----------------------------------------------------------------------------- 14. kiểm thử
s = slide("6. Kiểm thử tích hợp và CI", "Như", "Chạy lại toàn bộ từ CSDL trống trong khoảng 35 giây.")
table(s, L, T + Cm(0.2), Cm(17), [["Bước", "Kết quả"], ["Dựng CSDL 01 → 09 từ CSDL trống", "≈ 10 giây"],
                                  ["Kiểm tra dữ liệu mẫu", "11 kiểm tra, 0 lỗi"], ["Procedure / trigger / phân quyền", "25 / 17 / 36 ca PASS"],
                                  ["31 truy vấn nghiệp vụ", "chạy hết, không lỗi"], ["Smoke test mọi trang × 5 vai trò + mọi báo cáo", "52 passed"]],
      [3, 2], 16, Cm(1.3))
bullets(s, Cm(19.4), T, Cm(13.4), CH, [
    "GitHub Actions: SQL Server 2025 (Docker) → run_all → test SQL → pytest",
    "Bắt buộc xanh trước khi merge develop → main",
    "Quy trình nhóm: 29 task = 29 issue = 29 PR vào develop, review bởi nhóm trưởng",
    "Phát hành v1.0.0"], 18)

# ----------------------------------------------------------------------------- 15. demo
s = slide("Kịch bản demo (≈ 5 phút)", "Cả nhóm", "Chuẩn bị sẵn 5 tab trình duyệt đã đăng nhập 5 vai trò.")
table(s, L, T + Cm(0.2), CW, [
    ["#", "Vai trò", "Thao tác", "Điểm nhấn"],
    ["1", "Giáo vụ", "Mở lớp → xếp lịch → sinh buổi học", "Chặn trùng phòng, bỏ qua ngày lễ"],
    ["2", "Giáo vụ", "Kiểm tra đầu vào → ghi danh (thử lớp đầy)", "XML Schema, lỗi 'Lớp đã đủ sĩ số'"],
    ["3", "Kế toán", "Lập phiếu thu 2 khoản → in PDF", "Master–detail, số tiền bằng chữ"],
    ["4", "Giáo viên", "Điểm danh → nhập điểm → quét cảnh báo", "Trigger tính kết quả, cursor"],
    ["5", "Học viên", "Xem lịch tuần, điểm, học phí", "Chỉ thấy dữ liệu của mình"],
    ["6", "Quản lý", "Dashboard → nhật ký hệ thống", "Ai đã thao tác gì, lúc nào"]], [0.5, 1.6, 5, 4.4], 16, Cm(1.35))

# ----------------------------------------------------------------------------- 16. phân công
s = slide("Phân công và đóng góp", "Như", "Số liệu commit từ scripts/thong_ke_dong_gop.py.")
table(s, L, T + Cm(0.2), CW, [
    ["Thành viên", "Task", "Phụ trách chính", "Đóng góp"],
    ["Trương Quang Như", "T01–T03, T15, T19, T29", "Quản lý dự án, Chương 1, môi trường, phân quyền, khung web, CI, tổng hợp", "20%"],
    ["Đỗ Phạm Minh Trâm", "T04–T07, T20, T25", "ERD, Class Diagram, lược đồ, DDL, trang Đào tạo, CSDL hướng đối tượng", "20%"],
    ["Đỗ Bình Dương", "T08–T10, T18, T21, T27", "Dữ liệu mẫu, truy vấn, XML, nhập / xuất, trang Học viên, NoSQL", "20%"],
    ["Nguyễn Việt Phú", "T11–T14, T22, T26", "Procedure, function, trigger, cursor, trang Học tập, CSDL phân tán", "20%"],
    ["Nguyễn Bảo Giang", "T16, T17, T23, T24, T28", "View, sao lưu, trang Tài chính, báo cáo & dashboard, Chương 4", "20%"]],
      [3, 3.2, 9, 1.4], 15, Cm(1.5))

# ----------------------------------------------------------------------------- 17. kết luận
s = slide("Kết luận và hướng phát triển", "Như", "")
bullets(s, L, T, Cm(15.5), CH, [
    "Đạt được: đủ 22 yêu cầu chức năng, đi qua đủ quy trình QLTT",
    ("Thu thập → Tổ chức → Xử lý → Trình bày", 1), ("Luật nghiệp vụ nằm trong CSDL, không thể bị bỏ qua", 1),
    ("Tái lập từ đầu bằng một lệnh, CI tự động", 1),
    "Hạn chế: dữ liệu nhỏ, giao diện chưa tối ưu di động, phân tán mới mô phỏng trên 1 máy"], 19)
bullets(s, Cm(17.6), T, Cm(15.2), CH, [
    "Hướng phát triển:",
    ("Cổng học viên / phụ huynh, thanh toán online, thông báo vắng học", 1),
    ("REST API + frontend di động, giữ lớp procedure / view", 1),
    ("Redis cache, MongoDB đồng bộ CDC cho cổng học viên", 1),
    ("Kho dữ liệu và dự báo học viên bỏ học (tầng Wisdom)", 1)], 19)

# ----------------------------------------------------------------------------- 18. cảm ơn
s = prs.slides.add_slide(BLANK)
STT["n"] += 1
bg = s.shapes.add_shape(MSO_SHAPE.RECTANGLE, 0, 0, W, H)
bg.fill.solid()
bg.fill.fore_color.rgb = NAVY
bg.line.fill.background()
text(s, 0, Cm(6), W, Cm(3), "CẢM ƠN THẦY VÀ CÁC BẠN ĐÃ LẮNG NGHE", 40, True, WHITE, PP_ALIGN.CENTER)
text(s, 0, Cm(9.5), W, Cm(2), "Hỏi & đáp", 28, False, WHITE, PP_ALIGN.CENTER)
text(s, 0, Cm(13.5), W, Cm(1.5), "github.com/nhutruong-uit/ecms", 18, False, WHITE, PP_ALIGN.CENTER)
s.notes_slide.notes_text_frame.text = ("Câu hỏi phản biện đã chuẩn bị: vì sao đặt luật nghiệp vụ trong CSDL; vì sao chọn SQL Server "
                                       "thay vì MongoDB; RLS bằng SESSION_CONTEXT có an toàn khi dùng chung login; "
                                       "khi nào nên dùng cursor; RPO/RTO đạt được bao nhiêu.")

OUT.parent.mkdir(parents=True, exist_ok=True)
prs.save(OUT)
print(f"✓ {OUT.relative_to(ROOT)} ({STT['n']} slide)")
