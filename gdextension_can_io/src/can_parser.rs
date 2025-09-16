use crate::{CanEntry, CanId};
use can_dbc::{ByteOrder, DBC};
use core::panic;
use crosscan::can::CanFrame;
use godot::builtin::{GString, VariantArray};
use godot::prelude::*;
use std::collections::HashMap;
use std::fs::File;
use std::io::prelude::*;

#[derive(Debug)]
pub enum Error {
    Io(std::io::Error),
    CanDbc(),
}

impl From<std::io::Error> for Error {
    fn from(e: std::io::Error) -> Self {
        Error::Io(e)
    }
}

pub struct CanParser {
    dbc: Option<DBC>,
}

impl CanParser {
    pub fn new() -> Self {
        return Self { dbc: None };
    }

    /// Loads a new DBC file into the CanParser for future deserialisation
    pub fn open_dbc(&mut self, file_path: String) -> Result<(), Error> {
        let mut file = File::open(file_path)?;
        let mut buffer = Vec::new();
        file.read_to_end(&mut buffer)?;

        match DBC::from_slice(&buffer) {
            Ok(dbc) => {
                self.dbc = Some(dbc);
                Ok(())
            }
            Err(_) => Err(Error::CanDbc()),
        }
    }

    /// Clears the DBC file if one is currently loaded in
    pub fn clear_dbc(&mut self) {
        self.dbc = None
    }

    /// Parses a set of CanDataFrames into a table of Godot CAN entries. Will optionally use a DBC for deserialisation if provided.
    pub fn parse_can_table(&self, can_entries: &HashMap<CanId, CanEntry>) -> Array<Variant> {
        let mut godot_can_table = VariantArray::new();

        for (_, entry) in can_entries.iter() {
            let godot_can_entry = &self.parse_can_entry(entry).to_variant();
            godot_can_table.push(godot_can_entry);
        }

        godot_can_table
    }

    /// Parses a given CanEntry into a Godot CAN entry. Will optionally use a DBC for deserialisation if provided.
    fn parse_can_entry(&self, can_entry: &CanEntry) -> Array<Variant> {
        let mut godot_can_entry = VariantArray::new();

        godot_can_entry.push(&GString::from(format!("{:?}", can_entry.timestamp)).to_variant());
        godot_can_entry.push(&GString::from(format!("{:?}", can_entry.freq_hz)).to_variant());
        godot_can_entry.push(&GString::from(format!("{:?}", can_entry.frame.id())).to_variant());

        // Search for a message in the DBC to deserialise this CAN frame
        let mut message_id_found_in_dbc = false;
        if let Some(dbc) = &self.dbc {
            for message_info in dbc.messages() {
                let mut id_with_ext_bit = can_entry.frame.id();
                if can_entry.frame.is_extended() {
                    id_with_ext_bit |= 1 << 31
                }
                message_id_found_in_dbc = id_with_ext_bit == message_info.message_id().raw();
                if message_id_found_in_dbc {
                    godot_can_entry.push(&GString::from(message_info.message_name()).to_variant());
                    godot_can_entry = self.deserialise_dbc_data(
                        godot_can_entry,
                        can_entry.frame.clone(),
                        message_info,
                    );
                    break;
                }
            }
        }

        // If none were found, deserialise as raw bytes
        if !message_id_found_in_dbc {
            godot_can_entry.push(&GString::from("").to_variant()); // Empty msg name to indicate no definition in the DBC
            godot_can_entry =
                Self::deserialise_unknown_data(godot_can_entry, can_entry.frame.clone());
        }

        // The last element indicates to Godot whether the frame is Extended
        godot_can_entry
            .push(&GString::from(format!("{:?}", can_entry.frame.is_extended())).to_variant());

        godot_can_entry
    }

