param(
  [Parameter(Mandatory = $true)][string]$InputPath,
  [Parameter(Mandatory = $true)][string]$OutputPath
)

$ErrorActionPreference = 'Stop'
$extension = [IO.Path]::GetExtension($InputPath).ToLowerInvariant()
$application = $null
$document = $null

try {
  switch ($extension) {
    '.docx' {
      $application = New-Object -ComObject Word.Application
      $application.Visible = $false
      $document = $application.Documents.Open($InputPath, $false, $true)
      $document.ExportAsFixedFormat($OutputPath, 17)
    }
    '.xlsx' {
      $application = New-Object -ComObject Excel.Application
      $application.Visible = $false
      $application.DisplayAlerts = $false
      $document = $application.Workbooks.Open($InputPath, 0, $true)
      $document.ExportAsFixedFormat(0, $OutputPath)
    }
    '.pptx' {
      $application = New-Object -ComObject PowerPoint.Application
      $document = $application.Presentations.Open($InputPath, $true, $false, $false)
      $document.SaveAs($OutputPath, 32)
    }
    default { throw "不支持的 Office 扩展名：$extension" }
  }
}
finally {
  try {
    if ($document) { $document.Close() }
  }
  finally {
    if ($application) { $application.Quit() }
  }
  if ($document) { [void][Runtime.InteropServices.Marshal]::ReleaseComObject($document) }
  if ($application) { [void][Runtime.InteropServices.Marshal]::ReleaseComObject($application) }
  [GC]::Collect()
  [GC]::WaitForPendingFinalizers()
}
