# GitHub 第一次发布（v0.1.1）

1. 登录 https://github.com/new ，仓库名填 `StarlitChronicle-HD2D`。
2. 选择 **Private**，不要勾选 Initialize with a README、.gitignore 或 License（本工程已经包含 README 和 .gitignore）。
3. 点击 Create repository。
4. 在 Windows 安装 Git for Windows（如已安装可跳过）。
5. 解压本 ZIP，在解压后的文件夹打开 PowerShell，执行：

   `powershell -ExecutionPolicy Bypass -File .\PUBLISH_TO_GITHUB.ps1`

6. 首次推送可能需要在浏览器中登录 GitHub。成功后刷新仓库主页。

工程文件必须在仓库根目录：`project.godot`、`codemagic.yaml`、`scripts/`、`assets/` 等，不能多嵌套一层文件夹。

如果你不想使用 Git 命令，也可以创建空仓库后在网页上传解压出来的文件；注意保留文件夹层次。
