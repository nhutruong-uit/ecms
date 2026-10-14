#!/usr/bin/env python3
"""Sinh dữ liệu mẫu cho ECMS (T08).

    pip install faker
    python3 scripts/gen_seed.py            # ghi database/02_seed.sql và data/import/*.csv

Dữ liệu tái lập được (seed cố định) và lấy ngày tham chiếu cố định REF_DATE thay cho ngày hiện tại,
nên chạy lại luôn ra cùng một file. Các giá trị suy diễn (sĩ số hiện tại, tổng tiền phiếu thu,
trạng thái học phí, kết quả) được tính sẵn để khớp với dữ liệu chi tiết.
"""
import csv
import random
from collections import defaultdict
from datetime import date, datetime, time, timedelta
from pathlib import Path

from faker import Faker

ROOT = Path(__file__).resolve().parent.parent
OUT_SQL = ROOT / "database" / "02_seed.sql"
OUT_CSV = ROOT / "data" / "import"
REF_DATE = date(2026, 10, 15)          # "hôm nay" của bộ dữ liệu
SEED = 103

rnd = random.Random(SEED)
fake = Faker("vi_VN")
Faker.seed(SEED)

# ----------------------------------------------------------------- danh mục cố định
CHINHANH = [
    ("CN01", "ECMS Thủ Đức", "Khu phố 6, P. Linh Trung, TP. Thủ Đức, TP.HCM", "02837251234", date(2018, 3, 1)),
    ("CN02", "ECMS Quận 1", "45 Lê Lợi, P. Bến Nghé, Quận 1, TP.HCM", "02838224567", date(2020, 8, 15)),
    ("CN03", "ECMS Bình Thạnh", "210 Xô Viết Nghệ Tĩnh, P.25, Q. Bình Thạnh, TP.HCM", "02835129876", date(2022, 1, 10)),
]
CAHOC = [
    (1, "Sáng 1", time(8, 0), time(9, 30)), (2, "Sáng 2", time(9, 45), time(11, 15)),
    (3, "Chiều 1", time(14, 0), time(15, 30)), (4, "Chiều 2", time(15, 45), time(17, 15)),
    (5, "Tối 1", time(18, 0), time(19, 30)), (6, "Tối 2", time(19, 45), time(21, 15)),
]
CHUONGTRINH = [
    ("IELTS", "Luyện thi IELTS", "Học sinh THPT, sinh viên, người đi làm cần du học / định cư",
     "Luyện 4 kỹ năng theo định dạng đề IELTS Academic"),
    ("TOEIC", "Luyện thi TOEIC", "Sinh viên, người đi làm cần chứng chỉ tốt nghiệp / thăng tiến",
     "Listening & Reading theo đề TOEIC mới"),
    ("GT", "Tiếng Anh Giao tiếp", "Người đi làm, người mất gốc", "Phản xạ nghe nói trong công việc và đời sống"),
    ("KIDS", "Tiếng Anh Thiếu nhi", "Trẻ 6 – 14 tuổi", "Theo khung Cambridge Young Learners"),
]
# MaKH, TenKH, MaCT, CapDo, Tu, Den, DauRa, SoBuoi, HocPhi
KHOAHOC = [
    ("IEF", "IELTS Foundation", "IELTS", 1, 0, 3.9, "IELTS 4.0", 24, 5_500_000),
    ("IE55", "IELTS 5.5", "IELTS", 2, 4.0, 5.4, "IELTS 5.5", 30, 7_500_000),
    ("IE65", "IELTS 6.5+", "IELTS", 3, 5.5, 10, "IELTS 6.5", 30, 9_000_000),
    ("TC450", "TOEIC 450", "TOEIC", 1, 0, 3.9, "TOEIC 450", 20, 3_500_000),
    ("TC650", "TOEIC 650", "TOEIC", 2, 4.0, 5.9, "TOEIC 650", 24, 4_500_000),
    ("TC850", "TOEIC 850+", "TOEIC", 3, 6.0, 10, "TOEIC 850", 24, 5_500_000),
    ("GT1", "Giao tiếp Cơ bản", "GT", 1, 0, 3.9, "A2", 20, 3_000_000),
    ("GT2", "Giao tiếp Trung cấp", "GT", 2, 4.0, 6.4, "B1", 20, 3_500_000),
    ("GT3", "Giao tiếp Nâng cao", "GT", 3, 6.5, 10, "B2", 20, 4_000_000),
    ("KD1", "Kids Starters", "KIDS", 1, 0, 3.9, "Cambridge Starters", 24, 4_000_000),
    ("KD2", "Kids Movers", "KIDS", 2, 4.0, 6.4, "Cambridge Movers", 24, 4_200_000),
    ("KD3", "Kids Flyers", "KIDS", 3, 6.5, 10, "Cambridge Flyers", 24, 4_500_000),
]
KH = {k[0]: k for k in KHOAHOC}
PREREQ = {k[0]: next((p[0] for p in KHOAHOC if p[2] == k[2] and p[3] == k[3] - 1), None) for k in KHOAHOC}

NGAYLE = [
    (date(2025, 1, 1), "Tết Dương lịch"), *[(date(2025, 1, 25) + timedelta(d), "Tết Nguyên đán Ất Tỵ") for d in range(9)],
    (date(2025, 4, 7), "Giỗ Tổ Hùng Vương"), (date(2025, 4, 30), "Ngày Giải phóng miền Nam"), (date(2025, 5, 1), "Quốc tế Lao động"),
    (date(2025, 9, 1), "Quốc khánh (nghỉ bù)"), (date(2025, 9, 2), "Quốc khánh"),
    (date(2026, 1, 1), "Tết Dương lịch"), *[(date(2026, 2, 14) + timedelta(d), "Tết Nguyên đán Bính Ngọ") for d in range(9)],
    (date(2026, 4, 26), "Giỗ Tổ Hùng Vương"), (date(2026, 4, 30), "Ngày Giải phóng miền Nam"), (date(2026, 5, 1), "Quốc tế Lao động"),
    (date(2026, 9, 2), "Quốc khánh"), (date(2026, 9, 3), "Quốc khánh (nghỉ thêm)"),
]
HOLIDAYS = {d for d, _ in NGAYLE}


