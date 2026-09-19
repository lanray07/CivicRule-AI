# Production-size export only; artwork is generated with Imagegen and retained unchanged.
Add-Type -AssemblyName System.Drawing
$assetDirectory = [System.IO.Path]::GetFullPath((Join-Path $PSScriptRoot '../store-assets/subscriptions'))
foreach ($plan in @('monthly','annual')) {
    $sourceImage = [System.Drawing.Image]::FromFile((Join-Path $assetDirectory "$plan-original.png"))
    $outputImage = New-Object System.Drawing.Bitmap 1024,1024,([System.Drawing.Imaging.PixelFormat]::Format24bppRgb)
    $canvas = [System.Drawing.Graphics]::FromImage($outputImage)
    $canvas.InterpolationMode = [System.Drawing.Drawing2D.InterpolationMode]::HighQualityBicubic
    $canvas.DrawImage($sourceImage,0,0,1024,1024)
    $outputImage.Save((Join-Path $assetDirectory "$plan-1024.png"),[System.Drawing.Imaging.ImageFormat]::Png)
    $canvas.Dispose()
    $outputImage.Dispose()
    $sourceImage.Dispose()
}
