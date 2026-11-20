#!/bin/bash
set -e
cd "/Users/d/WorkBuddy/2026-11-19-17-14-07/WheelVolume"
git init
git config user.name "googlemr"
git config user.email "72286699+googlemr@users.noreply.github.com"
git add -A
git commit -m "release: v1.0.0"
git remote remove origin 2>/dev/null || true
git remote add origin https://github.com/googlemr/WheelVolume.git
git branch -M main
git push -u origin main
git tag -a v1.0.0 -m "WheelVolume v1.0.0"
git push origin v1.0.0
echo "DONE: repository pushed and tag v1.0.0 created."
