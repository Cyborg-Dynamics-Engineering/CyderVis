mod can_parser;

use crate::can_parser::CanParser;
use godot::classes::{Node, ResourceLoader, Script};
use godot::prelude::*;
use nb;
use socketcan::{
    CanDataFrame, CanFrame, CanId, CanInterface, CanSocket, EmbeddedFrame, ExtendedId, Frame,
    NonBlockingCan, Socket, StandardId,
};
use std::collections::{HashMap, VecDeque};
use std::sync::{Arc, Mutex};
use std::thread;
use std::time::{Duration, SystemTime};

struct CanGDExtension;

// Assigns this file as the GDExtension entry-point
#[gdextension]
unsafe impl ExtensionLibrary for CanGDExtension {}

// Implement the GodotCanBridge as a Node for use inside Godot
#[derive(GodotClass)]
#[class(base=Node)]
struct GodotCanBridge {
    can_parser: can_parser::CanParser,
    read_handle: Option<thread::JoinHandle<()>>,
    can_entries: Arc<Mutex<HashMap<CanId, CanEntry>>>,
    sending_queue: Arc<Mutex<VecDeque<CanFrame>>>,
    closure_requested: Arc<Mutex<bool>>,

    base: Base<Node>,
}

struct CanEntry {
    timestamp: u128,
    freq_hz: f32,
    frame: CanDataFrame,
}

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
        // Open the CAN interface
        let interface = match CanInterface::open(&interface_name) {
            Ok(val) => val,
            Err(e) => {
                error_alert_godot(format!("Could not open CAN interface: {e}"));
                return false;
            }
        };

        // Configure CAN interface if required - bring down, set bitrate, bring up
        let bitrate: Option<u32> = None;
        if let Some(br) = bitrate {
            interface.bring_down().unwrap_or_else(|e| {
                error_alert_godot(format!("Cannnot bring down interface: {e}"));
            });
            interface.set_bitrate(br, None).unwrap_or_else(|e| {
                error_alert_godot(format!("Cannnot set bitrate: {e} (If using a vcan interface, bringing down the interface to modify the bitrate will crash the bridge)"));
            });
            interface.bring_up().unwrap_or_else(|e| {
                error_alert_godot(format!("Cannnot bring up interface: {e}"));
            });
        }

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

        // Create the CAN read thread
        self.read_handle = Some(thread::spawn({
            let can_entries = Arc::clone(&self.can_entries);
            let sending_queue = Arc::clone(&self.sending_queue);
            let closure_requested = Arc::clone(&self.closure_requested);
            move || {
                read_can(
                    interface_name,
                    can_entries,
                    sending_queue,
                    closure_requested,
                );
            }
        }));

        godot_print!("CAN bus opened");
        return true;
    }

    #[func]
    fn get_can_table(&mut self) -> VariantArray {
        self.can_parser
            .parse_can_table(&self.can_entries.lock().unwrap())
    }

    #[func]
    fn send_standard_can(&mut self, can_id_value: u16, data: VariantArray) {
        // Create a standard CAN ID (e.g., 0x123)
        let can_id = match StandardId::new(can_id_value) {
            Some(id) => id,
            None => {
                eprintln!("Could not resolve {can_id_value} into a Standard CAN ID");
                return;
            }
        };

        // Convert from Godot Variant to typed u8 vector
        let packed_bytes = PackedByteArray::from(&data);
        let byte_slice_data: &[u8] = packed_bytes.as_slice();

        // Create a CAN data frame with the ID and some data (up to 8 bytes for a standard CAN frame)
        let frame = match CanFrame::new(can_id, &byte_slice_data) {
            Some(can_frame) => can_frame,
            None => {
                eprintln!("Could not parse data for message: {can_id_value}");
                return;
            }
        };

        self.sending_queue.lock().unwrap().push_back(frame);
    }

    #[func]
    fn send_extended_can(&mut self, can_id_value: u32, data: VariantArray) {
        // Create an extended CAN ID (e.g., 0x12345678)
        let can_id = match ExtendedId::new(can_id_value) {
            Some(id) => id,
            None => {
                eprintln!("Could not resolve {can_id_value} into an Extended CAN ID");
                return;
            }
        };

        // Convert from Godot Variant to typed u8 vector
        let packed_bytes = PackedByteArray::from(&data);
        let byte_slice_data: &[u8] = packed_bytes.as_slice();

        // Create a CAN data frame with the ID and some data (up to 8 bytes for a standard CAN frame)
        let frame = match CanFrame::new(can_id, &byte_slice_data) {
            Some(can_frame) => can_frame,
            None => {
                eprintln!("Could not parse data for message: {can_id_value}");
                return;
            }
        };

        self.sending_queue.lock().unwrap().push_back(frame);
    }

    #[func]
    fn close_bus(&mut self) {
        if let Some(handle) = self.read_handle.take() {
            // Flag the thread to end
            *self.closure_requested.lock().unwrap() = true;

            // Wait for thread to complete
            handle.join().unwrap();

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

fn read_can(
    interface_name: String,
    can_entries: Arc<Mutex<HashMap<CanId, CanEntry>>>,
    sending_queue: Arc<Mutex<VecDeque<CanFrame>>>,
    closure_requested: Arc<Mutex<bool>>,
) {
    // Open async CAN socket
    let mut socket = match CanSocket::open(&interface_name) {
        Ok(sock) => sock,
        Err(err) => {
            error_alert_godot(format!("Failed to open CAN socket: {err:?}"));
            return;
        }
    };

    match socket.set_nonblocking(true) {
        Ok(_) => {}
        Err(err) => {
            error_alert_godot(format!("Failed to configure CAN socket: {err:?}"));
            return;
        }
    }

    loop {
        // Process outgoing CAN messages
        match sending_queue.lock() {
            Ok(mut frames_to_send) => {
                for frame in frames_to_send.iter() {
                    socket.transmit(frame).unwrap();
                }
                frames_to_send.clear();
            }
            Err(err) => error_alert_godot(format!("Received Mutex poison error: {:?}", err)),
        }

        // Check if the bus should be closed
        match closure_requested.lock() {
            Ok(mut should_close) => {
                if *should_close {
                    *should_close = false;

                    // Breaks out of the loop, ending the thread
                    break;
                }
            }
            Err(err) => error_alert_godot(format!("Received Mutex poison error: {:?}", err)),
        }

        // Process incoming CAN messages
        let res = socket.receive();
        match res {
            Ok(CanFrame::Data(frame)) => {
                let current_timestamp_us = match SystemTime::UNIX_EPOCH.elapsed() {
                    Ok(system_time) => system_time.as_micros(),
                    Err(error) => {
                        error_alert_godot(format!(
                            "A system time error occured during CAN frame decoding: {error}"
                        ));
                        return;
                    }
                };

                let mut can_entries = can_entries.lock().unwrap();
                match can_entries.entry(frame.can_id()) {
                    // If we've received this CAN ID before, update the existing entry and calculate frequency
                    std::collections::hash_map::Entry::Occupied(mut occupied_entry) => {
                        let can_entry = occupied_entry.get_mut();

                        let last_timestamp_us = can_entry.timestamp;
                        can_entry.freq_hz =
                            1e6 / ((current_timestamp_us - last_timestamp_us) as f32);
                        can_entry.timestamp = current_timestamp_us;
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
            Err(nb::Error::WouldBlock) => {
                thread::sleep(Duration::from_millis(50));
            }
            Err(err) => {
                error_alert_godot(format!("Received CAN error: {:?}", err));
                break;
            }
            Ok(CanFrame::Remote(frame)) => eprintln!("Remote frame: {frame:?}"),
            Ok(CanFrame::Error(frame)) => eprintln!("Error frame: {frame:?}"),
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
