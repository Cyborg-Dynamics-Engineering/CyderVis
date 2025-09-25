mod can_parser;

use crate::can_parser::CanParser;
use crosscan::CanInterface;
use crosscan::can::CanFrame;
use godot::classes::{Node, ResourceLoader, Script};
use godot::prelude::*;
use std::collections::{HashMap, VecDeque};
use std::sync::Arc;
use std::time::{Duration, SystemTime};
use tokio::runtime::Runtime;
use tokio::sync::Mutex;

struct CanGDExtension;

// Assigns this file as the GDExtension entry-point
#[gdextension]
unsafe impl ExtensionLibrary for CanGDExtension {}

// Implement the GodotCanBridge as a Node for use inside Godot
#[derive(GodotClass)]
#[class(base=Node)]
struct GodotCanBridge {
    can_parser: can_parser::CanParser,
    read_handle: Option<tokio::task::JoinHandle<()>>,
    can_entries: Arc<Mutex<HashMap<CanId, CanEntry>>>,
    sending_queue: Arc<Mutex<VecDeque<CanFrame>>>,
    closure_requested: Arc<Mutex<bool>>,
    runtime: tokio::runtime::Runtime,

    base: Base<Node>,
}

struct CanEntry {
    timestamp: u128,
    freq_hz: f32,
    frame: CanFrame,
}

type CanId = u32;

#[godot_api]
impl INode for GodotCanBridge {
    // 'init' is called in Godot everytime the extension is loaded into the editor
    fn init(base: Base<Node>) -> Self {
        godot_print!("RUST CAN module loaded");

        Self {
            can_parser: CanParser::new(),
            read_handle: None,
            can_entries: Arc::new(Mutex::new(HashMap::<CanId, CanEntry>::new())),
            sending_queue: Arc::new(Mutex::new(VecDeque::<CanFrame>::new())),
            closure_requested: Arc::new(Mutex::new(false)),
            runtime: Runtime::new().unwrap(),
            base,
        }
    }
}

#[godot_api]
impl GodotCanBridge {
    #[func]
    fn load_dbc_file(&mut self, dbc_filepath: String) -> bool {
        // Empty filepath, assume user does not have a DBC file
        if dbc_filepath.trim().is_empty() {
            self.can_parser.clear_dbc();
            return true;
        }

        match self.can_parser.open_dbc(dbc_filepath.clone()) {
            Ok(_) => {
                godot_print!("Loaded DBC file from [{:?}]", dbc_filepath);
                true
            }
            Err(e) => {
                match e {
                    can_parser::Error::Io(error) => {
                        error_alert_godot(format!("Error trying to open DBC file: {:?}", error))
                    }
                    can_parser::Error::CanDbc() => {
                        error_alert_godot(format!("DBC File failed to parse"))
                    }
                }
                false
            }
        }
    }

    #[func]
    fn configure_bus(&mut self, interface_name: String) -> bool {
        // Check if multithreading is functional in this godot-rust version
        if let Err(err) = std::thread::spawn(|| {
            godot_print!("RUST threading successful");
        })
        .join()
        {
            let msg = match err.downcast_ref::<&'static str>() {
                Some(s) => *s,
                None => match err.downcast_ref::<String>() {
                    Some(s) => &s[..],
                    None => "Sorry, unknown payload type",
                },
            };
            error_alert_godot(format!("Error when attempting to thread: {:?}", msg));
        }

        // Create the CAN read/write thread
        let _guard = self.runtime.enter();
        let can_entries = Arc::clone(&self.can_entries);
        let sending_queue = Arc::clone(&self.sending_queue);
        let closure_requested = Arc::clone(&self.closure_requested);
        self.read_handle = Some(tokio::spawn(async {
            read_can(
                interface_name,
                can_entries,
                sending_queue,
                closure_requested,
            )
            .await;
        }));

