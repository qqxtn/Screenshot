param(
    [string]$OutputDir = (Join-Path $env:USERPROFILE "Pictures\Screenshot"),
    [string]$Key = "A",
    [string[]]$Modifiers = @("Control", "Alt")
)

$ErrorActionPreference = "Stop"

$signature = @"
using System;
using System.Drawing;
using System.Drawing.Imaging;
using System.Runtime.InteropServices;
using System.Windows.Forms;

public static class HotkeyNative {
    public const int WM_HOTKEY = 0x0312;

    [StructLayout(LayoutKind.Sequential)]
    public struct POINT {
        public int x;
        public int y;
    }

    [StructLayout(LayoutKind.Sequential)]
    public struct MSG {
        public IntPtr hwnd;
        public uint message;
        public UIntPtr wParam;
        public IntPtr lParam;
        public uint time;
        public POINT pt;
    }

    [DllImport("user32.dll", SetLastError = true)]
    public static extern bool RegisterHotKey(IntPtr hWnd, int id, uint fsModifiers, uint vk);

    [DllImport("user32.dll", SetLastError = true)]
    public static extern bool UnregisterHotKey(IntPtr hWnd, int id);

    [DllImport("user32.dll")]
    public static extern sbyte GetMessage(out MSG lpMsg, IntPtr hWnd, uint wMsgFilterMin, uint wMsgFilterMax);
}

public sealed class ScreenSelector : Form {
    private readonly Bitmap desktop;
    private readonly string outputDir;
    private readonly Rectangle virtualScreen;
    private Point startPoint;
    private Point currentPoint;
    private bool selecting;
    private Rectangle finalSelection;
    private Bitmap selectedImage;

    public string SavedPath { get; private set; }
    public string CapturePath { get; private set; }
    public Point PreviewLocation { get; private set; }

    public ScreenSelector(string outputDir) {
        this.outputDir = outputDir;
        this.virtualScreen = SystemInformation.VirtualScreen;
        this.desktop = new Bitmap(virtualScreen.Width, virtualScreen.Height);

        using (Graphics g = Graphics.FromImage(desktop)) {
            g.CopyFromScreen(virtualScreen.Left, virtualScreen.Top, 0, 0, virtualScreen.Size);
        }

        StartPosition = FormStartPosition.Manual;
        FormBorderStyle = FormBorderStyle.None;
        ShowInTaskbar = false;
        TopMost = true;
        DoubleBuffered = true;
        KeyPreview = true;
        Cursor = Cursors.Cross;
        Bounds = virtualScreen;
        BackColor = Color.Black;
    }

    protected override void Dispose(bool disposing) {
        if (disposing) {
            if (selectedImage != null) {
                selectedImage.Dispose();
            }
            desktop.Dispose();
        }
        base.Dispose(disposing);
    }

    protected override void OnShown(EventArgs e) {
        base.OnShown(e);
        Activate();
        Focus();
    }

    protected override void OnKeyDown(KeyEventArgs e) {
        if (e.KeyCode == Keys.Escape) {
            DialogResult = DialogResult.Cancel;
            Close();
        }
        else if (e.Control && e.Alt && e.KeyCode == Keys.A) {
            DialogResult = DialogResult.Abort;
            Close();
        }
        base.OnKeyDown(e);
    }

    protected override void OnMouseDown(MouseEventArgs e) {
        if (e.Button != MouseButtons.Left) {
            return;
        }

        selecting = true;
        startPoint = e.Location;
        currentPoint = e.Location;
        Invalidate();
    }

    protected override void OnMouseMove(MouseEventArgs e) {
        if (!selecting) {
            return;
        }

        currentPoint = e.Location;
        Invalidate();
    }

    protected override void OnMouseUp(MouseEventArgs e) {
        if (!selecting || e.Button != MouseButtons.Left) {
            return;
        }

        selecting = false;
        currentPoint = e.Location;
        Rectangle selection = GetSelection();
        if (selection.Width < 3 || selection.Height < 3) {
            Invalidate();
            return;
        }

        SetFinalSelection(selection);
        SaveCaptureTemp();
        SetPreviewLocation(selection);
        DialogResult = DialogResult.OK;
        Close();
    }

