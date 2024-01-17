use std::process::{Command, exit};
use std::ffi::CStr;
use std::os::raw::c_char;
use std::sync::{Arc, Mutex};
use ctrlc;
use colored::Colorize;

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
    let c_str = unsafe {
        assert!(!ptr.is_null());
        CStr::from_ptr(ptr)
    };

    let script = c_str.to_string_lossy();

    // Print the script dimmed
    println!("$ {}", script.dimmed());
    println!("");

    let mut child = Command::new(SHELL);
    child.arg(OPTION).arg(&*script);

    let child_process = Arc::new(Mutex::new(Some(child.spawn().expect("Error spawning the script"))));
    let child_process_clone = Arc::clone(&child_process);

    // Set up Ctrl+C handler
    let _ = ctrlc::set_handler(move || {
        let mut child_mutex = child_process_clone.lock().unwrap();
        if let Some(mut child) = child_mutex.take() {
            child.kill().expect("Error killing the process");
            println!();
        }
        exit(69);
    });

    let status = match child_process.lock().unwrap().as_mut().unwrap().try_wait() {
        Ok(Some(status)) => status.code().unwrap_or(1),
        Ok(None) => {
            match child_process.lock().unwrap().as_mut().unwrap().wait() {
                Ok(status) => status.code().unwrap_or(1),
                Err(err) => {
                    eprintln!("Error waiting for the script: {}", err);
                    exit(1);
                }
            }
        }
        Err(err) => {
            eprintln!("Error checking child process status: {}", err);
            exit(1);
        }
    };

    status
}
