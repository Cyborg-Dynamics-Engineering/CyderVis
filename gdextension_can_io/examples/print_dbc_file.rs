use can_dbc::DBC;
use std::fs::File;
use std::io;
use std::io::prelude::*;

fn main() -> io::Result<()> {
    let path = "./examples/sample.dbc";
    let mut dbc_file = File::open(path)?;
    let mut buffer = Vec::new();
    dbc_file.read_to_end(&mut buffer)?;

    let dbc = DBC::from_slice(&buffer).expect("Failed to parse dbc file");

    println!("Reading dbc file at: {:?}", path);

    for message in dbc.messages() {
        println!("====");
        println!("Name: {:?}", message.message_name());
        println!("Id: {:?}", message.message_id());
        println!("Size: {:?}", message.message_size());
        println!("Transmitter: {:?}", message.transmitter());
        for signal in message.signals() {
            let ext_type = dbc.extended_value_type_for_signal(*message.message_id(), signal.name());

            println!("  {:?}", signal);
            println!("      Type: {:?}", ext_type);
        }
    }

    Ok(())
}
