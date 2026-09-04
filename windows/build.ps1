$ErrorActionPreference = 'Stop'
python -m PyInstaller --noconfirm --clean --windowed --name '图匠-Windows' image_workshop.py
Write-Host "已生成 dist\图匠-Windows.exe"
