# Phần 1. Giới thiệu

## 1.1 Mục đích tài liệu

Tài liệu này hướng dẫn cài đặt và sử dụng **ECMS – Hệ thống quản lý trung tâm tiếng Anh**. Nội dung gồm: cài đặt môi trường và khởi động hệ thống, các thao tác chung trên giao diện, hướng dẫn chi tiết theo từng vai trò người dùng, một quy trình nghiệp vụ mẫu từ lúc tư vấn đến lúc thu học phí và điểm danh, các tác vụ quản trị CSDL, cách xử lý sự cố và các câu hỏi thường gặp.

Mỗi chức năng được mô tả theo cùng một trình tự: **mở trang → thao tác từng bước → kết quả mong đợi**, kèm hình minh hoạ chụp từ ứng dụng chạy trên dữ liệu mẫu.

## 1.2 Tổng quan hệ thống

ECMS quản lý toàn bộ hoạt động của một chuỗi trung tâm tiếng Anh nhiều chi nhánh. Các chức năng được chia thành bảy phân hệ:

| Phân hệ | Chức năng chính |
|---|---|
| Danh mục | Chi nhánh, phòng học, ca học; nhân viên, giáo viên và chứng chỉ |
| Đào tạo | Chương trình, khoá học (có khoá tiên quyết), lớp học, lịch học cố định, buổi học |
| Học viên | Hồ sơ học viên, kiểm tra đầu vào, ghi danh, chuyển lớp, huỷ đăng ký |
| Học tập | Điểm danh, nhập điểm, cảnh báo chuyên cần |
| Tài chính | Lập phiếu thu học phí, in phiếu, theo dõi công nợ |
| Báo cáo | Dashboard, các báo cáo xuất PDF và Excel |
| Hệ thống | Tài khoản, nhật ký thay đổi, đổi mật khẩu, kiểm tra kết nối |

Mọi quy tắc nghiệp vụ – lớp còn chỗ, khoá tiên quyết, không trùng phòng, không thu vượt học phí… – đều được CSDL kiểm tra. Vì vậy khi thao tác sai, người dùng sẽ nhận được thông báo bằng tiếng Việt giải thích lý do; đây là hành vi đúng của hệ thống chứ không phải lỗi phần mềm.

## 1.3 Đối tượng sử dụng

Hệ thống có năm vai trò. Mỗi vai trò chỉ nhìn thấy các chức năng và phạm vi dữ liệu của mình:

| Vai trò | Công việc chính trên ECMS | Phạm vi dữ liệu |
|---|---|---|
| Quản lý | Danh mục, nhân viên, tài khoản, nhật ký, theo dõi toàn bộ nghiệp vụ và báo cáo | Toàn trung tâm (quản lý cấp trung tâm) hoặc chi nhánh của mình |
| Giáo vụ | Khoá học, mở lớp, xếp lịch, hồ sơ học viên, kiểm tra đầu vào, ghi danh, theo dõi chuyên cần và công nợ | Chi nhánh của mình |
| Kế toán | Lập phiếu thu, in phiếu, công nợ, báo cáo doanh thu, bảng lương giáo viên | Chi nhánh của mình |
| Giáo viên | Điểm danh, nhập điểm, xử lý cảnh báo chuyên cần, báo cáo các lớp mình dạy | Các lớp mình phụ trách |
| Học viên | Xem lịch học tuần, bảng điểm, học phí còn nợ | Dữ liệu của chính mình |

Bảng dưới đây cho biết mỗi vai trò thấy những mục menu nào (dấu ✓ là có quyền):

| Nhóm menu | Mục | Quản lý | Giáo vụ | Kế toán | Giáo viên | Học viên |
|---|---|:-:|:-:|:-:|:-:|:-:|
| – | Trang chủ | ✓ | ✓ | ✓ | ✓ | ✓ |
| Danh mục | Chi nhánh, phòng, ca học | ✓ | | | | |
| | Nhân viên & giáo viên | ✓ | | ✓ | | |
| Đào tạo | Chương trình & khoá học | ✓ | ✓ | | | |
| | Lớp học | ✓ | ✓ | | | |
| | Xếp lịch & buổi học | ✓ | ✓ | | | |
| Học viên | Hồ sơ học viên | ✓ | ✓ | | | |
| | Kiểm tra đầu vào | ✓ | ✓ | | | |
| | Ghi danh | ✓ | ✓ | | | |
| | Lịch học & kết quả của tôi | | | | | ✓ |
| Học tập | Điểm danh | ✓ | | | ✓ | |
| | Nhập điểm | ✓ | | | ✓ | |
| | Cảnh báo chuyên cần | ✓ | ✓ | | ✓ | |
| Tài chính | Lập phiếu thu | ✓ | | ✓ | | |
| | Công nợ | ✓ | ✓ | ✓ | | |
| Báo cáo | Dashboard | ✓ | | ✓ | | |
| | Báo cáo & xuất file | ✓ | ✓ | ✓ | ✓ | |
| Hệ thống | Tài khoản | ✓ | | | | |
| | Nhật ký hệ thống | ✓ | | | | |
| | Đổi mật khẩu | ✓ | ✓ | ✓ | ✓ | ✓ |
| | Kiểm tra kết nối | ✓ | | | | |

## 1.4 Quy ước trình bày

- Tên nút, ô nhập, thẻ trên giao diện được in **đậm**, ví dụ nút **Lưu**.
- Đường dẫn menu được viết theo dạng **Nhóm → Mục**, ví dụ **Học viên → Ghi danh**.
- Lệnh cần gõ trong cửa sổ dòng lệnh (Terminal, PowerShell) được đặt trong khung xám.
- Đoạn bắt đầu bằng **Lưu ý** là thông tin cần đọc kỹ để tránh thao tác sai.

# Phần 2. Cài đặt và khởi động

## 2.1 Yêu cầu hệ thống

