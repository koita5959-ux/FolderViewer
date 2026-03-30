using System.Drawing;
using System.IO;
using System.Runtime.InteropServices;
using System.Text.Json;
using System.Windows.Forms;
using DesktopKit.Common;

namespace DesktopKit.FolderViewer
{
    /// <summary>
    /// FolderViewer（フォルダ構造ビューア）のメインフォーム。
    /// </summary>
    public class MainForm : BaseForm
    {
        // --- Win32 API: ノード単位のチェックボックス表示制御 ---
        private const int TVIF_STATE = 0x0008;
        private const int TVIS_STATEIMAGEMASK = 0xF000;
        private const int TV_FIRST = 0x1100;
        private const int TVM_SETITEM = TV_FIRST + 63; // TVM_SETITEMW

        [StructLayout(LayoutKind.Sequential, CharSet = CharSet.Unicode)]
        private struct TVITEM
        {
            public int mask;
            public IntPtr hItem;
            public int state;
            public int stateMask;
            public IntPtr pszText;
            public int cchTextMax;
            public int iImage;
            public int iSelectedImage;
            public int cChildren;
            public IntPtr lParam;
        }

        [DllImport("user32.dll", CharSet = CharSet.Unicode)]
        private static extern IntPtr SendMessage(IntPtr hWnd, int Msg, IntPtr wParam, ref TVITEM lParam);

        private Button btnSelectFolder = null!;
        private TextBox txtFolderPath = null!;
        private Label lblDepth = null!;
        private NumericUpDown nudDepth = null!;
        private TreeView tvFolderTree = null!;
        private Button btnExport = null!;
        private CheckBox chkFullPaths = null!;
        private ContextMenuStrip contextMenu = null!;
        private ImageList treeImageList = null!;

        private string _currentRootPath = "";
        private bool _suppressCheckEvent = false;

        private static readonly string SettingsDir = Path.Combine(
            Environment.GetFolderPath(Environment.SpecialFolder.ApplicationData), "DesktopKit");
        private static readonly string SettingsFile = Path.Combine(SettingsDir, "FolderViewer.json");

        public MainForm()
        {
            ComponentName = "FolderViewer";
            InitializeControls();
        }

        private void InitializeControls()
        {
            // --- アイコン用ImageList ---
            treeImageList = new ImageList { ImageSize = new Size(16, 16), ColorDepth = ColorDepth.Depth32Bit };
            treeImageList.Images.Add(CreateFolderIcon());   // index 0: フォルダ
            treeImageList.Images.Add(CreateFileIcon());     // index 1: ファイル

            // --- 上部パネル: フォルダ選択 + 階層の深さ ---
            var topPanel = new Panel
            {
                Dock = DockStyle.Top,
                Height = 70,
                Padding = new Padding(10, 10, 10, 5)
            };

            btnSelectFolder = new Button
            {
                Text = "フォルダを選択",
                Location = new Point(10, 8),
                Size = new Size(120, 28)
            };
            btnSelectFolder.Click += BtnSelectFolder_Click;

            txtFolderPath = new TextBox
            {
                ReadOnly = true,
                Location = new Point(140, 10),
                Size = new Size(topPanel.ClientSize.Width - 140 - 20, 23),
                Anchor = AnchorStyles.Top | AnchorStyles.Left | AnchorStyles.Right
            };

            lblDepth = new Label
            {
                Text = "階層の深さ:",
                Location = new Point(10, 42),
                AutoSize = true
            };

            nudDepth = new NumericUpDown
            {
                Value = 5,
                Minimum = 1,
                Maximum = 20,
                Location = new Point(110, 40),
                Size = new Size(60, 23)
            };
            nudDepth.ValueChanged += NudDepth_ValueChanged;

            topPanel.Controls.AddRange(new Control[] { btnSelectFolder, txtFolderPath, lblDepth, nudDepth });

            // --- 中央: TreeView ---
            tvFolderTree = new TreeView
            {
                Dock = DockStyle.Fill,
                CheckBoxes = true,
                ImageList = treeImageList
            };
            tvFolderTree.AfterCheck += TvFolderTree_AfterCheck;

            // コンテキストメニュー
            contextMenu = new ContextMenuStrip();
            var menuItem = new ToolStripMenuItem("ここを起点にする");
            menuItem.Click += MenuSetRoot_Click;
            contextMenu.Items.Add(menuItem);
            tvFolderTree.MouseDown += TvFolderTree_MouseDown;

            // --- 下部パネル: オプション + 書き出しボタン（右寄せ） ---
            var bottomPanel = new Panel
            {
                Dock = DockStyle.Bottom,
                Height = 45,
                Padding = new Padding(10, 5, 10, 5)
            };

            chkFullPaths = new CheckBox
            {
                Text = "フルパス一覧を含める",
                Location = new Point(10, 11),
                AutoSize = true,
                Checked = true
            };

            btnExport = new Button
            {
                Text = "書き出し",
                Size = new Size(100, 28),
                Anchor = AnchorStyles.Top | AnchorStyles.Right
            };
            btnExport.Location = new Point(bottomPanel.ClientSize.Width - bottomPanel.Padding.Right - btnExport.Width, 8);
            btnExport.Click += BtnExport_Click;

            bottomPanel.Controls.AddRange(new Control[] { chkFullPaths, btnExport });

            // --- フォームに追加（順序重要: Fill は最後に追加） ---
            Controls.Add(tvFolderTree);
            Controls.Add(topPanel);
            Controls.Add(bottomPanel);

            // StatusBar（リサイズグリップ）をウィンドウ最下層に配置
            StatusBar.SendToBack();
        }