# ----------------------------------------------------------------- tiện ích
def q(v):
    """Giá trị Python → literal T-SQL."""
    if v is None:
        return "NULL"
    if isinstance(v, bool):
        return "1" if v else "0"
    if isinstance(v, (int, float)):
        return repr(round(v, 2)) if isinstance(v, float) else str(v)
    if isinstance(v, datetime):
        return f"'{v:%Y-%m-%dT%H:%M:%S}'"
    if isinstance(v, date):
        return f"'{v:%Y-%m-%d}'"
    if isinstance(v, time):
        return f"'{v:%H:%M}'"
    if isinstance(v, Raw):
        return v.sql
    return "N'" + str(v).replace("'", "''") + "'"


class Raw:
    def __init__(self, sql):
        self.sql = sql


def inserts(table, cols, rows, identity=False, batch=500):
    out = [f"-- {table}: {len(rows)} dòng"]
    if identity:
        out.append(f"SET IDENTITY_INSERT {table} ON;")
    for i in range(0, len(rows), batch):
        chunk = rows[i:i + batch]
        out.append(f"INSERT INTO {table} ({', '.join(cols)}) VALUES")
        out.append(",\n".join("  (" + ", ".join(q(v) for v in r) + ")" for r in chunk) + ";")
    if identity:
        out.append(f"SET IDENTITY_INSERT {table} OFF;")
    out.append("GO")
    return "\n".join(out)


def split_name(full):
    parts = full.split()
    return " ".join(parts[:-1]), parts[-1]


def phone(used):
    while True:
        p = rnd.choice(["090", "091", "093", "094", "096", "097", "098", "032", "033", "035", "070", "077", "081", "085"]) \
            + "".join(rnd.choice("0123456789") for _ in range(7))
        if p not in used:
            used.add(p)
            return p


def ascii_slug(s):
    import unicodedata
    s = unicodedata.normalize("NFD", s.replace("Đ", "D").replace("đ", "d"))
    return "".join(c for c in s if c.isalnum() and ord(c) < 128).lower()


TEN_LOT = {True: ["Văn", "Minh", "Quang", "Đức", "Hoàng", "Thành", "Hữu", "Gia", "Anh", "Tuấn"],
           False: ["Thị", "Ngọc", "Thu", "Thanh", "Minh", "Bảo", "Kim", "Mai", "Phương", "Khánh"]}


def gender_name(male, r=None):
    """Họ + tên lót + tên theo đúng thứ tự tiếng Việt (Faker vi_VN đặt tên trước họ và có danh xưng)."""
    r = r or rnd
    first = fake.first_name_male() if male else fake.first_name_female()
    return f"{fake.last_name()} {r.choice(TEN_LOT[male])} {first}"


# ----------------------------------------------------------------- nhân viên, giáo viên
used_phones = set()
NHANVIEN, GIAOVIEN, CHUNGCHI = [], [], []
staff_plan = [  # (chức vụ, chi nhánh, số lượng)
    ("Quản lý", "CN01", 1), ("Quản lý", "CN02", 1), ("Quản lý", "CN03", 1),
    ("Giáo vụ", "CN01", 2), ("Giáo vụ", "CN02", 1), ("Giáo vụ", "CN03", 1),
    ("Kế toán", "CN01", 1), ("Kế toán", "CN02", 1), ("Kế toán", "CN03", 1),
    ("Giáo viên", "CN01", 4), ("Giáo viên", "CN02", 3), ("Giáo viên", "CN03", 3),
]
FOREIGN = [("Smith", "John", "Anh"), ("Brown", "Emily", "Úc"), ("Wilson", "David", "Mỹ"), ("Taylor", "Sarah", "Canada")]
n = 0
managers = {}
for role, cn, cnt in staff_plan:
    for _ in range(cnt):
        n += 1
        ma = f"NV{n:04d}"
        male = rnd.random() < 0.45
        is_gv = role == "Giáo viên"
        native = is_gv and len([g for g in GIAOVIEN if g[1] == "Bản ngữ"]) < 4 and rnd.random() < 0.5
        if native:
            ho, ten, qt = FOREIGN[len([g for g in GIAOVIEN if g[1] == "Bản ngữ"])]
            male = ten in ("John", "David")
        else:
            ho, ten = split_name(gender_name(male))
            qt = "Việt Nam"
        vao_lam = date(rnd.randint(2018, 2024), rnd.randint(1, 12), rnd.randint(1, 28))
        vao_lam = max(vao_lam, next(c[4] for c in CHINHANH if c[0] == cn))
        ns = date(vao_lam.year - rnd.randint(23, 40), rnd.randint(1, 12), rnd.randint(1, 28))
        luong = {"Quản lý": 25_000_000, "Giáo vụ": 9_000_000, "Kế toán": 11_000_000, "Giáo viên": 6_000_000}[role]
        luong += rnd.randint(0, 6) * 500_000
        email = f"{ascii_slug(ten)}.{ascii_slug(ho.split()[0])}{n}@ecms.edu.vn"
        quan_ly = None if role == "Quản lý" else managers.get(cn)
        NHANVIEN.append([ma, ho, ten, ns, "Nam" if male else "Nữ", phone(used_phones), email, role, luong, vao_lam, cn, quan_ly, True])
        if role == "Quản lý":
            managers[cn] = ma
        if is_gv:
            don_gia = rnd.choice([350_000, 400_000, 450_000]) if not native else rnd.choice([700_000, 800_000])
            trinh_do = rnd.choice(["Cử nhân", "Thạc sĩ", "Thạc sĩ"]) if not native else "Cử nhân"
            GIAOVIEN.append([ma, "Bản ngữ" if native else "Việt Nam", qt, trinh_do, don_gia])
            ccs = ["TESOL"] if native else []
            ccs += rnd.sample(["IELTS", "TOEIC", "CELTA", "TKT", "TESOL"], rnd.randint(1, 2)) if not native else ["CELTA"]
            for cc in dict.fromkeys(ccs):
                diem = {"IELTS": rnd.choice([7.5, 8.0, 8.5]), "TOEIC": rnd.choice([900, 950, 990])}.get(cc)
                CHUNGCHI.append([ma, cc, diem, date(rnd.randint(2015, 2023), rnd.randint(1, 12), rnd.randint(1, 28)),
                                 {"IELTS": "British Council / IDP", "TOEIC": "IIG Việt Nam"}.get(cc, "Cambridge Assessment English")])
