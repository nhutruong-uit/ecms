# Quy ước làm việc

## Nguồn kế hoạch duy nhất

Toàn bộ kế hoạch nằm trong [`docs/data/tasks.json`](docs/data/tasks.json); thông tin thành viên nằm trong [`docs/data/team.json`](docs/data/team.json).
Từ hai file này sinh ra:

- Trang GitHub Pages: https://nhutruong-uit.github.io/ecms/
- Issues, labels, milestones: `python3 scripts/sync_issues.py`
- GitHub Project (bảng công việc): `python3 scripts/sync_project.py`

Khi đổi kế hoạch (thêm task, đổi hạn, đổi người), sửa `tasks.json` rồi chạy lại hai script trên.

## Quy trình một task

1. Kéo thẻ trên Project sang **In Progress** (hoặc gắn label `dang-lam` vào issue).
2. Tạo nhánh theo task:
   ```bash
   git switch -c t11-stored-procedure
   ```
3. Làm việc, commit **dưới tên người phụ trách task** (xem mục dưới).
4. Đẩy nhánh, mở Pull Request. Mô tả PR có dòng `Closes #<số issue>` và ảnh kết quả.
5. Xem lại, merge vào `main`. Issue tự đóng, thẻ Project tự chuyển sang **Done**.

## Commit đúng tên thành viên

Nhóm uỷ quyền cho Như thực hiện phần code. Để lịch sử git thể hiện đúng phân công, mọi commit của một task được ghi tên người phụ trách task đó:

```bash
scripts/commit-as.sh --list                                    # xem id thành viên
scripts/commit-as.sh phu -m "db(procedures): thêm sp_DangKyHoc (#11)"
scripts/commit-as.sh giang -m "feat(app): form phiếu thu master-detail (#23)"
```

Script đặt cả author và committer theo tên + email trong `team.json`.
Email mặc định là email sinh viên `MSSV@gm.uit.edu.vn`. GitHub chỉ gắn commit vào tài khoản của bạn khi email đó đã được thêm vào
**GitHub → Settings → Emails**. Nếu bạn dùng email khác, báo Như để cập nhật `team.json`.

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
