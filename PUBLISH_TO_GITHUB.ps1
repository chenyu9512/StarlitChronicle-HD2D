# Starlit Chronicle -- initial GitHub publication
# 1. Create an EMPTY private repository named StarlitChronicle-HD2D on chenyu9512.
# 2. Extract this ZIP, open PowerShell in its extracted folder, then run:
#    powershell -ExecutionPolicy Bypass -File .\PUBLISH_TO_GITHUB.ps1
$ErrorActionPreference = 'Stop'
Set-Location -LiteralPath $PSScriptRoot
if (-not (Get-Command git -ErrorAction SilentlyContinue)) {
    throw 'Git is not installed. Install Git for Windows: https://git-scm.com/downloads/win'
}
$repo = 'https://github.com/chenyu9512/StarlitChronicle-HD2D.git'
if (-not (Test-Path -LiteralPath '.git')) {
    git init -b main
    if ($LASTEXITCODE -ne 0) { throw 'git init failed' }
}
git add --all
if ($LASTEXITCODE -ne 0) { throw 'git add failed' }
git diff --cached --quiet
$hasChanges = $LASTEXITCODE -eq 1
if ($hasChanges) {
    git commit -m 'Initial playable prototype v0.1.1'
    if ($LASTEXITCODE -ne 0) { throw 'git commit failed: check git user.name and user.email' }
}
git branch -M main
if ($LASTEXITCODE -ne 0) { throw 'git branch failed' }
$existing = @(git remote)
if ($existing -contains 'origin') {
    git remote set-url origin $repo
} else {
    git remote add origin $repo
}
if ($LASTEXITCODE -ne 0) { throw 'git remote configuration failed' }
git push --set-upstream origin main
if ($LASTEXITCODE -ne 0) { throw 'git push failed. Confirm the repo exists and your GitHub authentication is configured.' }
Write-Host 'Pushed to https://github.com/chenyu9512/StarlitChronicle-HD2D' -ForegroundColor Green
