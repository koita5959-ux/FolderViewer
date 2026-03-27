using System.IO;
using System.Windows.Forms;

namespace DesktopKit.FolderViewer
{
    /// <summary>
    /// 指定フォルダからTreeViewノードを構築する。階層制限対応。
    /// フォルダノードにはチェックボックスを付与し、出力対象の選択を可能にする。
    /// </summary>
    public static class TreeBuilder
    {
        public const int IconFolder = 0;
        public const int IconFile = 1;

        /// <summary>
        /// 指定パスを起点にTreeViewを構築する。
        /// </summary>
        public static (int folders, int files) Build(TreeView treeView, string rootPath, int maxDepth)
        {
            treeView.BeginUpdate();
            treeView.Nodes.Clear();

            var rootNode = new TreeNode(Path.GetFileName(rootPath))
            {
                Tag = rootPath,
                Checked = true,
                ImageIndex = IconFolder,
                SelectedImageIndex = IconFolder
            };
            treeView.Nodes.Add(rootNode);

            int folders = 0;
            int files = 0;
            AddChildren(rootNode, rootPath, 1, maxDepth, ref folders, ref files);

            rootNode.ExpandAll();
            treeView.EndUpdate();

            return (folders, files);
        }

        /// <summary>
        /// チェックONになったフォルダノードの子を構築する。
        /// </summary>
        public static void ExpandCheckedFolder(TreeNode folderNode, int maxDepth, int currentDepth)
        {
            if (folderNode.Tag is not string dirPath) return;

            folderNode.Nodes.Clear();
            int folders = 0, files = 0;
            AddChildren(folderNode, dirPath, currentDepth, maxDepth, ref folders, ref files);
            folderNode.ExpandAll();
        }

        /// <summary>
        /// ノードの階層深さ（ルート=0）を返す。
        /// </summary>
        public static int GetNodeDepth(TreeNode node)
        {
            int depth = 0;
            var current = node.Parent;
            while (current != null)
            {
                depth++;
                current = current.Parent;
            }
            return depth;
        }

        /// <summary>
        /// ノードがフォルダかどうかを判定する。
        /// </summary>
        public static bool IsFolder(TreeNode node)
        {
            return node.ImageIndex == IconFolder;
        }

        /// <summary>
        /// 指定フォルダ配下の最深階層数を計算する。
        /// アクセス権限のないフォルダはスキップ。空フォルダは1を返す。
        /// </summary>
        public static int CalcMaxDepth(string rootPath)
        {
            int maxDepth = 0;
            CalcDepthRecursive(rootPath, 1, ref maxDepth);
            return Math.Max(maxDepth, 1);
        }

        private static void CalcDepthRecursive(string dirPath, int currentDepth, ref int maxDepth)
        {
            try
            {
                var dirs = Directory.GetDirectories(dirPath);
                if (dirs.Length == 0)
                {
                    if (currentDepth > maxDepth) maxDepth = currentDepth;
                    return;
                }
                foreach (var dir in dirs)
                {
                    CalcDepthRecursive(dir, currentDepth + 1, ref maxDepth);
                }
            }
            catch (UnauthorizedAccessException)
            {
                if (currentDepth > maxDepth) maxDepth = currentDepth;
            }
            catch (IOException)
            {
                if (currentDepth > maxDepth) maxDepth = currentDepth;
            }
        }

        private static void AddChildren(TreeNode parentNode, string dirPath, int currentDepth, int maxDepth, ref int folders, ref int files)
        {
            // フォルダを追加
            try
            {
                foreach (var dir in Directory.GetDirectories(dirPath))
                {
                    var dirName = Path.GetFileName(dir);
                    var node = new TreeNode(dirName)
                    {
                        Tag = dir,
                        Checked = true,
                        ImageIndex = IconFolder,
                        SelectedImageIndex = IconFolder
                    };
                    parentNode.Nodes.Add(node);
                    folders++;

                    if (currentDepth < maxDepth)
                    {
                        AddChildren(node, dir, currentDepth + 1, maxDepth, ref folders, ref files);
                    }
                }
            }
            catch (UnauthorizedAccessException) { }
            catch (IOException) { }

            // ファイルを追加
            try
            {
                foreach (var file in Directory.GetFiles(dirPath))
                {
                    var fileName = Path.GetFileName(file);
                    var node = new TreeNode(fileName)
                    {
                        Tag = file,
                        ImageIndex = IconFile,
                        SelectedImageIndex = IconFile
                    };
                    parentNode.Nodes.Add(node);
                    files++;
                }
            }
            catch (UnauthorizedAccessException) { }
            catch (IOException) { }
        }
    }
}
