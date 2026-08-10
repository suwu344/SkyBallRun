$ErrorActionPreference = 'Stop'

$projectDir = Split-Path -Parent $MyInvocation.MyCommand.Path
Set-Location -LiteralPath $projectDir


$null = & gh auth status *> $null
if ($LASTEXITCODE -ne 0) {
    Write-Host 'Paste your new GitHub token below. It will not be sent to Codex.'
    $token = Read-Host 'GitHub token'
    if ([string]::IsNullOrWhiteSpace($token)) {
        throw 'No token was entered.'
    }

    $tokenFile = Join-Path $env:TEMP ('gh-token-' + [guid]::NewGuid().ToString('N') + '.txt')
    try {
        [System.IO.File]::WriteAllText($tokenFile, $token, [System.Text.UTF8Encoding]::new($false))
        $auth = Start-Process -FilePath 'gh.exe' -ArgumentList @('auth', 'login', '--with-token') -RedirectStandardInput $tokenFile -Wait -PassThru -NoNewWindow
        if ($auth.ExitCode -ne 0) {
            throw 'GitHub CLI login failed. Check that the token is valid and has Contents: Read and write for SkyBallRun.'
        }
    }
    finally {
        Remove-Item -LiteralPath $tokenFile -Force -ErrorAction SilentlyContinue
    }
}
else {
    Write-Host 'GitHub CLI is already authenticated; continuing.'
}

# Find Git even when it is installed but not present in PowerShell's PATH.
$gitCommand = Get-Command git.exe -ErrorAction SilentlyContinue
if ($gitCommand) {
    $gitExe = $gitCommand.Source
}
else {
    $gitCandidates = @(
        'C:\Program Files\Git\cmd\git.exe',
        'C:\Program Files\Git\bin\git.exe',
        (Join-Path $env:USERPROFILE '.cache\codex-runtimes\codex-primary-runtime\dependencies\native\git\cmd\git.exe')
    )
    $gitExe = $gitCandidates | Where-Object { Test-Path -LiteralPath $_ } | Select-Object -First 1
}
if (!$gitExe) {
    throw 'Git was not found. Install Git for Windows, then run this script again.'
}
$env:Path = (Split-Path -Parent $gitExe) + ';' + $env:Path

gh auth setup-git

if (!(Test-Path -LiteralPath (Join-Path $projectDir '.git'))) {
    git init
}
git branch -M main

$login = (& gh api user --jq .login).Trim()
git config user.name $login
git config user.email ($login + '@users.noreply.github.com')

$remoteUrl = 'https://github.com/suwu344/SkyBallRun.git'
$remoteNames = @(git remote)
if ($remoteNames -contains 'origin') {
    git remote set-url origin $remoteUrl
}
else {
    git remote add origin $remoteUrl
}

git add -A
if (git diff --cached --quiet) {
    Write-Host 'No local changes to commit.'
}
else {
    git commit -m 'Restore free-fall behavior and upload game'
}

git push -u origin main
Write-Host ''
Write-Host 'Upload complete: https://github.com/suwu344/SkyBallRun'