    protected override void OnPaint(PaintEventArgs e) {
        Graphics g = e.Graphics;
        g.DrawImageUnscaled(desktop, 0, 0);

        Rectangle selection = GetSelection();
        using (Brush dim = new SolidBrush(Color.FromArgb(115, Color.Black))) {
            if (selection.Width <= 0 || selection.Height <= 0) {
                g.FillRectangle(dim, ClientRectangle);
            } else {
                g.FillRectangle(dim, new Rectangle(0, 0, ClientSize.Width, selection.Top));
                g.FillRectangle(dim, new Rectangle(0, selection.Bottom, ClientSize.Width, ClientSize.Height - selection.Bottom));
                g.FillRectangle(dim, new Rectangle(0, selection.Top, selection.Left, selection.Height));
                g.FillRectangle(dim, new Rectangle(selection.Right, selection.Top, ClientSize.Width - selection.Right, selection.Height));
            }
        }

        if (selection.Width > 0 && selection.Height > 0) {
            using (Pen border = new Pen(Color.FromArgb(64, 156, 255), 2)) {
                g.DrawRectangle(border, selection);
            }

            string label = selection.Width + " x " + selection.Height;
            using (Font font = new Font("Segoe UI", 9)) {
                SizeF size = g.MeasureString(label, font);
                RectangleF labelRect = new RectangleF(selection.Left, Math.Max(0, selection.Top - size.Height - 8), size.Width + 12, size.Height + 6);
                using (Brush bg = new SolidBrush(Color.FromArgb(220, 20, 20, 20))) {
                    g.FillRectangle(bg, labelRect);
                }
                using (Brush fg = new SolidBrush(Color.White)) {
                    g.DrawString(label, font, fg, labelRect.Left + 6, labelRect.Top + 3);
                }
            }
        }
    }

    private Rectangle GetSelection() {
        int x = Math.Min(startPoint.X, currentPoint.X);
        int y = Math.Min(startPoint.Y, currentPoint.Y);
        int width = Math.Abs(startPoint.X - currentPoint.X);
        int height = Math.Abs(startPoint.Y - currentPoint.Y);
        return new Rectangle(x, y, width, height);
    }

    private void SetFinalSelection(Rectangle selection) {
        finalSelection = selection;

        if (selectedImage != null) {
            selectedImage.Dispose();
        }

        selectedImage = desktop.Clone(selection, desktop.PixelFormat);
        Cursor = Cursors.Default;
    }

    private void SaveCaptureTemp() {
        string dir = System.IO.Path.Combine(System.IO.Path.GetTempPath(), "Screenshot");
        if (!System.IO.Directory.Exists(dir)) {
            System.IO.Directory.CreateDirectory(dir);
        }
        string fileName = "ocr-" + DateTime.Now.ToString("yyyyMMdd-HHmmss") + ".png";
        CapturePath = System.IO.Path.Combine(dir, fileName);
        selectedImage.Save(CapturePath, ImageFormat.Png);
    }

    private void SetPreviewLocation(Rectangle selection) {
        int toolbarHeight = 46;
        int previewWidth = Math.Max(selection.Width, 266);
        int previewHeight = selection.Height + toolbarHeight;
        int left = selection.Left;
        if (left < 8) {
            left = 8;
        }
        if (left + previewWidth > ClientSize.Width - 8) {
            left = ClientSize.Width - previewWidth - 8;
        }

        int top = selection.Top;
        if (top + previewHeight > ClientSize.Height - 8) {
            top = ClientSize.Height - previewHeight - 8;
        }
        if (top < 8) {
            top = 8;
        }

        PreviewLocation = new Point(virtualScreen.Left + left, virtualScreen.Top + top);
    }
}

public sealed class CapturePreview : Form {
    private readonly string imagePath;
    private readonly string outputDir;
    private readonly Image previewImage;
    private readonly Bitmap backgroundImage;
    private readonly int borderSize = 1;
    private readonly int toolbarHeight = 54;
    private readonly Point previewLocation;

    public bool ExtractTextRequested { get; private set; }

    public string SavedPath { get; private set; }

