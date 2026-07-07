# Screenshot

[中文](#中文) | [English](#english)

## 中文

`Screenshot` 是一个轻量级 Windows 区域截图工具，交互方式参考 QQ 截图。

### 功能

- 按 `Ctrl + Alt + A` 开始区域截图
- 拖拽鼠标选择矩形截图区域
- 支持长截图
- 支持 OCR 文字识别
- 框选完成进入预览后，未编辑前可拖动截图框调整截图范围
- 长截图会使用移动后的截图框位置继续向下截图
- 支持撤销上一步标注
- 支持矩形、椭圆、箭头、文字和马赛克标注
- 选择标注工具后，可在按钮上方弹出的竖向颜色面板中选择颜色
- 文字标注支持中文输入，按 `Ctrl + Enter` 提交，按 `Esc` 取消
- 支持复制截图到剪贴板
- 支持保存为 PNG 图片
- 长图预览会自动缩放，确保底部按钮可见
- 独立版 `Run-Screenshot.exe` 运行时不再弹出命令行窗口
- 程序常驻系统托盘，托盘图标和截图热键由同一进程管理
- 独立版内嵌脚本和应用图标，运行时不依赖 `Screenshot.ps1`

### 使用方法

推荐直接运行：

```powershell
Run-Screenshot.exe
```

程序启动后会显示在系统托盘。按 `Ctrl + Alt + A` 开始截图，右键托盘图标选择 `Exit` 可以退出程序并释放快捷键。

也可以直接运行脚本：

```powershell
powershell -NoProfile -ExecutionPolicy Bypass -File .\Screenshot.ps1
```

### 预览按钮

选择截图区域后，预览窗口底部包含以下按钮：

- 撤销上一步
- 矩形标注
- 椭圆标注
- 箭头标注
- 文字标注
- 矩形马赛克
- OCR 文字识别
- 长截图
- 保存到本地
- 取消
- 完成并复制到剪贴板

点击矩形、椭圆、箭头或文字按钮后，按钮上方会弹出竖向颜色面板。可选颜色包括红色、黄色、绿色、蓝色、紫色和黑色。

### 移动截图框

框选完成进入预览后，可以在未编辑前拖动截图框调整截图范围。开始标注后，截图框位置会锁定。

拖动截图框时，程序会使用第一次框选时保存的完整桌面底图来更新框内内容，因此浏览器 PDF、地图等动态页面在移动时也能保持原始画面。

### 标注与撤销

- 矩形和椭圆：按住鼠标拖拽绘制。
- 箭头：从起点拖拽到终点绘制。
- 文字：点击文字按钮后，在图片上点击需要输入的位置。
- 马赛克：点击马赛克按钮后，按住鼠标拖拽框选区域；竖向距离决定宽度，横向距离决定长度，松开后生成矩形马赛克。
- 撤销：点击撤销按钮可回退上一步标注，最多保留 20 步。

文字输入时，按 `Ctrl + Enter` 提交文字，点击其他位置也会提交文字，按 `Esc` 会取消当前输入。

### 长截图

点击预览窗口中的长截图按钮后，程序会自动滚动并拼接成长图。完成后会打开最终预览，可继续标注、保存或复制。

如果在预览中移动过截图框，长截图会从移动后的截图范围开始继续向下截图，而不是使用最初框选的位置。

长截图适合网页、文档、PDF、聊天记录等可滚动内容。实际效果会受到目标程序滚动方式、渲染速度和重复内容的影响。

### 快捷键冲突

Windows 全局快捷键同一时间只能被一个程序占用。如果 QQ 或其他程序已经占用了 `Ctrl + Alt + A`，本工具可能无法注册快捷键。

可以关闭冲突程序，或改用其他快捷键：

```powershell
powershell -NoProfile -ExecutionPolicy Bypass -File .\Screenshot.ps1 -Modifiers Control,Alt -Key S
```

使用 `PrintScreen` 的示例：

```powershell
powershell -NoProfile -ExecutionPolicy Bypass -File .\Screenshot.ps1 -Modifiers @() -Key PrintScreen
```

### OCR 说明

OCR 使用 Windows 内置 OCR 引擎。识别效果取决于图片清晰度、字体大小、系统语言包和 Windows OCR 可用性。

### 文件说明

- `Run-Screenshot.exe`：独立版程序，内嵌脚本和图标，运行时不依赖 `Screenshot.ps1`
- `Screenshot.ps1`：主脚本，适合开发和调试
- `Run-Screenshot.cmd`：脚本启动器
- `README.md`：项目说明文档

### 系统要求

- Windows
- Windows PowerShell
- .NET Windows Forms 和 System.Drawing

## English

`Screenshot` is a lightweight Windows region screenshot tool inspired by the QQ screenshot workflow.

### Features

- Press `Ctrl + Alt + A` to start region capture
- Drag to select a rectangular capture area
- Long screenshot support
- OCR text extraction
- Move the screenshot frame before editing to adjust the capture area
- Long screenshots use the moved screenshot frame position
- Undo the previous annotation step
- Rectangle, ellipse, arrow, text, and mosaic annotations
- Popup vertical color picker after selecting an annotation tool
- Text annotations support IME input; press `Ctrl + Enter` to commit and `Esc` to cancel
- Copy screenshots to the clipboard
- Save screenshots as PNG images
- Large previews are scaled so action buttons remain visible
- Standalone `Run-Screenshot.exe` runs without opening a command prompt
- The app stays in the system tray; the tray icon and screenshot hotkey are managed by the same process
- Standalone executable embeds the script and application icon; it does not require `Screenshot.ps1` at runtime

### Usage

Recommended:

```powershell
Run-Screenshot.exe
```

After launch, the app appears in the system tray. Press `Ctrl + Alt + A` to capture. Right-click the tray icon and choose `Exit` to quit and release the hotkey.

You can also run the script directly:

```powershell
powershell -NoProfile -ExecutionPolicy Bypass -File .\Screenshot.ps1
```

### Preview Buttons

After selecting an area, the preview toolbar includes:

- Undo previous step
- Rectangle annotation
- Ellipse annotation
- Arrow annotation
- Text annotation
- Rectangular mosaic
- OCR text extraction
- Long screenshot
- Save locally
- Cancel
- Done and copy to clipboard

Click the rectangle, ellipse, arrow, or text button to open a vertical color palette above the tool button. Available colors: red, yellow, green, blue, purple, and black.

### Moving The Screenshot Frame

After selecting an area, drag the screenshot frame before editing to adjust the capture area. Once an annotation is made, the frame is locked.

While moving the frame, the app updates the frame content from the full desktop snapshot captured at the start, so browser PDFs, maps, and other dynamic pages keep the original screen content while being adjusted.

### Annotation And Undo

- Rectangle and ellipse: drag to draw.
- Arrow: drag from the start point to the end point.
- Text: click the text button, then click the screenshot where the text should be placed.
- Mosaic: click the mosaic button and drag to select an area. The vertical distance sets its width and the horizontal distance sets its length; release to apply the rectangular mosaic.
- Undo: click the undo button to revert the previous annotation step. Up to 20 steps are kept.

For text input, press `Ctrl + Enter` to commit text, click elsewhere to commit text, or press `Esc` to cancel the current input.

### Long Screenshots

Click the long screenshot button in the preview window to automatically scroll and stitch a long image. When finished, the final preview opens, where you can annotate, save, or copy the image.

If the screenshot frame was moved in preview, long screenshot capture starts from the moved capture area instead of the original selected position.

Long screenshots are intended for scrollable pages, documents, PDFs, and chat histories. Results may vary depending on the target application's scrolling behavior, rendering speed, and repeated content.

### Hotkey Conflicts

A Windows global hotkey can only be owned by one program at a time. If QQ or another app is already using `Ctrl + Alt + A`, this tool may fail to register the hotkey.

Close the conflicting app or use another hotkey:

```powershell
powershell -NoProfile -ExecutionPolicy Bypass -File .\Screenshot.ps1 -Modifiers Control,Alt -Key S
```

Example using `PrintScreen`:

```powershell
powershell -NoProfile -ExecutionPolicy Bypass -File .\Screenshot.ps1 -Modifiers @() -Key PrintScreen
```

### OCR Notes

OCR uses the built-in Windows OCR engine. Accuracy depends on image clarity, font size, installed language support, and Windows OCR availability.

### Files

- `Run-Screenshot.exe`: standalone app with embedded script and icon; does not require `Screenshot.ps1` at runtime
- `Screenshot.ps1`: main script for development and debugging
- `Run-Screenshot.cmd`: script launcher
- `README.md`: project documentation

### Requirements

- Windows
- Windows PowerShell
- .NET Windows Forms and System.Drawing
