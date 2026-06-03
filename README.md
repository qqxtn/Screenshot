# Screenshot

[中文](#中文) | [English](#english)

## 中文

`Screenshot` 是一个轻量级 Windows 区域截图工具，交互方式参考 QQ 截图。

### 功能

- 按 `Ctrl + Alt + A` 开始区域截图
- 拖拽鼠标选择矩形截图区域
- 支持长截图
- 支持 OCR 文字识别
- 支持矩形、椭圆、箭头和文字标注
- 选择标注工具后，可在按钮上方弹出的竖向颜色面板中选择颜色
- 文字标注支持中文输入，`Ctrl + Enter` 提交，`Esc` 取消
- 支持复制到剪贴板
- 支持保存为 PNG 图片
- 长图预览会自动缩放，确保底部按钮可见
- 独立版 `Run-Screenshot.exe` 运行后不会弹出命令行窗口
- 程序常驻系统托盘，托盘图标和截图热键由同一进程管理，可通过托盘菜单退出
- 独立版内嵌脚本和应用图标，运行时不依赖 `Screenshot.ps1`

### 使用方法

推荐直接双击运行：

```powershell
Run-Screenshot.exe
```

运行后程序会出现在右下角系统托盘。按 `Ctrl + Alt + A` 开始截图。右键托盘图标选择 `Exit` 可退出程序并释放快捷键。

也可以通过脚本运行：

```powershell
powershell -NoProfile -ExecutionPolicy Bypass -File .\Screenshot.ps1
```

### 预览按钮

截图完成后会显示预览窗口，底部按钮从左到右包括：

- 矩形标注
- 椭圆标注
- 箭头标注
- 文字标注
- OCR 文字识别
- 长截图
- 保存到本地
- 取消
- 完成并复制到剪贴板

点击矩形、椭圆、箭头或文字按钮后，按钮上方会弹出竖向颜色面板，可选择红、黄、绿、蓝、紫、黑。

### 文字标注

点击文字按钮后，在截图上点击要放置文字的位置，会出现输入框。输入完成后：

- 按 `Ctrl + Enter` 提交文字
- 点击其他位置也会提交文字
- 按 `Esc` 取消当前文字输入

### 长截图

在截图预览中点击长截图按钮后，程序会自动滚动并拼接长图。长截图完成后会显示最终预览，可继续标注、保存或复制。

长截图适合网页、文档、PDF、聊天记录等可滚动内容。不同软件的滚动行为可能不同，效果会受到目标窗口滚动实现、页面渲染速度和内容重复度影响。

### 快捷键冲突

Windows 全局快捷键同一时间只能被一个程序占用。如果 QQ 或其他程序已经占用了 `Ctrl + Alt + A`，本工具可能无法注册快捷键。

可以关闭占用快捷键的程序，或改用其他快捷键：

```powershell
powershell -NoProfile -ExecutionPolicy Bypass -File .\Screenshot.ps1 -Modifiers Control,Alt -Key S
```

例如使用 `PrintScreen`：

```powershell
powershell -NoProfile -ExecutionPolicy Bypass -File .\Screenshot.ps1 -Modifiers @() -Key PrintScreen
```

### OCR 说明

OCR 使用 Windows 自带 OCR 引擎。识别效果会受到图片清晰度、字体大小、系统语言包和 Windows OCR 支持情况影响。

### 文件说明

- `Run-Screenshot.exe`: 独立版程序，内嵌脚本和图标，运行时不依赖 `Screenshot.ps1`
- `Screenshot.ps1`: 主脚本，便于开发和调试
- `Run-Screenshot.cmd`: 脚本启动器
- `README.md`: 项目说明

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
- Rectangle, ellipse, arrow, and text annotations
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

- Rectangle annotation
- Ellipse annotation
- Arrow annotation
- Text annotation
- OCR text extraction
- Long screenshot
- Save locally
- Cancel
- Done and copy to clipboard

Click the rectangle, ellipse, arrow, or text button to open a vertical color palette above the tool button. Available colors: red, yellow, green, blue, purple, and black.

### Text Annotation

Click the text button, then click the screenshot where the text should be placed. After typing:

- Press `Ctrl + Enter` to commit text
- Click elsewhere to commit text
- Press `Esc` to cancel the current text input

### Long Screenshots

Click the long screenshot button in the preview window to automatically scroll and stitch a long image. When finished, the final preview opens, where you can annotate, save, or copy the image.

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