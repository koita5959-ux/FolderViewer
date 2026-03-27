using System.IO;
using System.Text;
using System.Windows.Forms;

namespace DesktopKit.FolderViewer
{
    /// <summary>
    /// TreeViewからツリー形式テキスト＋フルパス一覧を生成する。
    /// チェックOFFのフォルダは「（省略）」付きで出力し、子の展開はしない。
    /// </summary>
    public static class TreeExporter
    {
        /// <summary>
        /// TreeViewの内容をテキストファイルに書き出す。
        /// </summary>
        /// <param name="treeView">対象のTreeView</param>
        /// <param name="outputPath">出力ファイルパス</param>
        /// <param name="includeFullPaths">フルパス一覧セクションを含めるか</param>
        public static void Export(TreeView treeView, string outputPath, bool includeFullPaths)
        {
            var sb = new StringBuilder();
            var fullPaths = new List<string>();

            sb.AppendLine("--- ツリー構造 ---");

            if (treeView.Nodes.Count > 0)
            {
                var rootNode = treeView.Nodes[0];
                var rootPath = rootNode.Tag as string ?? "";
                sb.AppendLine(rootPath + Path.DirectorySeparatorChar);
                BuildTreeText(rootNode, "", sb, fullPaths);
            }

            if (includeFullPaths)
            {
                sb.AppendLine();
                sb.AppendLine("--- フルパス一覧 ---");
                foreach (var path in fullPaths)
                {
                    sb.AppendLine(path);
                }
            }

            File.WriteAllText(outputPath, sb.ToString(), Encoding.UTF8);
        }

        private static void BuildTreeText(TreeNode parentNode, string indent, StringBuilder sb, List<string> fullPaths)
        {
            for (int i = 0; i < parentNode.Nodes.Count; i++)
            {
                var node = parentNode.Nodes[i];
                bool isLast = (i == parentNode.Nodes.Count - 1);
                var connector = isLast ? "└── " : "├── ";
                var childIndent = indent + (isLast ? "    " : "│   ");

                bool isFolder = TreeBuilder.IsFolder(node);

                if (isFolder)
                {
                    // フォルダのフルパスは常に収集
                    if (node.Tag is string dirPath)
                    {
                        fullPaths.Add(dirPath);
                    }

                    if (node.Checked && node.Nodes.Count > 0)
                    {
                        // チェックON → フォルダ名を出力し、子を再帰展開
                        sb.AppendLine(indent + connector + node.Text);
                        BuildTreeText(node, childIndent, sb, fullPaths);
                    }
                    else
                    {
                        // チェックOFF → フォルダ名＋（省略）を出力、子は展開しない
                        sb.AppendLine(indent + connector + node.Text + "（省略）");
                    }
                }
                else
                {
                    // ファイル
                    sb.AppendLine(indent + connector + node.Text);
                    if (node.Tag is string filePath)
                    {
                        fullPaths.Add(filePath);
                    }
                }
            }
        }
    }
}