    public CapturePreview(string imagePath, string outputDir, Point location) {
        this.imagePath = imagePath;
        this.outputDir = outputDir;
        this.previewLocation = location;
        using (Image loaded = Image.FromFile(imagePath)) {
            this.previewImage = (Image)loaded.Clone();
        }
        Rectangle screen = SystemInformation.VirtualScreen;
        this.backgroundImage = new Bitmap(screen.Width, screen.Height);
        using (Graphics g = Graphics.FromImage(backgroundImage)) {
            g.CopyFromScreen(screen.Left, screen.Top, 0, 0, screen.Size);
        }

        StartPosition = FormStartPosition.Manual;
        FormBorderStyle = FormBorderStyle.None;
        ShowInTaskbar = false;
        TopMost = true;
        KeyPreview = true;
        DoubleBuffered = true;
        BackColor = Color.FromArgb(240, 242, 245);
        Bounds = SystemInformation.VirtualScreen;
        int buttonWidth = 42;
        int buttonHeight = 34;
        int gap = 10;
        int totalWidth = buttonWidth * 4 + gap * 3;
        int imageAreaWidth = previewImage.Width;
        int imageAreaHeight = previewImage.Height;
        int windowWidth = Math.Max(imageAreaWidth, totalWidth + 24);
        int previewWidth = windowWidth + borderSize * 2;
        int previewHeight = imageAreaHeight + toolbarHeight + borderSize * 2;
        int contentLeft = Math.Max(8, Math.Min(location.X - Bounds.Left, Width - previewWidth - 8));
        int contentTop = Math.Max(8, Math.Min(location.Y - Bounds.Top, Height - previewHeight - 8));

        Panel container = new Panel();
        container.BackColor = Color.FromArgb(245, 248, 252);
        container.Bounds = new Rectangle(contentLeft, contentTop, previewWidth, previewHeight);
        container.Paint += delegate(object sender, PaintEventArgs e) {
            using (Pen border = new Pen(Color.FromArgb(96, 165, 250))) {
                e.Graphics.DrawRectangle(border, 0, 0, container.Width - 1, container.Height - 1);
            }
        };
        Controls.Add(container);

        Panel imageFrame = new Panel();
        imageFrame.BackColor = Color.White;
        imageFrame.Bounds = new Rectangle(borderSize + (windowWidth - imageAreaWidth) / 2, borderSize, imageAreaWidth, imageAreaHeight);
        container.Controls.Add(imageFrame);

        PictureBox picture = new PictureBox();
        picture.Image = previewImage;
        picture.SizeMode = PictureBoxSizeMode.Normal;
        picture.BackColor = Color.White;
        picture.Bounds = new Rectangle(0, 0, previewImage.Width, previewImage.Height);
        imageFrame.Controls.Add(picture);

        Panel bar = new Panel();
        bar.BackColor = Color.FromArgb(248, 250, 252);
        bar.Bounds = new Rectangle(borderSize, imageAreaHeight + borderSize, windowWidth, toolbarHeight);
        bar.Paint += delegate(object sender, PaintEventArgs e) {
            using (Pen pen = new Pen(Color.FromArgb(222, 230, 239))) {
                e.Graphics.DrawLine(pen, 0, 0, bar.Width, 0);
            }
        };
        container.Controls.Add(bar);

        int left = Math.Max(12, windowWidth - totalWidth - 12);

        AddButton(bar, "ocr", left, buttonWidth, buttonHeight, "Extract text", delegate {
            ExtractTextRequested = true;
            DialogResult = DialogResult.Retry;
            Close();
        });

        AddButton(bar, "save", left + buttonWidth + gap, buttonWidth, buttonHeight, "Save to local", delegate {
            SaveImage();
            if (!String.IsNullOrEmpty(SavedPath)) {
                DialogResult = DialogResult.Yes;
                Close();
            }
        });

        AddButton(bar, "cancel", left + (buttonWidth + gap) * 2, buttonWidth, buttonHeight, "Cancel", delegate {
            DialogResult = DialogResult.Cancel;
            Close();
        });

        AddButton(bar, "done", left + (buttonWidth + gap) * 3, buttonWidth, buttonHeight, "Done", delegate {
            CopyImage();
            DialogResult = DialogResult.OK;
            Close();
        });

    }

    protected override void Dispose(bool disposing) {
        if (disposing) {
            backgroundImage.Dispose();
            previewImage.Dispose();
        }
        base.Dispose(disposing);
    }

