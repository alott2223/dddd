# Script to push updates from cloned repo to your repo
cd "$PSScriptRoot"

# Add all changes
git add .

# Commit changes
$timestamp = Get-Date -Format "yyyy-MM-dd HH:mm:ss"
git commit -m "Update: $timestamp" 2>&1 | Out-Null

# Push to upstream (your repo)
git push upstream main

Write-Host "Updates pushed successfully to https://github.com/alott2223/dddd"

