# --------------------------------------------------------
# 1. 定义要移动的已解压程序文件夹
# 注意：你需要将这个脚本和你的程序文件夹放在同一个目录下
# --------------------------------------------------------
$SourceFolderName = "Yunzai"

# --------------------------------------------------------
# 2. 加载所需的.NET程序集
# --------------------------------------------------------
Add-Type -AssemblyName System.Windows.Forms
Add-Type -AssemblyName System.Drawing

# --------------------------------------------------------
# 3. 创建主窗体 (Form)
# --------------------------------------------------------
$Form = New-Object System.Windows.Forms.Form
$Form.Text = "Yunzai 安装程序"
$Form.Size = New-Object System.Drawing.Size(450, 160)
$Form.StartPosition = "CenterScreen"
$Form.FormBorderStyle = [System.Windows.Forms.FormBorderStyle]::FixedSingle
$Form.MaximizeBox = $false

# --------------------------------------------------------
# 4. 添加控件
# --------------------------------------------------------

# 标签
$Label = New-Object System.Windows.Forms.Label
$Label.Text = "请选择程序的安装位置："
$Label.Location = New-Object System.Drawing.Point(10, 20)
$Label.AutoSize = $true
$Form.Controls.Add($Label)

# 文本框（显示和输入路径）
$TextBox = New-Object System.Windows.Forms.TextBox
$DefaultPath = Join-Path (Join-Path ($env:LOCALAPPDATA) "Programs") $SourceFolderName
$TextBox.Text = $DefaultPath
$TextBox.Location = New-Object System.Drawing.Point(10, 45)
$TextBox.Size = New-Object System.Drawing.Size(350, 20)
$Form.Controls.Add($TextBox)

# 浏览按钮
$BrowseButton = New-Object System.Windows.Forms.Button
$BrowseButton.Text = "浏览..."
$BrowseButton.Location = New-Object System.Drawing.Point(370, 43)
$BrowseButton.Size = New-Object System.Drawing.Size(50, 23)
# 绑定点击事件
$BrowseButton.Add_Click({
  $FolderBrowser = New-Object System.Windows.Forms.FolderBrowserDialog
  $FolderBrowser.SelectedPath = $TextBox.Text
  if ($FolderBrowser.ShowDialog() -eq [System.Windows.Forms.DialogResult]::OK) {
    # 确保路径以程序文件夹名结尾
    if ((Split-Path -Path $FolderBrowser.SelectedPath -Leaf) -eq $SourceFolderName) {
      $TextBox.Text = $FolderBrowser.SelectedPath
    } else {
      $TextBox.Text = Join-Path $FolderBrowser.SelectedPath $SourceFolderName
    }
  }
})
$Form.Controls.Add($BrowseButton)

# 安装按钮
$InstallButton = New-Object System.Windows.Forms.Button
$InstallButton.Text = "开始安装"
$InstallButton.Location = New-Object System.Drawing.Point(175, 75)
$InstallButton.Size = New-Object System.Drawing.Size(80, 30)