    protected override void OnPaintBackground(PaintEventArgs e) {
        e.Graphics.DrawImageUnscaled(backgroundImage, 0, 0);
        using (Brush overlay = new SolidBrush(Color.FromArgb(115, 245, 247, 250))) {
            e.Graphics.FillRectangle(overlay, ClientRectangle);
        }
    }

    protected override void OnKeyDown(KeyEventArgs e) {
        if (e.KeyCode == Keys.Escape) {
            DialogResult = DialogResult.Cancel;
            Close();
        }
        base.OnKeyDown(e);
    }

    private void AddButton(Control parent, string text, int left, int width, int height, string tip, EventHandler handler) {
        PrettyButton button = new PrettyButton();
        button.IconKind = text;
        button.ForeColor = Color.FromArgb(24, 24, 24);
        button.Bounds = new Rectangle(left, 10, width, height);
        button.Click += handler;
        ToolTip tooltip = new ToolTip();
        tooltip.SetToolTip(button, tip);
        parent.Controls.Add(button);
    }

    private void CopyImage() {
        Clipboard.SetImage((Image)previewImage.Clone());
    }

    private void SaveImage() {
        if (!System.IO.Directory.Exists(outputDir)) {
            System.IO.Directory.CreateDirectory(outputDir);
        }

        using (SaveFileDialog dialog = new SaveFileDialog()) {
            dialog.Title = "Save screenshot";
            dialog.Filter = "PNG Image (*.png)|*.png";
            dialog.DefaultExt = "png";
            dialog.AddExtension = true;
            dialog.OverwritePrompt = true;
            dialog.InitialDirectory = outputDir;
            dialog.FileName = "screenshot-" + DateTime.Now.ToString("yyyyMMdd-HHmmss") + ".png";

            if (dialog.ShowDialog(this) == DialogResult.OK) {
                SavedPath = dialog.FileName;
                System.IO.File.Copy(imagePath, SavedPath, true);
            }
        }
    }
}

public sealed class PrettyButton : Button {
    private bool hovering;
    private bool pressing;

    public string IconKind { get; set; }

    public PrettyButton() {
        FlatStyle = FlatStyle.Flat;
        FlatAppearance.BorderSize = 0;
        BackColor = Color.Transparent;
        Cursor = Cursors.Hand;
        TabStop = false;
    }

    protected override void OnMouseEnter(EventArgs e) {
        hovering = true;
        Invalidate();
        base.OnMouseEnter(e);
    }

    protected override void OnMouseLeave(EventArgs e) {
        hovering = false;
        pressing = false;
        Invalidate();
        base.OnMouseLeave(e);
    }

    protected override void OnMouseDown(MouseEventArgs e) {
        pressing = true;
        Invalidate();
        base.OnMouseDown(e);
    }

    protected override void OnMouseUp(MouseEventArgs e) {
        pressing = false;
        Invalidate();
        base.OnMouseUp(e);
    }

    protected override void OnPaint(PaintEventArgs e) {
        e.Graphics.SmoothingMode = System.Drawing.Drawing2D.SmoothingMode.AntiAlias;
        Rectangle rect = new Rectangle(0, 0, Width - 1, Height - 1);
        Color fill = pressing ? Color.FromArgb(226, 232, 240) : (hovering ? Color.FromArgb(241, 245, 249) : Color.White);
        Color border = hovering ? Color.FromArgb(96, 165, 250) : Color.FromArgb(203, 213, 225);

        using (System.Drawing.Drawing2D.GraphicsPath path = RoundedPath(rect, 7)) {
            using (Brush brush = new SolidBrush(fill)) {
                e.Graphics.FillPath(brush, path);
            }
            using (Pen pen = new Pen(border)) {
                e.Graphics.DrawPath(pen, path);
            }
        }

        DrawIcon(e.Graphics, rect);
    }