| Thành phần | Yêu cầu |
|---|---|
| Hệ điều hành | Windows 10/11, macOS 13 trở lên hoặc Linux |
| Cơ sở dữ liệu | Windows: SQL Server 2022 (Developer hoặc Express); macOS, Linux: SQL Server 2025 chạy bằng Docker Desktop |
| Trình điều khiển | Microsoft ODBC Driver 18 for SQL Server |
| Python | 3.11 trở lên |
| Trình duyệt | Chrome, Edge, Firefox hoặc Safari phiên bản mới |

## 2.2 Lấy mã nguồn và cấu hình

Mở cửa sổ dòng lệnh, tải mã nguồn và tạo tệp cấu hình từ tệp mẫu:

```bash
git clone https://github.com/nhutruong-uit/ecms.git
cd ecms
cp .env.example .env        # Windows: copy .env.example .env
```

Tệp `.env` chứa thông tin kết nối. Giá trị mặc định dùng được ngay với Docker; chỉ cần sửa khi SQL Server cài trên máy khác hoặc dùng cổng khác.

| Biến | Ý nghĩa | Giá trị mặc định |
|---|---|---|
| `SA_PASSWORD` | Mật khẩu tài khoản `sa` của SQL Server, dùng cho script dựng CSDL và sao lưu | `Ecms@12345` |
| `DB_SERVER`, `DB_PORT` | Địa chỉ và cổng của SQL Server | `localhost`, `1433` |
| `DB_USER`, `DB_PASSWORD` | Login ít quyền của ứng dụng web | `ecms_app` và mật khẩu có sẵn trong tệp mẫu |
| `DB_TRUST_CERT` | Tin chứng chỉ tự ký của SQL Server | `yes` |
| `DB_TRUSTED` | Dùng Windows Authentication thay cho tên và mật khẩu | `no` |

**Lưu ý:** tệp `.env` chứa mật khẩu nên không được đưa lên kho mã nguồn.

## 2.3 Khởi động SQL Server

**Trên macOS hoặc Linux (Docker):**

```bash
docker compose up -d        # lần đầu sẽ tải image khoảng 1,5 GB
docker compose ps           # chờ cột STATUS hiện "healthy"
```

Trên máy Mac dùng chip Apple Silicon, cần bật **Settings → General → Use Rosetta for x86/amd64 emulation** trong Docker Desktop trước khi chạy lệnh trên.

**Trên Windows:** cài SQL Server 2022 Developer hoặc Express, chọn chế độ xác thực **Mixed Mode** khi cài đặt; bật giao thức **TCP/IP** trong *SQL Server Configuration Manager*; cài thêm SQL Server Management Studio (SSMS) và ODBC Driver 18.

## 2.4 Dựng cơ sở dữ liệu

Chạy script dựng CSDL tương ứng với hệ điều hành:

```bash
database/run_all.sh          # macOS, Linux hoặc Git Bash
```

```powershell
# Windows PowerShell
.\database\run_all.ps1 -SqlLogin sa -Password "Ecms@12345"
```

Script lần lượt tạo 22 bảng, nạp dữ liệu mẫu, tạo function, view, procedure, trigger, phân quyền và XML Schema. Toàn bộ mất khoảng 10 – 20 giây.

**Lưu ý:** script xoá CSDL ECMS cũ trước khi tạo mới. Có thể chạy lại bất cứ lúc nào để đưa hệ thống về trạng thái dữ liệu mẫu ban đầu, nhưng mọi dữ liệu đã nhập sẽ mất – hãy sao lưu trước nếu cần (mục 7.1).

## 2.5 Chạy ứng dụng web

```bash
python3 -m venv .venv
source .venv/bin/activate   # Windows: .venv\Scripts\activate
pip install -r requirements.txt
streamlit run app/main.py
```

Mở trình duyệt tại địa chỉ `http://localhost:8501`. Đăng nhập bằng tài khoản Quản lý (mục 2.6), vào **Hệ thống → Kiểm tra kết nối**: nếu trang báo *Kết nối thành công* thì môi trường đã sẵn sàng.

## 2.6 Tài khoản dùng thử

Dữ liệu mẫu có sẵn năm tài khoản đại diện cho năm vai trò:

| Tên đăng nhập | Mật khẩu | Vai trò |
|---|---|---|
| `quanly` | `Ecms@2026` | Quản lý – xem toàn trung tâm |
| `giaovu` | `Ecms@2026` | Giáo vụ chi nhánh CN01 |
| `ketoan` | `Ecms@2026` | Kế toán chi nhánh CN01 |
| `giaovien` | `Ecms@2026` | Giáo viên chi nhánh CN01 |
| `hocvien` | `Hocvien@2026` | Học viên |

**Lưu ý:** các tài khoản này chỉ dành cho môi trường thử nghiệm. Khi triển khai thật, cần đổi mật khẩu hoặc khoá các tài khoản này (mục 4.1.4) và gỡ khung "Tài khoản demo" khỏi màn hình đăng nhập.

# Phần 3. Thao tác chung

## 3.1 Đăng nhập và đăng xuất

1. Mở `http://localhost:8501`.
2. Nhập **Tên đăng nhập** và **Mật khẩu**, nhấn **Đăng nhập** hoặc phím Enter.
3. Khi muốn thoát, nhấn **Đăng xuất** ở cuối thanh menu bên trái.

Nếu nhập sai, hệ thống báo "Sai tên đăng nhập hoặc mật khẩu" kèm số lần thử còn lại. **Sai 5 lần liên tiếp, tài khoản bị khoá** – khi đó cần liên hệ Quản lý để mở khoá.

![Màn hình đăng nhập](../../report/images/ch4/01_dang_nhap.jpg)

*Hình 3.1 – Màn hình đăng nhập*

## 3.2 Bố cục giao diện

Sau khi đăng nhập, màn hình gồm ba vùng:

