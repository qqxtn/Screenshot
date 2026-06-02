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

    [DllImport("user32.dll")]
    public static extern IntPtr WindowFromPoint(POINT point);

    [DllImport("user32.dll")]
    public static extern IntPtr GetAncestor(IntPtr hwnd, uint gaFlags);

    [DllImport("user32.dll")]
    public static extern IntPtr GetParent(IntPtr hwnd);

    [DllImport("user32.dll")]
    public static extern bool SetForegroundWindow(IntPtr hWnd);

    [DllImport("user32.dll")]
    public static extern bool SetCursorPos(int X, int Y);

    [DllImport("user32.dll")]
    public static extern bool PostMessage(IntPtr hWnd, uint msg, IntPtr wParam, IntPtr lParam);

    [DllImport("user32.dll")]
    public static extern void keybd_event(byte bVk, byte bScan, uint dwFlags, UIntPtr dwExtraInfo);

    [DllImport("user32.dll")]
    public static extern void mouse_event(uint dwFlags, int dx, int dy, int dwData, UIntPtr dwExtraInfo);

    public const byte VK_NEXT = 0x22;
    public const uint KEYEVENTF_KEYUP = 0x0002;
    public const uint MOUSEEVENTF_WHEEL = 0x0800;
    public const uint WM_MOUSEWHEEL = 0x020A;
    public const uint WM_VSCROLL = 0x0115;
    public const uint GA_ROOT = 2;
    public const int SB_LINEDOWN = 1;
    public const int SB_PAGEDOWN = 3;

    public static IntPtr MakeLParam(int low, int high) {
        return new IntPtr((high << 16) | (low & 0xffff));
    }

    public static IntPtr MakeWheelWParam(int delta) {
        return new IntPtr(delta << 16);
    }

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
    public Rectangle CaptureBounds { get; private set; }
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
        CaptureBounds = new Rectangle(virtualScreen.Left + selection.Left, virtualScreen.Top + selection.Top, selection.Width, selection.Height);

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
    private readonly Bitmap previewImage;
    private readonly Bitmap backgroundImage;
    private readonly int borderSize = 1;
    private readonly int toolbarHeight = 54;
    private readonly Point previewLocation;
    private readonly bool showLongButton;
    private readonly double previewScale;
    private PictureBox picture;
    private ColorPalettePanel colorPalette;
    private string drawMode;
    private Color drawColor = Color.FromArgb(239, 68, 68);
    private bool drawing;
    private Point drawStart;
    private Point drawCurrent;

    public bool ExtractTextRequested { get; private set; }
    public bool LongScreenshotRequested { get; private set; }

    public string SavedPath { get; private set; }

    public CapturePreview(string imagePath, string outputDir, Point location) : this(imagePath, outputDir, location, true) {
    }

    public CapturePreview(string imagePath, string outputDir, Point location, bool showLongButton) {
        this.imagePath = imagePath;
        this.outputDir = outputDir;
        this.previewLocation = location;
        this.showLongButton = showLongButton;
        using (Image loaded = Image.FromFile(imagePath)) {
            this.previewImage = new Bitmap(loaded);
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
        int gap = 6;
        int buttonCount = showLongButton ? 8 : 7;
        int totalWidth = buttonWidth * buttonCount + gap * (buttonCount - 1);
        int maxPreviewWidth = Math.Max(120, screen.Width - 32 - borderSize * 2);
        int maxPreviewHeight = Math.Max(120, screen.Height - toolbarHeight - 32 - borderSize * 2);
        double scale = Math.Min(1.0, Math.Min((double)maxPreviewWidth / previewImage.Width, (double)maxPreviewHeight / previewImage.Height));
        this.previewScale = scale;
        int imageAreaWidth = Math.Max(1, (int)Math.Round(previewImage.Width * scale));
        int imageAreaHeight = Math.Max(1, (int)Math.Round(previewImage.Height * scale));
        int windowWidth = Math.Max(imageAreaWidth, totalWidth + 20);
        int previewWidth = windowWidth + borderSize * 2;
        int frameHeight = imageAreaHeight + borderSize * 2;
        int previewHeight = frameHeight + toolbarHeight;
        int contentLeft = Math.Max(8, Math.Min(location.X - Bounds.Left, Width - previewWidth - 8));
        int contentTop = Math.Max(8, Math.Min(location.Y - Bounds.Top, Height - previewHeight - 8));

        Panel container = new Panel();
        container.BackColor = Color.FromArgb(245, 248, 252);
        container.Bounds = new Rectangle(contentLeft, contentTop, previewWidth, frameHeight);
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

        picture = new PictureBox();
        picture.Image = previewImage;
        picture.SizeMode = scale < 1.0 ? PictureBoxSizeMode.Zoom : PictureBoxSizeMode.Normal;
        picture.BackColor = Color.White;
        picture.Bounds = new Rectangle(0, 0, imageAreaWidth, imageAreaHeight);
        picture.MouseDown += PictureMouseDown;
        picture.MouseMove += PictureMouseMove;
        picture.MouseUp += PictureMouseUp;
        picture.Paint += PicturePaint;
        imageFrame.Controls.Add(picture);

        Panel bar = new Panel();
        bar.BackColor = Color.Transparent;
        bar.Bounds = new Rectangle(contentLeft + borderSize, contentTop + frameHeight, windowWidth, toolbarHeight);
        Controls.Add(bar);

        int left = Math.Max(10, windowWidth - totalWidth - 10);

        AddButton(bar, "rect", left, buttonWidth, buttonHeight, "Rectangle", delegate {
            drawMode = drawMode == "rect" ? null : "rect";
            ShowColorPalette(bar, left, buttonWidth);
        });

        AddButton(bar, "ellipse", left + buttonWidth + gap, buttonWidth, buttonHeight, "Ellipse", delegate {
            drawMode = drawMode == "ellipse" ? null : "ellipse";
            ShowColorPalette(bar, left + buttonWidth + gap, buttonWidth);
        });

        AddButton(bar, "arrow", left + (buttonWidth + gap) * 2, buttonWidth, buttonHeight, "Arrow", delegate {
            drawMode = drawMode == "arrow" ? null : "arrow";
            ShowColorPalette(bar, left + (buttonWidth + gap) * 2, buttonWidth);
        });

        AddButton(bar, "ocr", left + (buttonWidth + gap) * 3, buttonWidth, buttonHeight, "Extract text", delegate {
            ExtractTextRequested = true;
            DialogResult = DialogResult.Retry;
            Close();
        });

        int index = 4;
        if (showLongButton) {
            AddButton(bar, "long", left + (buttonWidth + gap) * index, buttonWidth, buttonHeight, "Long screenshot", delegate {
                LongScreenshotRequested = true;
                DialogResult = DialogResult.Ignore;
                Close();
            });
            index++;
        }

        AddButton(bar, "save", left + (buttonWidth + gap) * index, buttonWidth, buttonHeight, "Save to local", delegate {
            SaveImage();
            if (!String.IsNullOrEmpty(SavedPath)) {
                DialogResult = DialogResult.Yes;
                Close();
            }
        });
        index++;

        AddButton(bar, "cancel", left + (buttonWidth + gap) * index, buttonWidth, buttonHeight, "Cancel", delegate {
            DialogResult = DialogResult.Cancel;
            Close();
        });
        index++;

        AddButton(bar, "done", left + (buttonWidth + gap) * index, buttonWidth, buttonHeight, "Done", delegate {
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

    private void ShowColorPalette(Control bar, int anchorLeft, int anchorWidth) {
        if (String.IsNullOrEmpty(drawMode)) {
            HideColorPalette();
            return;
        }

        if (colorPalette != null) {
            colorPalette.Dispose();
            colorPalette = null;
        }

        colorPalette = new ColorPalettePanel();
        colorPalette.ColorSelected += delegate(Color color) {
            drawColor = color;
            HideColorPalette();
        };
        colorPalette.Width = 40;
        colorPalette.Height = 190;
        int left = Math.Max(0, Math.Min(anchorLeft + (anchorWidth - colorPalette.Width) / 2, bar.Width - colorPalette.Width));
        Point screenPoint = bar.PointToScreen(new Point(left, 10 - colorPalette.Height - 4));
        colorPalette.Location = PointToClient(screenPoint);
        Controls.Add(colorPalette);
        colorPalette.BringToFront();
    }

    private void HideColorPalette() {
        if (colorPalette != null) {
            colorPalette.Dispose();
            colorPalette = null;
        }
    }

    private void CopyImage() {
        Clipboard.SetImage((Image)previewImage.Clone());
    }

    private void PictureMouseDown(object sender, MouseEventArgs e) {
        if (String.IsNullOrEmpty(drawMode) || e.Button != MouseButtons.Left) {
            return;
        }

        drawing = true;
        drawStart = ClampPreviewPoint(e.Location);
        drawCurrent = drawStart;
        picture.Invalidate();
    }

    private void PictureMouseMove(object sender, MouseEventArgs e) {
        if (!drawing) {
            return;
        }

        drawCurrent = ClampPreviewPoint(e.Location);
        picture.Invalidate();
    }

    private void PictureMouseUp(object sender, MouseEventArgs e) {
        if (!drawing || e.Button != MouseButtons.Left) {
            return;
        }

        drawing = false;
        drawCurrent = ClampPreviewPoint(e.Location);
        CommitShape();
        picture.Invalidate();
    }

    private void PicturePaint(object sender, PaintEventArgs e) {
        if (!drawing || String.IsNullOrEmpty(drawMode)) {
            return;
        }

        e.Graphics.SmoothingMode = System.Drawing.Drawing2D.SmoothingMode.AntiAlias;
        using (Pen pen = new Pen(drawColor, 2)) {
            if (drawMode == "arrow") {
                if (Distance(drawStart, drawCurrent) < 4) {
                    return;
                }
                using (System.Drawing.Drawing2D.AdjustableArrowCap cap = new System.Drawing.Drawing2D.AdjustableArrowCap(4, 5, true)) {
                    pen.CustomEndCap = cap;
                    e.Graphics.DrawLine(pen, drawStart, drawCurrent);
                }
            }
            else {
                Rectangle rect = GetPreviewRectangle(drawStart, drawCurrent);
                if (rect.Width < 2 || rect.Height < 2) {
                    return;
                }

                if (drawMode == "ellipse") {
                    e.Graphics.DrawEllipse(pen, rect);
                }
                else {
                    e.Graphics.DrawRectangle(pen, rect);
                }
            }
        }
    }

    private void CommitShape() {
        using (Graphics g = Graphics.FromImage(previewImage)) {
            g.SmoothingMode = System.Drawing.Drawing2D.SmoothingMode.AntiAlias;
            int stroke = Math.Max(2, (int)Math.Round(3.0 / Math.Max(0.25, previewScale)));
            using (Pen pen = new Pen(drawColor, stroke)) {
                if (drawMode == "arrow") {
                    if (Distance(drawStart, drawCurrent) < 4) {
                        return;
                    }

                    Point imageStart = PreviewToImagePoint(drawStart);
                    Point imageEnd = PreviewToImagePoint(drawCurrent);
                    using (System.Drawing.Drawing2D.AdjustableArrowCap cap = new System.Drawing.Drawing2D.AdjustableArrowCap(
                        Math.Max(4, (float)(stroke * 1.35)),
                        Math.Max(5, (float)(stroke * 2.0)),
                        true
                    )) {
                        pen.CustomEndCap = cap;
                        g.DrawLine(pen, imageStart, imageEnd);
                    }
                }
                else {
                    Rectangle previewRect = GetPreviewRectangle(drawStart, drawCurrent);
                    if (previewRect.Width < 3 || previewRect.Height < 3) {
                        return;
                    }

                    Rectangle imageRect = PreviewToImageRectangle(previewRect);
                    if (imageRect.Width < 2 || imageRect.Height < 2) {
                        return;
                    }

                    if (drawMode == "ellipse") {
                        g.DrawEllipse(pen, imageRect);
                    }
                    else {
                        g.DrawRectangle(pen, imageRect);
                    }
                }
            }
        }

        picture.Image = previewImage;
    }

    private double Distance(Point a, Point b) {
        int dx = a.X - b.X;
        int dy = a.Y - b.Y;
        return Math.Sqrt(dx * dx + dy * dy);
    }

    private Point ClampPreviewPoint(Point point) {
        int x = Math.Max(0, Math.Min(picture.Width - 1, point.X));
        int y = Math.Max(0, Math.Min(picture.Height - 1, point.Y));
        return new Point(x, y);
    }

    private Rectangle GetPreviewRectangle(Point a, Point b) {
        int x = Math.Min(a.X, b.X);
        int y = Math.Min(a.Y, b.Y);
        int width = Math.Abs(a.X - b.X);
        int height = Math.Abs(a.Y - b.Y);
        return new Rectangle(x, y, width, height);
    }

    private Rectangle PreviewToImageRectangle(Rectangle rect) {
        int x = (int)Math.Round(rect.X / previewScale);
        int y = (int)Math.Round(rect.Y / previewScale);
        int width = (int)Math.Round(rect.Width / previewScale);
        int height = (int)Math.Round(rect.Height / previewScale);

        x = Math.Max(0, Math.Min(previewImage.Width - 1, x));
        y = Math.Max(0, Math.Min(previewImage.Height - 1, y));
        width = Math.Max(1, Math.Min(previewImage.Width - x, width));
        height = Math.Max(1, Math.Min(previewImage.Height - y, height));
        return new Rectangle(x, y, width, height);
    }

    private Point PreviewToImagePoint(Point point) {
        int x = (int)Math.Round(point.X / previewScale);
        int y = (int)Math.Round(point.Y / previewScale);
        x = Math.Max(0, Math.Min(previewImage.Width - 1, x));
        y = Math.Max(0, Math.Min(previewImage.Height - 1, y));
        return new Point(x, y);
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
                previewImage.Save(SavedPath, ImageFormat.Png);
            }
        }
    }
}

public sealed class LongScreenshotSession : Form {
    private readonly Rectangle captureBounds;
    private readonly string outputDir;
    private readonly System.Collections.Generic.List<Bitmap> frames = new System.Collections.Generic.List<Bitmap>();
    private LongCaptureBorder border;
    private bool capturing;
    private int bestMatchCount;
    private int bestMatchIndex;
    private int bestIgnoreBottomOffset;

    public string Action { get; private set; }
    public string SavedPath { get; private set; }
    public string CapturePath { get; private set; }
    public Point PreviewLocation { get; private set; }

    public LongScreenshotSession(Rectangle captureBounds, string outputDir) {
        this.captureBounds = captureBounds;
        this.outputDir = outputDir;
        Action = "Cancel";

        StartPosition = FormStartPosition.Manual;
        FormBorderStyle = FormBorderStyle.None;
        ShowInTaskbar = false;
        TopMost = true;
        DoubleBuffered = true;
        KeyPreview = true;
        BackColor = Color.Magenta;
        TransparencyKey = Color.Magenta;
        Bounds = new Rectangle(captureBounds.Left, captureBounds.Top, 1, 1);
    }

    protected override void OnShown(EventArgs e) {
        base.OnShown(e);
        border = new LongCaptureBorder(captureBounds);
        border.Show();
        CaptureFrame();
        FocusCaptureTarget();
        BeginInvoke(new MethodInvoker(delegate {
            CaptureUntilBottom();
        }));
    }

    protected override void Dispose(bool disposing) {
        if (disposing) {
            foreach (Bitmap frame in frames) {
                frame.Dispose();
            }
            if (border != null) {
                border.Close();
                border.Dispose();
            }
        }
        base.Dispose(disposing);
    }

    protected override void OnKeyDown(KeyEventArgs e) {
        if (e.KeyCode == Keys.Escape) {
            Action = "Cancel";
            DialogResult = DialogResult.Cancel;
            Close();
        }
        base.OnKeyDown(e);
    }

    private IntPtr FocusCaptureTarget() {
        HotkeyNative.POINT point = new HotkeyNative.POINT();
        point.x = captureBounds.Left + captureBounds.Width / 2;
        point.y = captureBounds.Top + captureBounds.Height / 2;
        IntPtr target = HotkeyNative.WindowFromPoint(point);
        if (target != IntPtr.Zero) {
            IntPtr root = HotkeyNative.GetAncestor(target, HotkeyNative.GA_ROOT);
            HotkeyNative.SetForegroundWindow(root != IntPtr.Zero ? root : target);
        }
        return target;
    }

    private void CaptureFrame() {
        frames.Add(CaptureFrameBitmap());
    }

    private Bitmap CaptureFrameBitmap() {
        Bitmap frame = new Bitmap(captureBounds.Width, captureBounds.Height);
        using (Graphics g = Graphics.FromImage(frame)) {
            g.CopyFromScreen(captureBounds.Left, captureBounds.Top, 0, 0, captureBounds.Size);
        }
        return frame;
    }

    private void CaptureUntilBottom() {
        if (capturing) {
            return;
        }

        capturing = true;
        bool wasVisible = Visible;
        bool borderVisible = border != null && border.Visible;

        if (wasVisible) {
            Hide();
        }
        if (borderVisible) {
            border.Hide();
        }
        Application.DoEvents();
        System.Threading.Thread.Sleep(80);

        try {
            int unchangedCount = 0;
            for (int i = 0; i < 220; i++) {
                ScrollCaptureTarget();
                Application.DoEvents();
                System.Threading.Thread.Sleep(240);

                Bitmap frame = CaptureFrameBitmap();
                Bitmap previous = frames.Count > 0 ? frames[frames.Count - 1] : null;
                if (previous != null && IsSameFrame(previous, frame)) {
                    frame.Dispose();
                    unchangedCount++;
                    if (unchangedCount >= 5) {
                        break;
                    }
                }
                else {
                    unchangedCount = 0;
                    frames.Add(frame);
                }
            }
        }
        finally {
            capturing = false;
            SaveLongScreenshotTemp();
            Action = "Preview";
            DialogResult = DialogResult.OK;
            Close();
        }
    }

    private void ScrollCaptureTarget() {
        int x = captureBounds.Left + captureBounds.Width / 2;
        int y = captureBounds.Top + captureBounds.Height / 2;
        HotkeyNative.SetCursorPos(x, y);
        IntPtr target = FocusCaptureTarget();
        System.Threading.Thread.Sleep(60);

        HotkeyNative.mouse_event(HotkeyNative.MOUSEEVENTF_WHEEL, 0, 0, -120, UIntPtr.Zero);
    }

    private void PostScrollMessages(IntPtr target, int screenX, int screenY) {
        if (target == IntPtr.Zero) {
            return;
        }

        IntPtr wheelParam = HotkeyNative.MakeWheelWParam(-120);
        IntPtr pointParam = HotkeyNative.MakeLParam(screenX, screenY);
        IntPtr vScrollParam = new IntPtr(HotkeyNative.SB_LINEDOWN);
        IntPtr current = target;

        for (int i = 0; i < 3 && current != IntPtr.Zero; i++) {
            HotkeyNative.PostMessage(current, HotkeyNative.WM_MOUSEWHEEL, wheelParam, pointParam);
            HotkeyNative.PostMessage(current, HotkeyNative.WM_VSCROLL, vScrollParam, IntPtr.Zero);
            IntPtr parent = HotkeyNative.GetParent(current);
            if (parent == current) {
                break;
            }
            current = parent;
        }

        IntPtr root = HotkeyNative.GetAncestor(target, HotkeyNative.GA_ROOT);
        if (root != IntPtr.Zero && root != target) {
            HotkeyNative.PostMessage(root, HotkeyNative.WM_MOUSEWHEEL, wheelParam, pointParam);
            HotkeyNative.PostMessage(root, HotkeyNative.WM_VSCROLL, vScrollParam, IntPtr.Zero);
        }
    }

    private bool IsSameFrame(Bitmap previous, Bitmap current) {
        return ScoreWholeFrame(previous, current) <= 1.5;
    }

    private double ScoreWholeFrame(Bitmap previous, Bitmap current) {
        return ScoreBitmapRegion(previous, current, 0, 0, 0, Math.Min(previous.Height, current.Height), Math.Min(previous.Width, current.Width), 80, 80);
    }

    private sealed class MatchResult {
        public int Offset;
        public double Score;

        public MatchResult(int offset, double score) {
            Offset = offset;
            Score = score;
        }
    }

    private sealed class Segment {
        public Bitmap Image;
        public int SourceY;
        public int Height;

        public Segment(Bitmap image, int sourceY, int height) {
            Image = image;
            SourceY = sourceY;
            Height = height;
        }
    }

    private Bitmap BuildLongImage() {
        if (frames.Count == 0) {
            throw new InvalidOperationException("No long screenshot frames captured.");
        }

        System.Collections.Generic.List<Segment> segments = new System.Collections.Generic.List<Segment>();
        System.Collections.Generic.List<int> acceptedOffsets = new System.Collections.Generic.List<int>();
        segments.Add(new Segment(frames[0], 0, frames[0].Height));

        for (int i = 1; i < frames.Count; i++) {
            MatchResult match = FindSmallStepScrollOffset(frames[i - 1], frames[i]);
            if (match.Offset <= 2 && match.Score <= 2.0) {
                continue;
            }

            int minimumUsefulOffset = Math.Max(12, frames[i].Height / 24);
            if (match.Score <= 34.0 && match.Offset >= minimumUsefulOffset) {
                int normalizedOffset = NormalizeScrollOffset(match.Offset, acceptedOffsets, frames[i].Height);
                if (normalizedOffset < minimumUsefulOffset) {
                    continue;
                }

                int appendHeight = Math.Min(normalizedOffset, frames[i].Height);
                int sourceY = frames[i].Height - appendHeight;
                if (appendHeight > 0) {
                    segments.Add(new Segment(frames[i], sourceY, appendHeight));
                    acceptedOffsets.Add(appendHeight);
                }
            }
        }

        int totalHeight = 0;
        foreach (Segment segment in segments) {
            totalHeight += segment.Height;
        }

        Bitmap result = new Bitmap(captureBounds.Width, totalHeight);
        using (Graphics g = Graphics.FromImage(result)) {
            g.CompositingMode = System.Drawing.Drawing2D.CompositingMode.SourceCopy;
            g.InterpolationMode = System.Drawing.Drawing2D.InterpolationMode.NearestNeighbor;
            int y = 0;
            foreach (Segment segment in segments) {
                g.DrawImage(segment.Image, new Rectangle(0, y, captureBounds.Width, segment.Height),
                    new Rectangle(0, segment.SourceY, captureBounds.Width, segment.Height), GraphicsUnit.Pixel);
                y += segment.Height;
            }
        }

        return result;
    }

    private int NormalizeScrollOffset(int offset, System.Collections.Generic.List<int> acceptedOffsets, int frameHeight) {
        if (acceptedOffsets.Count < 3) {
            return offset;
        }

        int typical = MedianOffset(acceptedOffsets);
        if (typical <= 0) {
            return offset;
        }

        int high = Math.Min(frameHeight / 2, Math.Max(typical + 18, (int)Math.Round(typical * 1.45)));
        int low = Math.Max(4, Math.Min(typical - 18, (int)Math.Round(typical * 0.55)));

        if (offset > high) {
            return 0;
        }
        if (offset < low) {
            return 0;
        }
        return offset;
    }

    private int MedianOffset(System.Collections.Generic.List<int> offsets) {
        int[] values = offsets.ToArray();
        Array.Sort(values);
        return values[values.Length / 2];
    }

    private MatchResult FindSmallStepScrollOffset(Bitmap previous, Bitmap current) {
        int height = Math.Min(previous.Height, current.Height);
        int maxOffset = Math.Max(1, Math.Min(height - 40, Math.Min(260, height / 3)));
        int preferredMinOffset = Math.Min(maxOffset, Math.Max(18, height / 5));
        int bestOffset = 0;
        double bestScore = Double.MaxValue;
        int preferredOffset = 0;
        double preferredScore = Double.MaxValue;

        for (int offset = 0; offset <= maxOffset; offset += 8) {
            double score = ScoreOffset(previous, current, offset);
            if (score < bestScore - 0.1 || (Math.Abs(score - bestScore) <= 0.1 && offset < bestOffset)) {
                bestScore = score;
                bestOffset = offset;
            }
            if (offset >= preferredMinOffset &&
                (score < preferredScore - 0.1 || (Math.Abs(score - preferredScore) <= 0.1 && offset < preferredOffset))) {
                preferredScore = score;
                preferredOffset = offset;
            }
        }

        int fineStart = Math.Max(0, bestOffset - 8);
        int fineEnd = Math.Min(maxOffset, bestOffset + 8);
        for (int offset = fineStart; offset <= fineEnd; offset++) {
            double score = ScoreOffset(previous, current, offset);
            if (score < bestScore - 0.1 || (Math.Abs(score - bestScore) <= 0.1 && offset < bestOffset)) {
                bestScore = score;
                bestOffset = offset;
            }
        }

        if (preferredScore < Double.MaxValue) {
            int preferredFineStart = Math.Max(preferredMinOffset, preferredOffset - 8);
            int preferredFineEnd = Math.Min(maxOffset, preferredOffset + 8);
            for (int offset = preferredFineStart; offset <= preferredFineEnd; offset++) {
                double score = ScoreOffset(previous, current, offset);
                if (score < preferredScore - 0.1 || (Math.Abs(score - preferredScore) <= 0.1 && offset < preferredOffset)) {
                    preferredScore = score;
                    preferredOffset = offset;
                }
            }

            if (preferredScore <= 34.0 && preferredScore <= bestScore + 14.0) {
                return new MatchResult(preferredOffset, preferredScore);
            }
        }

        return new MatchResult(bestOffset, bestScore);
    }

    private MatchResult FindVerticalScrollOffset(Bitmap previous, Bitmap current) {
        int height = Math.Min(previous.Height, current.Height);
        int minOverlap = Math.Min(height - 1, Math.Max(40, height / 5));
        int maxOffset = Math.Max(0, height - minOverlap);
        int preferredMinOffset = Math.Min(maxOffset, Math.Max(12, height / 3));
        int bestOffset = 0;
        double bestScore = Double.MaxValue;
        int preferredOffset = 0;
        double preferredScore = Double.MaxValue;

        for (int offset = 0; offset <= maxOffset; offset += 8) {
            double score = ScoreOffset(previous, current, offset);
            if (score < bestScore - 0.25 || (Math.Abs(score - bestScore) <= 0.25 && offset > bestOffset)) {
                bestScore = score;
                bestOffset = offset;
            }
            if (offset >= preferredMinOffset &&
                (score < preferredScore - 0.25 || (Math.Abs(score - preferredScore) <= 0.25 && offset > preferredOffset))) {
                preferredScore = score;
                preferredOffset = offset;
            }
        }

        int fineStart = Math.Max(0, bestOffset - 12);
        int fineEnd = Math.Min(maxOffset, bestOffset + 12);
        for (int offset = fineStart; offset <= fineEnd; offset++) {
            double score = ScoreOffset(previous, current, offset);
            if (score < bestScore - 0.25 || (Math.Abs(score - bestScore) <= 0.25 && offset > bestOffset)) {
                bestScore = score;
                bestOffset = offset;
            }
        }

        if (preferredScore < Double.MaxValue) {
            int preferredFineStart = Math.Max(preferredMinOffset, preferredOffset - 12);
            int preferredFineEnd = Math.Min(maxOffset, preferredOffset + 12);
            for (int offset = preferredFineStart; offset <= preferredFineEnd; offset++) {
                double score = ScoreOffset(previous, current, offset);
                if (score < preferredScore - 0.25 || (Math.Abs(score - preferredScore) <= 0.25 && offset > preferredOffset)) {
                    preferredScore = score;
                    preferredOffset = offset;
                }
            }

            if (preferredScore <= 38.0 && preferredScore <= bestScore + 12.0) {
                return new MatchResult(preferredOffset, preferredScore);
            }
        }

        return new MatchResult(bestOffset, bestScore);
    }

    private Bitmap CombineImageShareXStyle(Bitmap result, Bitmap currentImage) {
        if (result == null) {
            return (Bitmap)currentImage.Clone();
        }

        if (currentImage.Width != result.Width || currentImage.Height <= 1 || result.Height < currentImage.Height) {
            return null;
        }

        int matchCount = 0;
        int matchIndex = 0;
        int matchLimit = currentImage.Height / 2;
        int ignoreSideOffset = Math.Max(24, currentImage.Width / 20);
        ignoreSideOffset = Math.Min(ignoreSideOffset, currentImage.Width / 3);
        int compareWidth = currentImage.Width - ignoreSideOffset * 2;
        if (compareWidth <= 8) {
            ignoreSideOffset = 0;
            compareWidth = currentImage.Width;
        }

        int ignoreBottomOffsetMax = currentImage.Height / 3;
        int ignoreBottomOffset = Math.Max(24, currentImage.Height / 10);
        ignoreBottomOffset = Math.Min(ignoreBottomOffset, ignoreBottomOffsetMax);
        ignoreBottomOffset = Math.Max(ignoreBottomOffset, bestIgnoreBottomOffset);

        int resultMatchBottom = result.Height - ignoreBottomOffset - 1;
        if (resultMatchBottom <= 0) {
            return null;
        }

        for (int currentImageY = currentImage.Height - 1; currentImageY >= 0 && matchCount < matchLimit; currentImageY--) {
            int currentMatchCount = 0;
            for (int y = 0; currentImageY - y >= 0 && resultMatchBottom - y >= 0 && currentMatchCount < matchLimit; y++) {
                if (RowsMatch(result, resultMatchBottom - y, currentImage, currentImageY - y, ignoreSideOffset, compareWidth)) {
                    currentMatchCount++;
                }
                else {
                    break;
                }
            }

            if (currentMatchCount > matchCount) {
                matchCount = currentMatchCount;
                matchIndex = currentImageY;
            }
        }

        bool bestGuess = false;
        if (matchCount == 0 && bestMatchCount > 0) {
            matchCount = bestMatchCount;
            matchIndex = bestMatchIndex;
            ignoreBottomOffset = bestIgnoreBottomOffset;
            bestGuess = true;
        }

        if (matchCount <= 0) {
            return null;
        }

        int matchHeight = currentImage.Height - matchIndex - 1;
        if (matchHeight <= 0) {
            return result;
        }

        if (!bestGuess && matchCount > bestMatchCount) {
            bestMatchCount = matchCount;
            bestMatchIndex = matchIndex;
            bestIgnoreBottomOffset = ignoreBottomOffset;
        }

        int keptResultHeight = result.Height - ignoreBottomOffset;
        Bitmap newResult = new Bitmap(result.Width, keptResultHeight + matchHeight);
        using (Graphics g = Graphics.FromImage(newResult)) {
            g.CompositingMode = System.Drawing.Drawing2D.CompositingMode.SourceCopy;
            g.InterpolationMode = System.Drawing.Drawing2D.InterpolationMode.NearestNeighbor;
            g.PixelOffsetMode = System.Drawing.Drawing2D.PixelOffsetMode.Half;
            g.DrawImage(result, new Rectangle(0, 0, result.Width, keptResultHeight),
                new Rectangle(0, 0, result.Width, keptResultHeight), GraphicsUnit.Pixel);
            g.DrawImage(currentImage, new Rectangle(0, keptResultHeight, currentImage.Width, matchHeight),
                new Rectangle(0, matchIndex + 1, currentImage.Width, matchHeight), GraphicsUnit.Pixel);
        }

        return newResult;
    }

    private Bitmap CombineImageByBestOffset(Bitmap result, Bitmap currentImage, MatchResult match) {
        if (result == null) {
            return (Bitmap)currentImage.Clone();
        }

        if (match.Offset <= 3 && match.Score < 10.0) {
            return result;
        }

        int appendHeight = currentImage.Height;
        int sourceY = 0;
        if (match.Score <= 50.0 && match.Offset > 0) {
            appendHeight = Math.Min(match.Offset, currentImage.Height);
            sourceY = currentImage.Height - appendHeight;
        }

        if (appendHeight <= 0) {
            return result;
        }

        Bitmap newResult = new Bitmap(result.Width, result.Height + appendHeight);
        using (Graphics g = Graphics.FromImage(newResult)) {
            g.CompositingMode = System.Drawing.Drawing2D.CompositingMode.SourceCopy;
            g.InterpolationMode = System.Drawing.Drawing2D.InterpolationMode.NearestNeighbor;
            g.DrawImage(result, new Rectangle(0, 0, result.Width, result.Height),
                new Rectangle(0, 0, result.Width, result.Height), GraphicsUnit.Pixel);
            g.DrawImage(currentImage, new Rectangle(0, result.Height, currentImage.Width, appendHeight),
                new Rectangle(0, sourceY, currentImage.Width, appendHeight), GraphicsUnit.Pixel);
        }
        return newResult;
    }

    private bool RowsMatch(Bitmap a, int ay, Bitmap b, int by, int left, int width) {
        int xStep = Math.Max(1, width / 96);
        int mismatches = 0;
        int maxMismatches = Math.Max(2, width / (xStep * 24));

        for (int x = left; x < left + width; x += xStep) {
            Color ca = a.GetPixel(x, ay);
            Color cb = b.GetPixel(x, by);
            int diff = Math.Abs(ca.R - cb.R) + Math.Abs(ca.G - cb.G) + Math.Abs(ca.B - cb.B);
            if (diff > 6) {
                mismatches++;
                if (mismatches > maxMismatches) {
                    return false;
                }
            }
        }

        return true;
    }

    private double ScoreOffset(Bitmap previous, Bitmap current, int offset) {
        int width = Math.Min(previous.Width, current.Width);
        int height = Math.Min(previous.Height, current.Height);
        int overlap = height - offset;
        if (overlap <= 0 || width <= 0) {
            return Double.MaxValue;
        }

        int trim = Math.Min(24, Math.Max(0, width / 5));
        int left = Math.Min(trim, Math.Max(0, width - 1));
        int right = Math.Max(left + 1, width - trim);
        return ScoreBitmapRegion(previous, current, left, offset, 0, overlap, right - left, 54, 72);
    }

    private double ScoreBitmapRegion(Bitmap previous, Bitmap current, int left, int previousTop, int currentTop, int height, int width, int xSamples, int ySamples) {
        if (height <= 0 || width <= 0) {
            return Double.MaxValue;
        }

        Rectangle previousRect = new Rectangle(0, 0, previous.Width, previous.Height);
        Rectangle currentRect = new Rectangle(0, 0, current.Width, current.Height);
        BitmapData previousData = null;
        BitmapData currentData = null;

        try {
            previousData = previous.LockBits(previousRect, ImageLockMode.ReadOnly, PixelFormat.Format32bppArgb);
            currentData = current.LockBits(currentRect, ImageLockMode.ReadOnly, PixelFormat.Format32bppArgb);

            int xStep = Math.Max(1, width / xSamples);
            int yStep = Math.Max(1, height / ySamples);
            long total = 0;
            long count = 0;

            for (int y = 0; y < height; y += yStep) {
                int previousY = previousTop + y;
                int currentY = currentTop + y;
                IntPtr previousRow = IntPtr.Add(previousData.Scan0, previousY * previousData.Stride);
                IntPtr currentRow = IntPtr.Add(currentData.Scan0, currentY * currentData.Stride);

                for (int x = left; x < left + width; x += xStep) {
                    int pixel = x * 4;
                    int previousB = Marshal.ReadByte(previousRow, pixel);
                    int previousG = Marshal.ReadByte(previousRow, pixel + 1);
                    int previousR = Marshal.ReadByte(previousRow, pixel + 2);
                    int currentB = Marshal.ReadByte(currentRow, pixel);
                    int currentG = Marshal.ReadByte(currentRow, pixel + 1);
                    int currentR = Marshal.ReadByte(currentRow, pixel + 2);
                    total += Math.Abs(previousR - currentR) + Math.Abs(previousG - currentG) + Math.Abs(previousB - currentB);
                    count++;
                }
            }

            if (count == 0) {
                return Double.MaxValue;
            }
            return (double)total / (double)(count * 3);
        }
        finally {
            if (previousData != null) {
                previous.UnlockBits(previousData);
            }
            if (currentData != null) {
                current.UnlockBits(currentData);
            }
        }
    }

    private double ScoreOffsetSlow(Bitmap previous, Bitmap current, int offset) {
        int width = Math.Min(previous.Width, current.Width);
        int height = Math.Min(previous.Height, current.Height);
        int overlap = height - offset;
        if (overlap <= 0 || width <= 0) {
            return Double.MaxValue;
        }

        int trim = Math.Min(24, Math.Max(0, width / 5));
        int left = Math.Min(trim, Math.Max(0, width - 1));
        int right = Math.Max(left + 1, width - trim);
        int xStep = Math.Max(1, (right - left) / 54);
        int yStep = Math.Max(1, overlap / 72);
        long total = 0;
        long count = 0;

        for (int y = 0; y < overlap; y += yStep) {
            int previousY = y + offset;
            for (int x = left; x < right; x += xStep) {
                Color a = previous.GetPixel(x, previousY);
                Color b = current.GetPixel(x, y);
                total += Math.Abs(a.R - b.R) + Math.Abs(a.G - b.G) + Math.Abs(a.B - b.B);
                count++;
            }
        }

        if (count == 0) {
            return Double.MaxValue;
        }
        return (double)total / (double)(count * 3);
    }

    private void CopyLongScreenshot() {
        using (Bitmap image = BuildLongImage()) {
            Clipboard.SetImage((Image)image.Clone());
        }
    }

    private void SaveLongScreenshotTemp() {
        string dir = System.IO.Path.Combine(System.IO.Path.GetTempPath(), "Screenshot");
        if (!System.IO.Directory.Exists(dir)) {
            System.IO.Directory.CreateDirectory(dir);
        }

        using (Bitmap image = BuildLongImage()) {
            string fileName = "long-screenshot-" + DateTime.Now.ToString("yyyyMMdd-HHmmss") + ".bmp";
            CapturePath = System.IO.Path.Combine(dir, fileName);
            image.Save(CapturePath, ImageFormat.Bmp);

            Rectangle screen = SystemInformation.VirtualScreen;
            int left = captureBounds.Left;
            int top = captureBounds.Top;
            if (left < screen.Left + 8) {
                left = screen.Left + 8;
            }
            if (top < screen.Top + 8) {
                top = screen.Top + 8;
            }
            PreviewLocation = new Point(left, top);
        }
    }

    private void SaveLongScreenshot() {
        if (!System.IO.Directory.Exists(outputDir)) {
            System.IO.Directory.CreateDirectory(outputDir);
        }

        using (Bitmap image = BuildLongImage()) {
            using (SaveFileDialog dialog = new SaveFileDialog()) {
                dialog.Title = "Save long screenshot";
                dialog.Filter = "PNG Image (*.png)|*.png";
                dialog.DefaultExt = "png";
                dialog.AddExtension = true;
                dialog.OverwritePrompt = true;
                dialog.InitialDirectory = outputDir;
                dialog.FileName = "long-screenshot-" + DateTime.Now.ToString("yyyyMMdd-HHmmss") + ".png";

                if (dialog.ShowDialog(this) == DialogResult.OK) {
                    SavedPath = dialog.FileName;
                    image.Save(SavedPath, ImageFormat.Png);
                    Action = "Save";
                    DialogResult = DialogResult.OK;
                    Close();
                }
            }
        }
    }
}

public sealed class LongCaptureBorder : Form {
    private const int WS_EX_TRANSPARENT = 0x00000020;
    private const int WS_EX_NOACTIVATE = 0x08000000;
    private const int WS_EX_TOOLWINDOW = 0x00000080;
    private readonly int thickness = 2;

    public LongCaptureBorder(Rectangle captureBounds) {
        StartPosition = FormStartPosition.Manual;
        FormBorderStyle = FormBorderStyle.None;
        ShowInTaskbar = false;
        TopMost = true;
        DoubleBuffered = true;
        BackColor = Color.Magenta;
        TransparencyKey = Color.Magenta;
        Bounds = new Rectangle(
            captureBounds.Left - thickness,
            captureBounds.Top - thickness,
            captureBounds.Width + thickness * 2,
            captureBounds.Height + thickness * 2
        );
    }

    protected override CreateParams CreateParams {
        get {
            CreateParams cp = base.CreateParams;
            cp.ExStyle |= WS_EX_TRANSPARENT | WS_EX_NOACTIVATE | WS_EX_TOOLWINDOW;
            return cp;
        }
    }

    protected override bool ShowWithoutActivation {
        get { return true; }
    }

    protected override void OnPaint(PaintEventArgs e) {
        using (Brush brush = new SolidBrush(Color.FromArgb(64, 156, 255))) {
            e.Graphics.FillRectangle(brush, 0, 0, Width, thickness);
            e.Graphics.FillRectangle(brush, 0, Height - thickness, Width, thickness);
            e.Graphics.FillRectangle(brush, 0, thickness, thickness, Height - thickness * 2);
            e.Graphics.FillRectangle(brush, Width - thickness, thickness, thickness, Height - thickness * 2);
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
        FlatAppearance.MouseDownBackColor = Color.Transparent;
        FlatAppearance.MouseOverBackColor = Color.Transparent;
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
        else if (IconKind == "long") {
            iconColor = Color.FromArgb(124, 58, 237);
        }
        else if (IconKind == "rect" || IconKind == "ellipse" || IconKind == "arrow") {
            iconColor = Color.FromArgb(239, 68, 68);
        }
        else if (IconKind.StartsWith("color-")) {
            iconColor = GetSwatchColor(IconKind);
        }

        if (IconKind.StartsWith("color-")) {
            DrawColorSwatch(graphics, rect, iconColor);
            return;
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
            else if (IconKind == "rect") {
                graphics.DrawRectangle(pen, new Rectangle(cx - 10, cy - 7, 20, 14));
            }
            else if (IconKind == "ellipse") {
                graphics.DrawEllipse(pen, new Rectangle(cx - 10, cy - 7, 20, 14));
            }
            else if (IconKind == "arrow") {
                pen.EndCap = System.Drawing.Drawing2D.LineCap.ArrowAnchor;
                graphics.DrawLine(pen, cx - 10, cy + 7, cx + 9, cy - 7);
            }
            else if (IconKind == "long") {
                DrawLongIcon(graphics, pen, cx, cy);
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

    private void DrawLongIcon(Graphics graphics, Pen pen, int cx, int cy) {
        Rectangle page = new Rectangle(cx - 8, cy - 11, 16, 22);
        graphics.DrawRectangle(pen, page);
        graphics.DrawLine(pen, cx - 4, cy - 5, cx + 4, cy - 5);
        graphics.DrawLine(pen, cx - 4, cy, cx + 4, cy);
        graphics.DrawLine(pen, cx, cy + 3, cx, cy + 10);
        graphics.DrawLine(pen, cx - 4, cy + 6, cx, cy + 10);
        graphics.DrawLine(pen, cx + 4, cy + 6, cx, cy + 10);
    }

    private Color GetSwatchColor(string kind) {
        if (kind == "color-yellow") {
            return Color.FromArgb(245, 158, 11);
        }
        if (kind == "color-green") {
            return Color.FromArgb(34, 197, 94);
        }
        if (kind == "color-blue") {
            return Color.FromArgb(59, 130, 246);
        }
        if (kind == "color-purple") {
            return Color.FromArgb(168, 85, 247);
        }
        if (kind == "color-black") {
            return Color.FromArgb(17, 24, 39);
        }
        return Color.FromArgb(239, 68, 68);
    }

    private void DrawColorSwatch(Graphics graphics, Rectangle rect, Color color) {
        int size = 18;
        Rectangle swatch = new Rectangle(rect.Left + (rect.Width - size) / 2, rect.Top + (rect.Height - size) / 2, size, size);
        using (Brush brush = new SolidBrush(color)) {
            graphics.FillEllipse(brush, swatch);
        }
        using (Pen pen = new Pen(Color.FromArgb(71, 85, 105), 1)) {
            graphics.DrawEllipse(pen, swatch);
        }
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

public sealed class ColorPalettePanel : Control {
    private readonly Color[] colors = new Color[] {
        Color.FromArgb(239, 68, 68),
        Color.FromArgb(245, 158, 11),
        Color.FromArgb(34, 197, 94),
        Color.FromArgb(59, 130, 246),
        Color.FromArgb(168, 85, 247),
        Color.FromArgb(17, 24, 39)
    };
    private int hoverIndex = -1;

    public delegate void ColorSelectedHandler(Color color);
    public event ColorSelectedHandler ColorSelected;

    public ColorPalettePanel() {
        SetStyle(ControlStyles.UserPaint | ControlStyles.AllPaintingInWmPaint | ControlStyles.OptimizedDoubleBuffer, true);
        BackColor = Color.FromArgb(248, 250, 252);
        Cursor = Cursors.Hand;
    }

    protected override void OnPaintBackground(PaintEventArgs e) {
        e.Graphics.SmoothingMode = System.Drawing.Drawing2D.SmoothingMode.AntiAlias;
        using (Brush brush = new SolidBrush(BackColor)) {
            e.Graphics.FillRectangle(brush, ClientRectangle);
        }
    }

    protected override void OnMouseMove(MouseEventArgs e) {
        int index = HitTest(e.Location);
        if (index != hoverIndex) {
            hoverIndex = index;
            Invalidate();
        }
        base.OnMouseMove(e);
    }

    protected override void OnMouseLeave(EventArgs e) {
        hoverIndex = -1;
        Invalidate();
        base.OnMouseLeave(e);
    }

    protected override void OnMouseClick(MouseEventArgs e) {
        int index = HitTest(e.Location);
        if (index >= 0 && ColorSelected != null) {
            ColorSelected(colors[index]);
        }
        base.OnMouseClick(e);
    }

    protected override void OnPaint(PaintEventArgs e) {
        e.Graphics.SmoothingMode = System.Drawing.Drawing2D.SmoothingMode.AntiAlias;
        Rectangle bg = new Rectangle(1, 1, Width - 3, Height - 3);
        using (System.Drawing.Drawing2D.GraphicsPath bgPath = RoundedPath(bg, 10)) {
            using (Brush fill = new SolidBrush(Color.FromArgb(248, 250, 252))) {
                e.Graphics.FillPath(fill, bgPath);
            }
            using (Pen border = new Pen(Color.FromArgb(148, 163, 184), 1)) {
                e.Graphics.DrawPath(border, bgPath);
            }
        }

        for (int i = 0; i < colors.Length; i++) {
            Rectangle rect = GetColorRect(i);
            using (Brush brush = new SolidBrush(colors[i])) {
                e.Graphics.FillEllipse(brush, rect);
            }
            if (i == hoverIndex) {
                using (Pen pen = new Pen(Color.FromArgb(37, 99, 235), 2)) {
                    e.Graphics.DrawEllipse(pen, rect);
                }
            }
        }
    }

    private int HitTest(Point point) {
        for (int i = 0; i < colors.Length; i++) {
            if (GetColorRect(i).Contains(point)) {
                return i;
            }
        }
        return -1;
    }

    private Rectangle GetColorRect(int index) {
        return new Rectangle(9, 9 + index * 29, 22, 22);
    }

    private static System.Drawing.Drawing2D.GraphicsPath RoundedPath(Rectangle rect, int radius) {
        System.Drawing.Drawing2D.GraphicsPath path = new System.Drawing.Drawing2D.GraphicsPath();
        int diameter = radius * 2;
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
                elseif ($previewResult -eq [System.Windows.Forms.DialogResult]::Ignore) {
                    $keepPreviewOpen = $false
                    $longWindow = New-Object LongScreenshotSession -ArgumentList @($selector.CaptureBounds, $Directory)
                    try {
                        $longWindow.ShowDialog() | Out-Null
                        if ($longWindow.Action -eq "Preview" -and $longWindow.CapturePath) {
                            $longPreviewOpen = $true
                            while ($longPreviewOpen) {
                                $longPreview = New-Object CapturePreview -ArgumentList @($longWindow.CapturePath, $Directory, $longWindow.PreviewLocation, $false)
                                try {
                                    $longPreviewResult = $longPreview.ShowDialog()
                                    if ($longPreviewResult -eq [System.Windows.Forms.DialogResult]::Retry) {
                                        $longPreviewOpen = $false
                                        try {
                                            $text = Invoke-ImageOcr -ImagePath $longWindow.CapturePath
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
                                    elseif ($longPreviewResult -eq [System.Windows.Forms.DialogResult]::OK) {
                                        Write-Host "Long screenshot copied."
                                        $longPreviewOpen = $false
                                    }
                                    elseif ($longPreviewResult -eq [System.Windows.Forms.DialogResult]::Yes) {
                                        Write-Host "Long screenshot saved: $($longPreview.SavedPath)"
                                        $longPreviewOpen = $false
                                    }
                                    else {
                                        Write-Host "Canceled."
                                        $longPreviewOpen = $false
                                    }
                                }
                                finally {
                                    $longPreview.Dispose()
                                }
                            }
                        }
                        else {
                            Write-Host "Canceled."
                        }
                    }
                    finally {
                        $longWindow.Dispose()
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
