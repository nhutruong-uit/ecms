# Quy ước làm việc

## Nguồn kế hoạch duy nhất

Toàn bộ kế hoạch nằm trong [`docs/data/tasks.json`](docs/data/tasks.json); thông tin thành viên nằm trong [`docs/data/team.json`](docs/data/team.json).
Từ hai file này sinh ra:

- Trang GitHub Pages: https://nhutruong-uit.github.io/ecms/
- Issues, labels, milestones: `python3 scripts/sync_issues.py`
- GitHub Project (bảng công việc): `python3 scripts/sync_project.py`

Khi đổi kế hoạch (thêm task, đổi hạn, đổi người), sửa `tasks.json` rồi chạy lại hai script trên.

## Nhánh

| Nhánh | Vai trò |
|---|---|
| `main` | Bản phát hành. Chỉ nhận merge từ `develop`, có CI chạy toàn bộ script SQL và kiểm tra ứng dụng, gắn tag `vX.Y.Z` + GitHub Release |
| `develop` | Nhánh tích hợp. Mỗi task là một Pull Request vào đây |
| `tNN-<mo-ta>` | Nhánh của một task, tạo từ `develop`, xoá sau khi merge |

## Quy trình một task

1. Kéo thẻ trên Project sang **In Progress** (hoặc gắn label `dang-lam` vào issue).
2. Tạo nhánh theo task từ `develop`:
   ```bash
   git switch develop && git pull
   git switch -c t11-stored-procedure
   ```
3. Làm việc, commit **dưới tên người phụ trách task** (xem mục dưới).
4. Đẩy nhánh, mở Pull Request **vào `develop`**: tiêu đề `[T11] ...`, mô tả có dòng `Closes #<số issue>`; assignee là người phụ trách, reviewer là nhóm trưởng (@nhutruong-uit).
5. Review xong thì **Merge commit** (không squash, để giữ đúng tác giả từng commit) và xoá nhánh.
6. Vì `develop` không phải nhánh mặc định nên issue không tự đóng: tick checklist, đóng issue kèm link PR, chuyển thẻ Project sang **Done**.
7. Khi đủ task cho một bản phát hành: PR `develop → main`, CI phải xanh, rồi tạo Release.

### CI (`.github/workflows/ci.yml`)

Chạy khi có PR / push vào `main` (hoặc bấm *Run workflow*): khởi động SQL Server 2025 bằng `docker compose`, dựng CSDL từ đầu bằng `database/run_all.sh`, chạy `database/tests/test_{seed,procedures,triggers,security}.sql` và `10_queries.sql`, rồi smoke test giao diện (`tests/test_app_smoke.py` – mở mọi trang với từng vai trò và sinh mọi báo cáo). Chạy thử trên máy:

```bash
cd app && pytest ../tests -q
```

## Commit đúng tên thành viên

Nhóm uỷ quyền cho Như thực hiện phần code. Để lịch sử git thể hiện đúng phân công, mọi commit của một task được ghi tên người phụ trách task đó:

```bash
scripts/commit-as.sh --list                                    # xem id thành viên
scripts/commit-as.sh phu -m "db(procedures): thêm sp_DangKyHoc (#11)"
scripts/commit-as.sh giang -m "feat(app): form phiếu thu master-detail (#23)"
```

Script đặt cả author và committer theo tên + email trong `team.json`.
Email trong `team.json` là email *noreply* của GitHub (`<id>+<username>@users.noreply.github.com`), nên commit luôn được gắn đúng
tài khoản GitHub của từng người mà không cần thêm email sinh viên vào **Settings → Emails**.

## Mẫu commit message

```
<loại>(<phạm vi>): <mô tả ngắn> (#<issue>)
```

| Loại | Dùng khi |
|---|---|
| `db` | Script CSDL (schema, procedure, view, trigger, ...) |
| `feat` | Tính năng ứng dụng web |
| `docs` | Tài liệu, báo cáo, sơ đồ thiết kế |
| `fix` | Sửa lỗi |
| `chore` | Cấu hình, công cụ, việc lặt vặt |

Ví dụ: `db(views): thêm vw_CongNoHocVien (#16)`, `docs(report): viết mục 2.4 chuẩn hoá (#6)`.

## Definition of Done

- Script SQL chạy lại được từ đầu (`DROP ... IF EXISTS`), có chú thích tiếng Việt.
- Có ảnh chụp kết quả và mục báo cáo tương ứng trong `report/`.
- Có phần so sánh / đánh giá kèm số liệu khi phù hợp (rubric A4 chấm "có so sánh, đối chiếu, số liệu rõ ràng").
- Tick đủ checklist trong issue; PR đã merge.

## Đặt tên trong CSDL

- Bảng: chữ HOA, không dấu, `CHINHANH`, `CT_PHIEUTHU`.
- Cột: PascalCase không dấu, `MaHV`, `NgayKhaiGiang`.
- Đối tượng lập trình: `sp_`, `fn_`, `vw_`, `trg_`, role `r_`.