- **Thanh menu bên trái** gom các chức năng theo nhóm nghiệp vụ. Mỗi vai trò chỉ thấy các mục mình được dùng; mục đang mở được tô nền đậm.
- **Cuối thanh menu** hiển thị họ tên, vai trò, chi nhánh, phạm vi dữ liệu và nút **Đăng xuất**.
- **Vùng nội dung** bên phải. Trang chủ hiển thị các chỉ số tóm tắt và danh sách lớp đang học, sắp mở trong phạm vi của người dùng.

![Trang chủ của Quản lý](../../report/images/ch4/02_trang_chu.jpg)

*Hình 3.2 – Trang chủ và menu đầy đủ của vai trò Quản lý*

## 3.3 Quy ước trên các trang nghiệp vụ

Hầu hết các trang dùng chung một cách thao tác:

1. **Lọc và tìm** bằng các ô ở đầu trang như chi nhánh, trạng thái, ô tìm kiếm.
2. **Chọn một dòng** trong bảng bằng ô vuông ở đầu dòng. Form bên dưới chuyển sang chế độ **sửa** với dữ liệu được điền sẵn. Bỏ chọn để quay lại chế độ **thêm mới**.
3. Nhập dữ liệu rồi nhấn **Lưu**. Ô có dấu `*` là bắt buộc. Nếu nhập sai định dạng, lỗi hiện ngay dưới ô tương ứng (Hình 3.3) và dữ liệu chưa được gửi đi.
4. Nút xoá luôn ghi rõ đối tượng sẽ bị xoá, ví dụ **Xoá chi nhánh CN02**. Dữ liệu đang được sử dụng ở nơi khác (chi nhánh còn lớp, lớp còn học viên…) sẽ bị từ chối xoá kèm thông báo lý do.
5. Sau khi lưu, khung xanh báo thành công hoặc khung đỏ báo lỗi nghiệp vụ xuất hiện ngay trên trang.

Một số ô và nút bị làm mờ có chủ đích để tránh thao tác sai, không phải lỗi: ô mã (chi nhánh, khoá học…) không sửa được khi đang sửa một bản ghi có sẵn; khoá học và chi nhánh của lớp đã có học viên không đổi được; tài khoản cấp chi nhánh không chọn được chi nhánh khác.

![Kiểm tra dữ liệu tại ô nhập](../../report/images/ch4/04_kiem_tra_nhap_lieu.jpg)

*Hình 3.3 – Lỗi nhập liệu hiển thị ngay dưới ô tương ứng*

## 3.4 Làm việc với bảng dữ liệu

- Nhấn vào tiêu đề cột để sắp xếp tăng hoặc giảm dần.
- Rê chuột lên góc trên bên phải bảng để hiện các biểu tượng **tìm kiếm** trong bảng, **phóng to** bảng và **tải về** dạng CSV.
- Với các bảng sửa trực tiếp (điểm danh, nhập điểm, chi tiết phiếu thu), cột sửa được có biểu tượng bút; nhấn đúp vào ô để sửa. Các cột còn lại chỉ để xem.

## 3.5 Đổi mật khẩu

1. Vào **Hệ thống → Đổi mật khẩu**.
2. Nhập **Mật khẩu hiện tại**, **Mật khẩu mới** và **Nhập lại mật khẩu mới**.
3. Nhấn **Đổi mật khẩu**.

Mật khẩu mới phải có từ 8 ký tự trở lên, gồm chữ hoa, chữ thường, chữ số, ký tự đặc biệt, và phải khác mật khẩu cũ. Chức năng này dành cho mọi vai trò.

![Đổi mật khẩu](images/doi_mat_khau.jpg)

*Hình 3.4 – Trang đổi mật khẩu*

# Phần 4. Hướng dẫn theo vai trò

## 4.1 Quản lý

### 4.1.1 Chi nhánh, phòng học và ca học

Vào **Danh mục → Chi nhánh, phòng, ca học**. Trang có ba thẻ:

- **Chi nhánh**: mã chi nhánh có dạng `CN` và hai chữ số; tên; địa chỉ; điện thoại; ngày thành lập; người quản lý (phải là nhân viên có chức vụ Quản lý).
- **Phòng học**: chọn chi nhánh, nhập số phòng, sức chứa và loại phòng. Phòng được dùng khi xếp lịch, vì vậy sức chứa phải từ sĩ số tối đa của lớp trở lên.
- **Ca học**: tên ca, giờ bắt đầu và giờ kết thúc.

![Danh mục chi nhánh](../../report/images/ch4/03_danh_muc_chi_nhanh.jpg)

*Hình 4.1 – Danh mục chi nhánh, phòng học, ca học*

### 4.1.2 Nhân viên và giáo viên

Vào **Danh mục → Nhân viên & giáo viên**.

1. Lọc theo chi nhánh, chức vụ, trạng thái; chọn một nhân viên để sửa thông tin chung.
2. Với nhân viên có chức vụ Giáo viên, form có thêm loại giáo viên, quốc tịch, trình độ, đơn giá mỗi buổi và danh sách **chứng chỉ**; thêm chứng chỉ bằng nút **Lưu chứng chỉ**.
3. Nút **Xoá / cho nghỉ** xoá nhân viên nếu chưa phát sinh dữ liệu, hoặc chuyển sang trạng thái đã nghỉ nếu đã có dữ liệu liên quan.

Kế toán cũng mở được trang này để xem danh sách phục vụ việc tính lương. Mọi thay đổi lương cơ bản đều được ghi vào nhật ký hệ thống.

![Nhân viên và giáo viên](../../report/images/ch4/05_nhan_vien.jpg)

*Hình 4.2 – Danh mục nhân viên và giáo viên*

### 4.1.3 Dashboard

Vào **Báo cáo → Dashboard**, chọn chi nhánh (hoặc toàn trung tâm) và năm.

