param([string]$ProjectDir)

$ProjectDir = (Resolve-Path -LiteralPath $ProjectDir).Path
$name = [string]::Concat([char]26085, [char]24120)
$godot = Join-Path (Join-Path 'D:\Documents' $name) 'Godot\Godot_v4.7.1-stable_win64\Godot_v4.7.1-stable_win64.exe'

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