        // --- アイコン生成 ---

        private static Bitmap CreateFolderIcon()
        {
            var bmp = new Bitmap(16, 16);
            using var g = Graphics.FromImage(bmp);
            g.SmoothingMode = System.Drawing.Drawing2D.SmoothingMode.AntiAlias;

            // フォルダのタブ部分
            using var brush = new SolidBrush(Color.FromArgb(255, 200, 80));
            using var pen = new Pen(Color.FromArgb(180, 140, 50));
            g.FillRectangle(brush, 1, 2, 5, 2);
            // フォルダ本体
            g.FillRectangle(brush, 1, 4, 14, 9);
            g.DrawRectangle(pen, 1, 4, 13, 8);
            g.DrawLine(pen, 1, 2, 5, 2);
            g.DrawLine(pen, 5, 2, 6, 4);

            return bmp;
        }

        private static Bitmap CreateFileIcon()
        {
            var bmp = new Bitmap(16, 16);
            using var g = Graphics.FromImage(bmp);
            g.SmoothingMode = System.Drawing.Drawing2D.SmoothingMode.AntiAlias;

            // 書類の本体
            using var brush = new SolidBrush(Color.FromArgb(240, 240, 245));
            using var pen = new Pen(Color.FromArgb(130, 130, 150));
            var body = new Point[] { new(3, 1), new(10, 1), new(13, 4), new(13, 14), new(3, 14) };
            g.FillPolygon(brush, body);
            g.DrawPolygon(pen, body);
            // 折り返し部分
            g.DrawLine(pen, 10, 1, 10, 4);
            g.DrawLine(pen, 10, 4, 13, 4);
            // テキスト行（装飾線）
            using var linePen = new Pen(Color.FromArgb(180, 180, 200));
            g.DrawLine(linePen, 5, 7, 11, 7);
            g.DrawLine(linePen, 5, 9, 11, 9);
            g.DrawLine(linePen, 5, 11, 9, 11);

            return bmp;
        }

        // --- イベントハンドラ ---

        private void BtnSelectFolder_Click(object? sender, EventArgs e)
        {
            using var dialog = new FolderBrowserDialog
            {
                Description = "表示するフォルダを選択してください"
            };

            if (dialog.ShowDialog() == DialogResult.OK)
            {
                SetRootAndBuild(dialog.SelectedPath);
            }
        }

        private void NudDepth_ValueChanged(object? sender, EventArgs e)
        {
            if (!string.IsNullOrEmpty(_currentRootPath) && Directory.Exists(_currentRootPath))
            {
                BuildTree();
            }
        }

        private void TvFolderTree_AfterCheck(object? sender, TreeViewEventArgs e)
        {
            if (_suppressCheckEvent || e.Node == null) return;
            if (!TreeBuilder.IsFolder(e.Node)) return;

            _suppressCheckEvent = true;
            try
            {
                if (e.Node.Checked)
                {
                    // チェックON → 子ノードを構築して展開
                    int depth = TreeBuilder.GetNodeDepth(e.Node);
                    TreeBuilder.ExpandCheckedFolder(e.Node, (int)nudDepth.Value, depth + 1);
                    HideFileCheckBoxes(e.Node.Nodes);
                }
                else
                {
                    // チェックOFF → 子ノードを削除して折りたたむ
                    e.Node.Nodes.Clear();
                    e.Node.Collapse();
                }
            }
            finally
            {
                _suppressCheckEvent = false;
            }
        }