- **Hàng chỉ số** trên cùng gồm học viên mới, doanh thu tháng, doanh thu năm, tỷ lệ lấp đầy lớp, tỷ lệ chuyên cần, công nợ; mũi tên xanh là tăng, đỏ là giảm so với tháng trước.
- **Các biểu đồ** bên dưới gồm doanh thu theo tháng xếp chồng theo chi nhánh, cơ cấu doanh thu theo chương trình, tỷ lệ lấp đầy của từng lớp, học viên mới theo tháng, tương quan giữa chuyên cần và điểm.

Rê chuột lên biểu đồ để xem số liệu chi tiết của từng điểm.

![Dashboard](../../report/images/ch4/16_dashboard.jpg)

*Hình 4.3 – Dashboard tổng hợp*

### 4.1.4 Tài khoản người dùng

Vào **Hệ thống → Tài khoản**.

**Tạo tài khoản mới:**

1. Chọn tài khoản dành **Cho** nhân viên hay học viên, rồi chọn người sở hữu.
2. Nhập **Tên đăng nhập** (từ 4 ký tự, chữ thường không dấu, số, dấu chấm), **Mật khẩu ban đầu** và **Vai trò**.
3. Nhấn **Tạo tài khoản**.

**Đổi vai trò, khoá hoặc mở khoá:** chọn tài khoản trong bảng; đổi vai trò rồi nhấn **Lưu**, hoặc nhấn **Khoá tài khoản** / **Mở khoá tài khoản**. Ô **Đặt lại mật khẩu** dùng khi người dùng quên mật khẩu (bỏ trống nếu không đổi).

**Lưu ý:** không thể tự khoá tài khoản đang đăng nhập. Mật khẩu chỉ được lưu ở dạng băm nên không ai, kể cả Quản lý, xem được mật khẩu gốc.

![Tài khoản](../../report/images/ch4/17_tai_khoan.jpg)

*Hình 4.4 – Quản lý tài khoản*

### 4.1.5 Nhật ký hệ thống

Vào **Hệ thống → Nhật ký hệ thống**. Trang liệt kê mọi thay đổi trên đăng ký, phiếu thu và lương nhân viên: thời gian, bảng, thao tác, khoá của dòng bị thay đổi, tài khoản ứng dụng và login SQL đã thực hiện.

1. Lọc theo **Bảng**, **Thao tác** và khoảng ngày.
2. Chọn một dòng để xem dữ liệu trước và sau khi thay đổi.

Nhật ký chỉ để đọc – không ai sửa hay xoá được.

![Nhật ký hệ thống](../../report/images/ch4/18_nhat_ky.jpg)

*Hình 4.5 – Nhật ký hệ thống*

## 4.2 Giáo vụ

### 4.2.1 Chương trình và khoá học

Vào **Đào tạo → Chương trình & khoá học**.

- Thẻ **Chương trình** quản lý các chương trình đào tạo: mã, tên, đối tượng học viên, mô tả.
- Thẻ **Khoá học** quản lý khoá học: mã, tên, chương trình, cấp độ, khoảng điểm kiểm tra đầu vào phù hợp, mục tiêu đầu ra, số buổi, học phí và **khoá tiên quyết** cùng chương trình. Học viên phải đạt khoá tiên quyết (hoặc có điểm đầu vào đủ cao) mới được ghi danh khoá sau.

### 4.2.2 Mở lớp

Vào **Đào tạo → Lớp học**.

1. Lọc danh sách theo chi nhánh, khoá học, trạng thái (mặc định hiện lớp Sắp mở và Đang học).
2. Ở form mở lớp mới, chọn khoá học, chi nhánh và giáo viên phụ trách; tên lớp được gợi ý sẵn theo khoá.
3. Nhập **Ngày khai giảng**, **Sĩ số tối đa** (từ 5 đến 40), nhấn **Lưu**.

Mã lớp do hệ thống sinh tự động gồm mã khoá học, hai số cuối của năm khai giảng và số thứ tự lớp trong năm; ví dụ `IE55-2602` là lớp thứ hai của khoá IELTS 5.5 khai giảng năm 2026.

**Lưu ý:** khi sửa một lớp đã hoạt động, hệ thống chặn các thay đổi làm sai dữ liệu đã có:

- lớp đã có học viên thì không đổi được khoá học và chi nhánh;
- sĩ số tối đa không được nhỏ hơn số học viên đang có;
- lớp đã sinh buổi học thì muốn đổi ngày khai giảng phải sinh lại buổi học (mục 4.2.3);
- đổi giáo viên phụ trách cho lớp đã có lịch thì hệ thống kiểm tra giáo viên mới có bị trùng lịch hay không;
- lớp đã kết thúc không mở lại được.

![Lớp học](../../report/images/ch4/06_lop_hoc.jpg)

*Hình 4.6 – Danh sách lớp và form mở lớp*

### 4.2.3 Xếp lịch và sinh buổi học

Vào **Đào tạo → Xếp lịch & buổi học**, thẻ **Lịch của một lớp**:

1. Chọn lớp cần xếp lịch.
2. Ở phần lịch cố định trong tuần, chọn **Thứ**, ca và phòng, nhấn **Thêm vào lịch**. Lặp lại cho các buổi khác trong tuần. Muốn bỏ một buổi, chọn ở ô **Bỏ một buổi khỏi lịch** rồi nhấn **Bỏ khỏi lịch**.
3. Nhấn **Sinh n buổi học tự động** (n là số buổi của khoá). Hệ thống duyệt từng ngày từ ngày khai giảng theo lịch cố định, **bỏ qua ngày lễ** và tạo đủ số buổi; ngày kết thúc của lớp được cập nhật theo buổi cuối cùng.
4. Nếu cần sửa lịch khi lớp chưa điểm danh buổi nào, sửa lịch cố định rồi nhấn **Sinh lại buổi học**.

Hệ thống từ chối thêm lịch nếu phòng hoặc giáo viên đã bận cùng thứ và ca trong khoảng thời gian của lớp, hoặc nếu phòng không đủ sức chứa. Thẻ **Lịch tuần toàn chi nhánh** hiển thị lưới thứ × ca để tìm phòng trống trước khi xếp.

