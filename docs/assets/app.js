(() => {
  'use strict';

  const $ = (sel, el = document) => el.querySelector(sel);
  const DAY = 86400000;
  const now = new Date();
  const state = {
    team: null,
    plan: null,
    issues: {},
    synced: false,
    filters: { owner: '', sprint: '', chapter: '', status: '', q: '' },
  };

  // ---------- helpers ----------
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
  const fmtDate = (iso) => iso.split('-').reverse().join('/');
  const endOfDay = (iso) => new Date(iso + 'T23:59:59+07:00');
  const startOfDay = (iso) => new Date(iso + 'T00:00:00+07:00');
  const member = (id) => state.team.members.find((m) => m.id === id);
  const chapter = (id) => state.plan.chapters.find((c) => c.id === id);
  const sprint = (id) => state.plan.sprints.find((s) => s.id === id);
  const initials = (name) => name.split(/\s+/).slice(-2).map((w) => w[0]).join('').toUpperCase();
  const issueUrl = (n) => `https://github.com/${state.plan.project.repo}/issues/${n}`;
  const storage = {
    get(store, key) { try { return window[store].getItem(key); } catch { return null; } },
    set(store, key, val) { try { window[store].setItem(key, val); } catch { /* bỏ qua */ } },
  };

  async function fetchJSON(url) {
    const res = await fetch(url, { cache: 'no-cache' });
    if (!res.ok) throw new Error(`${url}: ${res.status}`);
    return res.json();
  }

  async function loadIssues(repo) {
    const key = 'ecms-issues-v1';
    const cached = storage.get('sessionStorage', key);
    if (cached) {
      try {
        const c = JSON.parse(cached);
        if (Date.now() - c.t < 5 * 60 * 1000) return c;
      } catch { /* cache hỏng → tải lại */ }
    }
    const map = {};
    for (let page = 1; page <= 3; page++) {
      const res = await fetch(`https://api.github.com/repos/${repo}/issues?state=all&per_page=100&page=${page}`, {
        headers: { Accept: 'application/vnd.github+json' },
      });
      if (!res.ok) throw new Error(`GitHub API ${res.status}`);
      const arr = await res.json();
      for (const i of arr) {
        if (i.pull_request) continue;
        map[i.number] = {
          state: i.state,
          labels: i.labels.map((l) => l.name),
          assignees: i.assignees.map((a) => a.login),
        };
      }
      if (arr.length < 100) break;
    }
    const data = { t: Date.now(), map };
    storage.set('sessionStorage', key, JSON.stringify(data));
    return data;
  }

  function statusOf(task) {
    if (!task.issue) return { key: 'none', text: 'Chưa có issue' };
    const iss = state.issues[task.issue];
    if (!iss) return { key: 'open', text: state.synced ? 'Chưa xong' : 'Chưa đồng bộ' };
    if (iss.state === 'closed') return { key: 'done', text: 'Hoàn thành' };
    if (endOfDay(task.due) < now) return { key: 'late', text: 'Quá hạn' };
    if (iss.labels.includes('dang-lam')) return { key: 'doing', text: 'Đang làm' };
    return { key: 'open', text: 'Chưa xong' };
  }
  const isDone = (t) => statusOf(t).key === 'done';

  // ---------- theme ----------
  function effectiveTheme() {
    const forced = document.documentElement.dataset.theme;
    if (forced) return forced;
    return window.matchMedia('(prefers-color-scheme: dark)').matches ? 'dark' : 'light';
  }
  function initTheme() {
    const saved = storage.get('localStorage', 'ecms-theme');
    if (saved === 'dark' || saved === 'light') document.documentElement.dataset.theme = saved;
    $('#themeBtn').addEventListener('click', () => {
      const next = effectiveTheme() === 'dark' ? 'light' : 'dark';
      document.documentElement.dataset.theme = next;
      storage.set('localStorage', 'ecms-theme', next);
      renderMermaid();
    });
  }

  // ---------- mermaid ----------
  let mermaidSource = null;
  async function renderMermaid() {
    const el = $('.mermaid');
    if (!el || !window.mermaid) return;
    if (mermaidSource == null) mermaidSource = el.textContent;
    el.removeAttribute('data-processed');
    el.textContent = mermaidSource;
    window.mermaid.initialize({
      startOnLoad: false,
      theme: effectiveTheme() === 'dark' ? 'dark' : 'default',
      er: { useMaxWidth: true, layoutDirection: 'TB' },
      fontFamily: 'Be Vietnam Pro, system-ui, sans-serif',
    });
    try { await window.mermaid.run({ nodes: [el] }); } catch (e) { console.warn('Mermaid:', e); }
  }

  // ---------- hero & stats ----------
  function renderHero() {
    const { project, tasks, sprints } = state.plan;
    $('#deadlineChip').textContent = fmtDate(project.deadline);
    const btn = $('#btnProject');
    if (project.projectUrl) btn.href = project.projectUrl;
    else btn.setAttribute('aria-disabled', 'true');

    const done = tasks.filter(isDone).length;
    const pct = Math.round((done / tasks.length) * 100);
    $('#statProgress').textContent = state.synced ? `${pct}%` : '–';
    $('#barProgress').style.width = state.synced ? `${pct}%` : '0';
    $('#statDone').textContent = state.synced ? `${done}/${tasks.length}` : `–/${tasks.length}`;

    const cur = sprints.find((s) => startOfDay(s.start) <= now && now <= endOfDay(s.end));
    if (cur) {
      $('#statSprint').textContent = cur.id;
      $('#statSprintSub').textContent = `${cur.name.split('·')[1].trim()} · đến ${fmtDate(cur.end)}`;
    } else if (now < startOfDay(sprints[0].start)) {
      $('#statSprint').textContent = '–';
      $('#statSprintSub').textContent = `Bắt đầu ${fmtDate(sprints[0].start)}`;
    } else {
      $('#statSprint').textContent = '✓';
      $('#statSprintSub').textContent = 'Đã qua sprint cuối';
    }

    const days = Math.ceil((endOfDay(project.deadline) - now) / DAY);
    $('#statDays').textContent = days >= 0 ? `${days} ngày` : 'Đã qua hạn';
    $('#statDaysSub').textContent = project.deadlineNote;
  }

  // ---------- members ----------
  function renderMembers() {
    const wrap = $('#members');
    wrap.replaceChildren();
    for (const m of state.team.members) {
      const mine = state.plan.tasks.filter((t) => t.owner === m.id);
      const done = mine.filter(isDone).length;
      const pct = mine.length ? Math.round((done / mine.length) * 100) : 0;
      wrap.append(
        h('button', {
          class: 'card member', type: 'button',
          title: `Xem task của ${m.short}`,
          onclick: () => { setOwner(m.id); $('#cong-viec').scrollIntoView(); },
        },
          h('div', { class: 'avatar', style: { background: m.color } }, initials(m.name)),
          h('div', { class: 'name' }, m.name),
          h('div', { class: 'mssv' }, `MSSV ${m.mssv}`, m.github ? ` · @${m.github}` : ''),
          h('span', { class: 'role' }, m.role),
          h('div', { class: 'focus' }, m.focus),
          h('div', { class: 'mini' }, h('span', {}, `${mine.length} task`), h('span', {}, state.synced ? `${done} xong · ${pct}%` : '')),
          h('div', { class: 'bar' }, h('span', { style: { width: state.synced ? `${pct}%` : '0', background: m.color } })),
        ),
      );
    }
  }

  // ---------- sprints ----------
  function renderSprints() {
    const wrap = $('#sprints');
    wrap.replaceChildren();
    for (const s of state.plan.sprints) {
      const list = state.plan.tasks.filter((t) => t.sprint === s.id);
      const current = startOfDay(s.start) <= now && now <= endOfDay(s.end);
      wrap.append(
        h('div', { class: `card sprint${current ? ' current' : ''}` },
          h('div', { class: 'dates' }, `${fmtDate(s.start)} → ${fmtDate(s.end)}`),
          h('h3', {}, s.name),
          h('p', {}, s.goal),
          h('div', { class: 'tlist' }, list.map((t) =>
            h('span', {
              class: `tchip${isDone(t) ? ' done' : ''}`,
              title: `${t.title} – ${member(t.owner).short}`,
              onclick: () => openTask(t.id),
            }, t.id),
          )),
        ),
      );
    }
  }

  // ---------- dropdown ----------
  // Danh sách của <select> do trình duyệt vẽ (macOS: menu hệ thống) nên không theo màu của trang. Giữ <select> gốc
  // để lưu giá trị và phát sự kiện change như cũ; nút + listbox bên cạnh chỉ thay phần hiển thị (style.css: .dd-*).
  const dropdowns = [];

  function dropdown(sel) {
    const name = sel.getAttribute('aria-label') || '';
    const label = h('span', {});
    const btn = h('button', { type: 'button', class: 'dd-btn', 'aria-haspopup': 'listbox', 'aria-expanded': 'false', 'aria-label': name }, label);
    const menu = h('ul', { class: 'dd-menu', id: `${sel.id}-list`, role: 'listbox', tabindex: '-1', 'aria-label': name, hidden: true });
    const wrap = h('div', { class: 'dd' }, btn, menu);
    btn.setAttribute('aria-controls', menu.id);
    sel.classList.add('dd-native');
    sel.after(wrap);
    let active = -1;

    function sync() {
      const cur = sel.options[sel.selectedIndex];
      label.textContent = cur ? cur.textContent : '';
      btn.title = label.textContent;
      btn.classList.toggle('on', Boolean(sel.value));
      menu.replaceChildren(...[...sel.options].map((o, i) =>
        h('li', { role: 'option', id: `${menu.id}-${i}`, 'aria-selected': String(i === sel.selectedIndex),
                  onclick: () => pick(i), onpointermove: () => setActive(i) }, o.textContent)));
    }
    function setActive(i) {
      if (i < 0 || i >= menu.children.length) return;
      if (menu.children[active]) menu.children[active].classList.remove('active');
      active = i;
      const li = menu.children[i];
      li.classList.add('active');
      menu.setAttribute('aria-activedescendant', li.id);
      li.scrollIntoView({ block: 'nearest' });
    }
    function open() {
      for (const d of dropdowns) if (d.wrap !== wrap) d.close(false);
      sync();
      menu.hidden = false;
      menu.classList.toggle('right', wrap.getBoundingClientRect().left + menu.offsetWidth > document.documentElement.clientWidth - 8);
      btn.setAttribute('aria-expanded', 'true');
      setActive(sel.selectedIndex);
      menu.focus();
    }
    function close(focusBtn = true) {
      if (menu.hidden) return;
      menu.hidden = true;
      btn.setAttribute('aria-expanded', 'false');
      if (focusBtn) btn.focus();
    }
    function pick(i) {
      if (i !== sel.selectedIndex) {
        sel.selectedIndex = i;
        sel.dispatchEvent(new Event('change', { bubbles: true }));
      }
      sync();
      close();
    }

    btn.addEventListener('click', () => (menu.hidden ? open() : close()));
    btn.addEventListener('keydown', (e) => {
      if (['ArrowDown', 'ArrowUp', 'Enter', ' '].includes(e.key)) { e.preventDefault(); open(); }
    });
    menu.addEventListener('keydown', (e) => {
      const last = menu.children.length - 1;
      const moves = { ArrowDown: active + 1, ArrowUp: active - 1, Home: 0, End: last, PageDown: last, PageUp: 0 };
      if (e.key in moves) { e.preventDefault(); setActive(Math.max(0, Math.min(last, moves[e.key]))); }
      else if (e.key === 'Enter' || e.key === ' ') { e.preventDefault(); pick(active); }
      else if (e.key === 'Escape') { e.preventDefault(); close(); }
      else if (e.key === 'Tab') close(false);
      else if (e.key.length === 1) {               // gõ chữ cái đầu để nhảy tới mục
        const k = e.key.toLowerCase();
        const items = [...menu.children];
        const next = items.findIndex((li, i) => i > active && li.textContent.toLowerCase().startsWith(k));
        const i = next >= 0 ? next : items.findIndex((li) => li.textContent.toLowerCase().startsWith(k));
        if (i >= 0) setActive(i);
      }
    });
    menu.addEventListener('focusout', (e) => { if (!wrap.contains(e.relatedTarget)) close(false); });

    sync();
    dropdowns.push({ wrap, sync, close });
  }

  document.addEventListener('pointerdown', (e) => {
    for (const d of dropdowns) if (!d.wrap.contains(e.target)) d.close(false);
  });

  // ---------- filters ----------
  function setOwner(id) {
    state.filters.owner = id;
    for (const b of $('#ownerFilter').children) b.setAttribute('aria-pressed', String(b.dataset.id === id));
    renderTasks();
  }

  function renderFilters() {
    const seg = $('#ownerFilter');
    seg.replaceChildren(
      h('button', { type: 'button', 'data-id': '', 'aria-pressed': 'true', onclick: () => setOwner('') }, 'Tất cả'),
      ...state.team.members.map((m) =>
        h('button', { type: 'button', 'data-id': m.id, 'aria-pressed': 'false', onclick: () => setOwner(m.id) }, m.short),
      ),
    );
    const sp = $('#sprintFilter');
    for (const s of state.plan.sprints) sp.append(h('option', { value: s.id }, s.name));
    const ch = $('#chapterFilter');
    for (const c of state.plan.chapters) ch.append(h('option', { value: c.id }, c.name));

    sp.addEventListener('change', (e) => { state.filters.sprint = e.target.value; renderTasks(); });
    ch.addEventListener('change', (e) => { state.filters.chapter = e.target.value; renderTasks(); });
    $('#statusFilter').addEventListener('change', (e) => { state.filters.status = e.target.value; renderTasks(); });
    $('#searchBox').addEventListener('input', (e) => { state.filters.q = e.target.value.trim().toLowerCase(); renderTasks(); });
    for (const sel of document.querySelectorAll('.filters select')) dropdown(sel);
  }

  function matches(t) {
    const f = state.filters;
    if (f.owner && t.owner !== f.owner) return false;
    if (f.sprint && t.sprint !== f.sprint) return false;
    if (f.chapter && t.chapter !== f.chapter) return false;
    if (f.status) {
      const k = statusOf(t).key;
      if (f.status === 'done' && k !== 'done') return false;
      if (f.status === 'open' && k === 'done') return false;
      if (f.status === 'late' && k !== 'late') return false;
    }
    if (f.q) {
      const hay = [t.id, t.title, t.summary, t.syllabus, ...t.steps, ...t.deliverables, member(t.owner).name].join(' ').toLowerCase();
      if (!hay.includes(f.q)) return false;
    }
    return true;
  }

  // ---------- tasks ----------
  function labelChip(name, color) {
    return h('span', { class: 'lbl', style: { borderColor: `#${color}66` } },
      h('span', { class: 'dot', style: { background: `#${color}` } }), name);
  }

  function taskCard(t) {
    const m = member(t.owner);
    const st = statusOf(t);
    const ch = chapter(t.chapter);
    const typeChips = t.types.map((id) => state.plan.types.find((x) => x.id === id)).filter(Boolean);
    return h('details', { class: 'card task', id: `task-${t.id}` },
      h('summary', {},
        h('span', { class: 'tid' }, t.id),
        h('div', {},
          h('div', { class: 'ttitle' }, t.title),
          h('div', { class: 'tmeta' },
            h('span', { class: 'who' }, h('span', { class: 'dot', style: { background: m.color } }), m.name),
            h('span', {}, sprint(t.sprint).name.split('·')[0].trim()),
            h('span', {}, `Hạn ${fmtDate(t.due)}`),
            t.issue ? h('span', {}, `#${t.issue}`) : null,
          ),
        ),
        h('span', { class: `badge ${st.key}` }, st.text),
      ),
      h('div', { class: 'tbody' },
        h('div', { class: 'full' },
          h('p', { style: { margin: '0 0 10px' } }, t.summary),
          h('div', { class: 'syllabus' }, h('b', {}, 'Bám đề cương: '), t.syllabus),
        ),
        h('div', {},
          h('h4', {}, 'Công việc chi tiết'),
          h('ul', {}, t.steps.map((s) => h('li', {}, s))),
        ),
        h('div', {},
          h('h4', {}, 'Sản phẩm bàn giao'),
          h('ul', {}, t.deliverables.map((s) => h('li', {}, s))),
          h('h4', { style: { marginTop: '14px' } }, 'Tiêu chí hoàn thành'),
          h('ul', {}, t.acceptance.map((s) => h('li', {}, s))),
        ),
        h('div', { class: 'full links' },
          h('div', { class: 'labels' }, labelChip(ch.name, ch.color), typeChips.map((x) => labelChip(x.name, x.color))),
          t.depends.length ? h('span', { class: 'note' }, 'Phụ thuộc: ',
            t.depends.map((d, i) => [i ? ', ' : '', h('a', { href: `#task-${d}`, onclick: (e) => { e.preventDefault(); openTask(d); } }, d)])) : null,
          t.issue ? h('a', { class: 'btn', href: issueUrl(t.issue), target: '_blank', rel: 'noopener', style: { marginLeft: 'auto' } }, `Mở issue #${t.issue} ↗`) : null,
        ),
      ),
    );
  }

  function renderTasks() {
    const list = state.plan.tasks.filter(matches);
    const wrap = $('#tasks');
    wrap.replaceChildren(...(list.length ? list.map(taskCard) : [h('div', { class: 'card empty' }, 'Không có task nào khớp bộ lọc.')]));
    $('#taskCount').textContent = `${list.length}/${state.plan.tasks.length} task`;
  }

  function openTask(id) {
    const t = state.plan.tasks.find((x) => x.id === id);
    if (!t) return;
    if (!matches(t)) {
      state.filters = { owner: '', sprint: '', chapter: '', status: '', q: '' };
      $('#sprintFilter').value = ''; $('#chapterFilter').value = ''; $('#statusFilter').value = ''; $('#searchBox').value = '';
      for (const d of dropdowns) d.sync();          // đặt .value không phát sự kiện change
      setOwner('');
    }
    const el = document.getElementById(`task-${id}`);
    if (el) {
      el.open = true;
      el.scrollIntoView({ block: 'start' });
      history.replaceState(null, '', `#task-${id}`);
    }
  }

  // ---------- coverage ----------
  function renderCoverage() {
    const body = $('#coverage');
    body.replaceChildren();
    for (const c of state.plan.coverage) {
      c.items.forEach((it, i) => {
        const tr = h('tr', {});
        if (i === 0) {
          tr.append(h('td', { class: 'chap', rowspan: String(c.items.length) }, c.chapter, h('small', {}, `${c.session} · CĐR ${c.outcomes}`)));
        }
        tr.append(
          h('td', {}, it.topic),
          h('td', {}, it.tasks.map((id) => {
            const t = state.plan.tasks.find((x) => x.id === id);
            return h('span', {
              class: `tchip${t && isDone(t) ? ' done' : ''}`,
              style: { marginRight: '4px', display: 'inline-block' },
              title: t ? `${t.title} – ${member(t.owner).short}` : id,
              onclick: () => openTask(id),
            }, id);
          })),
          h('td', {}, it.output),
        );
        body.append(tr);
      });
    }
  }

  // ---------- nav: highlight, dropdown nhóm, nút ☰ trên màn hình hẹp ----------
  function initNav() {
    const topbar = $('.topbar');
    const menuBtn = $('#menuBtn');
    const links = [...document.querySelectorAll('.nav a')];
    const groupBtns = [...document.querySelectorAll('.nav-btn')];
    const byId = Object.fromEntries(links.map((a) => [a.getAttribute('href').slice(1), a]));

    const closeGroups = (except) => groupBtns.forEach((b) => { if (b !== except) b.setAttribute('aria-expanded', 'false'); });
    const setPanel = (open) => {
      topbar.classList.toggle('nav-open', open);
      menuBtn.setAttribute('aria-expanded', String(open));
      menuBtn.setAttribute('aria-label', open ? 'Đóng mục lục' : 'Mở mục lục');
      menuBtn.textContent = open ? '✕' : '☰';
    };

    groupBtns.forEach((btn) => {
      btn.addEventListener('click', () => {
        const open = btn.getAttribute('aria-expanded') !== 'true';
        closeGroups(btn);
        btn.setAttribute('aria-expanded', String(open));
        if (open && btn.matches(':focus-visible')) btn.nextElementSibling.querySelector('a')?.focus();
      });
      // Tab ra khỏi nhóm thì đóng dropdown
      btn.parentElement.addEventListener('focusout', (e) => {
        if (!btn.parentElement.contains(e.relatedTarget)) btn.setAttribute('aria-expanded', 'false');
      });
    });
    menuBtn.addEventListener('click', () => setPanel(!topbar.classList.contains('nav-open')));
    links.forEach((a) => a.addEventListener('click', () => { closeGroups(); setPanel(false); }));
    document.addEventListener('click', (e) => {
      if (!topbar.contains(e.target)) { closeGroups(); setPanel(false); }
    });
    document.addEventListener('keydown', (e) => {
      if (e.key !== 'Escape') return;
      const openBtn = groupBtns.find((b) => b.getAttribute('aria-expanded') === 'true');
      if (openBtn) { closeGroups(); openBtn.focus(); } else if (topbar.classList.contains('nav-open')) { setPanel(false); menuBtn.focus(); }
    });

    const io = new IntersectionObserver((entries) => {
      for (const e of entries) {
        if (e.isIntersecting) {
          links.forEach((a) => a.classList.remove('active'));
          const link = byId[e.target.id];
          link?.classList.add('active');
          // Mục đang xem nằm trong dropdown thì nút của nhóm cũng sáng
          groupBtns.forEach((b) => b.classList.toggle('active', !!link && b.parentElement.contains(link)));
        }
      }
    }, { rootMargin: '-45% 0px -50% 0px' });
    document.querySelectorAll('main section[id]').forEach((s) => io.observe(s));
  }

  function renderAll() {
    renderHero();
    renderMembers();
    renderSprints();
    renderTasks();
    renderCoverage();
  }

  async function main() {
    initTheme();
    initNav();
    renderMermaid();
    try {
      [state.team, state.plan] = await Promise.all([fetchJSON('data/team.json'), fetchJSON('data/tasks.json')]);
    } catch (e) {
      $('#syncNote').textContent = `Không tải được dữ liệu kế hoạch (${e.message}).`;
      return;
    }
    renderFilters();
    renderAll();
    if (location.hash.startsWith('#task-')) openTask(location.hash.slice(6));

    try {
      const data = await loadIssues(state.plan.project.repo);
      state.issues = data.map;
      state.synced = true;
      const t = new Date(data.t);
      $('#syncNote').textContent = `Trạng thái lấy từ GitHub Issues lúc ${t.toLocaleTimeString('vi-VN', { hour: '2-digit', minute: '2-digit' })} ${t.toLocaleDateString('vi-VN')}.`;
      renderAll();
      if (location.hash.startsWith('#task-')) openTask(location.hash.slice(6));
    } catch (e) {
      $('#syncNote').textContent = `Chưa lấy được trạng thái từ GitHub (${e.message}). Kế hoạch vẫn hiển thị đầy đủ; tải lại trang sau ít phút.`;
    }
  }

  main();
})();