    private void DrawIcon(Graphics graphics, Rectangle rect) {
        Color iconColor = Color.FromArgb(51, 65, 85);
        if (IconKind == "cancel") {
            iconColor = Color.FromArgb(220, 38, 38);
        }
        else if (IconKind == "done") {
            iconColor = Color.FromArgb(22, 163, 74);
        }
        else if (IconKind == "save") {
            iconColor = Color.FromArgb(2, 132, 199);
        }

        using (Pen pen = new Pen(iconColor, 2)) {
            pen.StartCap = System.Drawing.Drawing2D.LineCap.Round;
            pen.EndCap = System.Drawing.Drawing2D.LineCap.Round;
            pen.LineJoin = System.Drawing.Drawing2D.LineJoin.Round;

            int cx = rect.Left + rect.Width / 2;
            int cy = rect.Top + rect.Height / 2;

            if (IconKind == "ocr") {
                DrawOcrIcon(graphics, pen, cx, cy);
            }
            else if (IconKind == "save") {
                DrawSaveIcon(graphics, pen, cx, cy);
            }
            else if (IconKind == "cancel") {
                graphics.DrawLine(pen, cx - 7, cy - 7, cx + 7, cy + 7);
                graphics.DrawLine(pen, cx + 7, cy - 7, cx - 7, cy + 7);
            }
            else {
                graphics.DrawLines(pen, new Point[] {
                    new Point(cx - 8, cy),
                    new Point(cx - 2, cy + 6),
                    new Point(cx + 9, cy - 7)
                });
            }
        }
    }

    private void DrawOcrIcon(Graphics graphics, Pen pen, int cx, int cy) {
        int left = cx - 11;
        int top = cy - 10;
        int right = cx + 11;
        int bottom = cy + 10;
        int size = 5;

        graphics.DrawLine(pen, left, top, left + size, top);
        graphics.DrawLine(pen, left, top, left, top + size);
        graphics.DrawLine(pen, right, top, right - size, top);
        graphics.DrawLine(pen, right, top, right, top + size);
        graphics.DrawLine(pen, left, bottom, left + size, bottom);
        graphics.DrawLine(pen, left, bottom, left, bottom - size);
        graphics.DrawLine(pen, right, bottom, right - size, bottom);
        graphics.DrawLine(pen, right, bottom, right, bottom - size);

        using (Font font = new Font("Segoe UI", 9, FontStyle.Bold)) {
            Rectangle textRect = new Rectangle(cx - 6, cy - 8, 12, 16);
            TextRenderer.DrawText(graphics, "A", font, textRect, Color.FromArgb(51, 65, 85), TextFormatFlags.HorizontalCenter | TextFormatFlags.VerticalCenter);
        }
    }

    private void DrawSaveIcon(Graphics graphics, Pen pen, int cx, int cy) {
        graphics.DrawLine(pen, cx, cy - 10, cx, cy + 4);
        graphics.DrawLine(pen, cx - 5, cy - 1, cx, cy + 5);
        graphics.DrawLine(pen, cx + 5, cy - 1, cx, cy + 5);
        graphics.DrawLine(pen, cx - 8, cy + 10, cx + 8, cy + 10);
        graphics.DrawLine(pen, cx - 8, cy + 10, cx - 8, cy + 6);
        graphics.DrawLine(pen, cx + 8, cy + 10, cx + 8, cy + 6);
    }

    private static System.Drawing.Drawing2D.GraphicsPath RoundedPath(Rectangle rect, int radius) {
        int diameter = radius * 2;
        System.Drawing.Drawing2D.GraphicsPath path = new System.Drawing.Drawing2D.GraphicsPath();
        path.AddArc(rect.Left, rect.Top, diameter, diameter, 180, 90);
        path.AddArc(rect.Right - diameter, rect.Top, diameter, diameter, 270, 90);
        path.AddArc(rect.Right - diameter, rect.Bottom - diameter, diameter, diameter, 0, 90);
        path.AddArc(rect.Left, rect.Bottom - diameter, diameter, diameter, 90, 90);
        path.CloseFigure();
        return path;
    }
}