# 绑定点击事件（核心逻辑）
$InstallButton.Add_Click({
  $DestinationPath = $TextBox.Text
  $SourcePath = Join-Path (Get-Location) ($SourceFolderName + ".tar")

  # 检查目标文件夹是否已存在，如果存在则询问是否覆盖
  if (Test-Path $DestinationPath) {
    $MsgResult = [System.Windows.Forms.MessageBox]::Show("目标文件夹已存在，是否覆盖？", "警告", [System.Windows.Forms.MessageBoxButtons]::YesNo, [System.Windows.Forms.MessageBoxIcon]::Warning)
    if ($MsgResult -eq [System.Windows.Forms.DialogResult]::No) {
      return # 用户选择不覆盖，取消操作
    }
  }

  # 显示进度条窗体
  $ProgressForm = New-Object System.Windows.Forms.Form
  $ProgressForm.Text = "安装进行中..."
  $ProgressForm.Size = New-Object System.Drawing.Size(340, 150)
  $ProgressForm.StartPosition = "CenterScreen"
  $ProgressForm.FormBorderStyle = [System.Windows.Forms.FormBorderStyle]::FixedDialog
  $ProgressForm.ControlBox = $false # 禁用关闭按钮
  $ProgressForm.MinimizeBox = $false

  # 进度条
  $ProgressBar = New-Object System.Windows.Forms.ProgressBar
  $ProgressBar.Location = New-Object System.Drawing.Point(20, 20)
  $ProgressBar.Size = New-Object System.Drawing.Size(280, 20)
  $ProgressBar.Maximum = 100  # 设置最大值（百分比）
  $ProgressBar.Minimum = 0
  $ProgressForm.Controls.Add($ProgressBar)

  # 状态标签
  $StatusLabel = New-Object System.Windows.Forms.Label
  $StatusLabel.Text = "正在清理文件..."
  $StatusLabel.Location = New-Object System.Drawing.Point(20, 60)
  $StatusLabel.Size = New-Object System.Drawing.Size(300, 40)
  $ProgressForm.Controls.Add($StatusLabel)
  $ProgressForm.Show()
  # 刷新进度条窗体，确保它立即显示
  $ProgressForm.Refresh()
  [System.Windows.Forms.Application]::DoEvents()

  $OriginalErrorAction = $ErrorActionPreference
  $ErrorActionPreference = "Stop"
  # 执行安装
  try {
    if (Test-Path $DestinationPath) {
      if (Test-Path (Join-Path $DestinationPath "app") -Type Container) {
        $MsgResult = [System.Windows.Forms.MessageBox]::Show("是否保留数据？", "警告", [System.Windows.Forms.MessageBoxButtons]::YesNo, [System.Windows.Forms.MessageBoxIcon]::Warning)
        if ($MsgResult -eq [System.Windows.Forms.DialogResult]::Yes) {
          Get-ChildItem -Path $DestinationPath -Exclude "app" | Remove-Item -Recurse -Force
        } else {
          Remove-Item -Path $DestinationPath -Recurse -Force
        }
      } else {
        Remove-Item -Path $DestinationPath -Recurse -Force
      }
    }

    $StatusLabel.Text = "正在解压文件..."
    $ProgressBar.Value = 10
    $ProgressForm.Refresh()
    & (Join-Path (Get-Location) "7z.exe") x ("-o" + (Get-Location)) ($SourcePath + ".zst") | Write-Host
    if ($LASTEXITCODE -ne 0) {
      throw "解压错误 ($LASTEXITCODE) 请检查控制台"
    }

    $StatusLabel.Text = "正在释放文件..."
    $ProgressBar.Value = 37
    $ProgressForm.Refresh()
    & (Join-Path (Get-Location) "7z.exe") x ("-o" + $DestinationPath) $SourcePath | Write-Host
    if ($LASTEXITCODE -ne 0) {
      throw "释放错误 ($LASTEXITCODE) 请检查控制台"
    }

    $StatusLabel.Text = "正在安装程序..."
    $ProgressBar.Value = 64
    $ProgressForm.Refresh()
    & (Join-Path $DestinationPath "msys2_shell.cmd") -defterm -here -no-start -ucrt64 -c '""' | Write-Host
    if ($LASTEXITCODE -ne 0) {
      throw "安装错误 ($LASTEXITCODE) 请检查控制台"
    }

    $StatusLabel.Text = "正在创建快捷方式..."
    $ProgressBar.Value = 90
    $ProgressForm.Refresh()
    $DestinationName = Split-Path -Path $DestinationPath -Leaf
    $StartMenu = Join-Path (Join-Path ([System.Environment]::GetFolderPath("StartMenu")) "Programs") $DestinationName
    $Desktop = [System.Environment]::GetFolderPath("Desktop")
    New-Item -Path $StartMenu -ItemType Directory -Force
    $UninstallCommand = "/c rd /s ""$DestinationPath""||exit&rd /s /q ""$StartMenu"""

    $File = Join-Path $Desktop ($DestinationName + ".lnk")
    $ShortCut = (New-Object -ComObject WScript.Shell).CreateShortcut($File)
    $ShortCut.TargetPath = Join-Path $DestinationPath "start.cmd"
    $ShortCut.Save()
    $UninstallCommand += "&del /f /s /q ""$File"""
    Copy-Item -Path $File -Destination $StartMenu

    $File = Join-Path $Desktop ($DestinationName + " 命令行.lnk")
    $ShortCut = (New-Object -ComObject WScript.Shell).CreateShortcut($File)
    $ShortCut.TargetPath = Join-Path $DestinationPath "msys2_shell.cmd"
    $ShortCut.Arguments = "-defterm -here -no-start -ucrt64"
    $ShortCut.WorkingDirectory = Join-Path $DestinationPath "app"
    $ShortCut.Save()
    $UninstallCommand += " ""$File"""
    Copy-Item -Path $File -Destination $StartMenu

    $File = Join-Path $StartMenu ("卸载 " + $DestinationName + ".lnk")
    $ShortCut = (New-Object -ComObject WScript.Shell).CreateShortcut($File)
    $ShortCut.TargetPath = "cmd.exe"
    $ShortCut.Arguments = $UninstallCommand
    $ShortCut.Save()

    $ProgressForm.Text = "安装成功"
    $StatusLabel.Text = "程序已成功安装到：$DestinationPath"
    $ProgressBar.Style = [System.Windows.Forms.ProgressBarStyle]::Continuous
    $ProgressBar.Value = 100

    # 添加一个“完成”按钮让用户点击后关闭
    $DoneButton = New-Object System.Windows.Forms.Button
    $DoneButton.Text = "完成"
  } catch {
    if (Test-Path $DestinationPath) {
      $StatusLabel.Text = "正在清理文件..."
      $ProgressForm.Refresh()
      if ((Test-Path (Join-Path $DestinationPath "app") -Type Container) -and ($MsgResult -eq [System.Windows.Forms.DialogResult]::Yes)) {
        Get-ChildItem -Path $DestinationPath -Exclude "app" | Remove-Item -Recurse -Force -ErrorAction Continue
      } else {
        Remove-Item -Path $DestinationPath -Recurse -Force -ErrorAction Continue
      }
    }

    # 捕获错误并显示
    $ProgressForm.Text = "安装失败"
    $StatusLabel.Text = $_.Exception.Message
    Write-Host -Foreground Red $_.Exception
    $DoneButton = New-Object System.Windows.Forms.Button
    $DoneButton.Text = "关闭"
  }

  $ErrorActionPreference = $OriginalErrorAction
  # 启用关闭按钮，允许用户自行关闭窗口
  $ProgressForm.ControlBox = $true 
  $DoneButton.Location = New-Object System.Drawing.Point(120, 120)
  $DoneButton.Size = New-Object System.Drawing.Size(80, 30)
  $DoneButton.Add_Click({ $Form.Close() })
  $ProgressForm.Controls.Add($DoneButton)
  $ProgressForm.Size = New-Object System.Drawing.Size(340, 200)
  $ProgressForm.Refresh()
})
$Form.Controls.Add($InstallButton)

# --------------------------------------------------------
# 5. 显示窗体
# --------------------------------------------------------
$Form.ShowDialog() | Out-Null