![Xếp lịch và buổi học](../../report/images/ch4/07_xep_lich.jpg)

*Hình 4.7 – Lịch cố định và danh sách buổi học của lớp*

### 4.2.4 Hồ sơ học viên

Vào **Học viên → Hồ sơ học viên**.

1. Nhập tên, mã, số điện thoại hoặc email vào ô tìm kiếm, chọn thêm bộ lọc nếu cần, nhấn **Tìm**. Kết quả được phân trang 15 dòng; dùng nút **◀ Trang trước** và **Trang sau ▶** để chuyển trang.
2. Chọn một học viên để xem các thẻ **Lớp đã học & điểm**, **Kiểm tra đầu vào**, **Học phí** và **Sửa hồ sơ**.
3. Để thêm học viên mới, dùng form **Thêm học viên mới** ở cuối trang rồi nhấn **Lưu hồ sơ**. Với học viên dưới 16 tuổi, phải nhập họ tên phụ huynh.

Danh sách chỉ gồm học viên thuộc chi nhánh của người đăng nhập.

![Hồ sơ học viên](../../report/images/ch4/08_ho_so_hoc_vien.jpg)

*Hình 4.8 – Tìm kiếm hồ sơ học viên*

### 4.2.5 Kiểm tra đầu vào

Vào **Học viên → Kiểm tra đầu vào**, thẻ **Nhập kết quả**:

1. Tìm và chọn học viên.
2. Chọn chương trình quan tâm và **Hình thức** thi (Tại trung tâm hoặc Online).
3. Nhập điểm bốn kỹ năng Listening, Reading, Writing, Speaking (từ 0 đến 10, bước 0,5), nhận xét từng kỹ năng và nhận xét chung.
4. Nhấn **Lưu kết quả**.

Ngay sau khi lưu, trang hiển thị điểm tổng, khoá được đề xuất và bảng **gợi ý khoá học** phù hợp với điểm. Điểm ngoài khoảng 0 – 10 sẽ bị từ chối. Thẻ **Xem chi tiết (đọc từ XML)** hiển thị lại điểm và nhận xét của các lần kiểm tra trước.

![Kiểm tra đầu vào](../../report/images/ch4/09_kiem_tra_dau_vao.jpg)

*Hình 4.9 – Nhập kết quả kiểm tra đầu vào*

### 4.2.6 Ghi danh, chuyển lớp và huỷ đăng ký

Vào **Học viên → Ghi danh**.

**Ghi danh vào lớp mới:**

1. Nhập tên, số điện thoại hoặc mã học viên rồi chọn học viên. Trang hiển thị kết quả kiểm tra gần nhất và **khoá được đề xuất**.
2. Ở phần **Ghi danh lớp mới**, công tắc **Chỉ hiện lớp của khoá đề xuất** được bật sẵn; tắt đi nếu muốn chọn khoá khác.
3. Chọn lớp còn chỗ, kéo thanh **Giảm giá (%)** nếu có ưu đãi (từ 0 đến 50%).
4. Nhấn **Ghi danh vào** kèm mã lớp.

**Chuyển lớp hoặc huỷ đăng ký:** ở phần **Đăng ký hiện có**, chọn một đăng ký, rồi:

- chọn lớp ở ô **Chuyển sang lớp cùng khoá** và nhấn **Chuyển lớp** – số tiền đã đóng được chuyển theo; hoặc
- nhấn **Huỷ đăng ký** – chỉ thực hiện được khi đăng ký chưa đóng tiền.

Hệ thống tự kiểm tra lớp còn chỗ, học viên chưa đăng ký lớp đó và đã đủ điều kiện tiên quyết; sĩ số lớp được cập nhật tự động.

![Ghi danh](../../report/images/ch4/10_ghi_danh.jpg)

*Hình 4.10 – Ghi danh học viên*

### 4.2.7 Theo dõi chuyên cần và công nợ

Giáo vụ dùng được hai trang theo dõi:

- **Học tập → Cảnh báo chuyên cần**: xem và xử lý học viên vắng nhiều, cách dùng như ở mục 4.4.3.
- **Tài chính → Công nợ**: xem các đăng ký còn nợ để nhắc học viên đóng học phí, cách dùng như ở mục 4.3.2.

## 4.3 Kế toán

### 4.3.1 Lập phiếu thu

Vào **Tài chính → Lập phiếu thu**, thẻ **Lập phiếu thu**:

1. **Thông tin phiếu**: tìm và chọn học viên; mỗi học viên được hiển thị kèm tổng số tiền còn nợ.
2. **Chi tiết**: bảng liệt kê các đăng ký còn nợ của học viên; khoản quá hạn có dấu **⚠ Quá hạn**. Tích chọn các khoản cần thu. Cột **Thu lần này (đ)** mặc định bằng số còn nợ; sửa lại nếu học viên chỉ đóng một phần.
3. Chọn **Hình thức** (Tiền mặt, Chuyển khoản hoặc Thẻ), nhập **Ghi chú** nếu cần, kiểm tra **Tổng phiếu**.
4. Nhấn **Lập phiếu thu**. Hệ thống báo mã phiếu vừa tạo, ví dụ "Đã lập phiếu PT000527".
5. Nhấn **In phiếu … (PDF)** để tải phiếu thu có số tiền bằng chữ và chỗ ký.

Thẻ **Tra cứu phiếu thu** dùng để tìm lại phiếu theo khoảng ngày, số phiếu hoặc học viên, xem chi tiết và in lại.

**Lưu ý:** phiếu thu đã lập không sửa được. Hệ thống từ chối nếu số tiền thu vượt quá số còn nợ của đăng ký.

![Lập phiếu thu](../../report/images/ch4/14_phieu_thu.jpg)

*Hình 4.11 – Lập phiếu thu cho nhiều khoản (master – detail)*

![Phiếu thu PDF](../../report/images/ch4/19_pdf_phieu_thu.jpg)