        godot_print!("CAN bus opened");
        return true;
    }

    #[func]
    fn get_can_table(&mut self) -> VariantArray {
        self.can_parser
            .parse_can_table(&self.runtime.block_on(self.can_entries.lock()))
    }

    #[func]
    fn clear_can_table(&mut self) {
        self.runtime.block_on(self.can_entries.lock()).clear();
    }

    #[func]
    fn clear_can_entry(&mut self, can_id_value: u32) {
        self.runtime
            .block_on(self.can_entries.lock())
            .remove_entry(&can_id_value);
    }

    #[func]
    fn send_can_frame(&mut self, can_id_value: u32, is_extended: bool, data: VariantArray) {
        // Convert from Godot Variant to typed u8 vector
        let packed_bytes = PackedByteArray::from(&data);
        let byte_slice_data: &[u8] = packed_bytes.as_slice();

        // Create a CAN data frame with the ID and some data (up to 8 bytes for a standard CAN frame)
        let frame = if is_extended {
            CanFrame::new_eff(can_id_value, &byte_slice_data).unwrap()
        } else {
            CanFrame::new(can_id_value, &byte_slice_data).unwrap()
        };

        self.runtime
            .block_on(self.sending_queue.lock())
            .push_back(frame);
    }

    #[func]
    fn close_bus(&mut self) {
        if let Some(handle) = self.read_handle.take() {
            // Flag the thread to end
            *self.runtime.block_on(self.closure_requested.lock()) = true;

            // Wait for thread to complete
            self.runtime.block_on(handle).unwrap();

            godot_print!("CAN bus closed");
        } else {
            error_alert_godot("Attempted to close a nonexistent CAN connection".to_string());
        }
    }

    #[func]
    fn is_alive(&mut self) -> bool {
        if let Some(handle) = &self.read_handle {
            return !handle.is_finished();
        }
        false
    }
}

async fn read_can(
    interface_name: String,
    can_entries: Arc<Mutex<HashMap<CanId, CanEntry>>>,
    sending_queue: Arc<Mutex<VecDeque<CanFrame>>>,
    closure_requested: Arc<Mutex<bool>>,
) {
    // Select a specific CAN Socket implementation for the supported operating systems
    #[cfg(target_os = "linux")]
    use crosscan::lin_can::LinuxCan as CanSocket;

    #[cfg(target_os = "windows")]
    use crosscan::win_can::WindowsCan as CanSocket;

    // Open async CAN socket
    let mut socket = match CanSocket::open(&interface_name) {
        Ok(sock) => sock,
        Err(err) => {
            error_alert_godot(format!("Failed to open CAN socket: {err:?}"));
            return;
        }
    };

    loop {
        // Process outgoing CAN messages
        {
            let mut frames_to_send = sending_queue.lock().await;
            for frame in frames_to_send.clone().into_iter() {
                socket.write_frame(frame).await.unwrap();
            }
            frames_to_send.clear();
        }

        // Check if the bus should be closed
        {
            let mut should_close = closure_requested.lock().await;
            if *should_close {
                *should_close = false;

                // Breaks out of the loop, ending the thread
                break;
            }
        }

        // Read a CanFrame. If none found within timeout, continue the loop (rechecks for outgoing or closing requests then try again)
        let res = match tokio::time::timeout(Duration::from_millis(100), socket.read_frame()).await
        {
            Ok(res) => res,
            Err(_) => continue,
        };

        // Process the incoming CanFrame
        match res {
            Ok(frame) => {
                let current_timestamp_us = match SystemTime::UNIX_EPOCH.elapsed() {
                    Ok(system_time) => system_time.as_micros(),
                    Err(error) => {
                        error_alert_godot(format!(
                            "A system time error occured during CAN frame decoding: {error}"
                        ));
                        return;
                    }
                };

                let mut can_entries = can_entries.lock().await;
                match can_entries.entry(frame.id()) {
                    // If we've received this CAN ID before, update the existing entry and calculate frequency
                    std::collections::hash_map::Entry::Occupied(mut occupied_entry) => {
                        let can_entry = occupied_entry.get_mut();

                        // Calculate the frequency between the previous two messages
                        let last_timestamp_us = can_entry.timestamp;
                        let new_freq_hz = 1e6 / ((current_timestamp_us - last_timestamp_us) as f32);
                        can_entry.timestamp = current_timestamp_us;

                        // Apply exponential filter to existing frequency
                        const ALPHA: f32 = 0.9;
                        can_entry.freq_hz =
                            (ALPHA * new_freq_hz) + (1.0 - ALPHA) * can_entry.freq_hz;

                        can_entry.frame = frame;
                    }

                    // If this is a new CAN ID
                    std::collections::hash_map::Entry::Vacant(entry) => {
                        // Use frequency of 0.0 (Unable to calculate frequency)
                        entry.insert(CanEntry {
                            timestamp: current_timestamp_us,
                            freq_hz: 0.0,
                            frame: frame,
                        });
                    }
                }
            }
            Err(err) => {
                error_alert_godot(format!("Received CAN error: {:?}", err));
                break;
            }
        }
    }
}

// Sends an error popup to the user in Godot and logs the error to the Godot standard output
fn error_alert_godot(msg: String) {
    let mut script = ResourceLoader::singleton()
        .load("res://assets/alert_handler.gd")
        .unwrap()
        .cast::<Script>();

    let args = &[msg.to_variant()];
    script.call_deferred("display_error", args);

    godot_error!("{:?}", msg);
}
