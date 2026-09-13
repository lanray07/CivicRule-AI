Add-Type -AssemblyName System.Drawing
$destination = Join-Path $PSScriptRoot '../CivicRule/Assets.xcassets/AppIcon.appiconset'
New-Item -ItemType Directory -Force -Path $destination | Out-Null
$bitmap = New-Object System.Drawing.Bitmap 1024,1024
$graphics = [System.Drawing.Graphics]::FromImage($bitmap)
$graphics.SmoothingMode = [System.Drawing.Drawing2D.SmoothingMode]::AntiAlias
$graphics.Clear([System.Drawing.Color]::FromArgb(26,61,51))
$brush = New-Object System.Drawing.SolidBrush ([System.Drawing.Color]::FromArgb(214,235,156))
$roof = [System.Drawing.Point[]]@([System.Drawing.Point]::new(200,370),[System.Drawing.Point]::new(512,200),[System.Drawing.Point]::new(824,370))
$graphics.FillPolygon($brush,$roof)
$graphics.FillRectangle($brush,218,406,588,48)
foreach ($x in @(274,474,674)) { $graphics.FillRectangle($brush,$x,488,76,250) }
$graphics.FillRectangle($brush,218,768,588,56)
$bitmap.Save((Join-Path $destination 'app-icon.png'),[System.Drawing.Imaging.ImageFormat]::Png)
$brush.Dispose()
$graphics.Dispose()
$bitmap.Dispose()
