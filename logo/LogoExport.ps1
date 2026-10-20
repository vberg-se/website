# -------------------------------
# CONFIGURATION
# -------------------------------
$inkscape = "C:\Program Files\Inkscape\bin\inkscape.com"
$file     = (Resolve-Path "Logo.svg").Path

# -------------------------------
# HELPER: export one layer, forcing it visible
# -------------------------------
function Export-Layer {
    param(
        [string]   $Id,
        [string]   $Out,
        [string[]] $ExtraArgs = @()
    )

    $doc = New-Object System.Xml.XmlDocument
    $doc.PreserveWhitespace = $true
    $doc.Load($file)

    $node = $doc.SelectSingleNode("//*[@id='$Id']")
    if (-not $node) { throw "Element with id '$Id' not found in $file" }

    # Un-hide the target and all of its ancestors (parent layers)
    while ($node -and $node.NodeType -eq [System.Xml.XmlNodeType]::Element) {
        $style = $node.GetAttribute("style")
        if ($style) {
            $style = ($style -replace 'display\s*:\s*none\s*;?', '').Trim().TrimEnd(';')
            if ($style) { $node.SetAttribute("style", $style) }
            else        { $node.RemoveAttribute("style") }
        }
        if ($node.GetAttribute("display") -eq "none") { $node.RemoveAttribute("display") }
        $node = $node.ParentNode
    }

    # Save temp copy next to the original so relative links (images, etc.) still resolve
    $tmp = Join-Path (Split-Path $file) "_export_tmp.svg"
    $doc.Save($tmp)

    try {
        & $inkscape $tmp --export-id=$Id --export-id-only --export-filename=$Out @ExtraArgs
    }
    finally {
        Remove-Item $tmp -ErrorAction SilentlyContinue
    }
}

# -------------------------------
# EXPORT PAGE 1 LAYERS
# -------------------------------
$lightLayer = "g13"
$darkLayer  = "g16"

Export-Layer $lightLayer "LogoLight.svg" @("--export-type=svg")
Export-Layer $darkLayer  "LogoDark.svg"  @("--export-type=svg")

# -------------------------------
# EXPORT PAGE 2 ICONS
# -------------------------------
$lightLayer = "g19"
$darkLayer  = "g21"

foreach ($size in 32, 512) {
    $sz = @("--export-type=png", "--export-page=2", "--export-area-page")
    Export-Layer $lightLayer "IconLight-$size.png" $sz
    Export-Layer $darkLayer  "IconDark-$size.png"  $sz
}