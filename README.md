# CyderVis - A CAN Visualization tool for Windows & Linux

Cyder-Vis is an open-source visualizer and debugger for CAN bus networks. It helps engineers and developers receive, decode, transmit, and plot CAN messages for debugging and diagnostics.

<p align="center">
    <img src="godot/screenshot.png" width="50%">
</p>

## Documentation

For installation and usage instructions, read the docs!
**Link:** https://cyborg-dynamics-engineering.github.io/cyder-vis/

## License

Cyder Vis is licensed under either of

    Apache License, Version 2.0 (LICENSE-APACHE or http://www.apache.org/licenses/LICENSE-2.0)
    MIT license (LICENSE-MIT or http://opensource.org/licenses/MIT)


## Developers

### Project Structure

The visualiser tool is Godot based, with the Godot project located in the `godot/` directory. The `gdextension_can_io/` directory contains a rust-based GDExtension that provides a CAN interface node to Godot projects. The extension supports deserialisation of known CAN messages through the [CAN DBC](https://www.csselectronics.com/pages/can-dbc-file-database-intro) file format.

### Setup

- Ensure the all repo files are updated,

```bash
git lfs pull && git lfs checkout
```

- Install [Rust](https://www.rust-lang.org/tools/install) **(You may need to restart your computer on windows)**
- Build the CAN IO GDExtension with,

```bash
cd gdextension_can_io
cargo build
```

- Download the latest [Godot Editor](https://godotengine.org/)
- Open the project in the Godot editor. The project file can be found under `godot/project.godot`. Press `F5` or click the play button on the top right to run the project.

at your option.

### Contribution

Unless you explicitly state otherwise, any contribution intentionally submitted for inclusion in the work by you, as defined in the Apache-2.0 license, shall be dual licensed as above, without any additional terms or conditions.
