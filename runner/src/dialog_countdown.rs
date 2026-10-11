use std::ptr::{null, null_mut};

use windows_sys::Win32::{
  Foundation::{HWND, LPARAM, WPARAM},
  UI::{
    Controls::{
      TASKDIALOG_BUTTON, TASKDIALOGCONFIG, TASKDIALOGCONFIG_0, TDE_CONTENT,
      TDF_ALLOW_DIALOG_CANCELLATION, TDF_CALLBACK_TIMER, TDM_CLICK_BUTTON, TDM_UPDATE_ELEMENT_TEXT,
      TDN_TIMER, TaskDialogIndirect,
    },
    WindowsAndMessaging::SendMessageW,
  },
};

use crate::{StringConvert, dialog::Icon};

/// 倒计时状态，通过 `lpCallbackData` 传给回调
struct CountdownState<'a> {
  timeout_ms: u32,
  target_id: i32,
  template: &'a str,
  last_sec: u32,
}

/// TaskDialog 定时器回调：刷新正文剩余秒数，超时后自动点击目标按钮
///
/// 注意：绝不能跨 FFI 边界 panic
extern "system" fn countdown_callback(
  hwnd: HWND,
  msg: u32,
  wparam: WPARAM,
  _lparam: LPARAM,
  data: isize,
) -> i32 {
  if msg == TDN_TIMER as u32 && data != 0 {
    let state = unsafe { &mut *(data as *mut CountdownState) };
    let elapsed = wparam as u32;
    if elapsed >= state.timeout_ms {
      // 时间到：自动点击指定按钮
      unsafe { SendMessageW(hwnd, TDM_CLICK_BUTTON as u32, state.target_id as usize, 0) };
    } else {
      let remain = (state.timeout_ms - elapsed).div_ceil(1000);
      if remain != state.last_sec {
        state.last_sec = remain;
        let text = state.template.replace("{}", &remain.to_string());
        let wide = text.to_wide();
        unsafe {
          SendMessageW(
            hwnd,
            TDM_UPDATE_ELEMENT_TEXT as u32,
            TDE_CONTENT as usize,
            wide.as_ptr() as isize,
          )
        };
      }
    }
  }
  0 // S_OK
}

/// 带倒计时的自定义选项框
///
/// 在 [`optionbox`] 基础上：正文每秒刷新一次，把 `countdown_text` 中的 `{}`
/// 替换为剩余秒数；`countdown_secs` 秒后自动点击 `countdown_index` 对应的按钮。
/// 返回值含义与 [`optionbox`] 相同。
pub fn optionbox_countdown(
  icon: Icon,
  title: &str,
  head: &str,
  content: Option<&str>,
  options: &[&str],
  default_index: Option<usize>,
  allow_cancel: bool,
  countdown_secs: u32,
  countdown_index: usize,
  countdown_text: &str,
) -> Option<usize> {
  if options.is_empty() {
    return None;
  }
  let countdown_index = countdown_index.min(options.len() - 1);

  let title_w = title.to_wide();
  let head_w = head.to_wide();
  let content_w = content.map(|s| s.to_wide());
  let option_w: Vec<Vec<u16>> = options.iter().map(|s| s.to_wide()).collect();
  let buttons: Vec<TASKDIALOG_BUTTON> = option_w
    .iter()
    .enumerate()
    .map(|(i, text)| TASKDIALOG_BUTTON {
      nButtonID: 10 + i as i32,
      pszButtonText: text.as_ptr(),
    })
    .collect();

  let mut state = CountdownState {
    timeout_ms: countdown_secs.saturating_mul(1000),
    target_id: 10 + countdown_index as i32,
    template: countdown_text,
    last_sec: u32::MAX,
  };

  let config = TASKDIALOGCONFIG {
    cbSize: size_of::<TASKDIALOGCONFIG>() as u32,
    pszWindowTitle: title_w.as_ptr(),
    pszMainInstruction: head_w.as_ptr(),
    pszContent: content_w.as_ref().map_or(null(), |s| s.as_ptr()),
    cButtons: buttons.len() as u32,
    pButtons: buttons.as_ptr(),
    nDefaultButton: match default_index {
      Some(idx) if idx < options.len() => 10 + idx as i32,
      _ => buttons[0].nButtonID,
    },
    dwFlags: TDF_CALLBACK_TIMER
      | if allow_cancel {
        TDF_ALLOW_DIALOG_CANCELLATION
      } else {
        0
      },
    Anonymous1: TASKDIALOGCONFIG_0 {
      pszMainIcon: icon.into(),
    },
    pfCallback: Some(countdown_callback),
    lpCallbackData: &mut state as *mut CountdownState as isize,
    ..Default::default()
  };

  let mut res = 0;
  if let code = unsafe { TaskDialogIndirect(&config, &mut res, null_mut(), null_mut()) }
    && code < 0
  {
    panic!("TaskDialogIndirect 调用失败 {code}")
  }
  if res >= 10 {
    let idx = (res - 10) as usize;
    if idx < options.len() {
      return Some(idx);
    }
  }
  None
}
