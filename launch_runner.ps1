param([string]$ProjectDir)

$ProjectDir = (Resolve-Path -LiteralPath $ProjectDir).Path
$workspaceRoot = Split-Path -Parent $ProjectDir
$godotItem = Get-ChildItem -Path $workspaceRoot -Filter 'Godot_v4.7.1-stable_win64.exe' -File -Recurse -ErrorAction SilentlyContinue | Select-Object -First 1
$godot = if ($godotItem) { $godotItem.FullName } else { $null }

if (!(Test-Path -LiteralPath $godot)) {
    Write-Host "Could not find Godot: $godot"
    exit 1
}
if (!(Test-Path -LiteralPath (Join-Path $ProjectDir 'project.godot'))) {
    Write-Host "Could not find project.godot: $ProjectDir"
    exit 1
}

$quotedProjectDir = '"' + $ProjectDir + '"'
Start-Process -FilePath $godot -ArgumentList @('--path', $quotedProjectDir) -WorkingDirectory $ProjectDir
