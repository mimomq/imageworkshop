"""图匠 Windows 版：本地批量更名与图片尺寸处理。"""
from __future__ import annotations

import json
import re
import shutil
from datetime import datetime
from pathlib import Path
import tkinter as tk
from tkinter import filedialog, messagebox, ttk

from PIL import Image, ImageOps

SUPPORTED = {".jpg", ".jpeg", ".png", ".webp", ".heic", ".heif", ".tif", ".tiff", ".bmp", ".gif"}
PRESETS = Path.home() / ".tukuang-presets.json"


class App(tk.Tk):
    def __init__(self):
        super().__init__()
        self.title("图匠")
        self.geometry("1080x700")
        self.files: list[Path] = []
        self.mode = tk.StringVar(value="long")
        self.long_edge = tk.IntVar(value=1920)
        self.width = tk.IntVar(value=1920)
        self.height = tk.IntVar(value=1080)
        self.percent = tk.IntVar(value=50)
        self.keep_ratio = tk.BooleanVar(value=True)
        self.format = tk.StringVar(value="原格式")
        self.template = tk.StringVar(value="{name}")
        self.output = tk.StringVar(value="")
        self._build()

    def _build(self):
        toolbar = ttk.Frame(self, padding=10); toolbar.pack(fill="x")
        ttk.Button(toolbar, text="添加图片", command=self.add_files).pack(side="left")
        ttk.Button(toolbar, text="添加文件夹", command=self.add_folder).pack(side="left", padx=6)
        ttk.Button(toolbar, text="清空", command=lambda: (self.files.clear(), self.refresh())).pack(side="left")
        ttk.Button(toolbar, text="保存快捷方案", command=self.save_preset).pack(side="right")
        ttk.Button(toolbar, text="读取快捷方案", command=self.load_preset).pack(side="right", padx=6)

        main = ttk.PanedWindow(self, orient="horizontal"); main.pack(fill="both", expand=True, padx=10, pady=(0, 10))
        left = ttk.Frame(main); right = ttk.Frame(main, padding=12); main.add(left, weight=3); main.add(right, weight=2)
        self.listbox = tk.Listbox(left, selectmode="extended", activestyle="dotbox")
        self.listbox.pack(side="left", fill="both", expand=True)
        scroll = ttk.Scrollbar(left, command=self.listbox.yview); scroll.pack(side="right", fill="y"); self.listbox.config(yscrollcommand=scroll.set)

        ttk.Label(right, text="调整尺寸", font=("Segoe UI", 16, "bold")).pack(anchor="w", pady=(0, 12))
        mode = ttk.Combobox(right, textvariable=self.mode, state="readonly", values=["long", "wh", "percent"]); mode.pack(fill="x"); mode.bind("<<ComboboxSelected>>", lambda _: self.update_preview())
        self._row(right, "长边像素", self.long_edge)
        self._row(right, "宽度", self.width)
        self._row(right, "高度", self.height)
        self._row(right, "百分比", self.percent)
        ttk.Checkbutton(right, text="锁定宽高比例", variable=self.keep_ratio, command=self.update_preview).pack(anchor="w", pady=6)
        ttk.Label(right, text="输出格式").pack(anchor="w", pady=(10, 2))
        ttk.Combobox(right, textvariable=self.format, state="readonly", values=["原格式", "JPEG", "PNG", "WEBP", "TIFF", "BMP"]).pack(fill="x")
        ttk.Label(right, text="命名模板").pack(anchor="w", pady=(10, 2)); ttk.Entry(right, textvariable=self.template).pack(fill="x")
        ttk.Button(right, text="选择输出文件夹", command=self.choose_output).pack(fill="x", pady=(12, 4))
        ttk.Label(right, textvariable=self.output, foreground="#666", wraplength=300).pack(anchor="w")
        self.preview = ttk.Label(right, text="添加图片后显示目标尺寸", foreground="#2563eb", wraplength=300); self.preview.pack(anchor="w", pady=14)
        ttk.Button(right, text="开始处理", command=self.process).pack(fill="x", pady=6)

    def _row(self, parent, label, variable):
        row = ttk.Frame(parent); row.pack(fill="x", pady=3); ttk.Label(row, text=label, width=12).pack(side="left"); ttk.Spinbox(row, from_=1, to=50000, textvariable=variable, command=self.update_preview).pack(side="right", fill="x", expand=True)

    def add_files(self):
        paths = filedialog.askopenfilenames(filetypes=[("图片", " ".join("*" + x for x in SUPPORTED))]); self.files += [Path(p) for p in paths if Path(p).suffix.lower() in SUPPORTED]; self.refresh()
    def add_folder(self):
        folder = filedialog.askdirectory()
        if folder: self.files += [p for p in Path(folder).rglob("*") if p.is_file() and p.suffix.lower() in SUPPORTED]; self.refresh()
    def refresh(self):
        self.listbox.delete(0, "end"); [self.listbox.insert("end", str(p)) for p in self.files]; self.update_preview()
    def choose_output(self):
        value = filedialog.askdirectory(); self.output.set(value or "")
    def update_preview(self):
        if not self.files: return self.preview.config(text="添加图片后显示目标尺寸")
        try:
            with Image.open(self.files[0]) as im: w, h = im.size
            if self.mode.get() == "long": scale = self.long_edge.get() / max(w, h); tw, th = round(w * scale), round(h * scale)
            elif self.mode.get() == "percent": tw, th = round(w * self.percent.get() / 100), round(h * self.percent.get() / 100)
            elif self.keep_ratio: scale = min(self.width.get() / w, self.height.get() / h); tw, th = round(w * scale), round(h * scale)
            else: tw, th = self.width.get(), self.height.get()
            self.preview.config(text=f"原图：{w} × {h}\n处理后：{tw} × {th}")
        except Exception as e: self.preview.config(text=f"预览失败：{e}")
    def save_preset(self):
        PRESETS.write_text(json.dumps({"mode": self.mode.get(), "long": self.long_edge.get(), "width": self.width.get(), "height": self.height.get(), "percent": self.percent.get(), "ratio": self.keep_ratio.get(), "format": self.format.get(), "template": self.template.get()}, ensure_ascii=False), encoding="utf-8"); messagebox.showinfo("图匠", "快捷方案已保存")
    def load_preset(self):
        if not PRESETS.exists(): return messagebox.showinfo("图匠", "还没有保存的快捷方案")
        d = json.loads(PRESETS.read_text(encoding="utf-8")); self.mode.set(d.get("mode", "long")); self.long_edge.set(d.get("long", 1920)); self.width.set(d.get("width", 1920)); self.height.set(d.get("height", 1080)); self.percent.set(d.get("percent", 50)); self.keep_ratio.set(d.get("ratio", True)); self.format.set(d.get("format", "原格式")); self.template.set(d.get("template", "{name}")); self.update_preview()
    def process(self):
        if not self.files: return messagebox.showwarning("图匠", "请先添加图片")
        out = Path(self.output.get()) if self.output.get() else self.files[0].parent / "图匠输出"; out.mkdir(parents=True, exist_ok=True)
        ok = 0
        for src in self.files:
            try:
                with Image.open(src) as im:
                    im = ImageOps.exif_transpose(im).convert("RGBA")
                    w, h = im.size
                    if self.mode.get() == "long": scale = self.long_edge.get() / max(w, h); size = (round(w * scale), round(h * scale))
                    elif self.mode.get() == "percent": size = (round(w * self.percent.get() / 100), round(h * self.percent.get() / 100))
                    elif self.keep_ratio: scale = min(self.width.get() / w, self.height.get() / h); size = (round(w * scale), round(h * scale))
                    else: size = (self.width.get(), self.height.get())
                    result = im.resize(size, Image.Resampling.LANCZOS)
                    ext = src.suffix.lower() if self.format.get() == "原格式" else {"JPEG": ".jpg", "PNG": ".png", "WEBP": ".webp", "TIFF": ".tiff", "BMP": ".bmp"}[self.format.get()]
                    name = self.template.get().replace("{name}", src.stem).replace("{ext}", src.suffix[1:]).replace("{width}", str(size[0])).replace("{height}", str(size[1])).replace("{date}", datetime.now().strftime("%Y%m%d"))
                    dest = out / (name + ext); save = result.convert("RGB") if ext in {".jpg", ".jpeg", ".bmp"} else result
                    if ext in {".jpg", ".jpeg"}: save.save(dest, quality=90)
                    else: save.save(dest)
                    ok += 1
            except Exception as e: print(f"{src}: {e}")
        messagebox.showinfo("图匠", f"已处理 {ok}/{len(self.files)} 张\n输出到：{out}")


if __name__ == "__main__": App().mainloop()
