param(
    [string]$SourceImage
)

$ErrorActionPreference = 'Stop'
$taskProject = Split-Path -Parent $PSScriptRoot
if (-not $SourceImage) {
    $SourceImage = Join-Path $taskProject 'assets/branding/wild-guard-source.jpeg'
}
$taskSourcePath = (Resolve-Path -LiteralPath $SourceImage).Path

Add-Type -AssemblyName System.Drawing
$taskSource = [System.Drawing.Image]::FromFile($taskSourcePath)
try {
    $taskOutputs = @(
        @{ Path = 'assets/images/logo.png'; Size = 512 },
        @{ Path = 'android/app/src/main/res/mipmap-mdpi/ic_launcher.png'; Size = 48 },
        @{ Path = 'android/app/src/main/res/mipmap-hdpi/ic_launcher.png'; Size = 72 },
        @{ Path = 'android/app/src/main/res/mipmap-xhdpi/ic_launcher.png'; Size = 96 },
        @{ Path = 'android/app/src/main/res/mipmap-xxhdpi/ic_launcher.png'; Size = 144 },
        @{ Path = 'android/app/src/main/res/mipmap-xxxhdpi/ic_launcher.png'; Size = 192 }
    )
    foreach ($taskOutput in $taskOutputs) {
        $taskSize = [int]$taskOutput.Size
        $taskBitmap = [System.Drawing.Bitmap]::new($taskSize, $taskSize)
        $taskGraphics = [System.Drawing.Graphics]::FromImage($taskBitmap)
        try {
            $taskGraphics.Clear([System.Drawing.Color]::White)
            $taskGraphics.InterpolationMode = [System.Drawing.Drawing2D.InterpolationMode]::HighQualityBicubic
            $taskGraphics.PixelOffsetMode = [System.Drawing.Drawing2D.PixelOffsetMode]::HighQuality
            $taskGraphics.CompositingQuality = [System.Drawing.Drawing2D.CompositingQuality]::HighQuality
            $taskScale = [Math]::Min($taskSize / $taskSource.Width, $taskSize / $taskSource.Height)
            $taskWidth = [single]($taskSource.Width * $taskScale)
            $taskHeight = [single]($taskSource.Height * $taskScale)
            $taskBounds = [System.Drawing.RectangleF]::new(
                [single](($taskSize - $taskWidth) / 2),
                [single](($taskSize - $taskHeight) / 2),
                $taskWidth, $taskHeight)
            $taskGraphics.DrawImage($taskSource, $taskBounds)
            $taskOutputPath = Join-Path $taskProject $taskOutput.Path
            [void][System.IO.Directory]::CreateDirectory((Split-Path -Parent $taskOutputPath))
            $taskBitmap.Save($taskOutputPath, [System.Drawing.Imaging.ImageFormat]::Png)
            Write-Output "Created $($taskOutput.Path) ($taskSize x $taskSize)"
        } finally {
            $taskGraphics.Dispose()
            $taskBitmap.Dispose()
        }
    }
} finally {
    $taskSource.Dispose()
}
