<#
  Xuất PDF bằng Microsoft Word trên Windows từ file .docx do build_report.py sinh ra (bản tương đương export_pdf.sh
  của macOS): Word cập nhật Mục lục, Danh mục hình ảnh, Danh mục bảng và số trang rồi lưu PDF cạnh file docx.

    python scripts\build_report.py
    .\scripts\export_pdf.ps1                                   # cả báo cáo và hướng dẫn sử dụng
    .\scripts\export_pdf.ps1 report\BaoCao_IE103_Nhom1.docx    # một tài liệu

  File docx được thay bằng bản Word đã cập nhật trường (mục lục có số trang, bỏ cờ updateFields) nên mở bằng Word
  không bị hỏi "cập nhật trường?". Cần Microsoft Word cài trên máy (dùng qua COM) và Python có python-docx.
#>
param([string[]]$Files = @())
$ErrorActionPreference = "Stop"
$root = Split-Path -Parent $PSScriptRoot
$build = Join-Path $root "report\.build"
New-Item -ItemType Directory -Force -Path $build | Out-Null
if ($Files.Count -eq 0) {
  $Files = @((Join-Path $root "report\BaoCao_IE103_Nhom1.docx"), (Join-Path $root "report\HuongDanSuDung_ECMS.docx"))
}
$py = if ($env:PYTHON) { $env:PYTHON } else { "python" }

# Bản làm việc bỏ cờ updateFields và w:dirty: có cờ này Word hiện hộp thoại "cập nhật trường?" làm treo tự động hoá
$strip = @'
import sys
from docx import Document
from docx.oxml.ns import qn
d = Document(sys.argv[1])
el = d.settings.element.find(qn("w:updateFields"))
if el is not None:
    d.settings.element.remove(el)
for fld in d.element.body.iter(qn("w:fldChar")):
    fld.attrib.pop(qn("w:dirty"), None)
d.save(sys.argv[2])
'@
$stripFile = Join-Path $build "strip_fields.py"
Set-Content -Path $stripFile -Value $strip -Encoding UTF8

$word = New-Object -ComObject Word.Application
$word.Visible = $false
$word.DisplayAlerts = 0          # wdAlertsNone
try {
  foreach ($f in $Files) {
    $docx = (Resolve-Path $f).Path
    $name = Split-Path -Leaf $docx
    $work = Join-Path $build $name
    $pdf = [IO.Path]::ChangeExtension($docx, ".pdf")
    & $py $stripFile $docx $work
    if ($LASTEXITCODE -ne 0) { throw "Không chuẩn bị được $name" }

    $d = $word.Documents.Open($work, $false, $false)
    # Mục lục, Danh mục hình ảnh và Danh mục bảng đều là "table of contents" trong Word
    foreach ($toc in $d.TablesOfContents) { $toc.Update() }
    $d.Fields.Update() | Out-Null          # PAGE, SECTIONPAGES ở thân bài
    foreach ($toc in $d.TablesOfContents) { $toc.UpdatePageNumbers() }
    $d.Save()
    $d.ExportAsFixedFormat($pdf, 17)       # 17 = wdExportFormatPDF
    $d.Close($false)
    Copy-Item $work $docx -Force
    Write-Host "OK $pdf (docx đã được thay bằng bản Word cập nhật mục lục, số trang)"
  }
} finally {
  $word.Quit()
  [void][Runtime.InteropServices.Marshal]::ReleaseComObject($word)
}