        private void TvFolderTree_MouseDown(object? sender, MouseEventArgs e)
        {
            if (e.Button == MouseButtons.Right)
            {
                var hitNode = tvFolderTree.GetNodeAt(e.X, e.Y);
                if (hitNode != null && hitNode.Tag is string path && Directory.Exists(path))
                {
                    tvFolderTree.SelectedNode = hitNode;
                    contextMenu.Show(tvFolderTree, e.Location);
                }
            }
        }

        private void MenuSetRoot_Click(object? sender, EventArgs e)
        {
            if (tvFolderTree.SelectedNode?.Tag is string path && Directory.Exists(path))
            {
                SetRootAndBuild(path);
            }
        }

        private void BtnExport_Click(object? sender, EventArgs e)
        {
            if (tvFolderTree.Nodes.Count == 0)
            {
                MessageBox.Show("先にフォルダを選択してください。", "FolderViewer", MessageBoxButtons.OK, MessageBoxIcon.Information);
                return;
            }

            var folderName = Path.GetFileName(_currentRootPath);
            var defaultFileName = $"{folderName}_構造_{DateTime.Now:yyyyMMdd}.txt";

            using var dialog = new SaveFileDialog
            {
                Filter = "テキストファイル (*.txt)|*.txt|すべてのファイル (*.*)|*.*",
                FileName = defaultFileName
            };

            var lastDir = LoadLastSaveDirectory();
            if (!string.IsNullOrEmpty(lastDir) && Directory.Exists(lastDir))
            {
                dialog.InitialDirectory = lastDir;
            }

            if (dialog.ShowDialog() == DialogResult.OK)
            {
                TreeExporter.Export(tvFolderTree, dialog.FileName, chkFullPaths.Checked);
                SaveLastSaveDirectory(Path.GetDirectoryName(dialog.FileName) ?? "");
                StatusLabel.Text = $"書き出し完了: {dialog.FileName}";
            }
        }

        // --- ヘルパー ---

        private void SetRootAndBuild(string rootPath)
        {
            _currentRootPath = rootPath;
            txtFolderPath.Text = rootPath;

            // 最深階層を計算してNumericUpDownに反映
            var depth = TreeBuilder.CalcMaxDepth(rootPath);
            nudDepth.ValueChanged -= NudDepth_ValueChanged;
            nudDepth.Maximum = depth;
            nudDepth.Value = depth;
            nudDepth.ValueChanged += NudDepth_ValueChanged;

            BuildTree();
        }

        private void BuildTree()
        {
            _suppressCheckEvent = true;
            try
            {
                var (folders, files) = TreeBuilder.Build(tvFolderTree, _currentRootPath, (int)nudDepth.Value);
                HideFileCheckBoxes(tvFolderTree.Nodes);
                StatusLabel.Text = $"{folders}フォルダ、{files}ファイルを表示中";
            }
            finally
            {
                _suppressCheckEvent = false;
            }
        }

        /// <summary>
        /// ファイルノードのチェックボックスを非表示にする（再帰）。
        /// </summary>
        private void HideFileCheckBoxes(TreeNodeCollection nodes)
        {
            foreach (TreeNode node in nodes)
            {
                if (!TreeBuilder.IsFolder(node))
                {
                    HideCheckBox(node);
                }
                if (node.Nodes.Count > 0)
                {
                    HideFileCheckBoxes(node.Nodes);
                }
            }
        }

        /// <summary>
        /// 指定ノードのチェックボックスを非表示にする（Win32 API）。
        /// </summary>
        private void HideCheckBox(TreeNode node)
        {
            if (tvFolderTree.IsDisposed || !tvFolderTree.IsHandleCreated) return;

            var tvi = new TVITEM
            {
                hItem = node.Handle,
                mask = TVIF_STATE,
                stateMask = TVIS_STATEIMAGEMASK,
                state = 0
            };
            SendMessage(tvFolderTree.Handle, TVM_SETITEM, IntPtr.Zero, ref tvi);
        }

        // --- 設定の保存・読み込み ---

        private string? LoadLastSaveDirectory()
        {
            try
            {
                if (File.Exists(SettingsFile))
                {
                    var json = File.ReadAllText(SettingsFile);
                    var dict = JsonSerializer.Deserialize<Dictionary<string, string>>(json);
                    if (dict != null && dict.TryGetValue("LastSaveDirectory", out var dir))
                        return dir;
                }
            }
            catch { }
            return null;
        }

        private void SaveLastSaveDirectory(string directory)
        {
            try
            {
                Directory.CreateDirectory(SettingsDir);
                var dict = new Dictionary<string, string> { ["LastSaveDirectory"] = directory };
                File.WriteAllText(SettingsFile, JsonSerializer.Serialize(dict));
            }
            catch { }
        }
    }
}