public sealed class OcrTextWindow : Form {
    public OcrTextWindow(string text) {
        StartPosition = FormStartPosition.CenterScreen;
        Size = new Size(560, 360);
        Text = "Screenshot OCR";
        TopMost = true;

        TextBox box = new TextBox();
        box.Multiline = true;
        box.ReadOnly = false;
        box.ScrollBars = ScrollBars.Both;
        box.WordWrap = true;
        box.Text = text;
        box.Font = new Font("Microsoft YaHei UI", 10);
        box.Bounds = new Rectangle(12, 12, ClientSize.Width - 24, ClientSize.Height - 62);
        box.Anchor = AnchorStyles.Top | AnchorStyles.Bottom | AnchorStyles.Left | AnchorStyles.Right;
        Controls.Add(box);

        Button copy = new Button();
        copy.Text = "\u590d\u5236";
        copy.Bounds = new Rectangle(ClientSize.Width - 174, ClientSize.Height - 42, 76, 30);
        copy.Anchor = AnchorStyles.Bottom | AnchorStyles.Right;
        copy.Click += delegate {
            Clipboard.SetText(box.Text);
        };
        Controls.Add(copy);

        Button close = new Button();
        close.Text = "\u5173\u95ed";
        close.Bounds = new Rectangle(ClientSize.Width - 90, ClientSize.Height - 42, 76, 30);
        close.Anchor = AnchorStyles.Bottom | AnchorStyles.Right;
        close.Click += delegate {
            Close();
        };
        Controls.Add(close);
    }
}
"@

Add-Type -AssemblyName System.Drawing
Add-Type -AssemblyName System.Windows.Forms
Add-Type -TypeDefinition $signature -ReferencedAssemblies System.Drawing,System.Windows.Forms

function Wait-WinRtAsync {
    param(
        [Parameter(Mandatory = $true)]$Operation,
        [Parameter(Mandatory = $true)][Type]$ResultType
    )

    $method = [System.WindowsRuntimeSystemExtensions].GetMethods() |
        Where-Object {
            $_.Name -eq "AsTask" -and
            $_.IsGenericMethod -and
            $_.GetParameters().Count -eq 1 -and
            $_.GetGenericArguments().Count -eq 1 -and
            $_.GetParameters()[0].ParameterType.Name -eq 'IAsyncOperation`1'
        } |
        Select-Object -First 1

    if ($null -eq $method) {
        throw "Cannot find Windows Runtime async bridge."
    }

    $task = $method.MakeGenericMethod($ResultType).Invoke($null, @($Operation))
    $task.Wait()
    return $task.Result
}

function New-OcrEnhancedImage {
    param([Parameter(Mandatory = $true)][string]$ImagePath)

    Add-Type -AssemblyName System.Drawing

    $source = [System.Drawing.Image]::FromFile($ImagePath)
    try {
        $maxSide = [Math]::Max($source.Width, $source.Height)
        if ($maxSide -lt 700) {
            $scale = 3
        }
        elseif ($maxSide -lt 1400) {
            $scale = 2
        }
        else {
            $scale = 1
        }

        $targetWidth = [Math]::Max(1, $source.Width * $scale)
        $targetHeight = [Math]::Max(1, $source.Height * $scale)
        $target = New-Object System.Drawing.Bitmap $targetWidth, $targetHeight
        $graphics = [System.Drawing.Graphics]::FromImage($target)
        try {
            $graphics.Clear([System.Drawing.Color]::White)
            $graphics.InterpolationMode = [System.Drawing.Drawing2D.InterpolationMode]::HighQualityBicubic
            $graphics.SmoothingMode = [System.Drawing.Drawing2D.SmoothingMode]::HighQuality
            $graphics.PixelOffsetMode = [System.Drawing.Drawing2D.PixelOffsetMode]::HighQuality
            $graphics.DrawImage($source, 0, 0, $targetWidth, $targetHeight)

            $dir = Join-Path ([System.IO.Path]::GetTempPath()) "Screenshot"
            if (-not (Test-Path -LiteralPath $dir)) {
                New-Item -ItemType Directory -Path $dir | Out-Null
            }

            $path = Join-Path $dir ("ocr-enhanced-{0}.png" -f (Get-Date -Format "yyyyMMdd-HHmmss-fff"))
            $target.Save($path, [System.Drawing.Imaging.ImageFormat]::Png)
            return $path
        }
        finally {
            $graphics.Dispose()
            $target.Dispose()
        }
    }
    finally {
        $source.Dispose()
    }
}

