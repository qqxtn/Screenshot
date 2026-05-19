# Screenshot

[中文](#中文) | [English](#english)

## 中文

`Screenshot` 是一个轻量级 Windows 区域截图工具，交互方式参考 QQ 截图。

### 快捷键冲突

Windows 全局快捷键同一时间只能被一个程序占用。如果 QQ 已经打开，并且 QQ 截图占用了 `Ctrl + Alt + A`，本工具启动时可能会提示快捷键注册失败。

解决方式：

- 关闭 QQ 后再启动本工具
- 或者给本工具换一个快捷键

例如改成 `Ctrl + Alt + S`：

```powershell
powershell -NoProfile -ExecutionPolicy Bypass -File .\Screenshot.ps1 -Modifiers Control,Alt -Key S
```

### 功能

- 按 `Ctrl + Alt + A` 开始截图
- 拖拽鼠标选择矩形截图区域
- 框选完成后，背景显示为浅灰透明遮罩，可以看到原桌面内容
- 截图预览会显示在遮罩上，图片四角完整保留
- 底部提供图标按钮：提取文字、保存到本地、取消、完成
- 点击 `完成`：复制截图到剪贴板并退出
- 点击 `取消`：退出截图界面，不复制
- 点击 `保存到本地`：弹出 Windows 保存对话框，可选择文件夹和文件名
- 点击 `提取文字`：关闭截图预览，执行 OCR，并打开可复制文字窗口
- 再次按 `Ctrl + Alt + A` 可以重新截图
- 支持自定义快捷键

### 使用方法

双击运行：

```powershell
Run-Screenshot.cmd
```

或在 PowerShell 中运行：

```powershell
powershell -NoProfile -ExecutionPolicy Bypass -File .\Screenshot.ps1
```

启动后保持窗口打开，按 `Ctrl + Alt + A` 开始截图。

### 修改快捷键

例如改成 `Ctrl + Shift + F8`：

```powershell
powershell -NoProfile -ExecutionPolicy Bypass -File .\Screenshot.ps1 -Modifiers Control,Shift -Key F8
```

例如使用 `PrintScreen`：

```powershell
powershell -NoProfile -ExecutionPolicy Bypass -File .\Screenshot.ps1 -Modifiers @() -Key PrintScreen
```

### OCR 说明

文字识别使用 Windows 自带 OCR。识别效果会受到截图清晰度、字体大小、系统语言包和 Windows OCR 支持情况影响。脚本会在识别前对截图做放大增强，以提升小字识别效果。

### 文件说明

- `Screenshot.ps1`：主程序
- `Run-Screenshot.cmd`：双击启动器
- `README.md`：项目说明

## English

`Screenshot` is a lightweight Windows region screenshot tool inspired by the QQ screenshot workflow.

### Hotkey Conflicts

A Windows global hotkey can only be owned by one program at a time. If QQ is already running and its screenshot feature is using `Ctrl + Alt + A`, this tool may fail to start because it cannot register the same hotkey.

To fix it:

- Close QQ before starting this tool
- Or use a different hotkey for this tool

Example: use `Ctrl + Alt + S`:

```powershell
powershell -NoProfile -ExecutionPolicy Bypass -File .\Screenshot.ps1 -Modifiers Control,Alt -Key S
```

### Features

- Press `Ctrl + Alt + A` to start capturing
- Drag to select a rectangular capture area
- After selection, the background becomes a light translucent gray overlay while the desktop remains visible
- The captured image stays on top of the overlay with its corners fully preserved
- Icon buttons below the preview: extract text, save locally, cancel, and done
- Click `Done` to copy the screenshot to the clipboard and exit
- Click `Cancel` to exit without copying
- Click `Save locally` to open the Windows save dialog and choose a folder and file name
- Click `Extract text` to close the screenshot preview, run OCR, and open a copyable text window
- Press `Ctrl + Alt + A` again to start a new capture
- Customizable hotkey

### Usage

Double-click:

```powershell
Run-Screenshot.cmd
```

Or run from PowerShell:

```powershell
powershell -NoProfile -ExecutionPolicy Bypass -File .\Screenshot.ps1
```

Keep the window open, then press `Ctrl + Alt + A` to start capturing.

### Change The Hotkey

Example: use `Ctrl + Shift + F8`:

```powershell
powershell -NoProfile -ExecutionPolicy Bypass -File .\Screenshot.ps1 -Modifiers Control,Shift -Key F8
```

Example: use `PrintScreen`:

```powershell
powershell -NoProfile -ExecutionPolicy Bypass -File .\Screenshot.ps1 -Modifiers @() -Key PrintScreen
```

### OCR Notes

OCR uses the built-in Windows OCR engine. Accuracy depends on image clarity, font size, installed language support, and Windows OCR availability. The script upscales the captured image before recognition to improve results on small text.

### Files

- `Screenshot.ps1`: main tool
- `Run-Screenshot.cmd`: double-click launcher
- `README.md`: project documentation

## Requirements

- Windows
- Windows PowerShell
- .NET Windows Forms and System.Drawing, included with standard Windows PowerShell environments
