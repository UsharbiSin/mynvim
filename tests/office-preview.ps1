$ErrorActionPreference = 'Stop'
$testRoot = Join-Path ([IO.Path]::GetTempPath()) ("nvim-office-preview-" + [Guid]::NewGuid().ToString('N'))
New-Item -ItemType Directory -Path $testRoot | Out-Null

try {
  $docx = Join-Path $testRoot '中文 文档.docx'
  $pdf = Join-Path $testRoot '中文 文档.pdf'
  $page = Join-Path $testRoot 'page'
  & python (Join-Path $PSScriptRoot 'office_fixture.py') $docx
  if ($LASTEXITCODE -ne 0) { throw 'DOCX 测试文件生成失败' }
  $helper = Join-Path $PSScriptRoot '..\scripts\office_ooxml.py'
  $docxInspect = (& python $helper inspect-docx $docx) | ConvertFrom-Json
  $docxInput = Join-Path $testRoot 'docx-save.json'
  $docxPayload = @{
    fingerprint = $docxInspect.fingerprint
    changes = @{ p0 = 'Office edited preview test' }
  } | ConvertTo-Json -Depth 4 -Compress
  [IO.File]::WriteAllText($docxInput, $docxPayload, [Text.UTF8Encoding]::new($false))
  & python $helper save-docx $docx --input $docxInput | Out-Null
  if ($LASTEXITCODE -ne 0) { throw 'DOCX minimal edit failed' }

  & powershell -NoProfile -NonInteractive -ExecutionPolicy Bypass -File `
    (Join-Path $PSScriptRoot '..\scripts\office-export.ps1') -InputPath $docx -OutputPath $pdf
  if ($LASTEXITCODE -ne 0 -or -not (Test-Path -LiteralPath $pdf)) {
    throw 'Microsoft Word 转 PDF 测试失败'
  }
  & pdftoppm -png -f 1 -singlefile -r 72 $pdf $page
  if ($LASTEXITCODE -ne 0 -or -not (Test-Path -LiteralPath ($page + '.png'))) {
    throw 'pdftoppm 页面渲染测试失败'
  }

  $xlsx = Join-Path $testRoot '中文 表格.xlsx'
  $xlsxPdf = Join-Path $testRoot '中文 表格.pdf'
  & python (Join-Path $PSScriptRoot 'office_fixture.py') $xlsx
  if ($LASTEXITCODE -ne 0) { throw 'XLSX 测试文件生成失败' }
  $xlsxInspect = (& python $helper inspect-xlsx $xlsx) | ConvertFrom-Json
  $xlsxInput = Join-Path $testRoot 'xlsx-save.json'
  $xlsxPayload = @{
    fingerprint = $xlsxInspect.fingerprint
    changes = @{ '0' = @{ A1 = @{ old = 'old'; new = 'new'; kind = 'string' } } }
  } | ConvertTo-Json -Depth 6 -Compress
  [IO.File]::WriteAllText($xlsxInput, $xlsxPayload, [Text.UTF8Encoding]::new($false))
  & python $helper save-xlsx $xlsx --input $xlsxInput | Out-Null
  if ($LASTEXITCODE -ne 0) { throw 'XLSX minimal edit failed' }
  & powershell -NoProfile -NonInteractive -ExecutionPolicy Bypass -File `
    (Join-Path $PSScriptRoot '..\scripts\office-export.ps1') -InputPath $xlsx -OutputPath $xlsxPdf
  if ($LASTEXITCODE -ne 0 -or -not (Test-Path -LiteralPath $xlsxPdf)) {
    throw 'Microsoft Excel 转 PDF 测试失败'
  }

  $pptx = Join-Path $testRoot '中文 演示.pptx'
  $pptxPdf = Join-Path $testRoot '中文 演示.pdf'
  $powerPoint = New-Object -ComObject PowerPoint.Application
  try {
    $presentation = $powerPoint.Presentations.Add()
    [void]$presentation.Slides.Add(1, 12)
    $presentation.SaveAs($pptx, 24)
    $presentation.Close()
  }
  finally {
    $powerPoint.Quit()
    [void][Runtime.InteropServices.Marshal]::ReleaseComObject($powerPoint)
  }
  & powershell -NoProfile -NonInteractive -ExecutionPolicy Bypass -File `
    (Join-Path $PSScriptRoot '..\scripts\office-export.ps1') -InputPath $pptx -OutputPath $pptxPdf
  if ($LASTEXITCODE -ne 0 -or -not (Test-Path -LiteralPath $pptxPdf)) {
    throw 'Microsoft PowerPoint 转 PDF 测试失败'
  }
  Write-Output 'PASS: Word/Excel/PowerPoint COM export and PDF page rendering'
}
finally {
  $resolvedRoot = [IO.Path]::GetFullPath($testRoot)
  $resolvedTemp = [IO.Path]::GetFullPath([IO.Path]::GetTempPath())
  if ($resolvedRoot.StartsWith($resolvedTemp, [StringComparison]::OrdinalIgnoreCase)) {
    Remove-Item -LiteralPath $resolvedRoot -Recurse -Force
  }
}
