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

# 源选择窗口
function Show-SourceSelectionDialog {
  $SourceForm = New-Object System.Windows.Forms.Form
  $SourceForm.Text = "安装项目 - 请选择安装源"
  $SourceForm.Size = New-Object System.Drawing.Size(350, 250)
  $SourceForm.StartPosition = "CenterScreen"
  $SourceForm.FormBorderStyle = [System.Windows.Forms.FormBorderStyle]::FixedDialog
  $SourceForm.MaximizeBox = $false
  $SourceForm.MinimizeBox = $false
  $SourceForm.ControlBox = $true
  # 使用 Tag 属性在事件处理程序和函数返回之间传递选定的 URL
  $SourceForm.Tag = $null

  $GroupBox = New-Object System.Windows.Forms.GroupBox
  $GroupBox.Text = "请选择 Git 仓库源"
  $GroupBox.Location = New-Object System.Drawing.Point(20, 10)
  $GroupBox.Size = New-Object System.Drawing.Size(300, 150)
  $SourceForm.Controls.Add($GroupBox)

  $Sources = [ordered]@{
    "GitHub（国外推荐）" = "github.com";
    "Gitee（国内推荐）" = "gitee.com";
    "GitCode" = "gitcode.com"
  }
  $RadioButtons = @()
  $Y = 30

  foreach ($Name in $Sources.Keys) {
    $RadioButton = New-Object System.Windows.Forms.RadioButton
    $RadioButton.Text = $Name
    $RadioButton.Tag = $Sources[$Name] # Store URL in Tag
    $RadioButton.Location = New-Object System.Drawing.Point(10, $Y)
    $RadioButton.AutoSize = $true
    $GroupBox.Controls.Add($RadioButton)
    $RadioButtons += $RadioButton
    $Y += 30
  }

  # 默认选择 Gitee
  $RadioButtons[1].Checked = $true

  # 确认按钮
  $OkButton = New-Object System.Windows.Forms.Button
  $OkButton.Text = "确认"
  $OkButton.Location = New-Object System.Drawing.Point(165, 170)
  $OkButton.Size = New-Object System.Drawing.Size(75, 30)
  $OkButton.Add_Click({
    foreach ($RB in $RadioButtons) {
      if ($RB.Checked) {
        $SourceForm.Tag = $RB.Tag
        break
      }
    }
    $SourceForm.DialogResult = [System.Windows.Forms.DialogResult]::OK
  })
  $SourceForm.Controls.Add($OkButton)

  # 取消按钮
  $CancelButton = New-Object System.Windows.Forms.Button
  $CancelButton.Text = "取消"
  $CancelButton.Location = New-Object System.Drawing.Point(245, 170)
  $CancelButton.Size = New-Object System.Drawing.Size(75, 30)
  $CancelButton.Add_Click({
    $SourceForm.DialogResult = [System.Windows.Forms.DialogResult]::Cancel
  })
  $SourceForm.Controls.Add($CancelButton)

  $Result = $SourceForm.ShowDialog()

  if ($Result -eq [System.Windows.Forms.DialogResult]::OK) {
    return $SourceForm.Tag
  } else {
    return $null
  }
}

# --------------------------------------------------------
# 3. 创建主窗体 (Form)
# --------------------------------------------------------
$Form = New-Object System.Windows.Forms.Form
$Form.Text = "$SourceFolderName 安装程序"
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
  $SourcePath = Join-Path (Get-Location) ($SourceFolderName + ".7z")

  if ($DestinationPath -match '[^\x00-\x7F]')  {
    $MsgResult = [System.Windows.Forms.MessageBox]::Show("路径包含特殊字符，可能会导致问题，是否继续？", "警告", [System.Windows.Forms.MessageBoxButtons]::YesNo, [System.Windows.Forms.MessageBoxIcon]::Warning)
    if ($MsgResult -eq [System.Windows.Forms.DialogResult]::No) {
      return
    }
  }

  # 检查目标文件夹是否已存在，如果存在则询问是否覆盖、保留数据
  $KeepDataResult = $null
  if (Test-Path $DestinationPath) {
    $MsgResult = [System.Windows.Forms.MessageBox]::Show("目标文件夹已存在，是否覆盖？", "警告", [System.Windows.Forms.MessageBoxButtons]::YesNo, [System.Windows.Forms.MessageBoxIcon]::Warning)
    if ($MsgResult -eq [System.Windows.Forms.DialogResult]::No) {
      return # 用户选择不覆盖，取消操作
    }

    if (Test-Path (Join-Path $DestinationPath "app") -Type Container) {
      $KeepDataResult = [System.Windows.Forms.MessageBox]::Show("是否保留数据？", "警告", [System.Windows.Forms.MessageBoxButtons]::YesNo, [System.Windows.Forms.MessageBoxIcon]::Warning)
    }
  }

  # 选择仓库源
  if ($KeepDataResult -ne [System.Windows.Forms.DialogResult]::Yes) {
    $SelectedURL = Show-SourceSelectionDialog
    if (-not $SelectedURL) {
      return
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
      if ($KeepDataResult -eq [System.Windows.Forms.DialogResult]::Yes) {
        Get-ChildItem -Path $DestinationPath -Exclude "app" | Remove-Item -Recurse -Force
      } else {
        Remove-Item -Path $DestinationPath -Recurse -Force
      }
    }

    $StatusLabel.Text = "正在释放文件..."
    $ProgressBar.Value = 10
    $ProgressForm.Refresh()
    & (Join-Path (Get-Location) "7z.exe") x ("-o" + $DestinationPath) $SourcePath | Write-Host
    if ($LASTEXITCODE -ne 0) {
      throw "释放错误 ($LASTEXITCODE) 请检查控制台"
    }

    $StatusLabel.Text = "正在安装程序..."
    $ProgressBar.Value = 40
    $ProgressForm.Refresh()
    $Msys2Command = '""'
    & (Join-Path $DestinationPath "msys2_shell.cmd") -defterm -here -no-start -ucrt64 -c $Msys2Command | Write-Host

    $StatusLabel.Text = "正在安装项目..."
    $ProgressBar.Value = 70
    $ProgressForm.Refresh()
    if ($SelectedURL) {
      $Msys2Command = """git clone --depth 1 https://$SelectedURL/TimeRainStarSky/Yunzai /app && cd /app && pnpm i"""
    }
    & (Join-Path $DestinationPath "msys2_shell.cmd") -defterm -here -no-start -ucrt64 -c $Msys2Command | Write-Host
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
    $ShortCut.Arguments = "-defterm -here -no-start -ucrt64 -c fish"
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
      if ($KeepDataResult -eq [System.Windows.Forms.DialogResult]::Yes) {
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
Write-Host "请查看弹出的安装程序窗口。"
$Form.ShowDialog() | Out-Null