*Hình 4.12 – Phiếu thu in ra PDF*

### 4.3.2 Công nợ

Vào **Tài chính → Công nợ**. Trang liệt kê các đăng ký chưa đóng đủ học phí; hạn đóng là 14 ngày kể từ ngày đăng ký. Ba chỉ số trên cùng tóm tắt tổng nợ, số đăng ký còn nợ và số đăng ký quá hạn. Màu nền của dòng cho biết mức độ:

| Màu | Ý nghĩa |
|---|---|
| Đỏ đậm | Quá hạn trên 30 ngày |
| Đỏ nhạt | Đã quá hạn |
| Vàng | Chưa đóng đồng nào, chưa tới hạn |

Bật **Chỉ nợ quá hạn** hoặc nhập **Nợ từ (đ)** để lọc danh sách cần nhắc nợ.

![Công nợ](../../report/images/ch4/14b_cong_no.jpg)

*Hình 4.13 – Theo dõi công nợ học phí*

### 4.3.3 Bảng lương giáo viên

1. Vào **Báo cáo → Báo cáo & xuất file**, chọn báo cáo *Bảng lương giáo viên*.
2. Nhập **Tháng (yyyy-MM)**.
3. Nếu tháng đó chưa có bảng lương, nhấn **Tính lại bảng lương tháng này**: hệ thống đếm số buổi đã dạy của từng giáo viên, nhân với đơn giá và cộng lương cơ bản.
4. Nhấn **Tải PDF** hoặc **Tải Excel** ở cuối trang.

## 4.4 Giáo viên

### 4.4.1 Điểm danh

Vào **Học tập → Điểm danh**:

1. Chọn **Lớp**, rồi chọn **Buổi học**. Buổi đã điểm danh có dấu ✓; chỉ điểm danh được các buổi từ hôm nay trở về trước.
2. Cả lớp mặc định ở trạng thái *Có mặt*. Sửa cột **Trạng thái** cho học viên *Vắng*, *Muộn* hoặc *Có phép*; ghi chú nếu cần.
3. Nhấn **Lưu điểm danh** – cả lớp được lưu trong một lần.

Giáo viên chỉ thấy các lớp mình phụ trách.

![Điểm danh](../../report/images/ch4/11_diem_danh.jpg)

*Hình 4.14 – Điểm danh cả lớp*

### 4.4.2 Nhập điểm

Vào **Học tập → Nhập điểm**:

1. Chọn lớp.
2. Sửa trực tiếp cột *Giữa kỳ* và *Cuối kỳ* (từ 0 đến 10, bước 0,25). Điểm trung bình được tính theo công thức 0,4 × giữa kỳ + 0,6 × cuối kỳ; xếp loại và kết quả (Đạt khi điểm trung bình từ 5 trở lên) được tính tự động.
3. Dòng chữ dưới bảng cho biết số học viên có thay đổi chưa lưu. Nhấn **Lưu điểm**.

![Nhập điểm](../../report/images/ch4/12_nhap_diem.jpg)

*Hình 4.15 – Nhập điểm giữa kỳ, cuối kỳ*

### 4.4.3 Cảnh báo chuyên cần

Vào **Học tập → Cảnh báo chuyên cần**:

1. Chọn **Ngưỡng vắng (%)** (mặc định 20%) và **Số buổi tối thiểu** đã học để bắt đầu xét.
2. Nhấn **Quét cảnh báo hôm nay**. Danh sách hiện các học viên vượt ngưỡng với mức *Nghiêm trọng* (vắng trên 30%) hoặc *Nhắc nhở*, kèm số điện thoại của học viên và phụ huynh.
3. Sau khi liên hệ, chọn dòng và nhấn **Đã liên hệ / xử lý xong**.

Tắt **Chỉ hiện cảnh báo chưa xử lý** để xem lại cả các cảnh báo đã xử lý. Giáo vụ và Quản lý cũng dùng được trang này.

![Cảnh báo chuyên cần](../../report/images/ch4/13_canh_bao.jpg)

*Hình 4.16 – Cảnh báo học viên vắng nhiều*

## 4.5 Học viên

Vào **Học viên → Lịch học & kết quả của tôi**. Trang có ba thẻ:

- **Lịch học tuần**: chọn một ngày ở ô **Tuần chứa ngày** để xem các buổi học trong tuần đó (ca, giờ, phòng, nội dung, giáo viên).
- **Bảng điểm**: điểm giữa kỳ, cuối kỳ, trung bình, tỷ lệ chuyên cần và kết quả của từng lớp.
- **Học phí**: số phải đóng, đã đóng, còn nợ và hạn đóng của từng đăng ký.

![Lịch học của học viên](images/hoc_vien_cua_toi.jpg)

*Hình 4.17 – Trang thông tin cá nhân của học viên*

# Phần 5. Báo cáo và xuất file

Vào **Báo cáo → Báo cáo & xuất file**:

1. Chọn báo cáo ở ô **Báo cáo**; mỗi vai trò chỉ thấy các báo cáo của mình.
2. Nhập tham số của báo cáo.
3. Xem trước kết quả trên màn hình.
4. Nhấn **Tải PDF** hoặc **Tải Excel**.

| Báo cáo | Tham số | Vai trò được dùng |
|---|---|---|
| Danh sách học viên theo lớp | Lớp | Quản lý, Giáo vụ, Giáo viên |
| Doanh thu theo chi nhánh và tháng | Từ ngày, đến ngày | Quản lý, Kế toán |
| Bảng điểm lớp | Lớp | Quản lý, Giáo vụ, Giáo viên |
| Lịch sử học tập của học viên | Học viên | Quản lý, Giáo vụ |
| Công nợ học viên | Ngưỡng nợ, chỉ nợ quá hạn | Quản lý, Kế toán, Giáo vụ |
| Bảng lương giáo viên | Tháng | Quản lý, Kế toán |
| Tổng hợp theo chương trình | Năm | Quản lý, Kế toán |

