(() => {
  'use strict';

  const $ = (sel, el = document) => el.querySelector(sel);
  const $$ = (sel, el = document) => [...el.querySelectorAll(sel)];
  const D = window.TIEN_DO;
  const T = D.tienDo;
  const YC = D.yeuCau;
  const LT = D.lapTrinh;
  const REPO = 'https://github.com/nhutruong-uit/ecms';
  const SVG = 'http://www.w3.org/2000/svg';

  function h(tag, attrs = {}, ...children) {
    const el = document.createElement(tag);
    for (const [k, v] of Object.entries(attrs)) {
      if (v == null || v === false) continue;
      if (k === 'class') el.className = v;
      else if (k === 'style' && typeof v === 'object') Object.assign(el.style, v);
      else if (k.startsWith('on')) el.addEventListener(k.slice(2), v);
      else el.setAttribute(k, v === true ? '' : v);
    }
    for (const c of children.flat(Infinity)) {
      if (c == null || c === false) continue;
      el.append(c instanceof Node ? c : document.createTextNode(String(c)));
    }
    return el;
  }
  function s(tag, attrs = {}, ...children) {
    const el = document.createElementNS(SVG, tag);
    for (const [k, v] of Object.entries(attrs)) {
      if (v == null || v === false) continue;
      if (k === 'class') el.setAttribute('class', v);
      else if (k.startsWith('on')) el.addEventListener(k.slice(2), v);
      else el.setAttribute(k, v);
    }
    for (const c of children.flat(Infinity)) if (c != null && c !== false) el.append(c);
    return el;
  }
  const fmtNgay = (iso) => iso.split('-').reverse().slice(0, 2).join('/');
  const fmtSo = (n) => n.toLocaleString('vi-VN');
  const ngayISO = (d) => `${d.getFullYear()}-${String(d.getMonth() + 1).padStart(2, '0')}-${String(d.getDate()).padStart(2, '0')}`;
  const homNay = ngayISO(new Date());

  // ---------- số liệu gắn vào slide ----------
  function bindData() {
    const xong = T.viec.filter((v) => v.xong).length;
    const sp = T.sprint.find((x) => x.start <= homNay && homNay <= x.end);
    const vals = {
      capNhat: D.capNhat.split('-').reverse().join('/'),
      viecXong: xong,
      viecTong: T.viec.length,
      ycChucNang: YC.chucNang.length,
      ycPhiChucNang: YC.phiChucNang.length,
      ycBaoCao: YC.baoCao.length,
      ycNhom: YC.nhomNguoiDung.length,
      ltProcedure: LT.procedure.length,
      ltFunction: LT.function.length,
      ltTrigger: LT.trigger.length,
      ltView: LT.view.length,
      ltCursor: LT.cursor.length,
      nfBcnf: Object.values(D.schema.bang).filter((t) => t.nf === 'BCNF').length,
      nf2: Object.values(D.schema.bang).filter((t) => t.nf === '2NF').length,
      nf1: Object.values(D.schema.bang).filter((t) => t.nf === '1NF').length,
      sprintTen: sp ? sp.name.split('·')[0].trim() : 'giai đoạn cuối',
      sprintSo: sp ? sp.id.slice(1) : 4,
      sprintKhoang: sp ? `${fmtNgay(sp.start)} – ${fmtNgay(sp.end)}` : 'đã qua lịch',
      han: T.han.split('-').reverse().join('/'),
    };
    for (const el of $$('[data-bind]')) el.textContent = vals[el.dataset.bind];
  }

  const chipOf = (v) => h('a', {
    class: `chip${v.xong ? '' : ' open'}`, href: `${REPO}/issues/${v.issue}`, target: '_blank', rel: 'noopener',
    'data-tip': `${v.id}: ${v.ten} · ${v.xong ? 'đã xong' : 'còn lại'}`,
  }, v.id);

  function renderMembers() {
    for (const el of $$('.member')) {
      const mine = T.viec.filter((v) => v.ai === el.dataset.ai);
      $('.chips', el).replaceChildren(...mine.map(chipOf));
      const xong = mine.filter((v) => v.xong).length;
      $('.done', el).textContent = `${xong}/${mine.length} việc đã xong`;
    }
  }

  function renderCoverage() {
    for (const tr of $$('#coverage tbody tr')) {
      const ds = tr.dataset.t.split(',').map((id) => T.viec.find((v) => v.id === id));
      $('.ts', tr).replaceChildren(h('div', { class: 'chips' }, ds.map(chipOf)));
      const xong = ds.filter((v) => v.xong).length;
      $('.st', tr).textContent = xong === ds.length ? '✓ Xong' : `${xong}/${ds.length}`;
    }
  }

  // ---------- lộ trình theo kế hoạch ----------
  const sprintHienTai = () => T.sprint.find((sp) => sp.start <= homNay && homNay <= sp.end);

  function renderSprints() {
    const ngay = (iso) => new Date(`${iso}T12:00:00`);
    const soNgay = (a, b) => Math.round((ngay(b) - ngay(a)) / 86400000) + 1;
    const tong = soNgay(T.batDau, T.han);
    const line = $('#planLine');
    line.replaceChildren(...T.sprint.map((sp) => h('div', {
      class: `seg${sp.end < homNay ? ' past' : ''}${sp === sprintHienTai() ? ' now' : ''}`,
      style: { flex: soNgay(sp.start, sp.end) },
    }, h('b', {}, sp.id), h('span', {}, `${fmtNgay(sp.start)} → ${fmtNgay(sp.end)}`))));
    if (homNay >= T.batDau && homNay <= T.han) {
      const vt = ((soNgay(T.batDau, homNay) - 0.5) / tong) * 100;
      line.append(h('i', { class: 'today', style: { left: `${vt}%` } }, h('em', {}, `Hôm nay ${fmtNgay(homNay)}`)));
    }
    $('#sprints').replaceChildren(...T.sprint.map((sp) => {
      const dangChay = sp === sprintHienTai();
      const [ma, ten] = sp.name.split('·').map((x) => x.trim());
      return h('article', { class: `sprint${dangChay ? ' now' : ''}` },
        h('div', { class: 'tag-row' }, dangChay ? h('span', { class: 'now-tag' }, 'Đang diễn ra') : h('span', { class: 'dates' }, sp.end < homNay ? 'Đã qua' : 'Sắp tới')),
        h('h3', {}, ma, h('small', {}, ten)),
        h('div', { class: 'dates' }, `${fmtNgay(sp.start)} → ${fmtNgay(sp.end)}`),
        h('p', {}, sp.goal),
        h('div', { class: 'chips' }, T.viec.filter((v) => v.sprint === sp.id).map(chipOf)));
    }));
  }

  // ---------- modal chi tiết ở slide tóm tắt ----------
  const TEN_NGAN = { nhu: 'Như', tram: 'Trâm', phu: 'Phú', duong: 'Dương', giang: 'Giang' };
  let modalTu = null;

  function moModal(tieuDe, noiDung, tu) {
    modalTu = tu;
    $('#modalTitle').textContent = tieuDe;
    $('#modalBody').replaceChildren(h('div', {}, noiDung));
    $('#modalBody').scrollTop = 0;
    $('#modal').hidden = false;
    $('#modalClose').focus();
  }
  function dongModal() {
    $('#modal').hidden = true;
    modalTu?.focus();
    modalTu = null;
  }

  function chiTietSprint() {
    return T.sprint.map((sp) => {
      const ds = T.viec.filter((v) => v.sprint === sp.id);
      const xong = ds.filter((v) => v.xong).length;
      const dangChay = sp === sprintHienTai();
      const [ma, ten] = sp.name.split('·').map((x) => x.trim());
      return h('section', { class: `m-sprint${dangChay ? ' now' : ''}` },
        h('div', { class: 'm-sprint-head' },
          h('h3', {}, `${ma} · ${ten}`),
          dangChay ? h('span', { class: 'now-tag' }, 'Đang diễn ra') : h('span', { class: 'm-note' }, sp.end < homNay ? 'Đã qua' : 'Sắp tới')),
        h('div', { class: 'm-note' }, `${fmtNgay(sp.start)} → ${fmtNgay(sp.end)} · ${xong}/${ds.length} việc đã xong`),
        h('p', {}, sp.goal),
        h('div', { class: 'chips' }, ds.map(chipOf)));
    });
  }

  function chiTietViec() {
    return T.sprint.map((sp) => {
      const ds = T.viec.filter((v) => v.sprint === sp.id);
      const xong = ds.filter((v) => v.xong).length;
      return h('section', { class: 'm-group' },
        h('h3', {}, `${sp.name} · ${xong}/${ds.length}`),
        h('table', { class: 'm-table' },
          h('thead', {}, h('tr', {}, ['Mã', 'Công việc', 'Phụ trách', 'Hạn', 'Trạng thái'].map((t) => h('th', {}, t)))),
          h('tbody', {}, ds.map((v) => h('tr', {},
            h('td', {}, chipOf(v)),
            h('td', {}, v.ten),
            h('td', {}, TEN_NGAN[v.ai]),
            h('td', {}, fmtNgay(v.han)),
            h('td', { class: v.xong ? 'm-ok' : 'm-open' }, v.xong ? '✓ Xong' : '○ Còn lại'))))));
    });
  }

  // Bảng chi tiết trong modal (yêu cầu, chuẩn hoá); cls: lớp từng cột ('ma' đậm, 'nw' không xuống dòng)
  function bangChiTiet(cot, hang, cls) {
    return h('table', { class: 'm-req' },
      h('thead', {}, h('tr', {}, cot.map((t) => h('th', {}, t)))),
      h('tbody', {}, hang.map((r) => h('tr', {}, r.map((c, i) => h('td', { class: cls[i] }, c))))));
  }

  function chiTietYeuCau(loai) {
    if (loai === 'chucNang') return bangChiTiet(['Mã', 'Yêu cầu', 'Người dùng'], YC.chucNang.map((r) => [r.ma, r.yeuCau, r.nguoiDung]), ['ma', '', 'nw']);
    if (loai === 'phiChucNang') return bangChiTiet(['Mã', 'Nhóm', 'Yêu cầu'], YC.phiChucNang.map((r) => [r.ma, r.nhom, r.yeuCau]), ['ma', 'nw', '']);
    if (loai === 'baoCao') return bangChiTiet(['Báo cáo', 'Loại', 'Người dùng'], YC.baoCao.map((r) => [r.ten, r.loai, r.nguoiDung]), ['', 'nw', 'nw']);
    return bangChiTiet(['Nhóm người dùng', 'Mô tả', 'Role trong CSDL'], YC.nhomNguoiDung.map((r) => [r.ten, r.moTa, h('code', {}, r.role)]), ['ma', '', 'nw']);
  }

  // Ba ô số ở slide chuẩn hoá: nf là dạng chuẩn trong D.schema, ghiChu giải thích vì sao nhóm giữ nguyên (báo cáo mục 2.4)
  const NF_NHOM = {
    bcnf: { nf: 'BCNF', tieuDe: (n) => `${n} quan hệ đạt BCNF`, ghiChu: 'Mọi phụ thuộc hàm đều có vế trái là siêu khoá, nên không còn dư thừa do phụ thuộc hàm.' },
    nf2: { nf: '2NF', tieuDe: (n) => `${n} quan hệ chỉ đạt 2NF`, ghiChu: 'Có thuộc tính suy diễn (thành tiền, điểm trung bình, tỷ lệ vắng…) phụ thuộc bắc cầu nên vi phạm 3NF. Nhóm vẫn lưu sẵn để tra công nợ, bảng điểm nhanh và đánh chỉ mục được; bảng lương và cảnh báo chuyên cần còn là chứng từ chốt tại một thời điểm.' },
    nf1: { nf: '1NF', tieuDe: (n) => `${n} quan hệ vi phạm 2NF`, ghiChu: 'Có phụ thuộc bộ phận (MaLop → MaCN, MaDK → MaLop). Nhóm giữ cột dư này để khoá ngoại phức hợp tự kiểm tra, thay cho trigger dễ bị vô hiệu hoá nhầm.' },
  };

  function chiTietChuanHoa(loai) {
    const g = NF_NHOM[loai];
    const ds = Object.entries(D.schema.bang).filter(([, t]) => t.nf === g.nf);
    const dongBang = ds.map(([ten, t]) => [
      h('a', { href: `#/schema/${ten}`, onclick: dongModal }, ten),
      t.y, D.chuanHoa[ten].phuThuoc, D.chuanHoa[ten].khoa]);
    return [
      h('p', { class: 'm-lead' }, g.ghiChu),
      bangChiTiet(['Quan hệ', 'Ý nghĩa', 'Phụ thuộc hàm khác', 'Khoá dự tuyển'], dongBang, ['ma', '', '', '']),
    ];
  }

  // Năm ô số ở slide lập trình CSDL: tên và ý nghĩa từng đối tượng, gom theo nhóm
  const LT_TEN = { procedure: 'procedure', function: 'function', trigger: 'trigger', view: 'view', cursor: 'nghiệp vụ dùng cursor' };

  function chiTietLapTrinh(loai) {
    let nhomCu = null;
    const dong = [];
    for (const o of LT[loai]) {
      if (o.nhom && o.nhom !== nhomCu) {
        dong.push(h('tr', { class: 'm-grp' }, h('td', { colspan: 2 }, o.nhom)));
        nhomCu = o.nhom;
      }
      dong.push(h('tr', {}, h('td', { class: 'ma' }, o.ten), h('td', {}, o.yNghia)));
    }
    return [
      loai === 'cursor' ? h('p', { class: 'm-lead' }, 'Mỗi nghiệp vụ có một bản xử lý theo tập hợp (hậu tố _SetBased) để so sánh.') : null,
      h('table', { class: 'm-req' },
        h('thead', {}, h('tr', {}, h('th', {}, 'Tên'), h('th', {}, 'Ý nghĩa'))),
        h('tbody', {}, dong)),
    ];
  }

  function initModal() {
    const dem =() => `${T.viec.filter((v) => v.xong).length}/${T.viec.length}`;
    const CHI_TIET = {
      sprint: () => ['Lộ trình 4 sprint theo kế hoạch', chiTietSprint()],
      viec: () => [`${dem()} công việc đã xong`, chiTietViec()],
      chucNang: () => [`${YC.chucNang.length} yêu cầu chức năng`, chiTietYeuCau('chucNang')],
      phiChucNang: () => [`${YC.phiChucNang.length} yêu cầu phi chức năng`, chiTietYeuCau('phiChucNang')],
      baoCao: () => [`${YC.baoCao.length} báo cáo`, chiTietYeuCau('baoCao')],
      nhom: () => [`${YC.nhomNguoiDung.length} nhóm người dùng, mỗi nhóm một role`, chiTietYeuCau('nhom')],
      ...Object.fromEntries(Object.keys(LT_TEN).map((k) => [k, () => [`${LT[k].length} ${LT_TEN[k]}`, chiTietLapTrinh(k)]])),
      ...Object.fromEntries(Object.entries(NF_NHOM).map(([k, g]) => [k, () => {
        const n = Object.values(D.schema.bang).filter((t) => t.nf === g.nf).length;
        return [g.tieuDe(n), chiTietChuanHoa(k)];
      }])),
    };
    for (const b of $$('[data-modal]')) {
      b.addEventListener('click', () => {
        const [tieuDe, noiDung] = CHI_TIET[b.dataset.modal]();
        moModal(tieuDe, noiDung, b);
      });
    }
    $('#modalClose').addEventListener('click', dongModal);
    $('#modal').addEventListener('click', (e) => { if (e.target === e.currentTarget) dongModal(); });
  }

  // ---------- cursor so với xử lý theo tập hợp (báo cáo Bảng 3.52) ----------
  function renderCursor() {
    const data = [
      ['Bảng lương 12 tháng', 69.39, 10.05, '6,9 lần'],
      ['Cảnh báo chuyên cần', 24.23, 8.80, '2,8 lần'],
      ['Sinh 30 buổi học', 11.52, 10.72, '1,1 lần'],
    ];
    const max = 69.39;
    const so = (v) => v.toLocaleString('vi-VN', { minimumFractionDigits: 2 });
    const hang = (v, mau, ten, tieude) => h('div', { class: 'hbar-r', 'data-tip': `${tieude} · ${ten}: ${so(v)} ms` },
      h('i', { style: { width: `${(v / max) * 74}%`, background: mau } }), `${so(v)} ms`);
    $('#cursorBars').replaceChildren(...data.map(([t, c, b, lan]) => h('div', {},
      h('div', { class: 'hbar-t' }, `${t}: Cursor chậm hơn ${lan}`),
      h('div', { class: 'hbar' }, hang(c, 'var(--s-cursor)', 'Cursor', t), hang(b, 'var(--accent)', 'Theo tập hợp', t)))));
  }

  // ---------- bản đồ mã nguồn ----------
  function renderCodemap() {
    const ds = [
      ['Tạo bảng, ràng buộc, chỉ mục', 'database/01_schema.sql'],
      ['Dữ liệu mẫu', 'database/02_seed.sql'],
      ['Function', 'database/03_functions.sql'],
      ['View', 'database/04_views.sql'],
      ['Stored procedure', 'database/05_procedures.sql'],
      ['Trigger, nhật ký', 'database/06_triggers.sql'],
      ['Cursor', 'database/07_cursors.sql'],
      ['Login, role, phân quyền', 'database/08_security.sql'],
      ['XML Schema, XQuery', 'database/09_xml.sql'],
      ['31 truy vấn nghiệp vụ', 'database/10_queries.sql'],
      ['Sao lưu, phục hồi', 'database/11_backup_restore.sql'],
      ['Nhập, xuất dữ liệu', 'database/12_import_export.sql'],
      ['CSDL phân tán', 'database/13_distributed.sql'],
      ['Mã hoá, Audit, ledger', 'database/14_encryption_audit.sql'],
      ['Bộ kiểm thử SQL', 'database/tests'],
      ['Ứng dụng web', 'app'],
      ['Báo cáo PDF, Excel, Word', 'app/reports'],
      ['CSDL hướng đối tượng', 'oodb'],
      ['MongoDB', 'nosql'],
      ['Lược đồ quan hệ, ODL', 'docs/design'],
      ['Kiểm thử giao diện', 'tests'],
      ['CI', '.github/workflows/ci.yml'],
      ['Báo cáo theo chương', 'report'],
    ];
    $('#codemap').replaceChildren(...ds.map(([t, p]) => h('a', {
      href: `${REPO}/${/\.\w+$/.test(p) ? 'blob' : 'tree'}/main/${p}`, target: '_blank', rel: 'noopener',
    }, h('b', {}, t), h('span', {}, p))));
  }

  // ---------- schema tương tác ----------
  const NHOM = {
    danhmuc: ['Danh mục', '#2a78d6'],
    nhansu: ['Nhân sự', '#eb6834'],
    daotao: ['Đào tạo', '#1baf7a'],
    hocvien: ['Học viên, học tập', '#eda100'],
    taichinh: ['Tài chính', '#e87ba4'],
    hethong: ['Hệ thống', '#6250d6'],
  };
  const NODE_W = 186, NODE_H = 50;
  const CX = [8, 228, 448, 668, 888];
  const RY = [10, 124, 238, 352, 466, 580];
  // Xếp theo nhóm và để các bảng hay nối với nhau đứng gần, giảm đường cắt nhau
  const VI_TRI = {
    BANGLUONG: [0, 0], CHUNGCHI_GV: [0, 1], GIAOVIEN: [0, 2], NHANVIEN: [0, 3], TAIKHOAN: [0, 5],
    CHUONGTRINH: [1, 0], KHOAHOC: [1, 1], CAHOC: [1, 2], CHINHANH: [1, 3], PHONGHOC: [1, 4], NGAYLE: [1, 5],
    BUOIHOC: [2, 1], LOPHOC: [2, 2], LICHHOC: [2, 3], KIEMTRA_DAUVAO: [2, 5],
    DIEMDANH: [3, 1], DANGKY: [3, 2], HOCVIEN: [3, 4],
    CANHBAO_CHUYENCAN: [4, 1], CT_PHIEUTHU: [4, 2], PHIEUTHU: [4, 4], NHATKY: [4, 5],
  };
  const TINH_HUONG = [
    { id: 'rb12', ten: 'Phòng cùng chi nhánh với lớp', fk: ['FK_LICHHOC_LOPHOC', 'FK_LICHHOC_PHONGHOC'], y: 'Hai khoá ngoại phức hợp cùng chứa MaCN nên phòng của lịch học bắt buộc thuộc chi nhánh của lớp. CSDL tự kiểm tra, không cần trigger. Đổi lại LICHHOC vi phạm 2NF vì MaLop → MaCN.' },
    { id: 'rb13', ten: 'Điểm danh đúng lớp', fk: ['FK_DIEMDANH_DANGKY', 'FK_DIEMDANH_BUOIHOC'], y: 'DIEMDANH giữ MaLop để so khớp (MaDK, MaLop) với DANGKY và (MaLop, STT) với BUOIHOC. Học viên chỉ điểm danh được ở buổi học của lớp mình, đổi lại vi phạm 2NF vì MaDK → MaLop.' },
    { id: 'nm', ten: 'Ghi danh (N – M)', fk: ['FK_DANGKY_HOCVIEN', 'FK_DANGKY_LOPHOC'], y: 'DANGKY là bảng liên kết HOCVIEN và LOPHOC, mang thêm học phí, giảm giá, điểm, kết quả. UNIQUE (MaHV, MaLop) bảo đảm mỗi học viên đăng ký một lớp tối đa một lần.' },
    { id: 'md', ten: 'Phiếu thu (master – detail)', fk: ['FK_CT_PHIEUTHU_PHIEUTHU', 'FK_CT_PHIEUTHU_DANGKY', 'FK_PHIEUTHU_HOCVIEN'], y: 'Một phiếu thu gồm nhiều dòng, mỗi dòng thu cho một đăng ký. TongTien do trigger tính; trigger cũng chặn thu cho đăng ký của học viên khác và thu vượt thành tiền.' },
    { id: 'kt', ten: 'Chuyên biệt hoá, đa trị', fk: ['FK_GIAOVIEN_NHANVIEN', 'FK_CHUNGCHI_GV_GIAOVIEN'], y: 'GIAOVIEN có khoá chính đồng thời là khoá ngoại tới NHANVIEN (chiến lược joined). Chứng chỉ là thuộc tính đa trị nên tách thành bảng riêng.' },
    { id: 'dq', ten: 'Đệ quy', fk: ['FK_NHANVIEN_QuanLy', 'FK_KHOAHOC_TienQuyet'], y: 'NHANVIEN trỏ tới người quản lý trực tiếp, KHOAHOC trỏ tới khoá tiên quyết. Truy vấn bằng CTE đệ quy (Q26, Q27).' },
    { id: '11', ten: 'Quan hệ 1 – 1', fk: ['FK_CHINHANH_QuanLy', 'FK_TAIKHOAN_NHANVIEN', 'FK_TAIKHOAN_HOCVIEN'], y: 'Khoá ngoại cộng chỉ mục duy nhất có lọc (WHERE … IS NOT NULL) tạo quan hệ 1 – 1 tuỳ chọn. CHECK bảo đảm tài khoản gắn đúng một trong NHANVIEN hoặc HOCVIEN.' },
  ];

  const sc = { bang: null, canh: null, nodes: {}, edges: [] };

  function diem(ten) {
    const [c, r] = VI_TRI[ten];
    return { x: CX[c], y: RY[r], cx: CX[c] + NODE_W / 2, cy: RY[r] + NODE_H / 2 };
  }

  function duongCanh(fk) {
    const a = diem(fk.tu), b = diem(fk.den);
    if (fk.tu === fk.den) {               // tự trỏ: cung nhỏ ở góc trên bên phải
      const xr = a.x + NODE_W, yt = a.y;
      return { d: `M${xr - 34},${yt} C${xr - 30},${yt - 28} ${xr + 22},${yt - 22} ${xr},${yt + 18}`, lx: xr - 6, ly: yt - 16 };
    }
    const dx = b.cx - a.cx, dy = b.cy - a.cy;
    if (dx === 0 && Math.abs(dy) > RY[1] - RY[0]) {  // cùng cột, không liền nhau: vòng qua cạnh phải để không xuyên bảng ở giữa
      const xr = a.x + NODE_W, k = 26 + Math.abs(dy) * 0.06;
      return { d: `M${xr},${a.cy} C${xr + k},${a.cy} ${xr + k},${b.cy} ${xr},${b.cy}`, lx: xr + k, ly: (a.cy + b.cy) / 2 };
    }
    let p1, p2, c1, c2;
    if (Math.abs(dx) * 0.55 >= Math.abs(dy)) {      // chủ yếu theo chiều ngang: nối hai cạnh bên
      const dir = Math.sign(dx);
      p1 = [a.cx + dir * NODE_W / 2, a.cy];
      p2 = [b.cx - dir * NODE_W / 2, b.cy];
      const k = Math.max(36, Math.abs(p2[0] - p1[0]) * 0.45);
      c1 = [p1[0] + dir * k, p1[1]];
      c2 = [p2[0] - dir * k, p2[1]];
    } else {                                         // chủ yếu theo chiều dọc: nối cạnh trên, dưới
      const dir = Math.sign(dy);
      p1 = [a.cx, a.cy + dir * NODE_H / 2];
      p2 = [b.cx, b.cy - dir * NODE_H / 2];
      const k = Math.max(28, Math.abs(p2[1] - p1[1]) * 0.45);
      c1 = [p1[0], p1[1] + dir * k];
      c2 = [p2[0], p2[1] - dir * k];
    }
    // Hai chiều giữa cùng một cặp bảng (CHINHANH ↔ NHANVIEN): tách hai đường để không đè nhau
    const nguoc = D.schema.fk.some((f) => f.tu === fk.den && f.den === fk.tu);
    if (nguoc) {
      const off = fk.tu < fk.den ? -9 : 9;
      p1 = [p1[0], p1[1] + off]; p2 = [p2[0], p2[1] + off];
      c1 = [c1[0], c1[1] + off]; c2 = [c2[0], c2[1] + off];
    }
    const t = 0.5;
    const lx = (1 - t) ** 3 * p1[0] + 3 * (1 - t) ** 2 * t * c1[0] + 3 * (1 - t) * t ** 2 * c2[0] + t ** 3 * p2[0];
    const ly = (1 - t) ** 3 * p1[1] + 3 * (1 - t) ** 2 * t * c1[1] + 3 * (1 - t) * t ** 2 * c2[1] + t ** 3 * p2[1];
    return { d: `M${p1} C${c1} ${c2} ${p2}`, lx, ly };
  }

  function renderSchema() {
    const svg = $('#schemaSvg');
    const defs = s('defs', {}, [['a0', '#c3c7d6'], ['a1', '#4f46e5'], ['a2', '#ea580c']].map(([id, mau]) =>
      s('marker', { id, viewBox: '0 0 10 10', refX: 9, refY: 5, markerWidth: 7, markerHeight: 7, orient: 'auto-start-reverse', markerUnits: 'userSpaceOnUse' },
        s('path', { d: 'M0,0 L10,5 L0,10 z', fill: mau }))));
    const gEdge = s('g'), gLabel = s('g'), gNode = s('g');
    svg.append(defs, gEdge, gNode, gLabel);

    for (const fk of D.schema.fk) {
      const hinh = duongCanh(fk);
      const el = s('path', { class: 'edge', d: hinh.d, 'marker-end': 'url(#a0)' });
      gEdge.append(el);
      sc.edges.push({ fk, el, lx: hinh.lx, ly: hinh.ly });
    }
    sc.gLabel = gLabel;

    for (const [ten, t] of Object.entries(D.schema.bang)) {
      const p = diem(ten);
      const g = s('g', {
        class: 'node', transform: `translate(${p.x},${p.y})`, tabindex: 0, role: 'button', 'aria-label': `Bảng ${ten}`,
        onclick: () => chonBang(ten),
        onkeydown: (e) => { if (e.key === 'Enter' || e.key === ' ') { e.preventDefault(); chonBang(ten); } },
      },
        s('rect', { class: 'box', width: NODE_W, height: NODE_H, rx: 8 }),
        s('path', { d: `M8,0 H4 A4,4 0 0 0 0,4 V${NODE_H - 4} A4,4 0 0 0 4,${NODE_H} H8 Z`, fill: NHOM[t.nhom][1] }),
      );
      const nm = s('text', { class: 'nm', x: 16, y: 21 }); nm.textContent = ten;
      const sb = s('text', { class: 'sb', x: 16, y: 39 }); sb.textContent = `${t.cot.length} cột · ${t.dong ? `${fmtSo(t.dong)} dòng` : 'sinh khi chạy'}`;
      g.append(nm, sb);
      gNode.append(g);
      sc.nodes[ten] = g;
    }

    $('#scenes').replaceChildren(...TINH_HUONG.map((c) =>
      h('button', { type: 'button', 'aria-pressed': 'false', 'data-id': c.id, onclick: () => chonCanh(c) }, c.ten)));
    $('#schemaLegend').replaceChildren(
      ...Object.values(NHOM).map(([ten, mau]) => h('span', {}, h('i', { style: { background: mau } }), ten)),
      h('span', {}, h('i', { style: { background: '#4f46e5' } }), 'trỏ đi'),
      h('span', {}, h('i', { style: { background: '#ea580c' } }), 'được trỏ tới'),
    );
    panelMacDinh();
  }

  function veTrangThai(chon, ra, vao) {
    // chon: tập bảng sáng; ra, vao: tập FK tô màu. Không chọn gì thì trả về sơ đồ gốc
    const coChon = chon.size > 0;
    for (const [ten, g] of Object.entries(sc.nodes)) {
      g.classList.toggle('sel', ten === sc.bang);
      g.classList.toggle('dim', coChon && !chon.has(ten));
    }
    sc.gLabel.replaceChildren();
    for (const e of sc.edges) {
      const laRa = ra.has(e.fk.ten), laVao = vao.has(e.fk.ten);
      e.el.setAttribute('class', `edge${laRa ? ' out' : ''}${laVao ? ' in' : ''}${coChon && !laRa && !laVao ? ' dim' : ''}`);
      e.el.setAttribute('marker-end', `url(#${laRa ? 'a1' : laVao ? 'a2' : 'a0'})`);
      if (laRa || laVao) {
        const nhan = s('text', { class: `edge-label ${laRa ? 'out' : 'in'}`, x: e.lx, y: e.ly - 8, 'text-anchor': 'middle' });
        nhan.textContent = e.fk.cot.join(', ');
        sc.gLabel.append(nhan);
      }
    }
    // đưa đường đang chọn lên trên cùng để không bị đường mờ che
    for (const e of sc.edges) if (ra.has(e.fk.ten) || vao.has(e.fk.ten)) e.el.parentNode.append(e.el);
  }

  function datHash(duoi) {
    if (dangO('schema')) history.replaceState(null, '', duoi ? `#/schema/${duoi}` : '#/schema');
  }

  function boChon() {
    sc.bang = null; sc.canh = null;
    for (const b of $$('#scenes button')) b.setAttribute('aria-pressed', 'false');
    veTrangThai(new Set(), new Set(), new Set());
    panelMacDinh();
    datHash('');
  }

  function chonBang(ten) {
    if (sc.bang === ten) { boChon(); return; }
    sc.bang = ten; sc.canh = null;
    for (const b of $$('#scenes button')) b.setAttribute('aria-pressed', 'false');
    const ra = D.schema.fk.filter((f) => f.tu === ten);
    const vao = D.schema.fk.filter((f) => f.den === ten && f.tu !== ten);
    const chon = new Set([ten, ...ra.map((f) => f.den), ...vao.map((f) => f.tu)]);
    veTrangThai(chon, new Set(ra.map((f) => f.ten)), new Set(vao.map((f) => f.ten)));
    panelBang(ten, ra, vao);
    datHash(ten);
  }

  function chonCanh(c) {
    if (sc.canh === c.id) { boChon(); return; }
    sc.bang = null; sc.canh = c.id;
    for (const b of $$('#scenes button')) b.setAttribute('aria-pressed', String(b.dataset.id === c.id));
    const ds = c.fk.map((ten) => D.schema.fk.find((f) => f.ten === ten));
    const chon = new Set(ds.flatMap((f) => [f.tu, f.den]));
    veTrangThai(chon, new Set(c.fk), new Set());
    $('#schemaPanel').replaceChildren(h('div', {},
      h('h3', { style: { fontFamily: 'inherit' } }, c.ten),
      h('p', {}, c.y),
      h('h4', {}, 'Khoá ngoại liên quan'),
      ds.map((f) => h('button', { class: 'fk-row', type: 'button', onclick: () => chonBang(f.tu) },
        h('b', {}, `${f.tu} → ${f.den}`), h('small', {}, `(${f.cot.join(', ')}) → (${f.cotDen.join(', ')})`))),
    ));
    datHash('');
  }

  function panelMacDinh() {
    const bcnf = Object.values(D.schema.bang).filter((t) => t.nf === 'BCNF').length;
    $('#schemaPanel').replaceChildren(
      h('h3', { style: { fontFamily: 'inherit' } }, 'Cách xem'),
      h('p', {}, 'Bấm một bảng để xem cột, khoá và các bảng liên quan. Bấm lại hoặc nhấn Esc để bỏ chọn.'),
      h('p', {}, 'Các nút phía trên làm nổi các bảng và khoá ngoại của từng quan hệ, kèm lời giải thích.'),
      h('h4', {}, 'Tổng quan'),
      h('ul', { class: 'cols-list' },
        [['Bảng', 22], ['Khoá ngoại', D.schema.fk.length], ['Khoá ngoại phức hợp', D.schema.fk.filter((f) => f.cot.length > 1).length],
          ['Xoá lan truyền', D.schema.fk.filter((f) => f.xoa === 'CASCADE').length], ['Đạt BCNF', `${bcnf}/22`]]
          .map(([k, v]) => h('li', {}, h('span', {}, k), h('span', { class: 'ct' }, v)))),
      h('h4', {}, 'Bảng được tham chiếu nhiều nhất'),
      h('ul', { class: 'cols-list' }, Object.keys(D.schema.bang)
        .map((t) => [t, D.schema.fk.filter((f) => f.den === t).length])
        .sort((a, b) => b[1] - a[1]).slice(0, 5)
        .map(([t, n]) => h('li', {}, h('button', { class: 'fk-row', type: 'button', style: { border: 0, padding: 0 }, onclick: () => chonBang(t) }, h('b', {}, t)), h('span', { class: 'ct' }, `${n} khoá ngoại`)))),
    );
  }

  function panelBang(ten, ra, vao) {
    const t = D.schema.bang[ten];
    const laFk = new Set(ra.flatMap((f) => f.cot));
    const nfCls = t.nf === 'BCNF' ? 'bcnf' : t.nf === '2NF' ? 'nf2' : 'nf1';
    const nfTen = t.nf === 'BCNF' ? 'Đạt BCNF' : t.nf === '2NF' ? 'Chỉ đạt 2NF' : 'Vi phạm 2NF, có chủ đích';
    const dongFk = (f, dich) => h('button', { class: 'fk-row', type: 'button', onclick: () => chonBang(dich) },
      h('b', {}, dich), h('small', {}, `(${f.cot.join(', ')}) → (${f.cotDen.join(', ')})${f.xoa === 'CASCADE' ? ' · xoá lan truyền' : ''}`));
    $('#schemaPanel').replaceChildren(h('div', {},
      h('h3', {}, ten),
      h('p', {}, t.y),
      h('div', { class: 'panel-tags' },
        h('span', { class: 'tag' }, NHOM[t.nhom][0]),
        h('span', { class: `tag ${nfCls}` }, nfTen),
        h('span', { class: 'tag' }, t.dong ? `${fmtSo(t.dong)} dòng mẫu` : 'Sinh khi chạy')),
      ra.length ? [h('h4', {}, `Trỏ tới (${ra.length})`), ra.map((f) => dongFk(f, f.den))] : null,
      vao.length ? [h('h4', {}, `Được trỏ tới bởi (${vao.length})`), vao.map((f) => dongFk(f, f.tu))] : null,
      h('h4', {}, `Cột (${t.cot.length})`),
      h('ul', { class: 'cols-list' }, t.cot.map((c) => h('li', {},
        t.pk.includes(c.ten) ? h('span', { class: 'k pk' }, 'PK') : null,
        laFk.has(c.ten) ? h('span', { class: 'k fk' }, 'FK') : null,
        c.tinh || c.duyTri ? h('span', { class: 'k dv', 'data-tip': c.duyTri ? `Suy diễn, duy trì bằng ${c.duyTri}` : `Cột tính toán ${c.tinh}` }, 'SD') : null,
        h('span', { class: 'cn' }, c.ten),
        h('span', { class: 'ct' }, c.tinh ? c.tinh : `${c.kieu}${c.null ? ' ?' : ''}`)))),
    ));
    $('#schemaPanel').scrollTop = 0;
  }

  // ---------- điều khiển slide ----------
  const slides = $$('.slide');
  let cur = 0;
  const dangO = (id) => slides[cur].dataset.id === id;

  function fit() {
    const vp = $('#viewport');
    const k = Math.min(vp.clientWidth / 1600, vp.clientHeight / 900);
    const st = $('#stage');
    st.style.transform = `translate(${(vp.clientWidth - 1600 * k) / 2}px, ${(vp.clientHeight - 900 * k) / 2}px) scale(${k})`;
  }

  function hienThi(i) {
    cur = Math.max(0, Math.min(slides.length - 1, i));
    slides.forEach((el, n) => el.classList.toggle('on', n === cur));
    $('#count').textContent = `${cur + 1} / ${slides.length}`;
    $('#progress').style.width = `${((cur + 1) / slides.length) * 100}%`;
    const sec = slides[cur].dataset.sec;
    for (const b of $$('#secs button')) b.classList.toggle('on', b.textContent === sec);
    document.title = `${cur + 1}. ${slides[cur].dataset.title} · ECMS`;
    $('#notesDrawer').textContent = $('.notes', slides[cur])?.textContent.trim() || '';
    an($('#tip'));
  }

  function an(el) { el.hidden = true; }

  function di(i) {
    hienThi(i);
    const id = slides[cur].dataset.id;
    const dich = `#/${id}`;
    if (location.hash !== dich) history.pushState(null, '', dich);
    if (id !== 'schema' && (sc.bang || sc.canh)) { sc.bang = null; sc.canh = null; veTrangThai(new Set(), new Set(), new Set()); panelMacDinh(); for (const b of $$('#scenes button')) b.setAttribute('aria-pressed', 'false'); }
  }

  function theoHash() {
    const m = location.hash.match(/^#\/([\w-]+)(?:\/(\w+))?/);
    const i = m ? slides.findIndex((el) => el.dataset.id === m[1]) : 0;
    hienThi(i >= 0 ? i : 0);
    if (m && m[1] === 'schema' && m[2] && D.schema.bang[m[2]] && sc.bang !== m[2]) { sc.bang = null; chonBang(m[2]); }
  }

  function initBar() {
    const secs = [...new Set(slides.map((el) => el.dataset.sec))];
    $('#secs').replaceChildren(...secs.map((t) => h('button', {
      type: 'button', onclick: () => di(slides.findIndex((el) => el.dataset.sec === t)),
    }, t)));
    $('#prevBtn').addEventListener('click', () => di(cur - 1));
    $('#nextBtn').addEventListener('click', () => di(cur + 1));
    $('#schemaBtn').addEventListener('click', () => di(slides.findIndex((el) => el.dataset.id === 'schema')));
    $('#tocBtn').addEventListener('click', moToc);
    $('#notesBtn').addEventListener('click', doiGhiChu);
    $('#fullBtn').addEventListener('click', toanManHinh);
  }

  function doiGhiChu() {
    const d = $('#notesDrawer');
    d.hidden = !d.hidden;
    $('#notesBtn').setAttribute('aria-pressed', String(!d.hidden));
  }
  function toanManHinh() {
    if (document.fullscreenElement) document.exitFullscreen();
    else document.documentElement.requestFullscreen?.();
  }

  function moToc() {
    const secs = [...new Set(slides.map((el) => el.dataset.sec))];
    $('#tocList').replaceChildren(...secs.map((t) => h('div', { class: 'toc-sec' },
      h('h3', {}, t),
      slides.map((el, i) => (el.dataset.sec === t ? h('button', {
        type: 'button', class: i === cur ? 'on' : null,
        onclick: () => { an($('#toc')); di(i); },
      }, h('i', {}, i + 1), el.dataset.title) : null)))));
    $('#toc').hidden = false;
    $('#tocClose').focus();
  }

  // ---------- phóng to ảnh ----------
  const lb = { k: 1, x: 0, y: 0, keo: null };
  function veAnh() { $('#lbImg').style.transform = `translate(${lb.x}px, ${lb.y}px) scale(${lb.k})`; }
  function vuaKhung() {
    const img = $('#lbImg'), c = $('#lbCanvas');
    const w = img.naturalWidth || 1600, h2 = img.naturalHeight || 900;
    lb.k = Math.min(c.clientWidth / w, c.clientHeight / h2) * 0.98;
    lb.x = (c.clientWidth - w * lb.k) / 2;
    lb.y = (c.clientHeight - h2 * lb.k) / 2;
    veAnh();
  }
  function zoom(he, px, py) {
    const k = Math.max(0.1, Math.min(8, lb.k * he));
    lb.x = px - (px - lb.x) * (k / lb.k);
    lb.y = py - (py - lb.y) * (k / lb.k);
    lb.k = k;
    veAnh();
  }
  function moAnh(src, cap) {
    const img = $('#lbImg');
    $('#lbCap').textContent = cap || '';
    img.alt = cap || '';
    $('#lightbox').hidden = false;
    img.onload = vuaKhung;
    img.src = src;
    if (img.complete) vuaKhung();
    $('#lbClose').focus();
  }
  function initLightbox() {
    document.addEventListener('click', (e) => {
      const b = e.target.closest('[data-zoom]');
      if (b) moAnh(b.dataset.zoom, b.dataset.cap);
    });
    const c = $('#lbCanvas');
    const giua = () => [c.clientWidth / 2, c.clientHeight / 2];
    c.addEventListener('wheel', (e) => {
      e.preventDefault();
      const r = c.getBoundingClientRect();
      zoom(e.deltaY < 0 ? 1.18 : 1 / 1.18, e.clientX - r.left, e.clientY - r.top);
    }, { passive: false });
    c.addEventListener('pointerdown', (e) => {
      lb.keo = { x: e.clientX - lb.x, y: e.clientY - lb.y };
      c.setPointerCapture(e.pointerId);
      c.classList.add('drag');
    });
    c.addEventListener('pointermove', (e) => {
      if (!lb.keo) return;
      lb.x = e.clientX - lb.keo.x; lb.y = e.clientY - lb.keo.y;
      veAnh();
    });
    const tha = () => { lb.keo = null; c.classList.remove('drag'); };
    c.addEventListener('pointerup', tha);
    c.addEventListener('pointercancel', tha);
    $('#lbIn').addEventListener('click', () => zoom(1.3, ...giua()));
    $('#lbOut').addEventListener('click', () => zoom(1 / 1.3, ...giua()));
    $('#lbFit').addEventListener('click', vuaKhung);
    $('#lbClose').addEventListener('click', () => an($('#lightbox')));
    window.addEventListener('resize', () => { if (!$('#lightbox').hidden) vuaKhung(); });
  }

  // ---------- chú thích khi rê chuột, cũng hiện khi dùng bàn phím ----------
  function initTip() {
    const tip = $('#tip');
    const hien = (el, x, y) => {
      tip.textContent = el.dataset.tip;
      tip.hidden = false;
      const w = tip.offsetWidth, ht = tip.offsetHeight;
      tip.style.left = `${Math.min(x + 14, innerWidth - w - 8)}px`;
      tip.style.top = `${Math.max(8, y - ht - 12)}px`;
    };
    document.addEventListener('pointermove', (e) => {
      const el = e.target.closest?.('[data-tip]');
      if (el) hien(el, e.clientX, e.clientY); else tip.hidden = true;
    });
    document.addEventListener('focusin', (e) => {
      const el = e.target.closest?.('[data-tip]');
      if (el) { const r = el.getBoundingClientRect(); hien(el, r.left, r.top); }
    });
    document.addEventListener('focusout', () => { tip.hidden = true; });
  }

  // ---------- bàn phím, vuốt ----------
  function initKeys() {
    document.addEventListener('keydown', (e) => {
      if (e.ctrlKey || e.metaKey || e.altKey) return;
      if (!$('#modal').hidden) { if (e.key === 'Escape') dongModal(); return; }
      if (!$('#lightbox').hidden) { if (e.key === 'Escape') an($('#lightbox')); return; }
      if (!$('#toc').hidden) { if (e.key === 'Escape' || e.key.toLowerCase() === 'o') an($('#toc')); return; }
      const k = e.key.toLowerCase();
      if (k === 'arrowright' || k === 'pagedown' || (k === ' ' && !e.target.closest('button, a, .node'))) { e.preventDefault(); di(cur + 1); }
      else if (k === 'arrowleft' || k === 'pageup') { e.preventDefault(); di(cur - 1); }
      else if (k === 'home') di(0);
      else if (k === 'end') di(slides.length - 1);
      else if (k === 'o') moToc();
      else if (k === 's') di(slides.findIndex((el) => el.dataset.id === 'schema'));
      else if (k === 'n') doiGhiChu();
      else if (k === 'f') toanManHinh();
      else if (k === 'escape' && dangO('schema') && (sc.bang || sc.canh)) boChon();
    });
    let dau = null;
    const vp = $('#viewport');
    vp.addEventListener('touchstart', (e) => { dau = e.touches[0].clientX; }, { passive: true });
    vp.addEventListener('touchend', (e) => {
      if (dau == null) return;
      const d = e.changedTouches[0].clientX - dau;
      dau = null;
      if (Math.abs(d) > 70) di(cur + (d < 0 ? 1 : -1));
    });
  }

  bindData();
  renderMembers();
  renderCoverage();
  renderSprints();
  renderCursor();
  renderCodemap();
  renderSchema();
  initBar();
  initLightbox();
  initModal();
  initTip();
  initKeys();
  fit();
  window.addEventListener('resize', fit);
  window.addEventListener('hashchange', theoHash);
  window.addEventListener('popstate', theoHash);
  theoHash();
})();