    /// Deserialises and appends the data from the CAN frame into the Godot CAN entry
    fn deserialise_dbc_data(
        &self,
        mut godot_can_entry: Array<Variant>,
        frame: CanFrame,
        message_info: &can_dbc::Message,
    ) -> Array<Variant> {
        for signal in message_info.signals() {
            godot_can_entry.push(&GString::from(signal.name()).to_variant());

            let dbc = match &self.dbc {
                Some(table) => table,
                None => {
                    panic!("Attempted to deserialise data using DBC when no DBC table has been set")
                }
            };

            let mut bytes = frame.data().to_vec();
            if *signal.byte_order() == ByteOrder::BigEndian {
                CanParser::reverse_bit_order(&mut bytes);
            }

            let formatted_value = match dbc
                .extended_value_type_for_signal(*message_info.message_id(), signal.name())
                .unwrap_or(&can_dbc::SignalExtendedValueType::SignedOrUnsignedInteger)
            {
                can_dbc::SignalExtendedValueType::SignedOrUnsignedInteger => {
                    let start_bit = usize::try_from(*signal.start_bit()).unwrap();
                    let length = usize::try_from(*signal.signal_size()).unwrap();
                    match signal.value_type() {
                        can_dbc::ValueType::Signed => {
                            format!(
                                "{:?}",
                                CanParser::extract_bits_i64(bytes, start_bit, length)
                            )
                        }
                        can_dbc::ValueType::Unsigned => {
                            format!(
                                "{:?}",
                                CanParser::extract_bits_u64(bytes, start_bit, length)
                            )
                        }
                    }
                }
                can_dbc::SignalExtendedValueType::IEEEfloat32Bit => {
                    let start_bit = usize::try_from(*signal.start_bit()).unwrap();
                    let raw_value = CanParser::extract_bits_u64(bytes, start_bit, 32) as u32;
                    format!("{:?}", f32::from_bits(raw_value))
                }
                can_dbc::SignalExtendedValueType::IEEEdouble64bit => {
                    let start_bit = usize::try_from(*signal.start_bit()).unwrap();
                    let raw_value = CanParser::extract_bits_u64(bytes, start_bit, 64);
                    format!("{:?}", f64::from_bits(raw_value))
                }
            };
            godot_can_entry.push(&GString::from(formatted_value).to_variant());
        }
        godot_can_entry
    }

    /// Deserialises and appends the raw byte data from the CAN frame to the Godot CAN entry
    fn deserialise_unknown_data(
        mut godot_can_entry: Array<Variant>,
        frame: CanFrame,
    ) -> Array<Variant> {
        for byte in frame.data() {
            godot_can_entry.push(&GString::from(format!("{:?}", byte)).to_variant())
        }
        godot_can_entry
    }

    fn reverse_bit_order(bytes: &mut Vec<u8>) {
        for byte in bytes.iter_mut() {
            *byte = byte.reverse_bits();
        }
    }

    // Extracts a u64 value from a data vector given the start bit and length. Assumes little-endian bit representation.
    fn extract_bits_u64(bytes: Vec<u8>, start_bit: usize, length: usize) -> u64 {
        assert!(bytes.len() <= 8, "Input slice must a maximum of 8 bytes");
        assert!(
            length <= (bytes.len() * 8),
            "Signal length exceeds data size"
        );
        assert!(
            start_bit + length <= (bytes.len() * 8),
            "Out of bounds bit extraction"
        );

        let mut bytes_buf = [0u8; 8];
        bytes_buf[..bytes.len()].copy_from_slice(&bytes[..bytes.len()]);

        let value = u64::from_le_bytes(bytes_buf);
        let mask = if length == 64 {
            u64::MAX
        } else {
            (1u64 << length) - 1
        };

        (value >> start_bit) & mask
    }

    // Extracts an i64 value from a data vector given the start bit and length. Assumes little-endian bit representation.
    fn extract_bits_i64(bytes: Vec<u8>, start_bit: usize, length: usize) -> i64 {
        let mut value = CanParser::extract_bits_u64(bytes, start_bit, length) as i64;

        // Sign extend if the most significant bit of the extracted value is set (two's complement)
        if value & (1 << (length - 1)) != 0 {
            value = value | (!0 << length);
        }

        value
    }
}