Tệp PDF có tên trung tâm, tên báo cáo, dòng tham số, tổng phụ theo nhóm, dòng tổng cộng và số trang dạng "Trang X / Y". Tệp Excel có định dạng tiền và dòng tổng dùng công thức nên có thể tiếp tục tính toán.

![Báo cáo và xuất file](../../report/images/ch4/15_bao_cao_danh_sach.jpg)

*Hình 5.1 – Chọn báo cáo, nhập tham số và tải tệp*

![Báo cáo doanh thu PDF](../../report/images/ch4/20_pdf_doanh_thu.jpg)

*Hình 5.2 – Báo cáo doanh thu theo chi nhánh xuất ra PDF*

# Phần 6. Quy trình nghiệp vụ mẫu

Phần này hướng dẫn thực hiện trọn vẹn vòng đời của một học viên mới, đi qua nhiều vai trò, để người dùng thấy các chức năng liên kết với nhau như thế nào. Có thể thực hành ngay trên dữ liệu mẫu bằng các tài khoản ở mục 2.6.

| Bước | Vai trò | Thao tác | Hướng dẫn chi tiết |
|:-:|---|---|:-:|
| 1 | Giáo vụ | Tư vấn và lập hồ sơ học viên mới | Mục 4.2.4 |
| 2 | Giáo vụ | Ghi nhận kết quả kiểm tra đầu vào, xem khoá được đề xuất | Mục 4.2.5 |
| 3 | Giáo vụ | Ghi danh học viên vào một lớp của khoá đề xuất | Mục 4.2.6 |
| 4 | Kế toán | Lập phiếu thu cho đăng ký vừa tạo và in phiếu | Mục 4.3.1 |
| 5 | Giáo viên | Điểm danh các buổi học của lớp | Mục 4.4.1 |
| 6 | Giáo viên | Nhập điểm giữa kỳ, cuối kỳ | Mục 4.4.2 |
| 7 | Học viên | Xem lịch học, bảng điểm và học phí của mình | Mục 4.5 |
| 8 | Quản lý | Theo dõi doanh thu, sĩ số trên dashboard; xem nhật ký thay đổi | Mục 4.1.3, 4.1.5 |

**Kết quả mong đợi sau từng bước:**

- Sau bước 3, sĩ số của lớp tăng thêm một; đăng ký mới có trạng thái học phí *Chưa đóng* và xuất hiện ở trang **Công nợ**.
- Sau bước 4, trạng thái học phí chuyển thành *Đã đóng* (hoặc *Đóng một phần* nếu thu một phần) và đăng ký biến mất khỏi danh sách công nợ nếu đã đóng đủ.
- Sau bước 6, cột kết quả của đăng ký hiển thị *Đạt* hoặc *Không đạt*.
- Ở bước 8, trang **Nhật ký hệ thống** có các dòng ghi lại thao tác ghi danh và lập phiếu thu, kèm đúng tên tài khoản giáo vụ và kế toán đã thực hiện.

# Phần 7. Quản trị cơ sở dữ liệu

## 7.1 Sao lưu và phục hồi

Lịch sao lưu khuyến nghị:

| Loại sao lưu | Lịch | Thời gian giữ |
|---|---|---|
| Toàn bộ (FULL) | Chủ nhật 01:00 | 4 tuần |
| Vi sai (DIFF) | Thứ Hai đến thứ Bảy 01:00 | 1 tuần |
| Nhật ký (LOG) | Mỗi 15 phút từ 07:00 đến 22:00 | 2 tuần |

Nếu SQL Server có SQL Server Agent, dùng các job được tạo bởi script `database/11_backup_restore.sql`. Nếu không có Agent (bản Express hoặc Docker), đặt lịch chạy định kỳ (cron trên macOS, Linux; Task Scheduler trên Windows) cho lệnh:

```bash
# hoặc DIFF, LOG – tệp sao lưu được lưu trong thư mục backups/
scripts/backup.sh FULL
```

**Phục hồi đến một thời điểm:** làm theo phần phục hồi trong `database/11_backup_restore.sql` – khôi phục bản FULL, sau đó bản DIFF gần nhất, rồi lần lượt các bản LOG với tuỳ chọn dừng tại thời điểm cần phục hồi.

**Lưu ý:** nên phục hồi ra một CSDL có tên khác để đối chiếu trước, chỉ thay thế CSDL chính khi đã chắc chắn dữ liệu đúng.

## 7.2 Nhập và xuất dữ liệu

```bash
# kiểm tra và nạp danh sách đăng ký trực tuyến
python3 scripts/import_export.py import data/import/hocvien_online.csv
# xuất dữ liệu ra thư mục data/export/
python3 scripts/import_export.py export --format csv xlsx json xml
```

Lệnh `import` kiểm tra từng dòng (ngày sinh, số điện thoại, email, chi nhánh, khoá học, dòng trùng), nạp các dòng hợp lệ và in danh sách dòng lỗi kèm lý do để gửi trả bộ phận cung cấp dữ liệu.

## 7.3 Kiểm thử sau khi cập nhật

Sau mỗi lần cập nhật mã nguồn hoặc script CSDL, chạy lại bộ kiểm thử để bảo đảm hệ thống vẫn hoạt động đúng:

```bash
database/run_all.sh      # dựng lại CSDL từ đầu
# mở mọi trang với từng vai trò và sinh mọi báo cáo
cd app && pytest ../tests -q
```

Các bộ kiểm thử SQL trong thư mục `database/tests/` (dữ liệu mẫu, procedure, trigger, phân quyền) chạy được bằng `sqlcmd -i`; mỗi bộ báo lỗi nếu có ca kiểm thử không đạt.

# Phần 8. Xử lý sự cố và câu hỏi thường gặp

## 8.1 Lỗi cài đặt và kết nối

