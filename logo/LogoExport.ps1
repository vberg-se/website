<#
.SYNOPSIS
    Exports layers/elements from an SVG using Inkscape, driven by a JSON config file.

.DESCRIPTION
    Each entry in 'exports' selects what to export in exactly one of two ways:
      - "elementId": the SVG element's id attribute (e.g. "g13"),
                     shown in Inkscape under Object > Object Properties > ID.
      - "layer":     the layer's name as shown in Inkscape's Layers panel
                     (the inkscape:label attribute, e.g. "Logo Light").

.PARAMETER ConfigPath
    Path to the config file (default: export-config.json next to this script). Relative paths inside the config file are resolved relative to the config file's folder.

.EXAMPLE
    .\LogoExport.ps1 .\export-config.json
#>
[CmdletBinding()]
param(
    [Parameter(Position = 0)]
    [string] $ConfigPath = (Join-Path $PSScriptRoot "export-config.json")
)

$ErrorActionPreference = 'Stop'

$InkscapeNs = "http://www.inkscape.org/namespaces/inkscape"

# -------------------------------
# LOAD CONFIGURATION
# -------------------------------
$configFile = (Resolve-Path $ConfigPath).Path
$configDir  = Split-Path $configFile
$config     = Get-Content $configFile -Raw -Encoding UTF8 | ConvertFrom-Json

function Resolve-ConfigPath([string] $Path) {
    if ([System.IO.Path]::IsPathRooted($Path)) { return $Path }
    return [System.IO.Path]::GetFullPath((Join-Path $configDir $Path))
}

if (-not $config.inkscape) { throw "Config file is missing 'inkscape'." }
if (-not $config.source)   { throw "Config file is missing 'source'." }
if (-not $config.exports)  { throw "Config file is missing 'exports'." }

$inkscape = Resolve-ConfigPath $config.inkscape
$file     = Resolve-ConfigPath $config.source
$outDir   = if ($config.outputDir) { Resolve-ConfigPath $config.outputDir } else { $configDir }

if (-not (Test-Path $inkscape)) { throw "Inkscape not found: $inkscape" }
if (-not (Test-Path $file))     { throw "Source file not found: $file" }
if (-not (Test-Path $outDir))   { New-Item -ItemType Directory -Path $outDir | Out-Null }

# -------------------------------
# HELPERS
# -------------------------------

# Builds an XPath string literal that is safe even if the value contains quotes
function ConvertTo-XPathLiteral([string] $Value) {
    if ($Value -notmatch "'") { return "'$Value'" }
    if ($Value -notmatch '"') { return "`"$Value`"" }
    $parts = $Value -split "'" | ForEach-Object { "'$_'" }
    return "concat(" + ($parts -join ", `"'`", ") + ")"
}

# Finds the target element by element id or by Inkscape layer name
function Find-TargetNode {
    param(
        [System.Xml.XmlDocument] $Doc,
        [string] $ElementId,
        [string] $Layer
    )

    $ns = New-Object System.Xml.XmlNamespaceManager($Doc.NameTable)
    $ns.AddNamespace("inkscape", $InkscapeNs)

    if ($ElementId) {
        $nodes = $Doc.SelectNodes("//*[@id=$(ConvertTo-XPathLiteral $ElementId)]", $ns)
        $what  = "element id '$ElementId'"
    }
    else {
        $nodes = $Doc.SelectNodes("//*[@inkscape:groupmode='layer' and @inkscape:label=$(ConvertTo-XPathLiteral $Layer)]", $ns)
        $what  = "layer '$Layer'"
    }

    if ($nodes.Count -eq 0) { throw "No element found for $what in $file" }
    if ($nodes.Count -gt 1) { throw "$($nodes.Count) elements match $what in $file; use 'elementId' instead." }

    $node = $nodes[0]
    if (-not $node.GetAttribute("id")) { throw "Matched $what has no id attribute; Inkscape needs one to export it." }
    return $node
}

# Exports one element, forcing it and its parent layers visible
function Export-Element {
    param(
        [string]   $ElementId,
        [string]   $Layer,
        [string]   $Out,
        [string[]] $ExtraArgs = @()
    )

    $doc = New-Object System.Xml.XmlDocument
    $doc.PreserveWhitespace = $true
    $doc.Load($file)

    $node = Find-TargetNode -Doc $doc -ElementId $ElementId -Layer $Layer
    $id   = $node.GetAttribute("id")

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
        & $inkscape $tmp --export-id=$id --export-id-only --export-filename=$Out @ExtraArgs
        if ($LASTEXITCODE -ne 0) { throw "Inkscape failed (exit code $LASTEXITCODE) for '$id' -> $Out" }
    }
    finally {
        Remove-Item $tmp -ErrorAction SilentlyContinue
    }
}

# -------------------------------
# RUN ALL EXPORTS
# -------------------------------
foreach ($exp in $config.exports) {
    $entry = $exp | ConvertTo-Json -Compress

    if (-not $exp.out) { throw "Export entry is missing 'out': $entry" }
    if ([bool]$exp.elementId -eq [bool]$exp.layer) {
        throw "Export entry must have exactly one of 'elementId' or 'layer': $entry"
    }
    $target = if ($exp.elementId) { "element id '$($exp.elementId)'" } else { "layer '$($exp.layer)'" }

    # Collect arguments: preset first, then the export's own 'args'
    $baseArgs = @()
    if ($exp.preset) {
        $preset = $config.presets.PSObject.Properties[$exp.preset]
        if (-not $preset) { throw "Unknown preset '$($exp.preset)' for $target." }
        $baseArgs += @($preset.Value)
    }
    if ($exp.args) { $baseArgs += @($exp.args) }

    # The size is always set by the script via 'sizes'
    if ($baseArgs -match '^--export-(width|height)|\{size\}') {
        throw "Set the size with 'sizes' instead of --export-width/--export-height/{size} in args for $target."
    }

    # Without 'sizes' the export runs once; with 'sizes' it runs once per height,
    # and '{size}' in 'out' becomes e.g. 'h512'
    # (assigned directly, since an if-expression would unroll @($null) to $null and skip the loop)
    $sizes = @($null)
    if ($exp.sizes) { $sizes = @($exp.sizes) }

    foreach ($size in $sizes) {
        $out        = $exp.out
        $exportArgs = $baseArgs

        if ($null -ne $size) {
            $out        = $out -replace '\{size\}', "h$size"
            $exportArgs = $baseArgs + "--export-height=$size"
        }
        if ($out -match '\{size\}') {
            throw "'{size}' is used for $target but 'sizes' is missing."
        }

        $outPath = Join-Path $outDir $out
        $label   = if ($exp.description) { "$($exp.description) ($target)" } else { $target }
        Write-Host "Exporting $label -> $out"
        Export-Element -ElementId $exp.elementId -Layer $exp.layer -Out $outPath -ExtraArgs $exportArgs
    }
}

Write-Host "Done."