# Quản lý CN02, CN03 báo cáo cho quản lý CN01 (giám đốc trung tâm)
for nv in NHANVIEN:
    if nv[7] == "Quản lý" and nv[10] != "CN01":
        nv[11] = managers["CN01"]
# Một giáo viên kiêm trưởng bộ môn: các giáo viên CN01 báo cáo cho giáo viên đầu tiên của CN01
gv_cn01 = [nv for nv in NHANVIEN if nv[7] == "Giáo viên" and nv[10] == "CN01"]
for nv in gv_cn01[1:]:
    nv[11] = gv_cn01[0][0]
NV = {nv[0]: nv for nv in NHANVIEN}
GV = {g[0]: g for g in GIAOVIEN}
KETOAN = {nv[10]: nv[0] for nv in NHANVIEN if nv[7] == "Kế toán"}
GIAOVU = defaultdict(list)
for nv in NHANVIEN:
    if nv[7] == "Giáo vụ":
        GIAOVU[nv[10]].append(nv[0])

# ----------------------------------------------------------------- phòng học
PHONGHOC = []
for cn, *_ in CHINHANH:
    for i, (cap, loai) in enumerate([(30, "Thường"), (25, "Thường"), (30, "Lab"), (40, "Hội trường")]):
        PHONGHOC.append([cn, f"P{101 + i}", cap, loai])
ROOMS = defaultdict(list)
for p in PHONGHOC:
    ROOMS[p[0]].append(p)

# ----------------------------------------------------------------- lớp học, lịch học, buổi học
# (MaKH, chi nhánh, ngày khai giảng mong muốn, sĩ số tối đa)
CLASS_PLAN = []
starts_2025 = {1: date(2025, 2, 10), 2: date(2025, 6, 9), 3: date(2025, 10, 20)}
starts_2026 = {1: date(2026, 4, 20), 2: date(2026, 8, 10), 3: date(2026, 10, 26)}
cn_cycle = ["CN01", "CN02", "CN03"]
for i, k in enumerate(KHOAHOC):
    lvl = k[3]
    CLASS_PLAN.append((k[0], cn_cycle[i % 3], starts_2025[lvl] + timedelta(days=7 * (i % 3)), 25))
    CLASS_PLAN.append((k[0], cn_cycle[(i + 1) % 3], starts_2026[lvl] + timedelta(days=7 * (i % 3)), 30 if lvl < 3 else 25))
# một lớp IELTS 5.5 mở thêm ở CN01 – lớp hot, sẽ đầy sĩ số
CLASS_PLAN.append(("IE55", "CN01", date(2026, 8, 17), 20))
CLASS_PLAN.sort(key=lambda c: (c[2], c[0]))

PATTERNS_ADULT = [((2, 4), 5), ((3, 5), 5), ((2, 4), 6), ((3, 5), 6), ((4, 6), 5), ((4, 6), 6), ((7, 8), 1), ((7, 8), 3)]
PATTERNS_KIDS = [((7, 8), 1), ((7, 8), 2), ((7, 8), 3), ((3, 5), 4), ((2, 4), 4)]
NATIVE_PROGRAMS = {"IELTS", "GT"}


def sessions_for(start, days, so_buoi):
    out, d = [], start
    while len(out) < so_buoi:
        if d.weekday() + 2 in days and d not in HOLIDAYS:
            out.append(d)
        d += timedelta(days=1)
    return out


LOPHOC, LICHHOC, BUOIHOC = [], [], []
busy_room = defaultdict(list)     # (cn, phòng, thứ, ca) -> [(đầu, cuối)]
busy_gv = defaultdict(list)       # (gv, thứ, ca) -> [(đầu, cuối)]
seq = defaultdict(int)
gv_load = defaultdict(int)


def free(slots, a, b):
    return all(b < s or a > e for s, e in slots)