| Hiện tượng | Nguyên nhân và cách xử lý |
|---|---|
| `Can't open lib 'ODBC Driver 18 for SQL Server'` | Chưa cài ODBC Driver 18 – cài theo mục 2.1 |
| `SSL Provider: certificate verify failed` | Đặt `DB_TRUST_CERT=yes` trong tệp `.env` |
| `Login timeout expired` | SQL Server chưa khởi động xong (kiểm tra bằng `docker compose ps`) hoặc Windows chưa bật TCP/IP; trên macOS thử đặt `DB_SERVER=127.0.0.1` |
| `Login failed for user 'sa'` | `SA_PASSWORD` khác với mật khẩu lúc tạo container – chạy `docker compose down -v` rồi `docker compose up -d` để tạo lại |
| `Login failed for user 'ecms_app'` | Chưa chạy script phân quyền – chạy lại `database/run_all.sh` |
| Trang báo "Bạn không có quyền truy cập chức năng này" | Vai trò hiện tại không được dùng chức năng đó – đăng nhập bằng đúng tài khoản |

## 8.2 Thông báo nghiệp vụ thường gặp

Các thông báo dưới đây do CSDL trả về khi dữ liệu vi phạm quy tắc nghiệp vụ. Đây là hành vi đúng của hệ thống; người dùng chỉ cần điều chỉnh dữ liệu theo hướng dẫn.

| Thông báo | Nguyên nhân và cách xử lý |
|---|---|
| Lớp đã đủ sĩ số. | Chọn lớp khác cùng khoá hoặc tăng sĩ số tối đa của lớp |
| Học viên đã đăng ký lớp này. | Đăng ký đã tồn tại – xem ở phần **Đăng ký hiện có** |
| Chưa đủ điều kiện: cần Đạt khoá … hoặc điểm kiểm tra đầu vào từ … trở lên. | Học viên chưa đạt khoá tiên quyết – ghi danh khoá cấp thấp hơn hoặc cho học viên kiểm tra đầu vào lại |
| Lớp đã có lịch vào thứ và ca này; trùng phòng; trùng giáo viên | Chọn thứ, ca hoặc phòng khác; xem thẻ **Lịch tuần toàn chi nhánh** để tìm phòng trống |
| Sức chứa phòng nhỏ hơn sĩ số tối đa của lớp. | Chọn phòng lớn hơn |
| Lớp đã sinh buổi học, không thể sửa lịch cố định. | Lớp đã điểm danh – giữ nguyên lịch hiện tại |
| Chưa tới ngày học, không thể điểm danh. | Chỉ điểm danh các buổi từ hôm nay trở về trước |
| Giáo viên chỉ được thao tác trên lớp mình phụ trách. | Đăng nhập bằng tài khoản của giáo viên phụ trách lớp |
| Điểm phải nằm trong khoảng 0 – 10. | Sửa lại điểm |
| Số tiền thu vượt quá số tiền còn nợ của đăng ký. | Giảm số tiền ở cột **Thu lần này (đ)** |
| Chỉ kế toán hoặc quản lý được lập phiếu thu. | Đăng nhập bằng tài khoản Kế toán |
| Đăng ký đã có phiếu thu, không thể huỷ (cần hoàn tiền trước). | Dùng chức năng **Chuyển lớp** hoặc xử lý hoàn tiền trước |
| Chỉ được chuyển sang lớp cùng khoá học. | Huỷ đăng ký rồi ghi danh khoá khác |
| Chi nhánh đã có nhân viên, lớp học hoặc học viên – không thể xoá. | Chuyển dữ liệu sang chi nhánh khác trước khi xoá |
| Mật khẩu mới phải từ 8 ký tự, có chữ hoa, chữ thường, chữ số và ký tự đặc biệt. | Đặt mật khẩu mạnh hơn |
| Tài khoản đã bị khoá. Liên hệ quản trị viên. | Đăng nhập sai quá 5 lần – nhờ Quản lý mở khoá ở **Hệ thống → Tài khoản** |

## 8.3 Câu hỏi thường gặp

**Tôi quên mật khẩu thì làm thế nào?**
Liên hệ Quản lý. Quản lý vào **Hệ thống → Tài khoản**, chọn tài khoản của bạn, nhập mật khẩu mới vào ô **Đặt lại mật khẩu** rồi nhấn **Lưu**. Sau khi đăng nhập, bạn nên đổi lại mật khẩu của riêng mình (mục 3.5).

**Vì sao tôi không thấy học viên hoặc lớp của chi nhánh khác?**
Mỗi tài khoản chỉ xem được dữ liệu trong phạm vi chi nhánh của mình. Chỉ Quản lý cấp trung tâm xem được toàn bộ.

**Vì sao một số ô hoặc nút bị mờ, không bấm được?**
Hệ thống khoá các điều khiển không được dùng trong tình huống hiện tại. Ví dụ: ô mã không sửa được khi đang sửa bản ghi có sẵn; nút **Lưu điểm** chỉ bật khi đã sửa ít nhất một điểm; nút **Lập phiếu thu** chỉ bật khi đã chọn ít nhất một khoản và không có dòng nào nhập sai; nút **◀ Trang trước** mờ ở trang đầu tiên.

**Có xoá được một phiếu thu đã lập không?**
Không. Phiếu thu là chứng từ tài chính nên không được sửa hay xoá; mọi thao tác trên phiếu thu đều được ghi vào nhật ký.

**Dữ liệu tôi nhập có bị mất khi tắt ứng dụng không?**
Không. Dữ liệu được lưu ngay vào CSDL khi nhấn **Lưu**. Dữ liệu chỉ mất khi chạy lại script dựng CSDL (mục 2.4) – vì vậy hãy sao lưu định kỳ (mục 7.1).

**Làm sao đưa hệ thống về dữ liệu mẫu ban đầu để thực hành lại?**
Chạy lại lệnh `database/run_all.sh` (hoặc `run_all.ps1` trên Windows). Toàn bộ dữ liệu sẽ được thay bằng dữ liệu mẫu.