function Invoke-ImageOcr {
    param([Parameter(Mandatory = $true)][string]$ImagePath)

    try {
        $ocrImagePath = New-OcrEnhancedImage -ImagePath $ImagePath

        Add-Type -AssemblyName System.Runtime.WindowsRuntime
        [Windows.Storage.StorageFile, Windows.Storage, ContentType = WindowsRuntime] | Out-Null
        [Windows.Storage.Streams.IRandomAccessStreamWithContentType, Windows.Storage.Streams, ContentType = WindowsRuntime] | Out-Null
        [Windows.Graphics.Imaging.BitmapDecoder, Windows.Graphics.Imaging, ContentType = WindowsRuntime] | Out-Null
        [Windows.Graphics.Imaging.BitmapPixelFormat, Windows.Graphics.Imaging, ContentType = WindowsRuntime] | Out-Null
        [Windows.Graphics.Imaging.BitmapAlphaMode, Windows.Graphics.Imaging, ContentType = WindowsRuntime] | Out-Null
        [Windows.Graphics.Imaging.SoftwareBitmap, Windows.Graphics.Imaging, ContentType = WindowsRuntime] | Out-Null
        [Windows.Media.Ocr.OcrEngine, Windows.Foundation, ContentType = WindowsRuntime] | Out-Null
        [Windows.Media.Ocr.OcrResult, Windows.Foundation, ContentType = WindowsRuntime] | Out-Null

        $file = Wait-WinRtAsync `
            -Operation ([Windows.Storage.StorageFile]::GetFileFromPathAsync($ocrImagePath)) `
            -ResultType ([Windows.Storage.StorageFile])

        $stream = Wait-WinRtAsync `
            -Operation ($file.OpenReadAsync()) `
            -ResultType ([Windows.Storage.Streams.IRandomAccessStreamWithContentType])

        try {
            $decoder = Wait-WinRtAsync `
                -Operation ([Windows.Graphics.Imaging.BitmapDecoder]::CreateAsync($stream)) `
                -ResultType ([Windows.Graphics.Imaging.BitmapDecoder])

            $bitmap = Wait-WinRtAsync `
                -Operation ($decoder.GetSoftwareBitmapAsync()) `
                -ResultType ([Windows.Graphics.Imaging.SoftwareBitmap])

            $engine = [Windows.Media.Ocr.OcrEngine]::TryCreateFromUserProfileLanguages()
            if ($null -eq $engine) {
                throw "Windows OCR engine is unavailable."
            }

            $maxDimension = [Windows.Media.Ocr.OcrEngine]::MaxImageDimension
            if ($bitmap.PixelWidth -gt $maxDimension -or $bitmap.PixelHeight -gt $maxDimension) {
                throw "Image is too large for Windows OCR. Select a smaller area."
            }

            if ($bitmap.BitmapPixelFormat -ne [Windows.Graphics.Imaging.BitmapPixelFormat]::Bgra8 -or
                $bitmap.BitmapAlphaMode -ne [Windows.Graphics.Imaging.BitmapAlphaMode]::Premultiplied) {
                $converted = [Windows.Graphics.Imaging.SoftwareBitmap]::Convert(
                    $bitmap,
                    [Windows.Graphics.Imaging.BitmapPixelFormat]::Bgra8,
                    [Windows.Graphics.Imaging.BitmapAlphaMode]::Premultiplied
                )
                $bitmap.Dispose()
                $bitmap = $converted
            }

            $result = Wait-WinRtAsync `
                -Operation ($engine.RecognizeAsync($bitmap)) `
                -ResultType ([Windows.Media.Ocr.OcrResult])

            $lines = foreach ($line in $result.Lines) {
                ($line.Words | ForEach-Object { $_.Text }) -join " "
            }

            return ($lines -join [Environment]::NewLine).Trim()
        }
        finally {
            if ($null -ne $bitmap) {
                $bitmap.Dispose()
            }
            if ($null -ne $stream) {
                $stream.Dispose()
            }
        }
    }
    catch {
        throw "OCR unavailable or failed: $($_.Exception.Message)"
    }
}

