use colored::*;
use shared_child::SharedChild;
use std::ffi::CStr;
use std::os::raw::c_char;
use std::process::{Command, exit};
use std::sync::{Arc, Mutex};
use ctrlc;

#[cfg(target_os = "windows")]
const SHELL: &str = "cmd";

#[cfg(any(target_os = "macos", target_os = "linux"))]
const SHELL: &str = "bash";

#[cfg(target_os = "windows")]
const OPTION: &str = "/C";

#[cfg(any(target_os = "macos", target_os = "linux"))]
const OPTION: &str = "-c";

#[no_mangle]
pub extern "C" fn run_script(ptr: *const c_char) -> i32 {
    let script = unsafe { CStr::from_ptr(ptr).to_string_lossy() };

    println!("$ {}", script.dimmed());
    println!("");

    let mut binding = Command::new(SHELL);
    let mut child = binding.arg(OPTION).arg(script.as_ref());

    let child_shared = match SharedChild::spawn(&mut child) {
        Ok(child) => child,
        Err(_) => {
            eprintln!("Failed to spawn the child process");
            exit(1);
        }
    };

    let child_arc = Arc::new(Mutex::new(Some(child_shared)));
    let child_arc_clone = Arc::clone(&child_arc);

    let _ = ctrlc::set_handler(move || {
        if let Some(child) = child_arc_clone.lock().unwrap().take() {
            if let Err(_) = child.kill() {
                eprintln!("Failed to kill the process");
            }
            println!();
        }
        exit(69);
    });

    let status = match child_arc.lock().unwrap().as_mut().unwrap().wait() {
        Ok(status) => status,
        Err(_) => {
            eprintln!("Failed to await the process");
            exit(1);
        }
    };

    status.code().unwrap_or(1)
}
