# -------------------------------
# CONFIGURATION
# -------------------------------

# Path to your SVG
$file = "Logo.svg"

# Output folder (optional)
#$out = "export"
#New-Item -ItemType Directory -Force -Path $out | Out-Null

# -------------------------------
# EXPORT PAGE 1 LAYERS
# -------------------------------

# Page 1 layer IDs (replace with your actual IDs)
$lightLayer  = "g13"
$darkLayer = "g16"

& "C:\Program Files\Inkscape\bin\inkscape.com" $file --export-type=svg --export-page=1 --export-id=$lightLayer  --export-id-only --export-filename="LogoLight.svg"
& "C:\Program Files\Inkscape\bin\inkscape.com" $file --export-type=svg --export-page=1 --export-id=$darkLayer --export-id-only --export-filename="LogoDark.svg"

# -------------------------------
# EXPORT PAGE 2 ICONS
# -------------------------------

# Page 2 icon layer IDs
$lightLayer  = "g19"
$darkLayer = "g21"

& "C:\Program Files\Inkscape\bin\inkscape.com" $file --export-type=png --export-page=2 --export-id=$lightLayer  --export-id-only --export-width=32 --export-height=32 --export-filename="IconLight-32.png"
& "C:\Program Files\Inkscape\bin\inkscape.com" $file --export-type=png --export-page=2 --export-id=$darkLayer --export-id-only --export-width=32 --export-height=32 --export-filename="IconDark-32.png"
& "C:\Program Files\Inkscape\bin\inkscape.com" $file --export-type=png --export-page=2 --export-id=$lightLayer  --export-id-only --export-width=500 --export-height=500 --export-filename="IconLight-500.png"
& "C:\Program Files\Inkscape\bin\inkscape.com" $file --export-type=png --export-page=2 --export-id=$darkLayer --export-id-only --export-width=500 --export-height=500 --export-filename="IconDark-500.png"
