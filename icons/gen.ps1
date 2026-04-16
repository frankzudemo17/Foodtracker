Add-Type -AssemblyName System.Drawing

function New-Icon([int]$size, [string]$path) {
  $bmp = New-Object System.Drawing.Bitmap $size, $size
  $g = [System.Drawing.Graphics]::FromImage($bmp)
  $g.SmoothingMode = [System.Drawing.Drawing2D.SmoothingMode]::AntiAlias
  $g.InterpolationMode = [System.Drawing.Drawing2D.InterpolationMode]::HighQualityBicubic
  $g.CompositingQuality = [System.Drawing.Drawing2D.CompositingQuality]::HighQuality
  $g.PixelOffsetMode = [System.Drawing.Drawing2D.PixelOffsetMode]::HighQuality

  $s = $size / 512.0

  $sageBase  = [System.Drawing.Color]::FromArgb(232, 237, 226)
  $sageLight = [System.Drawing.Color]::FromArgb(220, 227, 213)
  $accent    = [System.Drawing.Color]::FromArgb(163, 69, 9)
  $accentDark= [System.Drawing.Color]::FromArgb(138, 57, 10)
  $cream     = [System.Drawing.Color]::FromArgb(253, 251, 247)

  # Rounded rectangle clip
  $cornerRad = [float](112 * $s)
  $diam = $cornerRad * 2
  $path_ = New-Object System.Drawing.Drawing2D.GraphicsPath
  $path_.AddArc(0, 0, $diam, $diam, 180, 90)
  $path_.AddArc(($size - $diam), 0, $diam, $diam, 270, 90)
  $path_.AddArc(($size - $diam), ($size - $diam), $diam, $diam, 0, 90)
  $path_.AddArc(0, ($size - $diam), $diam, $diam, 90, 90)
  $path_.CloseFigure()
  $g.SetClip($path_)

  # Base sage fill
  $brushSage = New-Object System.Drawing.SolidBrush $sageBase
  $g.FillRectangle($brushSage, 0, 0, $size, $size)

  # Checkered pattern rotated 45°
  $brushLight = New-Object System.Drawing.SolidBrush $sageLight
  $center = $size / 2.0
  $g.TranslateTransform($center, $center)
  $g.RotateTransform(45)
  $g.TranslateTransform(-$center, -$center)

  $tile = [float](40 * $s)
  $margin = $size
  $xStart = [int](-$margin)
  $xEnd   = [int]($size + $margin)
  $yStart = $xStart
  $yEnd   = $xEnd
  for ($x = $xStart; $x -lt $xEnd; $x += $tile) {
    for ($y = $yStart; $y -lt $yEnd; $y += $tile) {
      $xi = [Math]::Floor($x / $tile)
      $yi = [Math]::Floor($y / $tile)
      if ([Math]::Abs(($xi + $yi) % 2) -eq 1) {
        $g.FillRectangle($brushLight, [float]$x, [float]$y, $tile, $tile)
      }
    }
  }
  $g.ResetTransform()
  $g.SetClip($path_)

  # Vignette: draw dark ellipse at corners with blending
  $vignetteColor = [System.Drawing.Color]::FromArgb(24, 28, 32, 20)
  $brushVign = New-Object System.Drawing.SolidBrush $vignetteColor
  # corner darkening via 4 large ellipses positioned outside
  $vignR = $size * 0.9
  # subtle border darkening at edges
  for ($i = 0; $i -lt 12; $i++) {
    $alpha = [int](3 + $i)
    $c = [System.Drawing.Color]::FromArgb($alpha, 28, 32, 20)
    $b = New-Object System.Drawing.SolidBrush $c
    $margin2 = $i * 4
    $g.DrawRectangle((New-Object System.Drawing.Pen $c, 1), $margin2, $margin2, $size - 2*$margin2, $size - 2*$margin2)
    $b.Dispose()
  }

  # ----- Fork (links, rotiert -10°) -----
  $brushAccent = New-Object System.Drawing.SolidBrush $accent
  $g.TranslateTransform([float](92 * $s + 24 * $s), [float](180 * $s + 90 * $s))
  $g.RotateTransform(-10)

  $tineW = [float](7 * $s)
  $tineH = [float](46 * $s)
  $tineYOffset = [float](-90 * $s)
  $tineXOffset = [float](-24 * $s)
  # Tines
  $g.FillRectangle($brushAccent, $tineXOffset + 0, $tineYOffset, $tineW, $tineH)
  $g.FillRectangle($brushAccent, $tineXOffset + (13 * $s), $tineYOffset, $tineW, $tineH)
  $g.FillRectangle($brushAccent, $tineXOffset + (26 * $s), $tineYOffset, $tineW, $tineH)
  $g.FillRectangle($brushAccent, $tineXOffset + (39 * $s), $tineYOffset, $tineW, $tineH)
  # Connection trapezoid
  $tp = @(
    (New-Object System.Drawing.PointF ($tineXOffset + (-2 * $s)), ($tineYOffset + (44 * $s))),
    (New-Object System.Drawing.PointF ($tineXOffset + (48 * $s)), ($tineYOffset + (44 * $s))),
    (New-Object System.Drawing.PointF ($tineXOffset + (42 * $s)), ($tineYOffset + (60 * $s))),
    (New-Object System.Drawing.PointF ($tineXOffset + (4  * $s)), ($tineYOffset + (60 * $s)))
  )
  $g.FillPolygon($brushAccent, $tp)
  # Handle
  $g.FillRectangle($brushAccent, $tineXOffset + (18 * $s), $tineYOffset + (60 * $s), (12 * $s), (128 * $s))
  # Handle end ellipse
  $g.FillEllipse($brushAccent, $tineXOffset + (15 * $s), $tineYOffset + (184 * $s), (18 * $s), (12 * $s))
  $g.ResetTransform()
  $g.SetClip($path_)

  # ----- Knife (rechts, rotiert +10°) -----
  $g.TranslateTransform([float](380 * $s + 18 * $s), [float](178 * $s + 95 * $s))
  $g.RotateTransform(10)
  # Blade path
  $bladePath = New-Object System.Drawing.Drawing2D.GraphicsPath
  $bladeX = -18 * $s
  $bladeY = -95 * $s
  $bladePath.AddLines(@(
    (New-Object System.Drawing.PointF ($bladeX + (6  * $s)), ($bladeY + (0  * $s))),
    (New-Object System.Drawing.PointF ($bladeX + (28 * $s)), ($bladeY + (0  * $s))),
    (New-Object System.Drawing.PointF ($bladeX + (32 * $s)), ($bladeY + (6  * $s))),
    (New-Object System.Drawing.PointF ($bladeX + (32 * $s)), ($bladeY + (92 * $s))),
    (New-Object System.Drawing.PointF ($bladeX + (28 * $s)), ($bladeY + (96 * $s))),
    (New-Object System.Drawing.PointF ($bladeX + (6  * $s)), ($bladeY + (96 * $s)))
  ))
  $bladePath.CloseFigure()
  $g.FillPath($brushAccent, $bladePath)
  # Handle
  $g.FillRectangle($brushAccent, $bladeX + (10 * $s), $bladeY + (96 * $s), (16 * $s), (96 * $s))
  $g.FillEllipse($brushAccent, $bladeX + (9 * $s), $bladeY + (188 * $s), (18 * $s), (12 * $s))
  $g.ResetTransform()
  $g.SetClip($path_)

  # ----- Plate Shadow -----
  $shadowColor = [System.Drawing.Color]::FromArgb(36, 28, 32, 20)
  $shadowBrush = New-Object System.Drawing.SolidBrush $shadowColor
  $g.FillEllipse($shadowBrush, [float](116 * $s), [float](396 * $s), [float](280 * $s), [float](28 * $s))

  # ----- Plate -----
  $plateX = [float](106 * $s)
  $plateY = [float](106 * $s)
  $plateD = [float](300 * $s)
  $brushCream = New-Object System.Drawing.SolidBrush $cream
  $g.FillEllipse($brushCream, $plateX, $plateY, $plateD, $plateD)
  $penRim = New-Object System.Drawing.Pen -ArgumentList @($accent, [float](10 * $s))
  $g.DrawEllipse($penRim, $plateX, $plateY, $plateD, $plateD)

  # Inner decor rings
  $ring1X = [float](148 * $s)
  $ring1Size = [float](216 * $s)
  $penRing1 = New-Object System.Drawing.Pen -ArgumentList @(([System.Drawing.Color]::FromArgb(102, 163, 69, 9)), [float](2 * $s))
  $g.DrawEllipse($penRing1, $ring1X, $ring1X, $ring1Size, $ring1Size)

  $ring2X = [float](164 * $s)
  $ring2Size = [float](184 * $s)
  $penRing2 = New-Object System.Drawing.Pen -ArgumentList @(([System.Drawing.Color]::FromArgb(64, 163, 69, 9)), [float](1 * $s))
  $g.DrawEllipse($penRing2, $ring2X, $ring2X, $ring2Size, $ring2Size)

  # Highlight
  $highlightColor = [System.Drawing.Color]::FromArgb(140, 255, 255, 255)
  $brushHighlight = New-Object System.Drawing.SolidBrush $highlightColor
  $g.FillEllipse($brushHighlight, [float](174 * $s), [float](178 * $s), [float](88 * $s), [float](20 * $s))

  $bmp.Save($path, [System.Drawing.Imaging.ImageFormat]::Png)

  $g.Dispose()
  $bmp.Dispose()
  $brushSage.Dispose()
  $brushLight.Dispose()
  $brushAccent.Dispose()
  $brushCream.Dispose()
  Write-Host "OK: $path ($size x $size)"
}

$outDir = $PSScriptRoot
if (-not $outDir) { $outDir = (Get-Location).Path }

New-Icon 120 "$outDir/icon-120.png"
New-Icon 152 "$outDir/icon-152.png"
New-Icon 167 "$outDir/icon-167.png"
New-Icon 180 "$outDir/apple-touch-icon.png"
New-Icon 192 "$outDir/icon-192.png"
New-Icon 512 "$outDir/icon-512.png"

Write-Host "Done."
