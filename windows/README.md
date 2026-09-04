# 图匠 Windows

Windows 版使用 Python 3.11+、Tkinter 和 Pillow，支持 x86（32 位）与 ARM64 Windows。功能包括批量更名、扩展名转换、按长边/宽高/百分比缩放、保持比例、实时尺寸预览和 JSON 快捷方案。

## 本地运行

```powershell
py -3.11 -m venv .venv
.\.venv\Scripts\Activate.ps1
pip install -r requirements.txt
python image_workshop.py
```

## 打包

在目标架构的 Windows 机器上执行：

```powershell
pip install -r requirements-build.txt
.\build.ps1
```

请分别在 x86 Windows 和 ARM64 Windows 环境执行打包，生成对应架构的 `dist\图匠-Windows.exe`。Pillow 会根据当前 Python 架构安装匹配的图像库。
