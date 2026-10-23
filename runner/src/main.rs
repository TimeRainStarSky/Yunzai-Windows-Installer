#![windows_subsystem = "windows"]

use std::{
  env, fs,
  io::{Error, ErrorKind, Result},
  os::windows::process::CommandExt,
  path::{Path, PathBuf},
  process::Command,
};

use runner::{
  dialog_countdown::optionbox_countdown,
  {dialog, ok, okcancel, option, retry},
};
use windows_sys::Win32::System::Threading::{CREATE_NEW_CONSOLE, CREATE_NO_WINDOW};

const APP: &str = "Yunzai";
const OWNER: &str = "TimeRainStarSky";
const SOURCES: &[&str] = &["GitHub", "Gitee", "GitLab", "GitCode"];
const REPOS: &[&str] = &[
  "https://github.com",
  "https://gitee.com",
  "https://gitlab.com",
  "https://gitcode.com",
];

fn main() {
  // 1. 当前可执行文件所在文件夹；后续 git/node 都以此为工作目录
  let exe_dir = match env::current_exe()
    .ok()
    .and_then(|p| p.parent().map(Path::to_path_buf))
  {
    Some(p) => p,
    None => {
      ok!(
        dialog::Icon::Error,
        "启动失败",
        "无法定位可执行文件所在目录"
      );
      return;
    }
  };

  let app_dir = Path::new(APP);
  // 2. app 文件夹不存在 → 询问是否安装
  if !app_dir.exists() {
    if !okcancel!(
      "安装",
      &format!("是否安装 {APP} 到以下文件夹？"),
      &env::current_dir()
        .unwrap_or(PathBuf::from("."))
        .join(APP)
        .to_string_lossy()
    ) {
      return;
    }
    if !install(&exe_dir, app_dir) {
      return;
    }
  }

  // 3. 安装完成（或本来就存在）：3 秒后启动程序，按回车进入命令行
  let text = "{} 秒后启动程序，按回车进入命令行";
  match optionbox_countdown(
    dialog::Icon::Info,
    "启动程序",
    &format!("即将启动 {APP}"),
    Some(text.replace("{}", "3").as_str()),
    &["启动程序(&L)", "进入命令行(&C)"],
    Some(1), // 默认按钮 = 进入命令行（回车/确定）
    true,
    3, // 倒计时 3 秒
    0, // 超时自动点击「启动程序」
    text,
  ) {
    Some(0) => {
      start_msys2_shell(&exe_dir, "fastfetch; node .", app_dir);
    } // 启动程序
    Some(1) => {
      start_msys2_shell(&exe_dir, "fish", app_dir);
    } // 进入命令行
    _ => {} // 取消/关闭 → 直接退出
  }
}

/// 安装流程：选源 → 弹出控制台执行 git clone && pnpm i → 失败可重试/换源
fn install(exe_dir: &Path, app_dir: &Path) -> bool {
  loop {
    let src = option!(
      dialog::Icon::Info,
      "安装",
      "选择仓库源",
      "国内推荐 Gitee，国外推荐 GitHub",
      SOURCES
    );
    let Some(idx) = src else { return false }; // 取消选择 → 放弃安装

    let script = format!(
      "git clone --depth 1 \"{}/{OWNER}/{APP}\" \"{APP}\" && cd \"{APP}\" && pnpm i && exit; CODE=$?; echo -n \"安装失败！按回车键退出...\"; read; exit $CODE",
      REPOS[idx],
    );
    let err = match run_msys2_shell(exe_dir, &script) {
      Ok(()) => {
        if app_dir.exists() {
          return true;
        } else {
          Error::new(
            ErrorKind::NotFound,
            format!("命令执行完成，但 {APP} 文件夹不存在"),
          )
        }
      }
      Err(err) => {
        if app_dir.exists() {
          let _ = fs::remove_dir_all(app_dir);
        }
        err
      }
    };

    if retry!("安装失败", "安装失败，是否重试？", &err.to_string()) {
      continue;
    } else {
      return false;
    }
  }
}

/// 运行 MSYS2 Shell
fn run_msys2_shell(exe_dir: &Path, script: &str) -> Result<()> {
  Command::new("cmd")
    .args([
      "/c",
      &exe_dir.join("msys2_shell.cmd").to_string_lossy(),
      "-ucrt64",
      "-here",
      "-defterm",
      "-no-start",
      "-c",
      script,
    ])
    .creation_flags(CREATE_NEW_CONSOLE)
    .status()
    .and_then(|s| {
      if s.success() {
        Ok(())
      } else {
        Err(Error::new(
          ErrorKind::Interrupted,
          format!("进程退出码 {}", s.code().unwrap_or(0)),
        ))
      }
    })
}

/// 启动 MSYS2 Shell（不等待退出）
fn start_msys2_shell(exe_dir: &Path, script: &str, cwd: &Path) -> bool {
  if let Err(e) = Command::new("cmd")
    .args([
      "/c",
      &exe_dir.join("msys2_shell.cmd").to_string_lossy(),
      "-ucrt64",
      "-here",
      "-c",
      script,
    ])
    .creation_flags(CREATE_NO_WINDOW)
    .current_dir(cwd)
    .status()
    .and_then(|s| {
      if s.success() {
        Ok(())
      } else {
        Err(Error::new(
          ErrorKind::Interrupted,
          format!("进程退出码 {}", s.code().unwrap_or(0)),
        ))
      }
    })
  {
    ok!(
      dialog::Icon::Error,
      "执行失败",
      &format!("无法执行 {script}"),
      &e.to_string()
    );
    false
  } else {
    true
  }
}
