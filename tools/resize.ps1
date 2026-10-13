# Windows counterpart of resize.sh. Usage: powershell -File tools/resize.ps1 IMG_123.JPG yoshimuraya-001.jpg
param([Parameter(Mandatory)][string]$OrgPath, [Parameter(Mandatory)][string]$NewPath)
$ErrorActionPreference = 'Stop'
Add-Type -AssemblyName System.Drawing

$org = (Resolve-Path -LiteralPath $OrgPath).Path
$new = $ExecutionContext.SessionState.Path.GetUnresolvedProviderPathFromPSPath($NewPath)

$img = [System.Drawing.Image]::FromFile($org)
# Bake in the EXIF orientation, since the metadata is dropped below.
if ($img.PropertyIdList -contains 0x0112) {
  $flip = @{ 3 = 2; 6 = 1; 8 = 3 }[[int]$img.GetPropertyItem(0x0112).Value[0]]
  if ($flip) { $img.RotateFlip($flip) }
}
$scale = [Math]::Min(1.0,800 / [Math]::Max($img.Width, $img.Height))
$w = [int][Math]::Round($img.Width * $scale)
$h = [int][Math]::Round($img.Height * $scale)

# A newly drawn bitmap carries no metadata.
$bmp = New-Object System.Drawing.Bitmap $w, $h
$g = [System.Drawing.Graphics]::FromImage($bmp)
$g.InterpolationMode = 'HighQualityBicubic'
$g.DrawImage($img, 0, 0, $w, $h)
$encoder = [System.Drawing.Imaging.ImageCodecInfo]::GetImageEncoders() | Where-Object MimeType -eq 'image/jpeg'
$params = New-Object System.Drawing.Imaging.EncoderParameters 1
$params.Param[0] = New-Object System.Drawing.Imaging.EncoderParameter ([System.Drawing.Imaging.Encoder]::Quality), 85L
$bmp.Save($new, $encoder, $params)
$g.Dispose(); $bmp.Dispose(); $img.Dispose()

Remove-Item -LiteralPath $org
"pixelHeight: $h`npixelWidth: $w`nsize: $([Math]::Round((Get-Item -LiteralPath $new).Length / 1KB, 1)) KB (must be under 300 KB)"
