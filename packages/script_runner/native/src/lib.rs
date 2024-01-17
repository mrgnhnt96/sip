use colored::*;
use shared_child::SharedChild;
use std::ffi::CStr;
use std::os::raw::c_char;
use std::process::Command;
use std::sync::{Arc, Mutex};
use std::thread;

#[no_mangle]
pub extern "C" fn run_script(ptr: *const c_char) -> i32 {
    let c_str = unsafe { CStr::from_ptr(ptr) };
    let script: String = String::from(c_str.to_str().unwrap());

    println!("$ {}", script.dimmed());
    println!("");

    #[cfg(target_os = "windows")]
    let shell: &str = "cmd";

    #[cfg(not(target_os = "windows"))]
    let shell: &str = "bash";

    let option: &str = match shell {
        "cmd" => "/C",
        "bash" => "-c",
        _ => "",
    };

    let mut child = Command::new(shell);
    child.arg(option).arg(script);
    let child_shared =
        SharedChild::spawn(&mut child).expect("Rust: Couldn't spawn the shared_child process!");
    let child_arc = Arc::new(Mutex::new(Some(child_shared)));
    let child_arc_clone = Arc::clone(&child_arc);

    let handle = thread::spawn(move || {
        let _ = ctrlc::set_handler(move || {
            let mut child_mutex = child_arc.lock().unwrap();
            if let Some(child) = child_mutex.take() {
                child
                    .kill()
                    .expect("Rust: Couldn't kill the process!");
                println!();
            }
            std::process::exit(69); // Exit code for interrupt
        });

        let child_status = child_arc_clone.lock().unwrap().as_mut().unwrap().wait();
        match child_status {
            Ok(status) => {
                status.code().unwrap_or(1)
            }
            Err(err) => {
                let err_message = err.to_string();
                if err_message.contains("No child processes") {
                    // Child process has already terminated
                    0
                } else {
                    // Other error, return 1
                    1
                }
            }
        }
    });

    let result = handle.join().expect("Rust: Thread join failed");
    result
}
