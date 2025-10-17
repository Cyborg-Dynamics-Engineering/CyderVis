# Getting Started on Linux

This guide walks you through setting up and running **CyderVis** on Linux.

## Step 1: Download and Run CyderVis

1. Visit the [CyderVis Releases](https://github.com/Cyborg-Dynamics-Engineering/cyder-vis/releases) page on GitHub.  
2. Under the latest release, expand the **Assets** dropdown and download the Linux `.zip` package.

   ![Releases](images/releases_linux.png)

3. Extract the downloaded `.zip` file to your preferred location.  
4. Run the executable:

   ```bash
   ./CyderVis_vx.x.x_linux
   ```

Once launched, the **CyderVis** window will open:

![CyderVis Open](images/cydervis_opened.png)

---

## Step 2: Bring up a CAN interface

With your USB CAN adapter connected, bring up the CAN interface using the `ip` command:

```bash
sudo ip link set can0 up type can bitrate 1000000
```

This starts the `can0` interface at a bitrate of 1 Mbps.

You can verify the interface is active using:

```bash
ip link show can0
```

By default, CAN devices have a tx queue length of 10. If sending many messages at a fast rate, it's usually a good idea to increase this. After bringing the interface up, the tx queue length can be increased using:

```bash
sudo ip link set can0 txqueuelen 1000
```

> ⚙️ **Note:**  
> Replace `can0` and `1000000` with your actual interface name and bitrate if different.

---

## Step 3: Connect and Receive Data in CyderVis

1. In **CyderVis**, locate the **CAN Interface** input field.  
2. Verify that the interface name matches the one brought up in the previous step (default is `can0`).  
3. Click **Start** to begin receiving data from the CAN adapter.

If other devices are active on the bus, incoming CAN frames will begin streaming into CyderVis and appear in the viewing table.

![CyderVis Streaming](images/cydervis_streaming.png)

---

## Step 4: Adjust Display Options

Use the display option toggles to customize how CAN data is displayed.  
These toggles control message formatting and visualization preferences.

![CyderVis Display Options](images/cydervis_display_options.png)

---

## Step 5: Load a `.dbc` File to Decode Frames

A **DBC file** defines how to decode CAN frames into human-readable signals.  
You can learn more about the DBC format here:  
<https://docs.openvehicles.com/en/latest/components/vehicle_dbc/docs/dbc-primer.html>

We provide example `.dbc` files for Cyder products at:  
<https://github.com/cyborg-dynamics-engineering/cyder-vis/tree/main/gdextension_can_io/examples>

To load a `.dbc` file:
1. Click **Open** next to the **DBC File** dialog.
2. Select your `.dbc` file.
3. Once loaded, decoded frames will automatically appear in the viewing table.

![CyderVis Decoded Frames](images/cydervis_decoded_frames.png)

---

## Step 6: Plotting Decoded Data

1. Open the **Plot** tab.  
2. Click on any decoded variable name in the viewing table to toggle it on or off in the plot view.

![CyderVis Plotting](images/cydervis_plotting.png)

> 💡 **Note:**  
> Data must be decoded using a .dbc file to enable plotting.

---

## Step 7: Transmitting Frames

1. Open the **Transmit** tab.
2. Press 'Add New' to create a new message.
3. Fill out the Cycle Time, Frame ID and Data fields.
4. Click the 'Send' checkbox to begin transmitting.

> 💡 **Notes:**  
> 1. A **Cycle Time** of `0` designates a *one-shot* message — it sends once each time you click the **Send** checkbox.  
> 2. Frame ID values above `0x7FF` are always treated as *extended IDs*.  
>    To designate IDs below `0x7FF`, add leading zeros:  
>    - `0x7FF` → standard ID  
>    - `0x07FF` → extended ID  
>    - `0x000` → standard ID  
>    - `0x0000` → extended ID

## Troubleshooting

- **CyderVis doesn’t connect:**  
  Ensure the `canserver` is running and the interface name matches (e.g., `can0`).

---