function Get-ModifierMask {
    param([string[]]$Names)

    $mask = 0
    foreach ($name in $Names) {
        switch ($name.ToLowerInvariant()) {
            "alt"     { $mask = $mask -bor 0x0001; continue }
            "control" { $mask = $mask -bor 0x0002; continue }
            "ctrl"    { $mask = $mask -bor 0x0002; continue }
            "shift"   { $mask = $mask -bor 0x0004; continue }
            "win"     { $mask = $mask -bor 0x0008; continue }
            default   { throw "Unsupported modifier '$name'. Use Alt, Control/Ctrl, Shift, or Win." }
        }
    }

    return [uint32]$mask
}

function Start-RegionScreenshot {
    param([string]$Directory)

    $selector = New-Object ScreenSelector $Directory
    try {
        $result = $selector.ShowDialog()
        if ($result -eq [System.Windows.Forms.DialogResult]::OK -and $selector.CapturePath) {
            $keepPreviewOpen = $true
            while ($keepPreviewOpen) {
                $preview = New-Object CapturePreview -ArgumentList @($selector.CapturePath, $Directory, $selector.PreviewLocation)
                try {
                $previewResult = $preview.ShowDialog()
                if ($previewResult -eq [System.Windows.Forms.DialogResult]::Retry) {
                    $keepPreviewOpen = $false
                    try {
                        $text = Invoke-ImageOcr -ImagePath $selector.CapturePath
                        if ([string]::IsNullOrWhiteSpace($text)) {
                            $text = "No text recognized."
                        }
                        $ocrWindow = New-Object OcrTextWindow -ArgumentList @($text)
                        try {
                            $ocrWindow.ShowDialog() | Out-Null
                        }
                        finally {
                            $ocrWindow.Dispose()
                        }
                    }
                    catch {
                        $ocrWindow = New-Object OcrTextWindow -ArgumentList @($_.Exception.Message)
                        try {
                            $ocrWindow.ShowDialog() | Out-Null
                        }
                        finally {
                            $ocrWindow.Dispose()
                        }
                    }
                }
                elseif ($previewResult -eq [System.Windows.Forms.DialogResult]::OK) {
                    Write-Host "Copied."
                    $keepPreviewOpen = $false
                }
                elseif ($previewResult -eq [System.Windows.Forms.DialogResult]::Yes) {
                    Write-Host "Saved: $($preview.SavedPath)"
                    $keepPreviewOpen = $false
                }
                elseif ($previewResult -eq [System.Windows.Forms.DialogResult]::Abort) {
                    Write-Host "Restarting capture."
                    $keepPreviewOpen = $false
                    Start-RegionScreenshot -Directory $Directory
                }
                else {
                    Write-Host "Canceled."
                    $keepPreviewOpen = $false
                }
                }
                finally {
                    $preview.Dispose()
                }
            }
        }
        else {
            Write-Host "Canceled."
        }
    }
    finally {
        $selector.Dispose()
    }
}

$hotkeyId = 1
$modifierMask = Get-ModifierMask -Names $Modifiers
$keyCode = [System.Windows.Forms.Keys]::$Key
if ($null -eq $keyCode) {
    throw "Unsupported key '$Key'. Use a Windows Forms key name, for example S, F8, or PrintScreen."
}

$registered = [HotkeyNative]::RegisterHotKey([IntPtr]::Zero, $hotkeyId, $modifierMask, [uint32]$keyCode)
if (-not $registered) {
    $lastError = [Runtime.InteropServices.Marshal]::GetLastWin32Error()
    throw "Could not register hotkey. Windows error: $lastError. The shortcut may already be in use."
}

Write-Host "Screenshot is running."
Write-Host ("Hotkey: {0}+{1}" -f (($Modifiers -join "+")), $Key)
Write-Host "Output: $OutputDir"
Write-Host "Drag to select an area. Press Esc to cancel."
Write-Host "Close this window to stop."

try {
    $msg = New-Object HotkeyNative+MSG
    while ([HotkeyNative]::GetMessage([ref]$msg, [IntPtr]::Zero, 0, 0) -ne 0) {
        if ($msg.message -eq [HotkeyNative]::WM_HOTKEY -and $msg.wParam.ToUInt32() -eq $hotkeyId) {
            Start-RegionScreenshot -Directory $OutputDir
        }
    }
}
finally {
    [HotkeyNative]::UnregisterHotKey([IntPtr]::Zero, $hotkeyId) | Out-Null
}
