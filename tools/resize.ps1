#Requires -Version 5.1
# Windows counterpart of tools/resize.sh (no sips/jpegtran needed).
# Usage: powershell -File tools/resize.ps1 IMG_123.JPG yoshimuraya-001.jpg
param(
  [Parameter(Mandatory = $true, Position = 0)][string]$OrgPath,
  [Parameter(Mandatory = $true, Position = 1)][string]$NewPath
)

$ErrorActionPreference = 'Stop'
Add-Type -AssemblyName System.Drawing

$MaxSide = 800
$Quality = 85
$OrientationTagId = 0x0112

$orgFull = (Resolve-Path -LiteralPath $OrgPath).Path
$newFull = $ExecutionContext.SessionState.Path.GetUnresolvedProviderPathFromPSPath($NewPath)

Write-Host "Move: $OrgPath to $NewPath"
Move-Item -LiteralPath $orgFull -Destination $newFull -Force

Write-Host "Resize and Optimize: $NewPath"
$source = [System.Drawing.Image]::FromFile($newFull)
try {
  # Bake the EXIF orientation into the pixels, since the metadata is dropped below.
  if ($source.PropertyIdList -contains $OrientationTagId) {
    $orientation = $source.GetPropertyItem($OrientationTagId).Value[0]
    $rotation = switch ($orientation) {
      2 { 'RotateNoneFlipX' }
      3 { 'Rotate180FlipNone' }
      4 { 'Rotate180FlipX' }
      5 { 'Rotate90FlipX' }
      6 { 'Rotate90FlipNone' }
      7 { 'Rotate270FlipX' }
      8 { 'Rotate270FlipNone' }
      default { $null }
    }
    if ($rotation) { $source.RotateFlip([System.Drawing.RotateFlipType]::$rotation) }
  }

  $scale = [Math]::Min(1.0, $MaxSide / [Math]::Max($source.Width, $source.Height))
  $width = [int][Math]::Round($source.Width * $scale)
  $height = [int][Math]::Round($source.Height * $scale)

  # A freshly drawn bitmap carries no EXIF or other metadata.
  $bitmap = New-Object System.Drawing.Bitmap $width, $height
  try {
    $graphics = [System.Drawing.Graphics]::FromImage($bitmap)
    $graphics.InterpolationMode = [System.Drawing.Drawing2D.InterpolationMode]::HighQualityBicubic
    $graphics.DrawImage($source, 0, 0, $width, $height)
    $graphics.Dispose()

    $jpegEncoder = [System.Drawing.Imaging.ImageCodecInfo]::GetImageEncoders() |
      Where-Object { $_.MimeType -eq 'image/jpeg' }
    $encoderParams = New-Object System.Drawing.Imaging.EncoderParameters 1
    $encoderParams.Param[0] = New-Object System.Drawing.Imaging.EncoderParameter ([System.Drawing.Imaging.Encoder]::Quality), ([long]$Quality)

    $tempPath = "$newFull.tmp"
    $bitmap.Save($tempPath, $jpegEncoder, $encoderParams)
  }
  finally {
    $bitmap.Dispose()
  }
}
finally {
  $source.Dispose()
}

Move-Item -LiteralPath $tempPath -Destination $newFull -Force

Write-Host "  pixelHeight: $height"
Write-Host "  pixelWidth: $width"
$sizeKb = [Math]::Round((Get-Item -LiteralPath $newFull).Length / 1KB, 1)
Write-Host "  size: $sizeKb KB (must be under 300 KB)"