for ma_kh, cn, start, max_ss in CLASS_PLAN:
    k = KH[ma_kh]
    kids = k[2] == "KIDS"
    patterns = PATTERNS_KIDS if kids else PATTERNS_ADULT
    teachers = [g for g in GIAOVIEN if NV[g[0]][10] == cn] + [g for g in GIAOVIEN if NV[g[0]][10] != cn]
    if k[2] not in NATIVE_PROGRAMS:
        teachers = [g for g in teachers if g[1] == "Việt Nam"] + [g for g in teachers if g[1] != "Việt Nam"]
    done = False
    for shift in range(0, 21, 7):
        st = start + timedelta(days=shift)
        for days, ca in rnd.sample(patterns, len(patterns)):
            ses = sessions_for(st, days, k[7])
            a, b = ses[0], ses[-1]
            rooms = [r for r in ROOMS[cn] if r[2] >= max_ss and (r[3] != "Hội trường" or max_ss > 30)]
            room = next((r for r in rooms if all(free(busy_room[(cn, r[1], t, ca)], a, b) for t in days)), None)
            if not room:
                continue
            for g in sorted(teachers, key=lambda g: (NV[g[0]][10] != cn, gv_load[g[0]])):
                if all(free(busy_gv[(g[0], t, ca)], a, b) for t in days):
                    break
            else:
                continue
            seq[(ma_kh, a.year)] += 1
            ma_lop = f"{ma_kh}-{a:%y}{seq[(ma_kh, a.year)]:02d}"
            status = "Đã kết thúc" if b < REF_DATE else ("Đang học" if a <= REF_DATE else "Sắp mở")
            LOPHOC.append([ma_lop, f"{k[1]} – {cn[-2:]}.{a:%m/%y}", ma_kh, cn, g[0], a, b, max_ss, 0, status])
            for t in days:
                LICHHOC.append([ma_lop, t, ca, cn, room[1]])
                busy_room[(cn, room[1], t, ca)].append((a, b))
                busy_gv[(g[0], t, ca)].append((a, b))
            gv_load[g[0]] += 1
            for i, d in enumerate(ses, 1):
                BUOIHOC.append([ma_lop, i, d, ca, room[1], f"Unit {i}" if i not in (len(ses) // 2, len(ses)) else
                                ("Kiểm tra giữa kỳ" if i == len(ses) // 2 else "Kiểm tra cuối kỳ"),
                                "Đã dạy" if d <= REF_DATE else "Đã lên lịch"])
            done = True
            break
        if done:
            break
    if not done:
        raise SystemExit(f"Không xếp được lịch cho {ma_kh} tại {cn}")

LOP = {l[0]: l for l in LOPHOC}
BUOI_BY_LOP = defaultdict(list)
for bh in BUOIHOC:
    BUOI_BY_LOP[bh[0]].append(bh)

# ----------------------------------------------------------------- học viên & kiểm tra đầu vào
HOCVIEN, KIEMTRA, DANGKY, DIEMDANH, PHIEUTHU, CT_PT = [], [], [], [], [], []
QUAN = {"CN01": ["TP. Thủ Đức", "Quận 9", "Dĩ An"], "CN02": ["Quận 1", "Quận 3", "Quận 4", "Quận 10"],
        "CN03": ["Bình Thạnh", "Gò Vấp", "Phú Nhuận"]}
PHUONG = ["Phường 1", "Phường 3", "Phường 7", "Phường 12", "Phường 25", "Linh Trung", "Bến Nghé", "Đa Kao", "Hiệp Phú"]
hv_seq = 0


def new_student(cn, kids, created):
    global hv_seq
    hv_seq += 1
    male = rnd.random() < 0.48
    ho, ten = split_name(gender_name(male))
    age = rnd.randint(6, 13) if kids else rnd.choice([16, 17, 18, 19, 20, 21, 22, 23, 25, 28, 32, 38])
    ns = date(created.year - age, rnd.randint(1, 12), rnd.randint(1, 28))
    email = None if kids or rnd.random() < 0.08 else f"{ascii_slug(ten)}{ascii_slug(ho.split()[-1])}{hv_seq}@gmail.com"
    ph = gender_name(rnd.random() < 0.5) if kids else None
    hv = [f"HV{hv_seq:04d}", ho, ten, ns, "Nam" if male else "Nữ", phone(used_phones), email,
          f"{rnd.randint(1, 450)} {fake.street_name()}", rnd.choice(PHUONG), rnd.choice(QUAN[cn]), "TP. Hồ Chí Minh",
          ph, created, cn, True]
    HOCVIEN.append(hv)
    return hv


def test_xml(scores, comments, ma_kh, hinh_thuc):
    names = ["Listening", "Reading", "Writing", "Speaking"]
    ky_nang = "".join(f'<KyNang Ten="{n}" Diem="{s:.1f}"><NhanXet>{c}</NhanXet></KyNang>' for n, s, c in zip(names, scores, comments))
    return (f'<KetQua HinhThuc="{hinh_thuc}" DeThi="ECMS-PT-{rnd.randint(1, 6):02d}">{ky_nang}'
            f'<NhanXetChung>{rnd.choice(NX_CHUNG)}</NhanXetChung><DeXuat MaKH="{ma_kh}"/></KetQua>')


NX = {
    "Listening": ["Nghe ý chính tốt, còn sót chi tiết số liệu", "Cần luyện nghe giọng Anh – Úc", "Bắt từ khoá khá"],
    "Reading": ["Đọc hiểu tốt, thiếu kỹ năng skimming", "Vốn từ học thuật còn hạn chế", "Làm bài đúng thời gian"],
    "Writing": ["Ngữ pháp còn lỗi thì động từ", "Ý tưởng tốt, liên kết câu chưa mượt", "Cần mở rộng từ vựng"],
    "Speaking": ["Phát âm rõ, thiếu tự tin", "Trôi chảy nhưng ngữ điệu chưa tự nhiên", "Phản xạ chậm"],
}
NX_CHUNG = ["Nền tảng ổn, nên học đúng lộ trình", "Cần củng cố ngữ pháp trước khi luyện đề", "Tiến bộ nhanh nếu học đều",
            "Khuyến khích luyện nghe nói hằng ngày"]
kt_seq = 0


def add_test(hv, ma_kh, on):
    """Kiểm tra đầu vào có điểm nằm trong khoảng của khoá đề xuất."""
    global kt_seq
    k = KH[ma_kh]
    lo, hi = float(k[4]), float(k[5])
    target = round(rnd.uniform(lo + 0.1, min(hi, 9.5) - 0.1), 1)
    scores = [min(10, max(0, round(target + rnd.uniform(-0.8, 0.8), 1))) for _ in range(4)]
    total = round(sum(scores) / 4 + 1e-9, 1)
    if not (lo <= total <= hi):           # chỉnh điểm Speaking để tổng nằm đúng khoảng
        scores[3] = min(10, max(0, round(scores[3] + (target - total) * 4, 1)))
        total = round(sum(scores) / 4 + 1e-9, 1)
    total = min(max(total, lo), hi)
    kt_seq += 1
    comments = [rnd.choice(NX[n]) for n in ["Listening", "Reading", "Writing", "Speaking"]]
    cham = rnd.choice(GIAOVU[hv[13]])
    KIEMTRA.append([kt_seq, hv[0], on, total, test_xml(scores, comments, ma_kh, rnd.choice(["Tại trung tâm", "Online"])),
                    ma_kh, cham])
    return total


# học viên theo chương trình, để học tiếp khoá cấp sau
alumni = defaultdict(list)          # MaCT -> [(MaHV, MaKH đã đạt, ngày kết thúc)]
dk_seq = 0
student_profile = {}                # MaHV -> (chuyên cần, năng lực)
student_classes = defaultdict(list)


def enrol(hv, lop, ngay_dk, giam_gia):
    global dk_seq
    dk_seq += 1
    k = KH[lop[2]]
    dk = {"MaDK": dk_seq, "MaHV": hv[0], "MaLop": lop[0], "NgayDK": ngay_dk, "HocPhi": k[8], "GiamGia": giam_gia,
          "TrangThai": "Đang học", "DiemGK": None, "DiemCK": None}
    DANGKY.append(dk)
    student_classes[hv[0]].append(lop[0])
    return dk


HV_BY_ID = {}


def simulate(lop, dks):
    """Điểm danh, điểm số, trạng thái của các đăng ký trong một lớp."""
    ma_lop, b, status = lop[0], lop[6], lop[9]
    sessions = BUOI_BY_LOP[ma_lop]
    done = [s for s in sessions if s[2] <= REF_DATE]
    mid = len(sessions) // 2
    for dk in dks:                      # một vài học viên bảo lưu giữa khoá
        if len(done) > 6 and rnd.random() < 0.03:
            dk["TrangThai"] = "Bảo lưu"
            dk["StopAt"] = rnd.randint(3, len(done) - 2)
    for dk in dks:
        att, skill = student_profile[dk["MaHV"]]
        stop = dk.get("StopAt", 10 ** 6)
        absent = 0
        for s in done:
            if s[1] > stop:
                break
            r = rnd.random()
            st = "Có mặt" if r < att else rnd.choice(["Vắng", "Vắng", "Muộn", "Có phép"])
            absent += st == "Vắng"
            DIEMDANH.append([dk["MaDK"], ma_lop, s[1], st, "Báo bận việc gia đình" if st == "Có phép" else None])
        rate = 1 - absent / max(1, len(done))
        if dk["TrangThai"] == "Bảo lưu":
            continue
        if len(done) >= mid:
            dk["DiemGK"] = round(min(10, max(2, rnd.gauss(skill, 1.0) - (1 - rate) * 5)) * 4) / 4
        if status == "Đã kết thúc":
            dk["DiemCK"] = round(min(10, max(1.5, rnd.gauss(skill, 1.1) - (1 - rate) * 6)) * 4) / 4
            dk["TrangThai"] = "Hoàn thành"
            tb = round(dk["DiemGK"] * 0.4 + dk["DiemCK"] * 0.6, 2)
            dk["KetQua"] = "Đạt" if tb >= 5 else "Không đạt"
            if dk["KetQua"] == "Đạt":
                alumni[KH[lop[2]][2]].append((dk["MaHV"], lop[2], b))


DK_BY_LOP = defaultdict(list)
for lop in LOPHOC:
    ma_lop, _, ma_kh, cn, gv, a, b, max_ss, _, status = lop
    k = KH[ma_kh]
    kids = k[2] == "KIDS"
    if status == "Sắp mở":
        target = rnd.randint(8, 18)
    elif ma_lop.startswith("IE55") and max_ss == 20:
        target = max_ss                                         # lớp đầy
    else:
        target = rnd.randint(max_ss - 7, max_ss)
    chosen = []
    # 1) học viên đã Đạt khoá tiên quyết ở lớp kết thúc trước ngày khai giảng (giảm 10%)
    pre = PREREQ[ma_kh]
    if pre:
        pool = [x for x in alumni[k[2]] if x[1] == pre and x[2] < a and ma_lop not in student_classes[x[0]]]
        pool = list({x[0]: x for x in pool}.values())
        rnd.shuffle(pool)
        for ma_hv, _, _ in pool[: int(target * 0.6)]:
            chosen.append((HV_BY_ID[ma_hv], "alumni"))
    # 2) học viên mới, test đầu vào phù hợp khoá
    while len(chosen) < target:
        created = min(a - timedelta(days=rnd.randint(10, 60)), REF_DATE - timedelta(days=rnd.randint(0, 10)))
        hv = new_student(cn if rnd.random() < 0.85 else rnd.choice(cn_cycle), kids, created)
        HV_BY_ID[hv[0]] = hv
        add_test(hv, ma_kh, created)
        student_profile[hv[0]] = (rnd.choice([0.97] * 6 + [0.9] * 3 + [0.68]), rnd.gauss(7, 1.3))
        chosen.append((hv, "new"))
    for hv, src in chosen:
        ngay_dk = min(max(hv[12], a - timedelta(days=rnd.randint(3, 25))), REF_DATE)
        ngay_dk = max(ngay_dk, hv[12])
        giam = 10.0 if src == "alumni" else rnd.choice([0.0] * 8 + [5.0, 15.0])
        DK_BY_LOP[ma_lop].append(enrol(hv, lop, ngay_dk, giam))
    simulate(lop, DK_BY_LOP[ma_lop])

# Học viên đăng ký cùng lúc 2 lớp sắp mở khác chương trình (1 phiếu thu nhiều dòng – master–detail)
upcoming = [l for l in LOPHOC if l[9] == "Sắp mở" and KH[l[2]][2] != "KIDS"]
for _ in range(8):
    l1, l2 = rnd.sample(upcoming, 2)
    if KH[l1[2]][2] == KH[l2[2]][2]:
        continue
    cands = [dk for dk in DK_BY_LOP[l1[0]] if l2[0] not in student_classes[dk["MaHV"]]]
    if not cands or len(DK_BY_LOP[l2[0]]) >= l2[7]:
        continue
    dk1 = rnd.choice(cands)
    hv = HV_BY_ID[dk1["MaHV"]]
    if PREREQ[l2[2]]:
        add_test(hv, l2[2], dk1["NgayDK"])
    DK_BY_LOP[l2[0]].append(enrol(hv, l2, dk1["NgayDK"], 5.0))

# Các lớp cấp 2, 3 đã chọn học viên "alumni" trước khi biết kết quả lớp trước (thứ tự xử lý theo ngày).
# Bảo đảm RB17: học viên alumni phải Đạt khoá tiên quyết hoặc có test đầu vào phù hợp – bổ sung test nếu thiếu.
passed = {(dk["MaHV"], LOP[dk["MaLop"]][2]) for dk in DANGKY if dk.get("KetQua") == "Đạt"}
tested = defaultdict(list)
for kt in KIEMTRA:
    tested[kt[1]].append(kt)
for dk in DANGKY:
    ma_kh = LOP[dk["MaLop"]][2]
    pre = PREREQ[ma_kh]
    if pre and (dk["MaHV"], pre) not in passed:
        lo = float(KH[ma_kh][4])
        if not any(kt[3] >= lo and kt[2] <= dk["NgayDK"] for kt in tested[dk["MaHV"]]):
            add_test(HV_BY_ID[dk["MaHV"]], ma_kh, dk["NgayDK"] - timedelta(days=1))
            tested[dk["MaHV"]].append(KIEMTRA[-1])

# Sĩ số hiện tại: số đăng ký Đang học / Hoàn thành
for lop in LOPHOC:
    lop[8] = sum(1 for dk in DK_BY_LOP[lop[0]] if dk["TrangThai"] in ("Đang học", "Hoàn thành"))

# ----------------------------------------------------------------- phiếu thu
pt_seq = 0


def thanh_tien(dk):
    return round(dk["HocPhi"] * (100 - dk["GiamGia"]) / 100, -3)


def add_receipt(ma_hv, cn, when, lines):
    global pt_seq
    pt_seq += 1
    when = datetime.combine(when, time(rnd.randint(8, 20), rnd.choice([0, 15, 30, 45])))
    PHIEUTHU.append([pt_seq, ma_hv, KETOAN[cn], when, rnd.choice(["Tiền mặt", "Chuyển khoản", "Chuyển khoản", "Thẻ"]),
                     sum(t for _, t in lines), None])
    for ma_dk, tien in lines:
        CT_PT.append([pt_seq, ma_dk, tien])


paid = defaultdict(int)
by_student_day = defaultdict(list)
for dk in DANGKY:
    by_student_day[(dk["MaHV"], dk["NgayDK"])].append(dk)
for (ma_hv, ngay), dks in sorted(by_student_day.items(), key=lambda x: x[0][1]):
    cn = LOP[dks[0]["MaLop"]][3]
    r = rnd.random()
    finished = all(LOP[d["MaLop"]][9] == "Đã kết thúc" for d in dks)
    if r < 0.72 or (finished and r < 0.93):                # đóng đủ 1 lần
        when = min(ngay + timedelta(days=rnd.randint(0, 7)), REF_DATE)
        add_receipt(ma_hv, cn, when, [(d["MaDK"], thanh_tien(d)) for d in dks])
        for d in dks:
            paid[d["MaDK"]] = thanh_tien(d)
    elif r < 0.9:                                          # đóng 2 đợt
        when1 = min(ngay + timedelta(days=rnd.randint(0, 5)), REF_DATE)
        first = [(d["MaDK"], round(thanh_tien(d) * 0.5, -3)) for d in dks]
        add_receipt(ma_hv, cn, when1, first)
        for (m, t) in first:
            paid[m] += t
        when2 = ngay + timedelta(days=rnd.randint(20, 45))
        if when2 <= REF_DATE and rnd.random() < 0.8:
            second = [(d["MaDK"], thanh_tien(d) - paid[d["MaDK"]]) for d in dks]
            add_receipt(ma_hv, cn, when2, second)
            for (m, t) in second:
                paid[m] += t
    # còn lại: chưa đóng → công nợ

for dk in DANGKY:
    p, tt = paid[dk["MaDK"]], thanh_tien(dk)
    dk["TrangThaiHP"] = "Đã đóng" if p >= tt else ("Đóng một phần" if p > 0 else "Chưa đóng")

# ----------------------------------------------------------------- tài khoản
TAIKHOAN = []
role_map = {"Quản lý": "QuanLy", "Giáo vụ": "GiaoVu", "Kế toán": "KeToan", "Giáo viên": "GiaoVien"}
for nv in NHANVIEN:
    user = ascii_slug(nv[2]) + ascii_slug(nv[1].split()[0])[:1] + nv[0][-2:]
    TAIKHOAN.append([user, "Ecms@2026", role_map[nv[7]], nv[0], None])
for hv in HOCVIEN[:60]:
    TAIKHOAN.append([hv[0].lower(), "Hocvien@2026", "HocVien", None, hv[0]])
# tài khoản demo dễ nhớ
DEMO = {"QuanLy": "quanly", "GiaoVu": "giaovu", "KeToan": "ketoan", "GiaoVien": "giaovien"}
for role, name in DEMO.items():
    nv = next(t for t in TAIKHOAN if t[2] == role)
    nv[0] = name
next(t for t in TAIKHOAN if t[2] == "HocVien")[0] = "hocvien"


# ----------------------------------------------------------------- ghi file SQL
def build_sql():
    parts = [f"""/* =====================================================================
   ECMS – 02_seed.sql : dữ liệu mẫu                                   (T08)
   File sinh tự động bằng scripts/gen_seed.py (seed={SEED}, ngày tham chiếu {REF_DATE}).
   KHÔNG sửa tay – sửa script rồi chạy lại:  python3 scripts/gen_seed.py
   Chạy lại được: xoá toàn bộ dữ liệu cũ rồi nạp lại; tạm tắt trigger để giá trị suy diễn
   (sĩ số, tổng tiền, trạng thái học phí, kết quả) được nạp đúng như đã tính sẵn.

   Tài khoản demo ứng dụng web (mật khẩu chỉ dùng cho môi trường phát triển):
     quanly / giaovu / ketoan / giaovien  – mật khẩu Ecms@2026
     hocvien                              – mật khẩu Hocvien@2026
   ===================================================================== */
USE ECMS;
GO
SET NOCOUNT ON;
SET XACT_ABORT ON;
GO
-- Tắt trigger trên mọi bảng trong lúc nạp
DECLARE @sql NVARCHAR(MAX) = N'';
SELECT @sql += N'ALTER TABLE ' + QUOTENAME(SCHEMA_NAME(schema_id)) + N'.' + QUOTENAME(name) + N' DISABLE TRIGGER ALL;'
FROM sys.tables WHERE is_ms_shipped = 0;
EXEC sp_executesql @sql;
GO
-- Xoá dữ liệu cũ theo thứ tự phụ thuộc
UPDATE CHINHANH SET MaNVQuanLy = NULL;
DELETE FROM NHATKY; DELETE FROM CANHBAO_CHUYENCAN; DELETE FROM BANGLUONG; DELETE FROM TAIKHOAN;
DELETE FROM CT_PHIEUTHU; DELETE FROM PHIEUTHU; DELETE FROM DIEMDANH; DELETE FROM DANGKY;
DELETE FROM KIEMTRA_DAUVAO; DELETE FROM BUOIHOC; DELETE FROM LICHHOC; DELETE FROM LOPHOC;
DELETE FROM HOCVIEN; DELETE FROM KHOAHOC; DELETE FROM CHUONGTRINH; DELETE FROM NGAYLE;
DELETE FROM CHUNGCHI_GV; DELETE FROM GIAOVIEN; DELETE FROM PHONGHOC; DELETE FROM CAHOC;
UPDATE NHANVIEN SET MaNVQuanLy = NULL; DELETE FROM NHANVIEN; DELETE FROM CHINHANH;
DBCC CHECKIDENT ('NHATKY', RESEED, 0) WITH NO_INFOMSGS;
DBCC CHECKIDENT ('CANHBAO_CHUYENCAN', RESEED, 0) WITH NO_INFOMSGS;
GO
"""]
    parts.append(inserts("CHINHANH", ["MaCN", "TenCN", "DiaChi", "SoDienThoai", "NgayThanhLap"], [list(c) for c in CHINHANH]))
    parts.append(inserts("NHANVIEN", ["MaNV", "HoNV", "TenNV", "NgaySinh", "GioiTinh", "SoDienThoai", "Email", "ChucVu",
                                      "LuongCoBan", "NgayVaoLam", "MaCN", "MaNVQuanLy", "TrangThai"],
                         [nv for nv in NHANVIEN if nv[11] is None] + [nv for nv in NHANVIEN if nv[11] is not None and NV[nv[11]][11] is None]
                         + [nv for nv in NHANVIEN if nv[11] is not None and NV[nv[11]][11] is not None]))
    parts.append("\n".join(f"UPDATE CHINHANH SET MaNVQuanLy = {q(m)} WHERE MaCN = {q(cn)};" for cn, m in managers.items()) + "\nGO")
    parts.append(inserts("GIAOVIEN", ["MaGV", "LoaiGV", "QuocTich", "TrinhDo", "DonGiaBuoi"], GIAOVIEN))
    parts.append(inserts("CHUNGCHI_GV", ["MaGV", "TenChungChi", "Diem", "NgayCap", "NoiCap"], CHUNGCHI))
    parts.append(inserts("PHONGHOC", ["MaCN", "MaPhong", "SucChua", "LoaiPhong"], PHONGHOC))
    parts.append(inserts("CAHOC", ["MaCa", "TenCa", "GioBatDau", "GioKetThuc"], [list(c) for c in CAHOC]))
    parts.append(inserts("NGAYLE", ["Ngay", "TenNgayLe"], [list(x) for x in NGAYLE]))
    parts.append(inserts("CHUONGTRINH", ["MaCT", "TenCT", "DoiTuong", "MoTa"], [list(c) for c in CHUONGTRINH]))
    parts.append(inserts("KHOAHOC", ["MaKH", "TenKH", "MaCT", "CapDo", "DiemDauVaoTu", "DiemDauVaoDen", "MucTieuDauRa", "SoBuoi",
                                     "HocPhi", "MaKHTienQuyet"],
                         [[*k[:4], float(k[4]), float(k[5]), *k[6:], PREREQ[k[0]]] for k in sorted(KHOAHOC, key=lambda k: k[3])]))
    parts.append(inserts("LOPHOC", ["MaLop", "TenLop", "MaKH", "MaCN", "MaGV", "NgayKhaiGiang", "NgayKetThuc", "SiSoToiDa",
                                    "SiSoHienTai", "TrangThai"], LOPHOC))
    parts.append(inserts("LICHHOC", ["MaLop", "Thu", "MaCa", "MaCN", "MaPhong"], LICHHOC))
    parts.append(inserts("BUOIHOC", ["MaLop", "STT", "NgayHoc", "MaCa", "MaPhong", "NoiDung", "TrangThai"], BUOIHOC))
    parts.append(inserts("HOCVIEN", ["MaHV", "HoHV", "TenHV", "NgaySinh", "GioiTinh", "SoDienThoai", "Email", "SoNha", "PhuongXa",
                                     "QuanHuyen", "TinhTP", "HoTenPhuHuynh", "NgayTao", "MaCN", "TrangThai"], HOCVIEN))
    parts.append(inserts("KIEMTRA_DAUVAO", ["MaKT", "MaHV", "NgayKT", "DiemTong", "KetQuaChiTiet", "MaKHDeXuat", "MaNVCham"],
                         sorted(KIEMTRA, key=lambda x: x[0]), identity=True))
    parts.append(inserts("DANGKY", ["MaDK", "MaHV", "MaLop", "NgayDK", "HocPhi", "GiamGia", "TrangThaiHP", "DiemGK", "DiemCK",
                                    "KetQua", "TrangThai"],
                         [[d["MaDK"], d["MaHV"], d["MaLop"], d["NgayDK"], d["HocPhi"], d["GiamGia"], d["TrangThaiHP"], d["DiemGK"],
                           d["DiemCK"], d.get("KetQua"), d["TrangThai"]] for d in DANGKY], identity=True))
    parts.append(inserts("DIEMDANH", ["MaDK", "MaLop", "STT", "TrangThai", "GhiChu"], DIEMDANH, batch=1000))
    parts.append(inserts("PHIEUTHU", ["MaPT", "MaHV", "MaNV", "NgayThu", "HinhThuc", "TongTien", "GhiChu"], PHIEUTHU, identity=True))
    parts.append(inserts("CT_PHIEUTHU", ["MaPT", "MaDK", "SoTien"], CT_PT))
    parts.append("-- TAIKHOAN: mật khẩu băm SHA2_256(salt + mật khẩu UTF-16), salt ngẫu nhiên 16 byte mỗi tài khoản\n"
                 "INSERT INTO TAIKHOAN (TenDangNhap, MatKhauHash, Salt, VaiTro, MaNV, MaHV)\n"
                 "SELECT v.TenDangNhap, HASHBYTES('SHA2_256', s.Salt + CAST(v.MatKhau AS VARBINARY(200))), s.Salt, v.VaiTro, v.MaNV, v.MaHV\n"
                 "FROM (VALUES\n" + ",\n".join(f"  ({q(u)}, {q(p)}, {q(r)}, {q(nv)}, {q(hv)})" for u, p, r, nv, hv in TAIKHOAN)
                 + "\n) v (TenDangNhap, MatKhau, VaiTro, MaNV, MaHV)\nCROSS APPLY (SELECT CRYPT_GEN_RANDOM(16) AS Salt) s;\nGO")
    parts.append("""-- Bật lại trigger
DECLARE @sql NVARCHAR(MAX) = N'';
SELECT @sql += N'ALTER TABLE ' + QUOTENAME(SCHEMA_NAME(schema_id)) + N'.' + QUOTENAME(name) + N' ENABLE TRIGGER ALL;'
FROM sys.tables WHERE is_ms_shipped = 0;
EXEC sp_executesql @sql;
GO
-- Thống kê số dòng
SELECT t.name AS Bang, SUM(p.rows) AS SoDong
FROM sys.tables t JOIN sys.partitions p ON p.object_id = t.object_id AND p.index_id IN (0, 1)
GROUP BY t.name ORDER BY t.name;
PRINT N'✓ 02_seed.sql: đã nạp dữ liệu mẫu.';
GO
""")
    return "\n\n".join(parts)


# ----------------------------------------------------------------- CSV cho T18
def write_csv():
    OUT_CSV.mkdir(parents=True, exist_ok=True)
    head = ["HoHV", "TenHV", "NgaySinh", "GioiTinh", "SoDienThoai", "Email", "QuanHuyen", "MaCN", "MaKHQuanTam", "NgayDangKy"]
    r2 = random.Random(SEED + 1)
    phones = set(used_phones)

    def row(i, clean=True):
        male = r2.random() < 0.5
        ho, ten = split_name(gender_name(male, r2))
        cn = r2.choice(cn_cycle)
        ns = date(r2.randint(1988, 2010), r2.randint(1, 12), r2.randint(1, 28))
        while True:
            p = "09" + "".join(r2.choice("0123456789") for _ in range(8))
            if p not in phones:
                phones.add(p)
                break
        email = f"{ascii_slug(ten)}{ascii_slug(ho.split()[-1])}.dk{i}@gmail.com"
        rec = [ho, ten, ns.strftime("%d/%m/%Y"), "Nam" if male else "Nữ", p, email, r2.choice(QUAN[cn]), cn,
               r2.choice(list(KH)), (REF_DATE - timedelta(days=r2.randint(0, 60))).strftime("%d/%m/%Y")]
        if not clean:
            kind = r2.choice(["date", "phone", "email", "cn", "kh", "empty", "dup"])
            if kind == "date":
                rec[2] = r2.choice(["31/02/2005", "2005-13-01", "abc"])
            elif kind == "phone":
                rec[4] = r2.choice(["", "09012", "0901-234-567x"])
            elif kind == "email":
                rec[5] = r2.choice(["khong-co-a-cong", "a@b", "@gmail.com"])
            elif kind == "cn":
                rec[7] = "CN09"
            elif kind == "kh":
                rec[8] = "XYZ1"
            elif kind == "empty":
                rec[1] = ""
            elif kind == "dup":
                rec = None
        return rec

    rows = []
    for i in range(1200):
        rec = row(i, clean=r2.random() > 0.04)
        if rec is None:                                   # trùng số điện thoại với dòng trước
            rec = list(rows[-1]) if rows else row(i)
            rec[5] = f"trung.{i}@gmail.com"
        rows.append(rec)
    with open(OUT_CSV / "hocvien_online.csv", "w", newline="", encoding="utf-8-sig") as f:
        w = csv.writer(f)
        w.writerow(head)
        w.writerows(rows)
    with open(OUT_CSV / "hocvien_10000.csv", "w", newline="", encoding="utf-8") as f:
        w = csv.writer(f)
        w.writerow(head)
        for i in range(10000):
            w.writerow(row(10000 + i))
    # danh mục khoá học xuất ra CSV (minh hoạ export / import danh mục)
    with open(OUT_CSV / "khoahoc.csv", "w", newline="", encoding="utf-8-sig") as f:
        w = csv.writer(f)
        w.writerow(["MaKH", "TenKH", "MaCT", "CapDo", "SoBuoi", "HocPhi"])
        for k in KHOAHOC:
            w.writerow([k[0], k[1], k[2], k[3], k[7], k[8]])


def main():
    OUT_SQL.write_text(build_sql() + "\n", encoding="utf-8")
    write_csv()
    stats = {
        "CHINHANH": len(CHINHANH), "NHANVIEN": len(NHANVIEN), "GIAOVIEN": len(GIAOVIEN), "CHUNGCHI_GV": len(CHUNGCHI),
        "PHONGHOC": len(PHONGHOC), "CAHOC": len(CAHOC), "NGAYLE": len(NGAYLE), "CHUONGTRINH": len(CHUONGTRINH),
        "KHOAHOC": len(KHOAHOC), "LOPHOC": len(LOPHOC), "LICHHOC": len(LICHHOC), "BUOIHOC": len(BUOIHOC),
        "HOCVIEN": len(HOCVIEN), "KIEMTRA_DAUVAO": len(KIEMTRA), "DANGKY": len(DANGKY), "DIEMDANH": len(DIEMDANH),
        "PHIEUTHU": len(PHIEUTHU), "CT_PHIEUTHU": len(CT_PT), "TAIKHOAN": len(TAIKHOAN),
    }
    for k, v in stats.items():
        print(f"{k:<16}{v:>7}")
    print(f"→ {OUT_SQL.relative_to(ROOT)} ({OUT_SQL.stat().st_size // 1024} KB), {OUT_CSV.relative_to(ROOT)}/*.csv")


if __name__ == "__main__":
    main()
